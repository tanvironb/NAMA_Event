/* eslint-disable require-jsdoc */

import {randomBytes, createHash} from "node:crypto";
import {getFirestore, FieldValue} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

const REGION = "asia-southeast1";
const MAX_INVITATIONS_PER_REQUEST = 200;
const db = getFirestore();

type AdmissionSource = "invitation" | "walk_in";

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function normalizedRole(value: unknown): string {
  return text(value).toLowerCase();
}

function normalizedStatus(value: unknown): string {
  return text(value || "approved").toLowerCase();
}

function isApproved(value: unknown): boolean {
  return normalizedStatus(value) === "approved";
}

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

function normalizeEmail(value: unknown): string {
  const email = text(value).toLowerCase();

  if (
    email.length > 254 ||
    !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
  ) {
    throw new HttpsError("invalid-argument", "Enter a valid email address.");
  }

  return email;
}

function sha256(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

function eventRef(eventId: string) {
  return db.collection("events").doc(eventId);
}

function admissionsRef(eventId: string) {
  return eventRef(eventId).collection("admissions");
}

function requireSignedIn(request: {auth?: {uid: string} | null}): string {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Please sign in first.");
  }

  return request.auth.uid;
}

async function requireEventAccess(
  uid: string,
  eventId: string,
  allowStaff: boolean,
): Promise<void> {
  const eventDocument = eventRef(eventId);

  const [
    eventSnapshot,
    registrationSnapshot,
    staffSnapshot,
    profileSnapshot,
  ] = await Promise.all([
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

      const admissionId = sha256(email);
      const admissionDocument = admissionsRef(eventId).doc(admissionId);
      const token = randomBytes(32).toString("base64url");
      const tokenHash = sha256(token);

      const wasCreated = await db.runTransaction(async (transaction) => {
        const existing = await transaction.get(admissionDocument);

        if (existing.exists) return false;

        transaction.create(admissionDocument, {
          eventId,
          name,
          email,
          normalizedEmail: email,
          source: "invitation" satisfies AdmissionSource,
          status: "invited",
          invitationTokenHash: tokenHash,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          createdBy: uid,
        });

        return true;
      });

      if (!wasCreated) {
        skipped.push({
          email,
          reason: "This email already has an event record.",
        });
        continue;
      }

      created.push({name, email, admissionId, token});
    }

    return {created, skipped, invalid};
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

export const adminDeleteEventAdmission = onCall(
  {region: REGION},
  async (request) => {
    const uid = requireSignedIn(request);
    const input = request.data ?? {};
    const eventId = validDocumentId(input.eventId, "event ID");
    const admissionId = validDocumentId(input.admissionId, "admission ID");

    // Only event managers/admins can delete admission records.
    await requireEventAccess(uid, eventId, false);

    const admissionDocument = admissionsRef(eventId).doc(admissionId);

    await db.runTransaction(async (transaction) => {
      const admissionSnapshot = await transaction.get(admissionDocument);

      if (!admissionSnapshot.exists) {
        throw new HttpsError("not-found", "Admission record not found.");
      }

      transaction.delete(admissionDocument);
    });

    return {
      success: true,
      admissionId,
    };
  },
);
