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
 * Manual QR generation for sessions.
 * Called by speakers when auto-generation fails or QR is missing.
 */
export const generateSessionQR = onCall(
  {region: FUNCTION_REGION},
  async (request) => {
    console.log("=== Start Generate Session QR ===");

    if (!request.auth || !request.auth.uid) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }

    const sessionId = request.data.sessionId;
    console.log(
      `User ${request.auth.uid} requesting QR for session ${sessionId}`
    );

    if (!sessionId || typeof sessionId !== "string") {
      throw new HttpsError(
        "invalid-argument",
        "A 'sessionId' string must be provided."
      );
    }

    try {
      // Get session document
      const sessionRef = db.collection("sessions").doc(sessionId);
      const sessionDoc = await sessionRef.get();

      if (!sessionDoc.exists) {
        throw new HttpsError("not-found", "Session not found.");
      }

      const sessionData = sessionDoc.data();

      // Verify user is a speaker for this session
      if (!sessionData?.speakerIds?.includes(request.auth.uid)) {
        throw new HttpsError(
          "permission-denied",
          "Only speakers can generate QR codes for their sessions."
        );
      }

      // Check if QR already exists
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

      // Generate new QR payload
      const randomBytes = crypto.randomBytes(8).toString("hex");
      const uniquePayload = `session::${sessionId}_${randomBytes}`;

      console.log(`Generated new QR payload for session ${sessionId}`);

      // Update session with QR payload
      await sessionRef.update({qrCodePayload: uniquePayload});

      console.log("=== End Generate Session QR (Success) ===");

      return {
        success: true,
        qrCodePayload: uniquePayload,
        message: "QR code generated successfully",
      };
    } catch (error: unknown) {
      console.error("Error generating session QR:", error);
      console.log("=== End Generate Session QR (Error) ===");

      if (error instanceof HttpsError) {
        throw error;
      }

      const errorMessage = error instanceof Error ?
        error.message : "Unknown error";
      throw new HttpsError(
        "internal",
        `Failed to generate QR: ${errorMessage}`
      );
    }
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
 * Sends a push notification ONLY to the recipient (NOT the sender).
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

    // Get the conversation members from the parent document
    const conversationDoc = await db.collection("directMessages")
      .doc(conversationId).get();

    if (!conversationDoc.exists) {
      console.log("ERROR: Conversation document does not exist.");
      return null;
    }

    const conversationData = conversationDoc.data();
    const members = conversationData?.members as string[];

    if (!members || members.length !== 2) {
      console.log(`ERROR: Invalid members array: ${JSON.stringify(members)}`);
      return null;
    }

    console.log(`Conversation members: ${JSON.stringify(members)}`);

    // Find the recipient's ID (the OTHER person, not the sender)
    const recipientId = members.find((id: string) => id !== senderId);

    if (!recipientId) {
      console.log("ERROR: Could not find recipient ID (different from sender)");
      return null;
    }

    // CRITICAL: Triple-check that recipient is NOT the sender
    if (recipientId === senderId) {
      console.log(`ERROR: Recipient equals sender (${recipientId}). ABORTING.`);
      return null;
    }

    console.log(`✓ Recipient identified: ${recipientId}`);
    console.log(`✓ Sender: ${senderId}`);
    console.log(`✓ Recipient ≠ Sender: ${recipientId !== senderId}`);

    // Get recipient's user document to find their FCM token
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

    // CRITICAL: Get sender's FCM token to compare
    const senderDoc = await db.collection("users").doc(senderId).get();
    const senderData = senderDoc.data();
    const senderFcmToken = senderData?.fcmToken;

    const senderTokenPreview =
      senderFcmToken?.substring(0, 20) || "none";
    console.log(
      `Sender FCM token (first 20 chars): ${senderTokenPreview}...`
    );
    const recipientTokenPreview = recipientFcmToken.substring(0, 20);
    console.log(
      `Recipient FCM token (first 20 chars): ${recipientTokenPreview}...`
    );

    // CRITICAL: If both users have the SAME FCM token, don't send notification
    // This happens when testing with same device logged into multiple accounts
    if (senderFcmToken && recipientFcmToken === senderFcmToken) {
      console.log("WARNING: Sender and recipient have the SAME FCM token!");
      console.log("This means that...");
      console.log("you are testing with the same device for 2 accs");
      console.log("SKIPPING notification to prevent self-notification.");
      return null;
    }

    console.log("✓ FCM tokens are different. Safe to send notification.");

    // Construct the notification message using FCM HTTP v1 API
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
      console.log(`✓ SUCCESS: Notification sent to ${recipientId}`);
      console.log(`Response: ${response}`);
      console.log("=== End DM Notification ===\n");
      return response;
    } catch (error) {
      console.error("ERROR sending DM notification:", error);

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
 * ONLY sends to the affected party (NOT the action initiator).
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

    if (!afterData) {
      console.log("No after data in meeting write.");
      return null;
    }

    console.log("\n=== Meeting Notification Triggered ===");
    console.log(`Meeting ID: ${event.params.meetingId}`);

    let recipientId: string | null = null;
    let senderId: string | null = null;
    let payload: admin.messaging.MessagingPayload;

    // Case 1: A new meeting is created (a new request is sent)
    // Notify the RECIPIENT (person receiving the request), NOT the requester
    if (!beforeData && afterData) {
      const requesterId = afterData.requesterId;
      const potentialRecipientId = afterData.recipientId;

      console.log("Case: New meeting request");
      console.log(`Requester: ${requesterId}`);
      console.log(`Recipient: ${potentialRecipientId}`);

      // CRITICAL: Ensure we're NOT notifying the person who sent the request
      if (potentialRecipientId === requesterId) {
        console.log("ERROR: Requester equals recipient. ABORTING.");
        return null;
      }

      recipientId = potentialRecipientId;
      senderId = requesterId;

      console.log(`✓ Will notify: ${recipientId} (recipient)`);
      console.log(`✓ Won't notify: ${senderId} (requester)`);

      payload = {
        notification: {
          title: "New Meeting Request",
          body: `${afterData.requesterInfo.name} wants to meet with you.`,
        },
        data: {
          type: "meeting_request",
          meetingId: event.params.meetingId,
          senderId: requesterId, // Who sent the request
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
      // Notify the REQUESTER (original person who sent the request)
      const requesterId = afterData.requesterId;
      const responderId = afterData.recipientId;

      console.log(`Case: Meeting status updated to ${afterData.status}`);
      console.log(`Original requester: ${requesterId}`);
      console.log(`Responder: ${responderId}`);

      // CRITICAL: Ensure we're NOT notifying the person who just responded
      if (requesterId === responderId) {
        console.log("ERROR: Requester equals responder. ABORTING.");
        return null;
      }

      recipientId = requesterId;
      senderId = responderId;

      console.log(`✓ Will notify: ${recipientId} (original requester)`);
      console.log(`✓ Won't notify: ${senderId} (responder)`);

      payload = {
        notification: {
          title: `Meeting Request ${afterData.status}`,
          body: `${afterData.recipientInfo.name} has ` +
            `${afterData.status} your meeting request.`,
        },
        data: {
          type: "meeting_update",
          meetingId: event.params.meetingId,
          senderId: responderId, // Who responded to the request
          status: afterData.status,
        },
      };
    } else {
      console.log("No notification needed for this meeting change.");
      return null;
    }

    if (!recipientId) {
      console.log("ERROR: No recipient ID determined.");
      return null;
    }

    // Get recipient's FCM token
    const recipientDoc = await db.collection("users").doc(recipientId).get();

    if (!recipientDoc.exists) {
      console.log(`ERROR: Recipient user ${recipientId} does not exist.`);
      return null;
    }

    const recipientData = recipientDoc.data();
    const recipientFcmToken = recipientData?.fcmToken;

    if (!recipientFcmToken) {
      console.log(`Recipient ${recipientId} does not have an FCM token.`);
      return null;
    }

    // CRITICAL: Get sender's FCM token to compare (if sender exists)
    if (senderId) {
      const senderDoc = await db.collection("users").doc(senderId).get();
      const senderData = senderDoc.data();
      const senderFcmToken = senderData?.fcmToken;

      console.log(`Sndr FCM: ${senderFcmToken?.substring(0, 20) || "none"}...`);
      console.log(`Recipient FCM: ${recipientFcmToken.substring(0, 20)}...`);

      // If both users have the SAME FCM token, don't send
      if (senderFcmToken && recipientFcmToken === senderFcmToken) {
        console.log("WARNING: Sender and recipient have SAME FCM token!");
        console.log("Testing with same device. SKIPPING notification.");
        return null;
      }

      console.log("✓ FCM tokens are different. Safe to send.");
    }

    // Construct the notification message using FCM HTTP v1 API
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
      const response = await admin.messaging().send(message);
      console.log(`✓ SUCCESS: Meeting notification sent to ${recipientId}`);
      console.log(`Response: ${response}`);
      console.log("=== End Meeting Notification ===\n");
      return response;
    } catch (error) {
      console.error("ERROR sending meeting notification:", error);

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
