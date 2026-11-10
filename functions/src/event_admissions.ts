/* eslint-disable valid-jsdoc */

import {randomBytes, createHash} from "node:crypto";

import {getFirestore, FieldValue} from "firebase-admin/firestore";

import {HttpsError, onCall} from "firebase-functions/v2/https";

const REGION = "asia-southeast1";

const MAX_INVITATIONS_PER_REQUEST = 200;
const ACTIVE_EMAIL_SEND_WINDOW_MS = 10 * 60 * 1000;

const db = getFirestore();

type AdmissionSource = "invitation" | "walk_in";

/** Trims a value when it is a string. */
function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

/** Normalizes a role name for role checks. */
function normalizedRole(value: unknown): string {
  return text(value).toLowerCase();
}

/** Normalizes a status and defaults missing statuses to approved. */
function normalizedStatus(value: unknown): string {
  return text(value || "approved").toLowerCase();
}

/** Returns whether a user or event record is approved. */
function isApproved(value: unknown): boolean {
  return normalizedStatus(value) === "approved";
}

/** Validates a Firestore document ID argument. */
function validDocumentId(value: unknown, label: string): string {
  if (

    typeof value !== "string" ||

    !value.trim() ||

    value.includes("/") ||

    value.length > 1500

  ) {
    throw new HttpsError("invalid-argument", `A valid ${label} is required.`);
  }

  return value.trim();
}

/** Validates and lowercases a participant email address. */
function normalizeEmail(value: unknown): string {
  const email = typeof value === "string" ? value
    .normalize("NFKC")
    .replace(/[\u200B-\u200F\u202A-\u202E\u2060-\u206F\uFEFF]/g, "")
    .replace(/\u00A0/g, " ")
    .trim()
    .toLowerCase() : "";

  if (

    email.length > 254 ||

    [...email].some((character) => character.charCodeAt(0) > 0x7F) ||

    !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)

  ) {
    throw new HttpsError(
      "invalid-argument",
      "Enter a valid ASCII email address.",
    );
  }

  return email;
}

/** Creates a SHA-256 hex digest for an email or invitation token. */
function sha256(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

/** Returns the Firestore event document reference. */
function eventRef(eventId: string) {
  return db.collection("events").doc(eventId);
}

/** Returns the admissions collection reference for an event. */
function admissionsRef(eventId: string) {
  return eventRef(eventId).collection("admissions");
}

/** Requires an authenticated caller and returns their UID. */
function requireSignedIn(request: {auth?: {uid: string} | null}): string {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Please sign in first.");
  }

  return request.auth.uid;
}

/** Checks whether the caller can manage or staff the specified event. */
async function requireEventAccess(
  uid: string,
  eventId: string,
  allowStaff: boolean,
): Promise<void> {
  const eventDocument = eventRef(eventId);
  const [eventSnapshot, registrationSnapshot, staffSnapshot, profileSnapshot] =
    await Promise.all([
      eventDocument.get(),
      eventDocument.collection("registrations").doc(uid).get(),
      eventDocument.collection("staff").doc(uid).get(),
      db.collection("users").doc(uid).get(),
    ]);

  if (!eventSnapshot.exists) {
    throw new HttpsError("not-found", "Event not found.");
  }

  const event = eventSnapshot.data() ?? {};
  const registration = registrationSnapshot.data() ?? {};
  const staffRecord = staffSnapshot.data() ?? {};
  const profile = profileSnapshot.data() ?? {};

  if (
    event.isArchived === true ||
    text(event.status).toLowerCase() === "archived"
  ) {
    throw new HttpsError("failed-precondition", "This event is archived.");
  }

  const profileRole = normalizedRole(profile.role);
  const registrationRole = normalizedRole(registration.role);

  const isGlobalAdmin = ["admin", "superadmin", "super_admin"].includes(
    profileRole,
  );

  const isEventOwner = [
    event.organiserId,
    event.organizerId,
    event.ownerUid,
    event.createdBy,
  ].some((value) => value === uid);

  const isEventManager =
    isGlobalAdmin ||
    isEventOwner ||
    (
      ["admin", "organiser", "organizer"].includes(registrationRole) &&
      isApproved(registration.status)
    );

  if (isEventManager) return;

  const isApprovedRegistrationStaff =
    registrationRole === "staff" &&
    isApproved(registration.status);

  const isApprovedStaffRecord =
    staffSnapshot.exists &&
    isApproved(staffRecord.status);

  const profileEventIds = Array.isArray(profile.eventIds) ?
    profile.eventIds.map((value: unknown) => text(value)) :
    [];

  const isApprovedProfileStaff =
    profileRole === "staff" &&
    isApproved(profile.status) &&
    profileEventIds.includes(eventId);

  if (
    allowStaff &&
    (
      isApprovedRegistrationStaff ||
      isApprovedStaffRecord ||
      isApprovedProfileStaff
    )
  ) {
    return;
  }

  throw new HttpsError(
    "permission-denied",
    "Approved event staff or organiser access is required.",
  );
}

/** Validates an invitation QR token received during check-in. */
function validateAdmissionToken(value: unknown): string {
  const token = text(value);

  if (!/^[A-Za-z0-9_-]{40,100}$/.test(token)) {
    throw new HttpsError("invalid-argument", "This invitation QR is invalid.");
  }

  return token;
}

export const createEventInvitations = onCall(

  {region: REGION, timeoutSeconds: 120, memory: "256MiB"},

  async (request) => {
    const uid = requireSignedIn(request);

    const input = request.data ?? {};

    const forceResendExisting = input.forceResendExisting === true;

    const eventId = validDocumentId(input.eventId, "event ID");

    await requireEventAccess(uid, eventId, false);

    if (

      !Array.isArray(input.participants) ||

      input.participants.length === 0 ||

      input.participants.length > MAX_INVITATIONS_PER_REQUEST

    ) {
      throw new HttpsError(

        "invalid-argument",

        `Provide between 1 and ${MAX_INVITATIONS_PER_REQUEST} participants.`,

      );
    }

    const created: Array<{
      name: string;

      email: string;

      admissionId: string;

      token: string;
    }> = [];

    const retried: Array<{
      name: string;

      email: string;

      admissionId: string;

      token: string;
    }> = [];

    const skipped: Array<{email: string; reason: string}> = [];

    const invalid: Array<{row: number; reason: string}> = [];

    const seenEmails = new Set<string>();

    for (let index = 0; index < input.participants.length; index++) {
      const row = input.participants[index];

      if (!row || typeof row !== "object" || Array.isArray(row)) {
        invalid.push({row: index + 1, reason: "Invalid participant row."});

        continue;
      }

      const name = text((row as Record<string, unknown>).name);
      const existingAdmissionId = text(
        (row as Record<string, unknown>).existingAdmissionId,
      );

      let email: string;

      try {
        email = normalizeEmail((row as Record<string, unknown>).email);
      } catch {
        invalid.push({row: index + 1, reason: "Invalid email address."});

        continue;
      }

      if (!name || name.length > 200) {
        invalid.push({row: index + 1, reason: "A valid name is required."});

        continue;
      }

      if (seenEmails.has(email)) {
        skipped.push({email, reason: "Duplicate email in this upload."});

        continue;
      }

      seenEmails.add(email);

      let admissionId = existingAdmissionId || sha256(email);

      const admissionsCollection = admissionsRef(eventId);

      let admissionDocument = admissionsCollection.doc(admissionId);

      if (existingAdmissionId) {
        if (existingAdmissionId.includes("/")) {
          invalid.push({
            row: index + 1,
            reason: "Invalid admission record ID.",
          });
          continue;
        }

        const existingRecord = await admissionDocument.get();
        if (!existingRecord.exists) {
          invalid.push({
            row: index + 1,
            reason: "The invitation record to retry was not found.",
          });
          continue;
        }
      } else {
        const hashedAdmissionDocument = admissionDocument;

        // Older uploads may have created a random document ID. Look up their
        // normalized email before creating the deterministic document so the
        // same attendee is never added twice during migration.
        const hashedDocumentSnapshot = await hashedAdmissionDocument.get();

        if (!hashedDocumentSnapshot.exists) {
          const normalizedEmailMatches = await admissionsCollection
            .where("normalizedEmail", "==", email)
            .limit(1)
            .get();

          if (!normalizedEmailMatches.empty) {
            admissionDocument = normalizedEmailMatches.docs[0].ref;

            admissionId = normalizedEmailMatches.docs[0].id;
          } else {
            const emailMatches = await admissionsCollection
              .where("email", "==", email)
              .limit(1)
              .get();

            if (!emailMatches.empty) {
              admissionDocument = emailMatches.docs[0].ref;

              admissionId = emailMatches.docs[0].id;
            }
          }
        }
      }

      const token = randomBytes(32).toString("base64url");

      const tokenHash = sha256(token);

      const result = await db.runTransaction(async (transaction) => {
        const existing = await transaction.get(admissionDocument);

        if (!existing.exists) {
          transaction.create(admissionDocument, {
            eventId,

            name,

            email,

            normalizedEmail: email,

            source: "invitation" satisfies AdmissionSource,

            status: "invited",

            invitationTokenHash: tokenHash,

            invitationEmailStatus: "pending",

            createdAt: FieldValue.serverTimestamp(),

            updatedAt: FieldValue.serverTimestamp(),

            createdBy: uid,
          });

          return "created" as const;
        }

        const existingData = existing.data() ?? {};

        const admissionStatus = text(existingData.status).toLowerCase();

        const emailStatus = text(existingData.invitationEmailStatus)
          .toLowerCase();

        if (text(existingData.source) === "walk_in") {
          return "not_resendable" as const;
        }

        if (admissionStatus === "joined" || admissionStatus === "revoked") {
          return "not_resendable" as const;
        }

        if (emailStatus === "sent" && !forceResendExisting) {
          return "already_sent" as const;
        }

        if (emailStatus === "sending") {
          const updatedAt = existingData.updatedAt;

          const updatedAtMillis =
            updatedAt && typeof updatedAt.toMillis === "function" ?
              updatedAt.toMillis() : 0;

          if (updatedAtMillis > Date.now() - ACTIVE_EMAIL_SEND_WINDOW_MS) {
            return "currently_sending" as const;
          }
        }

        // Reuse the event admission record and rotate its QR token. Raw tokens
        // are never stored in Firestore; this permits safe retries for failed
        // or pending invitation emails without creating duplicate records.
        transaction.update(admissionDocument, {
          name,

          email,

          normalizedEmail: email,

          source: "invitation" satisfies AdmissionSource,

          invitationTokenHash: tokenHash,

          invitationEmailStatus: "pending",

          invitationEmailError: FieldValue.delete(),

          updatedAt: FieldValue.serverTimestamp(),
        });

        return "retried" as const;
      });

      const invitation = {name, email, admissionId, token};

      if (result === "created") {
        created.push(invitation);
      } else if (result === "retried") {
        retried.push(invitation);
      } else if (result === "already_sent") {
        skipped.push({email, reason: "Invitation email was already sent."});
      } else if (result === "currently_sending") {
        skipped.push({
          email,
          reason: "Invitation email is currently being sent.",
        });
      } else {
        skipped.push({email, reason: "Existing admission cannot be resent."});
      }
    }

    return {created, retried, skipped, invalid};
  },

);

export const adminDeleteEventAdmission = onCall(

  {region: REGION, timeoutSeconds: 60, memory: "256MiB"},

  async (request) => {
    const uid = requireSignedIn(request);

    const input = request.data ?? {};

    const eventId = validDocumentId(input.eventId, "event ID");

    const admissionId = validDocumentId(input.admissionId, "admission ID");

    await requireEventAccess(uid, eventId, false);

    const admissionDocument = admissionsRef(eventId).doc(admissionId);

    await db.runTransaction(async (transaction) => {
      const admissionSnapshot = await transaction.get(admissionDocument);

      if (!admissionSnapshot.exists) {
        throw new HttpsError("not-found", "Admission record not found.");
      }

      transaction.delete(admissionDocument);
    });

    return {deleted: true, admissionId};
  },

);

export const staffScanInvitationQr = onCall(

  {region: REGION, timeoutSeconds: 60, memory: "256MiB"},

  async (request) => {
    const uid = requireSignedIn(request);

    const input = request.data ?? {};

    const eventId = validDocumentId(input.eventId, "event ID");

    const token = validateAdmissionToken(input.token);

    await requireEventAccess(uid, eventId, true);

    const tokenHash = sha256(token);

    const matches = await admissionsRef(eventId)

      .where("invitationTokenHash", "==", tokenHash)

      .limit(1)

      .get();

    if (matches.empty) {
      throw new HttpsError("not-found", "No invitation matches this QR.");
    }

    const admission = matches.docs[0];

    const data = admission.data();

    const status = text(data.status).toLowerCase();

    if (status === "revoked") {
      throw new HttpsError(

        "failed-precondition",

        "This invitation has been revoked.",

      );
    }

    if (status === "joined") {
      throw new HttpsError(

        "failed-precondition",

        "This participant has already joined the event.",

      );
    }

    return {
      admissionId: admission.id,

      name: text(data.name),

      email: text(data.email),

      source: text(data.source),

      status,
    };
  },

);

export const staffConfirmInvitation = onCall(

  {region: REGION, timeoutSeconds: 60, memory: "256MiB"},

  async (request) => {
    const uid = requireSignedIn(request);

    const input = request.data ?? {};

    const eventId = validDocumentId(input.eventId, "event ID");

    const token = validateAdmissionToken(input.token);

    await requireEventAccess(uid, eventId, true);

    const tokenHash = sha256(token);

    const matches = await admissionsRef(eventId)

      .where("invitationTokenHash", "==", tokenHash)

      .limit(1)

      .get();

    if (matches.empty) {
      throw new HttpsError("not-found", "No invitation matches this QR.");
    }

    const admissionDocument = matches.docs[0].ref;

    return db.runTransaction(async (transaction) => {
      const admissionSnapshot = await transaction.get(admissionDocument);

      if (!admissionSnapshot.exists) {
        throw new HttpsError("not-found", "Invitation record not found.");
      }

      const data = admissionSnapshot.data() ?? {};

      const status = text(data.status).toLowerCase();

      if (status === "revoked") {
        throw new HttpsError(

          "failed-precondition",

          "This invitation has been revoked.",

        );
      }

      if (status === "joined") {
        throw new HttpsError(

          "failed-precondition",

          "This participant has already joined the event.",

        );
      }

      if (status !== "verified_by_staff") {
        transaction.update(admissionDocument, {
          status: "verified_by_staff",

          verifiedBy: uid,

          verifiedAt: FieldValue.serverTimestamp(),

          updatedAt: FieldValue.serverTimestamp(),
        });
      }

      return {
        admissionId: admissionSnapshot.id,

        name: text(data.name),

        email: text(data.email),

        source: "invitation",

        status: "verified_by_staff",
      };
    });
  },

);

export const staffCreateWalkInAdmission = onCall(

  {region: REGION, timeoutSeconds: 60, memory: "256MiB"},

  async (request) => {
    const uid = requireSignedIn(request);

    const input = request.data ?? {};

    const eventId = validDocumentId(input.eventId, "event ID");

    const name = text(input.name);

    if (!name || name.length > 200) {
      throw new HttpsError(
        "invalid-argument",
        "Enter a valid participant name.",
      );
    }

    const email = normalizeEmail(input.email);

    await requireEventAccess(uid, eventId, true);

    const admissionId = sha256(email);

    const admissionDocument = admissionsRef(eventId).doc(admissionId);

    return db.runTransaction(async (transaction) => {
      const existing = await transaction.get(admissionDocument);

      if (existing.exists) {
        const data = existing.data() ?? {};

        if (text(data.source) === "invitation") {
          throw new HttpsError(

            "already-exists",

            "This email has an invitation. Scan its invitation QR instead.",

          );
        }

        if (text(data.status) === "joined") {
          throw new HttpsError(

            "already-exists",

            "This participant has already joined the event.",

          );
        }

        if (text(data.source) === "walk_in") {
          return {
            admissionId,

            name: text(data.name),

            email: text(data.email),

            source: "walk_in",

            status: text(data.status),

            alreadyRecorded: true,
          };
        }
      }

      transaction.set(admissionDocument, {
        eventId,

        name,

        email,

        normalizedEmail: email,

        source: "walk_in",

        status: "verified_by_staff",

        verifiedBy: uid,

        verifiedAt: FieldValue.serverTimestamp(),

        createdBy: uid,

        createdAt: FieldValue.serverTimestamp(),

        updatedAt: FieldValue.serverTimestamp(),
      });

      return {
        admissionId,

        name,

        email,

        source: "walk_in",

        status: "verified_by_staff",

        alreadyRecorded: false,
      };
    });
  },

);
