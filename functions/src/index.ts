import {
  onDocumentWritten,
  onDocumentCreated,
} from "firebase-functions/v2/firestore";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as crypto from "crypto";

admin.initializeApp();
const db = admin.firestore();

/**
 * Triggered on any write to a user document.
 * Generates a secure QR code payload when a user's status becomes 'approved'.
 */
export const handleUserWrite = onDocumentWritten(
  "users/{userId}",
  async (event) => {
    const userId = event.params.userId;
    const before = event.data?.before?.exists ? event.data.before.data() : null;
    const after = event.data?.after?.exists ? event.data.after.data() : null;

    // Exit early if this is a deletion
    if (!after) return null;

    // Check if user status changed to 'approved' and doesn't already have QR
    const wasApproved = before?.status === "approved";
    const isNowApproved = after.status === "approved";
    const hasQrPayload = after.qrCodePayload && after.qrCodePayload.length > 0;

    if (isNowApproved && !wasApproved && !hasQrPayload) {
      console.log(
        `Generating QR payload for newly approved user: ${userId}`
      );

      // Generate a secure, unguessable token for the user QR code
      const randomBytes = crypto.randomBytes(16).toString("hex");
      const uniquePayload = `user::${userId}_${randomBytes}`;

      // Update the user document with the new QR payload
      return event.data?.after?.ref.update({
        qrCodePayload: uniquePayload,
        qrCodeGeneratedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    return null;
  });

/**
 * NEW: Triggered when a new session is created.
 * Generates a secure, unique QR code payload for the session.
 */
export const onSessionCreate = onDocumentCreated(
  "sessions/{sessionId}",
  async (event) => {
    const sessionId = event.params.sessionId;
    // Generate a secure, unguessable token for the session QR code.
    const randomBytes = crypto.randomBytes(8).toString("hex");
    const uniquePayload = `session::${sessionId}_${randomBytes}`;

    console.log(`Generating QR payload for session ${sessionId}`);

    // Update the session document with the new QR payload.
    return event.data?.ref.update({qrCodePayload: uniquePayload});
  }
);

/**
 * Securely validates ANY QR code payload (user or session).
 * Returns the type of code and the minimal public data.
 */
export const validateQrCode = onCall(async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }

  const qrPayload = request.data.payload;
  console.log(`Validating QR payload: ${qrPayload}`); // todo: remove in prod

  if (!qrPayload || typeof qrPayload !== "string") {
    throw new HttpsError(
      "invalid-argument",
      "A 'payload' string must be provided."
    );
  }

  // --- NEW: Distinguish between user and session QR codes ---
  if (qrPayload.startsWith("user::")) {
    const snapshot = await db
      .collection("users")
      .where("qrCodePayload", "==", qrPayload)
      .limit(1)
      .get();
    if (snapshot.empty) {
      throw new HttpsError("not-found", "User QR not found.");
    }

    const userDoc = snapshot.docs[0];
    const userData = userDoc.data();

    // Security check: Ensure user data exists
    if (!userData) {
      throw new HttpsError("not-found", "User data not found.");
    }

    return {
      type: "user",
      data: {
        uid: userDoc.id,
        name: userData.name,
        email: userData.email,
        role: userData.role,
        profileImageUrl: userData.profileImageUrl,
        title: userData.title,
      },
    };
  } else if (qrPayload.startsWith("session::")) {
    const sessionId = qrPayload.split("::")[1].split("_")[0];
    const sessionDoc = await db.collection("sessions").doc(sessionId).get();
    if (!sessionDoc.exists) {
      throw new HttpsError("not-found", "Session QR not found.");
    }

    const sessionData = sessionDoc.data();
    if (!sessionData) {
      throw new HttpsError("not-found", "Session data not found.");
    }

    return {
      type: "session",
      data: {
        sessionId: sessionDoc.id,
        title: sessionData.title || "Unknown Session",
        location: sessionData.location || "Unknown Location",
        startTime: sessionData.startTime ?
          sessionData.startTime.toDate().toISOString() :
          new Date().toISOString(),
      },
    };
  } else {
    throw new HttpsError("invalid-argument", "Invalid QR code format.");
  }
});

/**
 * Securely logs an EVENT check-in.
 * Only Admins or Staff can call this successfully.
 */
export const logEventCheckIn = onCall(async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }

  const adminUid = request.auth.uid;
  const scannedUserId = request.data.scannedUserId;

  if (!scannedUserId || typeof scannedUserId !== "string") {
    throw new HttpsError(
      "invalid-argument",
      "A 'scannedUserId' must be provided."
    );
  }

  // Verify admin/staff permissions
  const adminDoc = await db.collection("users").doc(adminUid).get();
  if (!adminDoc.exists) {
    throw new HttpsError("not-found", "Admin user not found.");
  }

  const adminData = adminDoc.data();
  if (!adminData) {
    throw new HttpsError("not-found", "Admin data not found.");
  }

  if (adminData.role !== "admin" && adminData.role !== "staff") {
    throw new HttpsError(
      "permission-denied",
      "Only admins and staff can check in users."
    );
  }

  // Verify scanned user exists
  const scannedUserDoc = await db.collection("users").doc(scannedUserId).get();
  if (!scannedUserDoc.exists) {
    throw new HttpsError("not-found", "Scanned user not found.");
  }

  const scannedUserData = scannedUserDoc.data();
  if (!scannedUserData) {
    throw new HttpsError("not-found", "Scanned user data not found.");
  }

  // Log the event check-in
  await db.collection("eventCheckins").add({
    scannedUserId,
    adminUserId: adminUid,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    scannedUserName: scannedUserData.name,
    adminUserName: adminData.name,
  });

  // Award points to the checked-in user
  await db.collection("users").doc(scannedUserId).update({
    points: admin.firestore.FieldValue.increment(5),
  });

  return {
    success: true,
    message: "User checked in to event successfully.",
    scannedUser: {
      uid: scannedUserId,
      name: scannedUserData.name,
    },
  };
});

/**
 * NEW: Securely logs a SESSION check-in.
 * Any approved user can call this.
 */
export const logSessionCheckIn = onCall(async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }

  const scannerUid = request.auth.uid;
  const sessionId = request.data.sessionId;

  if (!sessionId || typeof sessionId !== "string") {
    throw new HttpsError("invalid-argument", "A 'sessionId' must be provided.");
  }

  // --- NEW: Time Validation Logic ---
  const sessionDoc = await db.collection("sessions").doc(sessionId).get();
  if (!sessionDoc.exists) {
    throw new HttpsError("not-found", "Session not found.");
  }

  const sessionData = sessionDoc.data();
  if (!sessionData) {
    throw new HttpsError("not-found", "Session data not found.");
  }

  const now = new Date();
  const startTime = (sessionData.startTime as admin.firestore.Timestamp)
    .toDate();
  const endTime = (sessionData.endTime as admin.firestore.Timestamp)
    .toDate();

  // Check if the current time is within the session's active window
  if (now < startTime || now > endTime) {
    throw new HttpsError(
      "failed-precondition",
      "This session is not currently active."
    );
  }

  // Log the session check-in event.
  await db.collection("sessions")
    .doc(sessionId)
    .collection("checkins")
    .doc(scannerUid)
    .set({
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

  // Increment user's points for the leaderboard.
  await db.collection("users").doc(scannerUid).update({
    points: admin.firestore.FieldValue.increment(10),
  });

  return {
    success: true,
    message: "Checked into session successfully.",
    // Return session data so the app can navigate
    session: {
      id: sessionDoc.id,
      title: sessionData.title,
      eventId: sessionData.eventId, // Add eventId for Flutter app
    },
  };
});
