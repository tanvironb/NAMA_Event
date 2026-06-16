/* eslint-disable max-len */
/* eslint-disable require-jsdoc */
/* eslint-disable @typescript-eslint/no-explicit-any */
/* eslint-disable no-multiple-empty-lines */


import {onDocumentCreated, onDocumentWritten} from "firebase-functions/v2/firestore";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import * as functionsV1 from "firebase-functions/v1";
import * as admin from "firebase-admin";
import * as crypto from "crypto";

admin.initializeApp();

const db = admin.firestore();

// Region configuration - must match your Firestore region
const FUNCTION_REGION = "asia-southeast1";

// ============================================================================
// USER QR GENERATION
// ============================================================================

/**
 * Triggered on any write to a user document.
 * Generates a secure QR code payload when a user's status becomes approved.
 */
export const handleUserWrite = onDocumentWritten(
  {
    document: "users/{userId}",
    region: FUNCTION_REGION,
  },
  async (event) => {
    const userId = event.params.userId;

    const before = event.data?.before.exists ?
      event.data.before.data() :
      null;

    const after = event.data?.after.exists ?
      event.data.after.data() :
      null;

    if (!after) return null;

    const wasApproved = before?.status === "approved";
    const isNowApproved = after.status === "approved";
    const hasQrPayload = after.qrCodePayload && after.qrCodePayload.length > 0;

    if (isNowApproved && !wasApproved && !hasQrPayload) {
      console.log(`Generating QR payload for newly approved user: ${userId}`);

      const randomBytes = crypto.randomBytes(16).toString("hex");
      const uniquePayload = `user::${userId}_${randomBytes}`;

      return event.data?.after.ref.update({
        qrCodePayload: uniquePayload,
        qrCodeGeneratedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    return null;
  }
);

// ============================================================================
// SESSION QR GENERATION
// ============================================================================

/**
 * Triggered when a new session is created.
 * Generates a secure, unique QR code payload for the session.
 */
export const onSessionCreate = onDocumentCreated(
  {
    document: "sessions/{sessionId}",
    region: FUNCTION_REGION,
  },
  async (event) => {
    const sessionId = event.params.sessionId;

    const randomBytes = crypto.randomBytes(8).toString("hex");
    const uniquePayload = `session::${sessionId}_${randomBytes}`;

    console.log(`Generating QR payload for session ${sessionId}`);

    return event.data?.ref.update({
      qrCodePayload: uniquePayload,
    });
  }
);

/**
 * Manual QR generation for sessions.
 * Called by speakers when auto-generation fails or QR is missing.
 */
export const generateSessionQR = onCall(
  {
    region: FUNCTION_REGION,
  },
  async (request) => {
    console.log("=== Start Generate Session QR ===");

    if (!request.auth || !request.auth.uid) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }

    const sessionId = request.data.sessionId;

    console.log(`User ${request.auth.uid} requesting QR for session ${sessionId}`);

    if (!sessionId || typeof sessionId !== "string") {
      throw new HttpsError(
        "invalid-argument",
        "A 'sessionId' string must be provided."
      );
    }

    try {
      const sessionRef = db.collection("sessions").doc(sessionId);
      const sessionDoc = await sessionRef.get();

      if (!sessionDoc.exists) {
        throw new HttpsError("not-found", "Session not found.");
      }

      const sessionData = sessionDoc.data();

      if (!sessionData?.speakerIds?.includes(request.auth.uid)) {
        throw new HttpsError(
          "permission-denied",
          "Only speakers can generate QR codes for their sessions."
        );
      }

      if (
        sessionData.qrCodePayload &&
        sessionData.qrCodePayload.trim() !== ""
      ) {
        console.log("QR already exists, returning existing payload");

        return {
          success: true,
          qrCodePayload: sessionData.qrCodePayload,
          message: "QR code already exists",
        };
      }

      const randomBytes = crypto.randomBytes(8).toString("hex");
      const uniquePayload = `session::${sessionId}_${randomBytes}`;

      await sessionRef.update({
        qrCodePayload: uniquePayload,
      });

      console.log("=== End Generate Session QR Success ===");

      return {
        success: true,
        qrCodePayload: uniquePayload,
        message: "QR code generated successfully",
      };
    } catch (error) {
      console.error("Error generating session QR:", error);

      if (error instanceof HttpsError) {
        throw error;
      }

      const errorMessage =
        error instanceof Error ? error.message : "Unknown error";

      throw new HttpsError(
        "internal",
        `Failed to generate QR: ${errorMessage}`
      );
    }
  }
);

// ============================================================================
// QR VALIDATION
// ============================================================================

/**
 * Securely validates ANY QR code payload.
 * Supports user QR and session QR.
 */
export const validateQrCode = onCall(
  {
    region: FUNCTION_REGION,
  },
  async (request) => {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }

    const qrPayload = request.data.payload;

    console.log(`Validating QR payload: ${qrPayload}`);

    if (!qrPayload || typeof qrPayload !== "string") {
      throw new HttpsError(
        "invalid-argument",
        "A 'payload' string must be provided."
      );
    }

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
    }

    if (qrPayload.startsWith("session::")) {
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
    }

    throw new HttpsError(
      "invalid-argument",
      "Invalid QR code format."
    );
  }
);

// ============================================================================
// EVENT CHECK-IN
// ============================================================================

/**
 * Securely logs an EVENT check-in.
 * Only admins or staff can call this successfully.
 */
export const logEventCheckIn = onCall(
  {
    region: FUNCTION_REGION,
  },
  async (request) => {
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

    const scannedUserDoc = await db
      .collection("users")
      .doc(scannedUserId)
      .get();

    if (!scannedUserDoc.exists) {
      throw new HttpsError("not-found", "Scanned user not found.");
    }

    const scannedUserData = scannedUserDoc.data();

    if (!scannedUserData) {
      throw new HttpsError("not-found", "Scanned user data not found.");
    }

    await db.collection("eventCheckins").add({
      scannedUserId,
      adminUserId: adminUid,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      scannedUserName: scannedUserData.name,
      adminUserName: adminData.name,
    });

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
  }
);

// ============================================================================
// SESSION CHECK-IN - UPDATED FIX
// ============================================================================

/**
 * Securely logs a SESSION check-in.
 * Any approved user can call this.
 *
 * IMPORTANT FIX:
 * This now updates sessions/{sessionId}.checkedInAttendees.
 * Speaker audience, analytics, feedback, and engagement pages depend on this.
 */
export const logSessionCheckIn = onCall(
  {
    region: FUNCTION_REGION,
  },
  async (request) => {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }

    const scannerUid = request.auth.uid;
    const sessionId = request.data.sessionId;

    if (!sessionId || typeof sessionId !== "string") {
      throw new HttpsError(
        "invalid-argument",
        "A 'sessionId' must be provided."
      );
    }

    const sessionRef = db.collection("sessions").doc(sessionId);
    const checkinRef = sessionRef.collection("checkins").doc(scannerUid);
    const userRef = db.collection("users").doc(scannerUid);

    let alreadyCheckedIn = false;

    let sessionReturnData: {
      id: string;
      title: string;
      eventId: string;
    } | null = null;

    await db.runTransaction(async (transaction) => {
      const sessionDoc = await transaction.get(sessionRef);
      const checkinDoc = await transaction.get(checkinRef);

      if (!sessionDoc.exists) {
        throw new HttpsError("not-found", "Session not found.");
      }

      const sessionData = sessionDoc.data();

      if (!sessionData) {
        throw new HttpsError("not-found", "Session data not found.");
      }

      sessionReturnData = {
        id: sessionDoc.id,
        title: sessionData.title || "Session",
        eventId: sessionData.eventId || "",
      };

      // If old check-in exists, repair checkedInAttendees.
      if (checkinDoc.exists) {
        alreadyCheckedIn = true;

        transaction.update(sessionRef, {
          checkedInAttendees:
            admin.firestore.FieldValue.arrayUnion(scannerUid),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        return;
      }

      const now = new Date();

      const startTime = (
        sessionData.startTime as admin.firestore.Timestamp
      ).toDate();

      const endTime = (
        sessionData.endTime as admin.firestore.Timestamp
      ).toDate();

      if (now < startTime || now > endTime) {
        throw new HttpsError(
          "failed-precondition",
          "This session is not currently active."
        );
      }

      transaction.set(checkinRef, {
        userId: scannerUid,
        sessionId: sessionId,
        eventId: sessionData.eventId || "",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        checkedInBy: "self_scan",
        qrType: "session_checkin",
      });

      transaction.update(sessionRef, {
        checkedInAttendees:
          admin.firestore.FieldValue.arrayUnion(scannerUid),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      transaction.update(userRef, {
        points: admin.firestore.FieldValue.increment(10),
      });
    });

    return {
      success: true,
      alreadyCheckedIn: alreadyCheckedIn,
      message: alreadyCheckedIn ?
        "Already checked in. Attendance record repaired." :
        "Checked into session successfully.",
      session: sessionReturnData,
    };
  }
);

// ============================================================================
// DIRECT MESSAGE NOTIFICATIONS
// ============================================================================

/**
 * Triggered when a new direct message is created.
 * Sends a push notification only to the recipient, not sender.
 */
export const onNewDirectMessage = onDocumentCreated(
  {
    document: "directMessages/{conversationId}/messages/{messageId}",
    region: FUNCTION_REGION,
  },
  async (event) => {
    const messageData = event.data?.data();

    if (!messageData) {
      console.log("No message data found.");
      return null;
    }

    const conversationId = event.params.conversationId;
    const senderId = messageData.senderId;

    console.log("\n=== DM Notification Triggered ===");
    console.log(`Conversation: ${conversationId}`);
    console.log(`Sender: ${senderId}`);

    const conversationDoc = await db
      .collection("directMessages")
      .doc(conversationId)
      .get();

    if (!conversationDoc.exists) {
      console.log("ERROR: Conversation document does not exist.");
      return null;
    }

    const conversationData = conversationDoc.data();
    const members = conversationData?.members;

    if (!members || members.length !== 2) {
      console.log(`ERROR: Invalid members array: ${JSON.stringify(members)}`);
      return null;
    }

    const recipientId = members.find((id: string) => id !== senderId);

    if (!recipientId || recipientId === senderId) {
      console.log("ERROR: Could not find valid recipient.");
      return null;
    }

    const recipientDoc = await db.collection("users").doc(recipientId).get();

    if (!recipientDoc.exists) {
      console.log("ERROR: Recipient user document does not exist.");
      return null;
    }

    const recipientData = recipientDoc.data();
    const recipientFcmToken = recipientData?.fcmToken;

    if (!recipientFcmToken) {
      console.log(`Recipient ${recipientId} does not have an FCM token.`);
      return null;
    }

    const senderDoc = await db.collection("users").doc(senderId).get();
    const senderData = senderDoc.data();
    const senderFcmToken = senderData?.fcmToken;

    if (senderFcmToken && recipientFcmToken === senderFcmToken) {
      console.log("Sender and recipient have same FCM token. Skipping.");
      return null;
    }

    const message = {
      token: recipientFcmToken,
      notification: {
        title: `New message from ${messageData.senderName}`,
        body: messageData.text,
      },
      data: {
        type: "dm",
        conversationId: conversationId,
        senderId: senderId,
        otherUserId: senderId,
        otherUserName: messageData.senderName,
        otherUserProfileImage: senderData?.profileImageUrl || "",
      },
      android: {
        notification: {
          sound: "default",
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    };

    try {
      const response = await admin.messaging().send(message);
      console.log(`SUCCESS: Notification sent to ${recipientId}`);
      return response;
    } catch (error) {
      console.error("ERROR sending DM notification:", error);

      if (
        error instanceof Error &&
        (
          error.message.includes("registration-token-not-registered") ||
          error.message.includes("invalid-registration-token")
        )
      ) {
        await db.collection("users").doc(recipientId).update({
          fcmToken: admin.firestore.FieldValue.delete(),
        });
      }

      throw error;
    }
  }
);

// ============================================================================
// ADMIN NOTIFICATION FCM
// ============================================================================

/**
 * Triggered when a new notification is created.
 * Sends FCM push notification for admin-sent notifications.
 */
export const onNotificationCreate = onDocumentCreated(
  {
    document: "users/{userId}/notifications/{notificationId}",
    region: FUNCTION_REGION,
  },
  async (event) => {
    const userId = event.params.userId;
    const notificationId = event.params.notificationId;
    const notificationData = event.data?.data();

    if (!notificationData) {
      console.log("No notification data found.");
      return null;
    }

    const notificationType = notificationData.type;
    const adminTypes = ["alert", "announcement", "information", "maintenance"];

    if (!adminTypes.includes(notificationType)) {
      console.log(`Skipping FCM for type: ${notificationType}`);
      return null;
    }

    const userDoc = await db.collection("users").doc(userId).get();

    if (!userDoc.exists) {
      console.log(`ERROR: User ${userId} does not exist.`);
      return null;
    }

    const userData = userDoc.data();
    const fcmToken = userData?.fcmToken;
    const userRole = userData?.role;

    if (!fcmToken) {
      console.log(`User ${userId} does not have an FCM token.`);
      return null;
    }

    const targetRole = notificationData.targetRole || "all";

    if (targetRole !== "all" && userRole !== targetRole) {
      console.log("Skipping FCM due to target role mismatch.");
      return null;
    }

    const message: admin.messaging.Message = {
      token: fcmToken,
      notification: {
        title: notificationData.title || "New Notification",
        body: notificationData.subtitle || notificationData.body || "",
      },
      data: {
        type: "admin_notification",
        notificationId: notificationId,
        notificationType: notificationType,
        priority: notificationData.priority || "low",
      },
      android: {
        notification: {
          sound: "default",
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
          priority: notificationType === "alert" ? "high" : "default",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            contentAvailable: true,
          },
        },
      },
    };

    try {
      const response = await admin.messaging().send(message);
      console.log(`SUCCESS: FCM sent to ${userId}`);
      return response;
    } catch (error) {
      console.error("ERROR sending FCM:", error);

      if (
        error instanceof Error &&
        (
          error.message.includes("registration-token-not-registered") ||
          error.message.includes("invalid-registration-token")
        )
      ) {
        await db.collection("users").doc(userId).update({
          fcmToken: admin.firestore.FieldValue.delete(),
        });
      }

      throw error;
    }
  }
);

// ============================================================================
// SESSION END FEEDBACK NOTIFICATION
// ============================================================================

/**
 * Sends feedback request notifications to all checked-in attendees.
 */
export const onSessionEnd = onDocumentWritten(
  {
    document: "sessions/{sessionId}",
    region: FUNCTION_REGION,
  },
  async (event) => {
    const beforeData = event.data?.before.exists ?
      event.data.before.data() :
      null;

    const afterData = event.data?.after.exists ?
      event.data.after.data() :
      null;

    if (!beforeData || !afterData) return null;

    const sessionId = event.params.sessionId;
    const endTime = afterData.endTime.toDate();
    const now = new Date();

    const timeSinceEnd = now.getTime() - endTime.getTime();

    if (timeSinceEnd < 0 || timeSinceEnd > 5 * 60 * 1000) {
      return null;
    }

    const checkedInAttendees = afterData.checkedInAttendees || [];
    const speakerIds = afterData.speakerIds || [];
    const sessionTitle = afterData.title || "Session";
    const eventId = afterData.eventId;

    const attendeesToNotify = checkedInAttendees.filter(
      (uid: string) => !speakerIds.includes(uid)
    );

    if (attendeesToNotify.length === 0) {
      console.log(`No attendees to notify for session ${sessionId}`);
      return null;
    }

    const notificationPromises = attendeesToNotify.map(
      async (attendeeId: string) => {
        try {
          const userDoc = await db.collection("users").doc(attendeeId).get();
          const fcmToken = userDoc.data()?.fcmToken;

          if (!fcmToken) {
            console.log(`Attendee ${attendeeId} does not have FCM token.`);
            return null;
          }

          const message = {
            token: fcmToken,
            notification: {
              title: "How was the session?",
              body: `Share your feedback for "${sessionTitle}"`,
            },
            data: {
              type: "session_feedback",
              sessionId: sessionId,
              eventId: eventId,
              sessionTitle: sessionTitle,
            },
            android: {
              notification: {
                sound: "default",
                clickAction: "FLUTTER_NOTIFICATION_CLICK",
              },
            },
            apns: {
              payload: {
                aps: {
                  sound: "default",
                },
              },
            },
          };

          return await admin.messaging().send(message);
        } catch (error) {
          console.error(`Error sending feedback notification to ${attendeeId}:`, error);
          return null;
        }
      }
    );

    await Promise.all(notificationPromises);

    return null;
  }
);

// ============================================================================
// MEETING NOTIFICATIONS
// ============================================================================

export const onMeetingWrite = onDocumentWritten(
  {
    document: "meetings/{meetingId}",
    region: FUNCTION_REGION,
  },
  async (event) => {
    const beforeData = event.data?.before.exists ?
      event.data.before.data() :
      null;

    const afterData = event.data?.after.exists ?
      event.data.after.data() :
      null;

    if (!afterData) {
      console.log("No after data in meeting write.");
      return null;
    }

    let recipientId: string | null = null;
    let senderId: string | null = null;
    let payload: any = null;

    if (!beforeData && afterData) {
      const requesterId = afterData.requesterId;
      const potentialRecipientId = afterData.recipientId;

      if (potentialRecipientId === requesterId) {
        return null;
      }

      recipientId = potentialRecipientId;
      senderId = requesterId;

      payload = {
        notification: {
          title: "New Meeting Request",
          body: `${afterData.requesterInfo.name} wants to meet with you.`,
        },
        data: {
          type: "meeting_request",
          meetingId: event.params.meetingId,
          senderId: requesterId,
          requesterName: afterData.requesterInfo.name,
          proposedTime: afterData.proposedTime.toDate().toISOString(),
        },
      };
    } else if (
      beforeData &&
      afterData &&
      beforeData.status === "pending" &&
      afterData.status !== "pending"
    ) {
      const requesterId = afterData.requesterId;
      const responderId = afterData.recipientId;

      if (requesterId === responderId) {
        return null;
      }

      recipientId = requesterId;
      senderId = responderId;

      payload = {
        notification: {
          title: `Meeting Request ${afterData.status}`,
          body:
            `${afterData.recipientInfo.name} has ` +
            `${afterData.status} your meeting request.`,
        },
        data: {
          type: "meeting_update",
          meetingId: event.params.meetingId,
          senderId: responderId,
          status: afterData.status,
        },
      };
    } else {
      return null;
    }

    if (!recipientId || !payload) {
      return null;
    }

    try {
      await db
        .collection("users")
        .doc(recipientId)
        .collection("notifications")
        .add({
          title: payload.notification.title,
          subtitle: null,
          body: payload.notification.body,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          timeFrom: null,
          timeTo: null,
          isRead: false,
          type: "meetingRequest",
          targetRole: "all",
          data: payload.data || {},
        });
    } catch (error) {
      console.error("ERROR creating in-app notification:", error);
    }

    const recipientDoc = await db.collection("users").doc(recipientId).get();

    if (!recipientDoc.exists) {
      return null;
    }

    const recipientData = recipientDoc.data();
    const recipientFcmToken = recipientData?.fcmToken;

    if (!recipientFcmToken) {
      return null;
    }

    if (senderId) {
      const senderDoc = await db.collection("users").doc(senderId).get();
      const senderData = senderDoc.data();
      const senderFcmToken = senderData?.fcmToken;

      if (senderFcmToken && recipientFcmToken === senderFcmToken) {
        return null;
      }
    }

    const message = {
      token: recipientFcmToken,
      notification: payload.notification,
      data: payload.data,
      android: {
        notification: {
          sound: "default",
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    };

    try {
      return await admin.messaging().send(message);
    } catch (error) {
      console.error("ERROR sending meeting FCM:", error);
      return null;
    }
  }
);

// ============================================================================
// NOTIFICATION MANAGEMENT
// ============================================================================

const RATE_LIMIT_WINDOW_MS = 60000;
const MAX_EDIT_REQUESTS_PER_WINDOW = 10;
const MAX_DELETE_REQUESTS_PER_WINDOW = 5;

const rateLimitMap = new Map<string, {count: number; resetTime: number}>();

function checkRateLimit(userId: string, action: "edit" | "delete"): boolean {
  const key = `${userId}_${action}`;
  const now = Date.now();

  const limit =
    action === "edit" ?
      MAX_EDIT_REQUESTS_PER_WINDOW :
      MAX_DELETE_REQUESTS_PER_WINDOW;

  const entry = rateLimitMap.get(key);

  if (!entry || now > entry.resetTime) {
    rateLimitMap.set(key, {
      count: 1,
      resetTime: now + RATE_LIMIT_WINDOW_MS,
    });

    return true;
  }

  if (entry.count >= limit) {
    return false;
  }

  entry.count++;

  return true;
}

export const editNotification = onCall(
  {
    region: FUNCTION_REGION,
  },
  async (request) => {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }

    const userId = request.auth.uid;

    const userDoc = await db.collection("users").doc(userId).get();

    if (!userDoc.exists || userDoc.data()?.role !== "admin") {
      throw new HttpsError(
        "permission-denied",
        "Only admins can edit notifications."
      );
    }

    if (!checkRateLimit(userId, "edit")) {
      throw new HttpsError("resource-exhausted", "Rate limit exceeded.");
    }

    const {notificationId, title, subtitle, body} = request.data;

    if (!notificationId || !title || !body) {
      throw new HttpsError(
        "invalid-argument",
        "notificationId, title, and body are required."
      );
    }

    const adminNotifRef = db
      .collection("adminNotifications")
      .doc(notificationId);

    const adminNotifDoc = await adminNotifRef.get();

    if (!adminNotifDoc.exists) {
      throw new HttpsError("not-found", "Notification not found.");
    }

    const adminNotifData = adminNotifDoc.data();

    if (!adminNotifData) {
      throw new HttpsError("not-found", "Notification data not found.");
    }

    const targetRole = adminNotifData.targetRole;
    const timestamp = admin.firestore.Timestamp.now();

    const updateData: Record<string, any> = {
      title,
      body,
      editedAt: timestamp,
    };

    if (subtitle) {
      updateData.subtitle = subtitle;
    } else {
      updateData.subtitle = admin.firestore.FieldValue.delete();
    }

    await adminNotifRef.update(updateData);

    const usersQuery =
      targetRole === "all" ?
        db.collection("users").where("status", "==", "approved") :
        db
          .collection("users")
          .where("status", "==", "approved")
          .where("role", "==", targetRole);

    const usersSnapshot = await usersQuery.get();

    let updatedCount = 0;

    for (const userDocSnap of usersSnapshot.docs) {
      const userNotifSnapshot = await db
        .collection("users")
        .doc(userDocSnap.id)
        .collection("notifications")
        .where("data.notificationId", "==", notificationId)
        .limit(1)
        .get();

      if (!userNotifSnapshot.empty) {
        const userNotifRef = userNotifSnapshot.docs[0].ref;

        const userUpdateData: Record<string, any> = {
          title,
          body,
          "isRead": false,
          "data.editedAt": timestamp,
        };

        if (subtitle) {
          userUpdateData.subtitle = subtitle;
        } else {
          userUpdateData.subtitle = admin.firestore.FieldValue.delete();
        }

        await userNotifRef.update(userUpdateData);
        updatedCount++;
      }
    }

    return {
      success: true,
      updatedCount,
    };
  }
);

export const deleteNotification = onCall(
  {
    region: FUNCTION_REGION,
  },
  async (request) => {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }

    const userId = request.auth.uid;

    const userDoc = await db.collection("users").doc(userId).get();

    if (!userDoc.exists || userDoc.data()?.role !== "admin") {
      throw new HttpsError(
        "permission-denied",
        "Only admins can delete notifications."
      );
    }

    if (!checkRateLimit(userId, "delete")) {
      throw new HttpsError("resource-exhausted", "Rate limit exceeded.");
    }

    const {notificationId} = request.data;

    if (!notificationId) {
      throw new HttpsError("invalid-argument", "notificationId is required.");
    }

    const adminNotifRef = db
      .collection("adminNotifications")
      .doc(notificationId);

    const adminNotifDoc = await adminNotifRef.get();

    if (!adminNotifDoc.exists) {
      throw new HttpsError("not-found", "Notification not found.");
    }

    const adminNotifData = adminNotifDoc.data();

    if (!adminNotifData) {
      throw new HttpsError("not-found", "Notification data not found.");
    }

    const targetRole = adminNotifData.targetRole;

    const usersQuery =
      targetRole === "all" ?
        db.collection("users").where("status", "==", "approved") :
        db
          .collection("users")
          .where("status", "==", "approved")
          .where("role", "==", targetRole);

    const usersSnapshot = await usersQuery.get();

    let deletedCount = 0;

    for (const userDocSnap of usersSnapshot.docs) {
      const userNotifSnapshot = await db
        .collection("users")
        .doc(userDocSnap.id)
        .collection("notifications")
        .where("data.notificationId", "==", notificationId)
        .limit(1)
        .get();

      if (!userNotifSnapshot.empty) {
        await userNotifSnapshot.docs[0].ref.delete();
        deletedCount++;
      }
    }

    await adminNotifRef.delete();

    return {
      success: true,
      deletedCount,
    };
  }
);

// ============================================================================
// CONNECTIONS
// ============================================================================

export const addScannedConnection = onCall(
  {
    region: FUNCTION_REGION,
  },
  async (request) => {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError("unauthenticated", "Not authenticated");
    }

    const scannerUserId = request.auth.uid;
    const scannedUserId = request.data.scannedUserId;

    if (!scannedUserId || typeof scannedUserId !== "string") {
      throw new HttpsError(
        "invalid-argument",
        "scannedUserId is required and must be a string"
      );
    }

    if (scannerUserId === scannedUserId) {
      throw new HttpsError(
        "invalid-argument",
        "You cannot scan your own QR code"
      );
    }

    const [scannerDoc, scannedDoc] = await Promise.all([
      db.collection("users").doc(scannerUserId).get(),
      db.collection("users").doc(scannedUserId).get(),
    ]);

    if (!scannerDoc.exists) {
      throw new HttpsError("not-found", "Scanner user not found");
    }

    if (!scannedDoc.exists) {
      throw new HttpsError("not-found", "Scanned user not found");
    }

    const scannerData = scannerDoc.data();
    const scannedData = scannedDoc.data();

    if (scannerData?.status !== "approved") {
      throw new HttpsError("permission-denied", "Your account is not approved");
    }

    if (scannedData?.status !== "approved") {
      throw new HttpsError(
        "permission-denied",
        "The scanned user is not approved"
      );
    }

    const usersIScanned = scannerData?.usersIScanned || [];
    const alreadyScanned = usersIScanned.includes(scannedUserId);

    if (alreadyScanned) {
      return {
        success: false,
        message: "User already connected",
        user: {
          uid: scannedUserId,
          name: scannedData?.name || "Unknown",
          email: scannedData?.email || "",
          profileImageUrl: scannedData?.profileImageUrl || "",
          company: scannedData?.company || "",
          title: scannedData?.title || "",
          role: scannedData?.role || "attendee",
          profileVisibility: scannedData?.profileVisibility || "minimal",
        },
      };
    }

    await Promise.all([
      db.collection("users").doc(scannerUserId).update({
        usersIScanned: admin.firestore.FieldValue.arrayUnion(scannedUserId),
      }),
      db.collection("users").doc(scannedUserId).update({
        scannedByUsers: admin.firestore.FieldValue.arrayUnion(scannerUserId),
      }),
    ]);

    return {
      success: true,
      message: "Connection established",
      user: {
        uid: scannedUserId,
        name: scannedData?.name || "Unknown",
        email: scannedData?.email || "",
        profileImageUrl: scannedData?.profileImageUrl || "",
        company: scannedData?.company || "",
        title: scannedData?.title || "",
        role: scannedData?.role || "attendee",
        profileVisibility: scannedData?.profileVisibility || "minimal",
        bio: scannedData?.bio || "",
        phone: scannedData?.phone || "",
        linkedin: scannedData?.linkedin || "",
        twitter: scannedData?.twitter || "",
        website: scannedData?.website || "",
      },
    };
  }
);

// ============================================================================
// MANUAL EMAIL VERIFICATION
// ============================================================================

export const manuallyVerifyEmails = onCall(
  {
    region: FUNCTION_REGION,
  },
  async (request) => {
    console.log("=== Start Manual Email Verification ===");

    let emails: string[];

    if (!request.auth || !request.auth.uid) {
      console.log("Running in HARDCODED mode");

      emails = [
        "adminuser@gmail.com",
        "testuser1@gmail.com",
        "speaker1@gmail.com",
        "testuser3@gmail.com",
      ];
    } else {
      const adminUid = request.auth.uid;

      const adminDoc = await db.collection("users").doc(adminUid).get();

      if (!adminDoc.exists || adminDoc.data()?.role !== "admin") {
        throw new HttpsError(
          "permission-denied",
          "Only admins can manually verify emails."
        );
      }

      emails = request.data.emails;

      if (!emails || !Array.isArray(emails) || emails.length === 0) {
        throw new HttpsError(
          "invalid-argument",
          "An array of email addresses is required."
        );
      }
    }

    const results = [];

    for (const email of emails) {
      try {
        const userRecord = await admin.auth().getUserByEmail(email);

        if (userRecord.emailVerified) {
          results.push({
            email,
            success: true,
            error: "Already verified",
          });

          continue;
        }

        await admin.auth().updateUser(userRecord.uid, {
          emailVerified: true,
        });

        results.push({
          email,
          success: true,
        });
      } catch (error) {
        const errorMessage =
          error instanceof Error ? error.message : "Unknown error";

        results.push({
          email,
          success: false,
          error: errorMessage,
        });
      }
    }

    const successCount = results.filter((r) => r.success).length;
    const failureCount = results.length - successCount;

    return {
      success: true,
      total: emails.length,
      verified: successCount,
      failed: failureCount,
      results,
    };
  }
);

// ============================================================================
// AUTH USER DELETE CLEANUP
// ============================================================================

/**
 * Triggered when a Firebase Authentication user is deleted.
 * Deletes the matching Firestore user document:
 *
 * users/{uid}
 *
 * IMPORTANT:
 * This only deletes Firestore documents where the document ID is the same
 * as the Firebase Auth UID.
 */
export const deleteAuthUserFromFirestore = functionsV1
  .region(FUNCTION_REGION)
  .auth
  .user()
  .onDelete(async (user) => {
    const uid = user.uid;
    const email = user.email || "";

    console.log(`Auth user deleted. Cleaning Firestore user: ${uid} ${email}`);

    const userRef = db.collection("users").doc(uid);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
      console.log(`No Firestore user document found for UID: ${uid}`);
      return null;
    }

    await userRef.delete();

    console.log(`Deleted Firestore user document for UID: ${uid}`);

    return null;
  });


// ============================================================================
// EVENT ARCHIVE + 15 DAY CLEANUP
// ============================================================================

async function assertAdminUser(uid: string): Promise<void> {
  const userDoc = await db.collection("users").doc(uid).get();

  if (!userDoc.exists) {
    throw new HttpsError("permission-denied", "Admin profile not found.");
  }

  const role = (userDoc.data()?.role || "").toString().toLowerCase();

  if (role !== "admin") {
    throw new HttpsError("permission-denied", "Only admins can archive events.");
  }
}

/**
 * Admin callable function.
 * Archives the event immediately and schedules attendee/speaker cleanup
 * 15 days later.
 */
export const archiveEvent = onCall(
  {
    region: FUNCTION_REGION,
  },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Please sign in first.");
    }

    await assertAdminUser(request.auth.uid);

    const eventId = (request.data?.eventId || "").toString().trim();

    if (!eventId) {
      throw new HttpsError("invalid-argument", "Missing eventId.");
    }

    const eventRef = db.collection("events").doc(eventId);
    const eventDoc = await eventRef.get();

    if (!eventDoc.exists) {
      throw new HttpsError("not-found", "Event not found.");
    }

    const now = admin.firestore.Timestamp.now();
    const cleanupDate = new Date(Date.now() + 15 * 24 * 60 * 60 * 1000);
    const cleanupScheduledAt = admin.firestore.Timestamp.fromDate(cleanupDate);

    await eventRef.set(
      {
        isActive: false,
        status: "archived",
        archivedAt: now,
        eventEndedAt: now,
        cleanupScheduledAt,
        cleanupStatus: "scheduled",
        allowUploads: false,
        allowRegistrations: false,
        allowCheckIns: false,
        updatedAt: now,
      },
      {merge: true}
    );

    return {
      success: true,
      eventId,
      cleanupScheduledAt: cleanupDate.toISOString(),
    };
  }
);

async function deleteCollectionInBatches(
  collectionRef: admin.firestore.CollectionReference,
  batchSize = 300
): Promise<number> {
  let totalDeleted = 0;

  while (totalDeleted === 0 || totalDeleted % batchSize === 0) {
    const snapshot = await collectionRef.limit(batchSize).get();

    if (snapshot.empty) break;

    const batch = db.batch();

    snapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });

    await batch.commit();

    totalDeleted += snapshot.docs.length;

    if (snapshot.docs.length < batchSize) break;
  }

  return totalDeleted;
}

async function deleteStoragePath(storagePath: string): Promise<void> {
  const cleanPath = storagePath.trim();

  if (!cleanPath) return;

  try {
    await admin.storage().bucket().file(cleanPath).delete();
  } catch (error) {
    console.log(`Storage delete skipped/failed for ${cleanPath}:`, error);
  }
}

async function cleanupEventPhotos(eventId: string): Promise<number> {
  const photosRef = db
    .collection("events")
    .doc(eventId)
    .collection("eventPhotos");

  // After the 15-day grace period, delete all event photos.
  // The admin should export/download the final report before cleanup runs.
  const photosSnap = await photosRef.get();

  let deleted = 0;

  for (const doc of photosSnap.docs) {
    const data = doc.data();

    await deleteStorageFilesFromDoc(data);
    await doc.ref.delete();

    deleted++;
  }

  return deleted;
}

async function deleteStorageFilesFromDoc(data: admin.firestore.DocumentData): Promise<number> {
  const possibleFields = [
    "storagePath",
    "filePath",
    "path",
    "photoPath",
    "imagePath",
    "certificatePath",
    "pdfPath",
    "downloadPath",
    "attachmentPath",
    "uploadPath",
  ];

  const possibleUrlFields = [
    "storagePaths",
    "filePaths",
    "photoPaths",
    "imagePaths",
    "certificatePaths",
    "pdfPaths",
    "attachmentPaths",
    "uploadPaths",
  ];

  const paths = new Set<string>();

  for (const field of possibleFields) {
    const value = data[field];
    if (typeof value === "string" && value.trim().length > 0) {
      paths.add(value.trim());
    }
  }

  for (const field of possibleUrlFields) {
    const value = data[field];
    if (Array.isArray(value)) {
      value.forEach((item) => {
        if (typeof item === "string" && item.trim().length > 0) {
          paths.add(item.trim());
        }
      });
    }
  }

  let deleted = 0;

  for (const path of paths) {
    await deleteStoragePath(path);
    deleted++;
  }

  return deleted;
}

async function deleteCollectionWithStorageInBatches(
  collectionRef: admin.firestore.CollectionReference,
  batchSize = 150
): Promise<{docsDeleted: number; storageFilesDeleted: number}> {
  let docsDeleted = 0;
  let storageFilesDeleted = 0;

  while (docsDeleted === 0 || docsDeleted % batchSize === 0) {
    const snapshot = await collectionRef.limit(batchSize).get();

    if (snapshot.empty) break;

    const batch = db.batch();

    for (const doc of snapshot.docs) {
      storageFilesDeleted += await deleteStorageFilesFromDoc(doc.data());
      batch.delete(doc.ref);
    }

    await batch.commit();

    docsDeleted += snapshot.docs.length;

    if (snapshot.docs.length < batchSize) break;
  }

  return {docsDeleted, storageFilesDeleted};
}

async function cleanupEventUsers(eventId: string): Promise<{
  authDeleted: number;
  firestoreDeleted: number;
  eventLinksRemoved: number;
}> {
  const usersSnap = await db
    .collection("users")
    .where("eventIds", "array-contains", eventId)
    .get();

  let authDeleted = 0;
  let firestoreDeleted = 0;
  let eventLinksRemoved = 0;

  for (const userDoc of usersSnap.docs) {
    const userData = userDoc.data();
    const role = (userData.role || "").toString().toLowerCase();

    if (role !== "attendee" && role !== "speaker") continue;

    const eventIds = Array.isArray(userData.eventIds) ?
      userData.eventIds.map((item) => item.toString()) :
      [];

    const isEventOnlyUser = eventIds.length <= 1;
    const uid = userDoc.id;

    if (isEventOnlyUser) {
      try {
        await admin.auth().deleteUser(uid);
        authDeleted++;
      } catch (error) {
        console.log(`Auth delete skipped/failed for ${uid}:`, error);
      }

      try {
        await userDoc.ref.delete();
        firestoreDeleted++;
      } catch (error) {
        console.log(`Firestore user delete skipped/failed for ${uid}:`, error);
      }
    } else {
      await userDoc.ref.update({
        eventIds: admin.firestore.FieldValue.arrayRemove(eventId),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      eventLinksRemoved++;
    }
  }

  return {
    authDeleted,
    firestoreDeleted,
    eventLinksRemoved,
  };
}


// ============================================================================
// AUTOMATIC EVENT NOTIFICATIONS
// ============================================================================

async function createUserNotificationOnce({
  userId,
  notificationId,
  data,
}: {
  userId: string;
  notificationId: string;
  data: Record<string, any>;
}) {
  const notificationRef = db
    .collection("users")
    .doc(userId)
    .collection("notifications")
    .doc(notificationId);

  const existingNotification = await notificationRef.get();

  if (existingNotification.exists) {
    return false;
  }

  await notificationRef.set({
    ...data,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    isRead: false,
  });

  return true;
}

/**
 * Runs every minute and alerts assigned speakers 5 minutes before their
 * active/upcoming session ends.
 */
export const sendSpeakerSessionEndingAlerts = onSchedule(
  {
    region: FUNCTION_REGION,
    schedule: "every 1 minutes",
    timeZone: "Asia/Kuala_Lumpur",
  },
  async () => {
    const now = new Date();

    const alertWindowStart = admin.firestore.Timestamp.fromDate(
      new Date(now.getTime() + 4 * 60 * 1000)
    );

    const alertWindowEnd = admin.firestore.Timestamp.fromDate(
      new Date(now.getTime() + 6 * 60 * 1000)
    );

    const sessionsSnap = await db
      .collection("sessions")
      .where("endTime", ">=", alertWindowStart)
      .where("endTime", "<=", alertWindowEnd)
      .get();

    let sentCount = 0;

    for (const sessionDoc of sessionsSnap.docs) {
      const sessionData = sessionDoc.data();

      if (sessionData.speakerFiveMinuteAlertSent === true) {
        continue;
      }

      const speakerIds = Array.isArray(sessionData.speakerIds) ?
        sessionData.speakerIds.map((speakerId) => speakerId.toString()) :
        [];

      if (speakerIds.length === 0) {
        await sessionDoc.ref.update({
          speakerFiveMinuteAlertSent: true,
          speakerFiveMinuteAlertSkippedReason: "No speakerIds found",
          speakerFiveMinuteAlertSentAt:
            admin.firestore.FieldValue.serverTimestamp(),
        });

        continue;
      }

      const eventId = (sessionData.eventId || "").toString();
      const sessionTitle = (sessionData.title || "Session").toString();
      const sessionLocation = (sessionData.location || "").toString();

      for (const speakerId of speakerIds) {
        const created = await createUserNotificationOnce({
          userId: speakerId,
          notificationId: `speaker_5min_${sessionDoc.id}`,
          data: {
            eventId,
            title: "Session Ending Soon",
            subtitle: "5 minutes remaining",
            body: `Your session "${sessionTitle}" will end in 5 minutes.`,
            type: "alert",
            targetRole: "speaker",
            includeDate: true,
            data: {
              notificationCategory: "speakerSessionEndingAlert",
              sessionId: sessionDoc.id,
              sessionTitle,
              sessionLocation,
              eventId,
            },
          },
        });

        if (created) sentCount++;
      }

      await sessionDoc.ref.update({
        speakerFiveMinuteAlertSent: true,
        speakerFiveMinuteAlertSentAt:
          admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    console.log(`Speaker 5-minute session alerts created: ${sentCount}`);
  }
);

/**
 * Runs every 5 minutes and sends a closing message to delegates/attendees and
 * speakers shortly before the active event ends.
 *
 * Required event document field:
 * endTime: Firestore Timestamp
 */
export const sendEventEndingMessages = onSchedule(
  {
    region: FUNCTION_REGION,
    schedule: "every 5 minutes",
    timeZone: "Asia/Kuala_Lumpur",
  },
  async () => {
    const now = new Date();

    const endingWindowStart = admin.firestore.Timestamp.fromDate(
      new Date(now.getTime() + 25 * 60 * 1000)
    );

    const endingWindowEnd = admin.firestore.Timestamp.fromDate(
      new Date(now.getTime() + 35 * 60 * 1000)
    );

    const eventsSnap = await db
      .collection("events")
      .where("isActive", "==", true)
      .where("endTime", ">=", endingWindowStart)
      .where("endTime", "<=", endingWindowEnd)
      .get();

    let sentCount = 0;

    for (const eventDoc of eventsSnap.docs) {
      const eventData = eventDoc.data();

      if (eventData.eventEndingMessageSent === true) {
        continue;
      }

      const eventName = (
        eventData.name ||
        eventData.title ||
        eventData.eventName ||
        "the event"
      ).toString();

      const usersSnap = await db
        .collection("users")
        .where("status", "==", "approved")
        .where("eventIds", "array-contains", eventDoc.id)
        .where("role", "in", ["attendee", "delegate", "speaker"])
        .get();

      for (const userDoc of usersSnap.docs) {
        const created = await createUserNotificationOnce({
          userId: userDoc.id,
          notificationId: `event_ending_${eventDoc.id}`,
          data: {
            eventId: eventDoc.id,
            eventName,
            title: "Event Coming to an End",
            subtitle: "Thank you for being part of this event",
            body:
              `As ${eventName} comes to an end, we sincerely thank you for ` +
              "your participation, engagement, and valuable presence. We hope " +
              "this event was meaningful and memorable for you.",
            type: "information",
            targetRole: "all",
            includeDate: true,
            data: {
              notificationCategory: "eventEndingMessage",
              eventId: eventDoc.id,
            },
          },
        });

        if (created) sentCount++;
      }

      await eventDoc.ref.update({
        eventEndingMessageSent: true,
        eventEndingMessageSentAt:
          admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    console.log(`Event ending messages created: ${sentCount}`);
  }
);

/**
 * Runs daily and cleans archived events whose cleanupScheduledAt is due.
 * Keeps admin/staff accounts and keeps approved report photos.
 */
export const cleanupArchivedEvents = onSchedule(
  {
    region: FUNCTION_REGION,
    schedule: "every 24 hours",
    timeZone: "Asia/Kuala_Lumpur",
  },
  async () => {
    const now = admin.firestore.Timestamp.now();

    const eventsSnap = await db
      .collection("events")
      .where("status", "==", "archived")
      .where("cleanupScheduledAt", "<=", now)
      .get();

    for (const eventDoc of eventsSnap.docs) {
      const eventId = eventDoc.id;
      const eventData = eventDoc.data();
      const cleanupStatus = (eventData.cleanupStatus || "scheduled")
        .toString()
        .toLowerCase();

      if (cleanupStatus === "completed" || cleanupStatus === "running") {
        continue;
      }

      await eventDoc.ref.update({
        cleanupStatus: "running",
        cleanupStartedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      try {
        const deletedPhotos = await cleanupEventPhotos(eventId);
        const userCleanup = await cleanupEventUsers(eventId);

        // Delete high-volume temporary/event-only subcollections.
        const registrationsDeleted = await deleteCollectionInBatches(
          eventDoc.ref.collection("registrations")
        );

        const screenTimeDeleted = await deleteCollectionInBatches(
          eventDoc.ref.collection("screenTime")
        );

        const notificationsDeleted = await deleteCollectionInBatches(
          eventDoc.ref.collection("notifications")
        );

        const attendanceDeleted = await deleteCollectionInBatches(
          eventDoc.ref.collection("attendance")
        );

        const feedbackDeleted = await deleteCollectionInBatches(
          eventDoc.ref.collection("feedback")
        );

        const connectionsDeleted = await deleteCollectionInBatches(
          eventDoc.ref.collection("connections")
        );

        const checkInsDeleted = await deleteCollectionInBatches(
          eventDoc.ref.collection("checkIns")
        );

        const sessionAttendanceDeleted = await deleteCollectionInBatches(
          eventDoc.ref.collection("sessionAttendance")
        );

        // These may contain Storage files such as PDF certificates or uploads.
        const certificatesCleanup = await deleteCollectionWithStorageInBatches(
          eventDoc.ref.collection("certificates")
        );

        const sessionUploadsCleanup = await deleteCollectionWithStorageInBatches(
          eventDoc.ref.collection("sessionUploads")
        );

        await eventDoc.ref.update({
          cleanupStatus: "completed",
          cleanupCompletedAt: admin.firestore.FieldValue.serverTimestamp(),
          cleanupSummary: {
            deletedPhotos,
            registrationsDeleted,
            screenTimeDeleted,
            notificationsDeleted,
            attendanceDeleted,
            feedbackDeleted,
            connectionsDeleted,
            checkInsDeleted,
            sessionAttendanceDeleted,
            certificatesDeleted: certificatesCleanup.docsDeleted,
            certificateStorageFilesDeleted: certificatesCleanup.storageFilesDeleted,
            sessionUploadsDeleted: sessionUploadsCleanup.docsDeleted,
            sessionUploadStorageFilesDeleted: sessionUploadsCleanup.storageFilesDeleted,
            ...userCleanup,
          },
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log(`Cleanup completed for event ${eventId}`);
      } catch (error) {
        console.error(`Cleanup failed for event ${eventId}:`, error);

        await eventDoc.ref.update({
          cleanupStatus: "failed",
          cleanupFailedAt: admin.firestore.FieldValue.serverTimestamp(),
          cleanupError: error instanceof Error ? error.message : String(error),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }
  }
);

