/* eslint-disable max-len */
/* eslint-disable require-jsdoc */

import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import * as crypto from "crypto";

const REGION = "asia-southeast1";

async function ensureCredentials(eventId: string): Promise<void> {
  const db = admin.firestore();
  const eventRef = db.collection("events").doc(eventId);
  const credentialsRef = db.collection("eventJoinCredentials").doc(eventId);

  for (let attempt = 0; attempt < 8; attempt++) {
    const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    const bytes = crypto.randomBytes(10);
    const candidate = "EVT-" + Array.from(
      bytes,
      (value) => alphabet[value % alphabet.length]
    ).join("");

    const success = await db.runTransaction(async (transaction) => {
      const eventDoc = await transaction.get(eventRef);
      const credentialsDoc = await transaction.get(credentialsRef);

      if (!eventDoc.exists) {
        throw new HttpsError("not-found", "Event not found.");
      }

      const stored = String(credentialsDoc.data()?.code || "");
      const code = /^EVT-[A-Z2-9]{10}$/.test(stored) ? stored : candidate;
      const codeRef = db.collection("eventJoinCodes").doc(code);
      const codeDoc = await transaction.get(codeRef);

      if (codeDoc.exists && codeDoc.data()?.eventId !== eventId) {
        return false;
      }

      if (!codeDoc.exists) {
        transaction.set(codeRef, {
          eventId,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      if (
        !credentialsDoc.exists ||
        stored !== code ||
        !credentialsDoc.data()?.qrPayload
      ) {
        transaction.set(credentialsRef, {
          eventId,
          code,
          qrPayload: JSON.stringify({
            type: "event_join",
            eventId,
            code,
          }),
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      return true;
    });

    if (success) return;
  }

  throw new HttpsError(
    "aborted",
    "Could not create event code. Please retry."
  );
}

export const generateEventJoinCredentials = onDocumentCreated(
  {
    document: "events/{eventId}",
    region: REGION,
  },
  async (event) => {
    if (!event.data) return;
    await ensureCredentials(event.params.eventId);
  }
);

export const ensureEventJoinCredentials = onCall(
  {
    region: REGION,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Please sign in.");
    }

    const db = admin.firestore();
    const profile = await db.collection("users").doc(request.auth.uid).get();

    if (profile.data()?.role !== "admin") {
      throw new HttpsError(
        "permission-denied",
        "Only admin can generate event codes."
      );
    }

    const eventId = request.data?.eventId;

    if (
      typeof eventId !== "string" ||
      !eventId.trim() ||
      eventId.includes("/")
    ) {
      throw new HttpsError(
        "invalid-argument",
        "A valid eventId is required."
      );
    }

    await ensureCredentials(eventId);

    return {
      success: true,
    };
  }
);

export const joinActiveEvent = onCall(
  {
    region: REGION,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Please sign in.");
    }

    if (request.auth.token.email_verified !== true) {
      throw new HttpsError(
        "failed-precondition",
        "Please verify your email first."
      );
    }

    const credential = request.data?.credential;

    if (typeof credential !== "string" || !credential.trim()) {
      throw new HttpsError(
        "invalid-argument",
        "Scan the event QR or enter its code."
      );
    }

    let code = credential.trim().toUpperCase();
    let qrEventId = "";

    if (credential.trim().startsWith("{")) {
      try {
        const qr = JSON.parse(credential.trim());

        if (
          qr.type !== "event_join" ||
          typeof qr.code !== "string" ||
          typeof qr.eventId !== "string"
        ) {
          throw new Error("invalid-event-qr");
        }

        code = qr.code.trim().toUpperCase();
        qrEventId = qr.eventId;
      } catch (_) {
        throw new HttpsError(
          "invalid-argument",
          "Please scan a valid event QR."
        );
      }
    }

    if (!/^EVT-[A-Z2-9]{10}$/.test(code)) {
      throw new HttpsError("invalid-argument", "Invalid event code.");
    }

    const db = admin.firestore();
    const uid = request.auth.uid;
    const userRef = db.collection("users").doc(uid);
    const codeRef = db.collection("eventJoinCodes").doc(code);

    return db.runTransaction(async (transaction) => {
      const codeDoc = await transaction.get(codeRef);
      const userDoc = await transaction.get(userRef);
      const eventId = codeDoc.data()?.eventId;

      if (
        !codeDoc.exists ||
        typeof eventId !== "string" ||
        !eventId ||
        eventId.includes("/")
      ) {
        throw new HttpsError("not-found", "Event code not found.");
      }

      if (qrEventId && qrEventId !== eventId) {
        throw new HttpsError("invalid-argument", "Invalid event QR.");
      }

      const eventRef = db.collection("events").doc(eventId);
      const credentialsRef = db.collection("eventJoinCredentials").doc(eventId);
      const registrationRef = eventRef.collection("registrations").doc(uid);
      const attendanceRef = eventRef.collection("attendance").doc(uid);

      const eventDoc = await transaction.get(eventRef);
      const credentialsDoc = await transaction.get(credentialsRef);
      const registrationDoc = await transaction.get(registrationRef);
      const attendanceDoc = await transaction.get(attendanceRef);

      const eventData = eventDoc.data();
      const userData = userDoc.data();

      if (!eventData || credentialsDoc.data()?.code !== code) {
        throw new HttpsError(
          "not-found",
          "Event code is unavailable."
        );
      }

      if (
        eventData.isActive !== true ||
        eventData.status === "archived"
      ) {
        throw new HttpsError(
          "failed-precondition",
          "This event is not active."
        );
      }

      if (!userData || userData.status !== "approved") {
        throw new HttpsError(
          "permission-denied",
          "Your account must be approved before joining."
        );
      }

      const role = String(userData.role || "attendee")
        .toLowerCase()
        .trim();

      if (role === "admin" || role === "superadmin") {
        throw new HttpsError(
          "permission-denied",
          "Admin accounts use the admin interface."
        );
      }

      const userName = String(
        userData.name ||
        userData.fullName ||
        userData.displayName ||
        "User"
      );

      const userEmail = String(
        userData.email ||
        request.auth?.token.email ||
        ""
      );

      const eventName = String(
        eventData.name ||
        eventData.title ||
        eventData.eventName ||
        "Event"
      );

      const timestamp = admin.firestore.FieldValue.serverTimestamp();

      transaction.set(userRef, {
        eventIds: admin.firestore.FieldValue.arrayUnion(eventId),
        activeEventId: eventId,
        currentEventId: eventId,
        lastEventLoginAt: timestamp,
        updatedAt: timestamp,
      }, {merge: true});

      transaction.set(registrationRef, {
        eventId,
        eventName,
        userId: uid,
        userName,
        userEmail,
        userRole: role,
        status: "registered",
        admissionVerified: true,
        admissionMethod: qrEventId ? "event_qr" : "event_code",
        admissionVerifiedAt:
          registrationDoc.data()?.admissionVerifiedAt || timestamp,
        registeredAt:
          registrationDoc.data()?.registeredAt || timestamp,
        updatedAt: timestamp,
      }, {merge: true});

      transaction.set(attendanceRef, {
        eventId,
        eventName,
        userId: uid,
        userName,
        userEmail,
        userRole: role,
        status: "present",
        source: qrEventId ? "event_qr" : "event_code",
        checkedInAt: attendanceDoc.data()?.checkedInAt || timestamp,
        createdAt: attendanceDoc.data()?.createdAt || timestamp,
        lastSeenAt: timestamp,
        updatedAt: timestamp,
      }, {merge: true});

      return {
        success: true,
        eventId,
        eventName,
      };
    });
  }
);
