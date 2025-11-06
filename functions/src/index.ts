import {
  onDocumentWritten,
  onDocumentCreated,
} from "firebase-functions/v2/firestore";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as crypto from "crypto";

admin.initializeApp();
const db = admin.firestore();

// Region configuration - must match your Firestore region (asia-southeast1)
const FUNCTION_REGION = "asia-southeast1";

/**
 * Triggered on any write to a user document.
 * Generates a secure QR code payload when a user's status becomes 'approved'.
 */
export const handleUserWrite = onDocumentWritten(
  {document: "users/{userId}", region: FUNCTION_REGION},
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
  {document: "sessions/{sessionId}", region: FUNCTION_REGION},
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
export const validateQrCode = onCall(
  {region: FUNCTION_REGION},
  async (request) => {
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
export const logEventCheckIn = onCall(
  {region: FUNCTION_REGION},
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
export const logSessionCheckIn = onCall(
  {region: FUNCTION_REGION},
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

/**
 * NEW: Triggered when a new direct message is created.
 * Sends a push notification to the recipient.
 */
export const onNewDirectMessage = onDocumentCreated(
  {
    document: "directMessages/{conversationId}/messages/{messageId}",
    region: FUNCTION_REGION,
  },
  async (event) => {
    const messageData = event.data?.data();
    if (!messageData) return null;

    const conversationId = event.params.conversationId;

    // Get the conversation members from the parent document
    const conversationDoc = await db.collection("directMessages")
      .doc(conversationId).get();
    const members = conversationDoc.data()?.members as string[];

    // Find the recipient's ID
    const recipientId = members.find(
      (id: string) => id !== messageData.senderId
    );
    if (!recipientId) {
      console.log("Recipient not found.");
      return null;
    }

    // Get recipient's user document to find their FCM token
    const recipientDoc = await db.collection("users").doc(recipientId).get();
    const fcmToken = recipientDoc.data()?.fcmToken;

    if (!fcmToken) {
      console.log(`Recipient ${recipientId} does not have an FCM token.`);
      return null;
    }

    // Get sender's full profile for deep linking
    const senderDoc = await db
      .collection("users")
      .doc(messageData.senderId)
      .get();
    const senderData = senderDoc.data();

    const tokenPreview = fcmToken.substring(0, 20);
    console.log(`Sending DM notification to user ${recipientId} ` +
      `with token: ${tokenPreview}...`);

    // Construct the notification message using FCM HTTP v1 API
    const message = {
      token: fcmToken,
      notification: {
        title: `New message from ${messageData.senderName}`,
        body: messageData.text,
      },
      data: {
        type: "dm",
        conversationId: conversationId,
        senderId: messageData.senderId,
        otherUserId: messageData.senderId,
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
      console.log(`Successfully sent DM notification: ${response}`);
      return response;
    } catch (error) {
      console.error("Error sending DM notification:", error);

      // If token is invalid, remove it from the user document
      if (error instanceof Error &&
          (error.message.includes("registration-token-not-registered") ||
           error.message.includes("invalid-registration-token"))) {
        console.log(`Removing invalid FCM token for user ${recipientId}`);
        await db.collection("users").doc(recipientId).update({
          fcmToken: admin.firestore.FieldValue.delete(),
        });
      }

      throw error;
    }
  }
);

/**
 * NEW: Triggered when a session ends.
 * Sends feedback request notifications to-
 * all checked-in attendees (excluding speakers).
 */
export const onSessionEnd = onDocumentWritten(
  {document: "sessions/{sessionId}", region: FUNCTION_REGION},
  async (event) => {
    const beforeData = event.data?.before?.exists ?
      event.data.before.data() :
      null;
    const afterData = event.data?.after?.exists ?
      event.data.after.data() :
      null;

    // Only proceed if this is an update (not creation or deletion)
    if (!beforeData || !afterData) return null;

    const sessionId = event.params.sessionId;
    const endTime = (afterData.endTime as admin.firestore.Timestamp).toDate();
    const now = new Date();

    // Check if session just ended (within last 5 minutes)
    const timeSinceEnd = now.getTime() - endTime.getTime();
    if (timeSinceEnd < 0 || timeSinceEnd > 5 * 60 * 1000) {
      return null; // Session hasn't ended yet or ended more than 5 minutes ago
    }

    // Get checked-in attendees (excluding speakers)
    const checkedInAttendees = afterData.checkedInAttendees || [];
    const speakerIds = afterData.speakerIds || [];
    const sessionTitle = afterData.title || "Session";
    const eventId = afterData.eventId;

    // Filter out speakers from attendees
    const attendeesToNotify = checkedInAttendees.filter(
      (uid: string) => !speakerIds.includes(uid)
    );

    if (attendeesToNotify.length === 0) {
      console.log(`No attendees to notify for session ${sessionId}`);
      return null;
    }

    console.log(
      `Sending feedback notifications for session ${sessionId} ` +
      `to ${attendeesToNotify.length} attendees`
    );

    // Send notifications to all attendees
    const notificationPromises = attendeesToNotify.map(
      async (attendeeId: string) => {
        try {
          const userDoc = await db.collection("users").doc(attendeeId).get();
          const fcmToken = userDoc.data()?.fcmToken;

          if (!fcmToken) {
            console.log(`Attendee ${attendeeId} does not have an FCM token.`);
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

          const response = await admin.messaging().send(message);
          console.log(
            `Sent feedback notification to ${attendeeId}: ${response}`
          );
          return response;
        } catch (error) {
          console.error(
            `Error sending feedback notification to ${attendeeId}:`,
            error
          );

          // If token is invalid, remove it
          if (error instanceof Error &&
              (error.message.includes("registration-token-not-registered") ||
               error.message.includes("invalid-registration-token"))) {
            console.log(`Removing invalid FCM token for user ${attendeeId}`);
            await db.collection("users").doc(attendeeId).update({
              fcmToken: admin.firestore.FieldValue.delete(),
            });
          }

          return null;
        }
      }
    );

    await Promise.all(notificationPromises);
    return null;
  }
);

/**
 * NEW: Triggered on any write to the meetings collection.
 * Sends a notification for new requests or status updates.
 */
export const onMeetingWrite = onDocumentWritten(
  {document: "meetings/{meetingId}", region: FUNCTION_REGION},
  async (event) => {
    const beforeData = event.data?.before?.exists ?
      event.data.before.data() :
      null;
    const afterData = event.data?.after?.exists ?
      event.data.after.data() :
      null;

    let recipientId: string | null = null;
    let payload: admin.messaging.MessagingPayload;

    // Case 1: A new meeting is created (a new request is sent)
    if (!beforeData && afterData) {
      recipientId = afterData.recipientId;
      payload = {
        notification: {
          title: "New Meeting Request",
          body: `${afterData.requesterInfo.name} wants to meet with you.`,
        },
        data: {
          type: "meeting_request",
          meetingId: event.params.meetingId,
          requesterName: afterData.requesterInfo.name,
          proposedTime: afterData.proposedTime.toDate().toISOString(),
        },
      };
    } else if (
      beforeData && afterData &&
      beforeData.status === "pending" &&
      afterData.status !== "pending"
    ) {
      // Case 2: An existing meeting is updated (accepted/rejected)
      recipientId = afterData.requesterId; // Notify requester
      payload = {
        notification: {
          title: `Meeting Request ${afterData.status}`,
          body: `${afterData.recipientInfo.name} has ` +
            `${afterData.status} your meeting request.`,
        },
        data: {
          type: "meeting_update",
          meetingId: event.params.meetingId,
          status: afterData.status,
        },
      };
    } else {
      return null; // No notification needed
    }

    if (!recipientId) {
      console.log("No recipient ID found.");
      return null;
    }

    // Get recipient's FCM token and send the notification
    const recipientDoc = await db.collection("users").doc(recipientId).get();
    const fcmToken = recipientDoc.data()?.fcmToken;
    if (!fcmToken) {
      console.log(`Recipient ${recipientId} does not have an FCM token.`);
      return null;
    }

    const tokenPreview = fcmToken.substring(0, 20);
    console.log(`Sending meeting notification to user ${recipientId} ` +
      `with token: ${tokenPreview}...`);

    // Construct the notification message using FCM HTTP v1 API
    const message = {
      token: fcmToken,
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
      const response = await admin.messaging().send(message);
      console.log(`Successfully sent meeting notification: ${response}`);
      return response;
    } catch (error) {
      console.error("Error sending meeting notification:", error);

      // If token is invalid, remove it from the user document
      if (error instanceof Error &&
          (error.message.includes("registration-token-not-registered") ||
           error.message.includes("invalid-registration-token"))) {
        console.log(`Removing invalid FCM token for user ${recipientId}`);
        await db.collection("users").doc(recipientId).update({
          fcmToken: admin.firestore.FieldValue.delete(),
        });
      }

      throw error;
    }
  }
);
