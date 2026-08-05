/* functions/src/account_deletion.ts */

/* eslint-disable max-len */
/* eslint-disable require-jsdoc */
/* eslint-disable @typescript-eslint/no-explicit-any */

import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as crypto from "crypto";

const FUNCTION_REGION = "asia-southeast1";

type DocumentData = admin.firestore.DocumentData;
type DocRef = admin.firestore.DocumentReference<DocumentData>;
type UpdateData = admin.firestore.UpdateData<DocumentData>;

type WriteOperation =
  | {type: "set"; ref: DocRef; data: DocumentData}
  | {type: "update"; ref: DocRef; data: UpdateData}
  | {type: "delete"; ref: DocRef};

function db(): admin.firestore.Firestore {
  return admin.firestore();
}

function anonymousId(uid: string): string {
  return `deleted_${crypto
    .createHash("sha256")
    .update(uid)
    .digest("hex")
    .slice(0, 16)}`;
}

function recentlyAuthenticated(authTime: unknown): boolean {
  if (typeof authTime !== "number") return false;
  const age = Math.floor(Date.now() / 1000) - authTime;
  return age >= 0 && age <= 10 * 60;
}

async function commit(operations: WriteOperation[]): Promise<void> {
  for (let i = 0; i < operations.length; i += 400) {
    const batch = db().batch();

    for (const operation of operations.slice(i, i + 400)) {
      if (operation.type === "set") {
        batch.set(operation.ref, operation.data, {merge: true});
      } else if (operation.type === "update") {
        batch.update(operation.ref, operation.data);
      } else {
        batch.delete(operation.ref);
      }
    }

    await batch.commit();
  }
}

async function moveToAnonymousDocument(params: {
  oldRef: DocRef;
  newRef: DocRef;
  oldData: DocumentData;
  anonymousData: DocumentData;
}): Promise<void> {
  await commit([
    {
      type: "set",
      ref: params.newRef,
      data: {
        ...params.oldData,
        ...params.anonymousData,
      },
    },
    {
      type: "delete",
      ref: params.oldRef,
    },
  ]);
}

async function deleteStorageFile(path: string): Promise<void> {
  const cleanPath = path.trim();
  if (!cleanPath) return;

  try {
    await admin.storage().bucket().file(cleanPath).delete();
  } catch (error: any) {
    if (error?.code !== 404) {
      console.error(`Storage deletion failed: ${cleanPath}`, error);
    }
  }
}

async function processEvents(
  uid: string,
  anonId: string,
  summary: Record<string, number>
): Promise<void> {
  const events = await db().collection("events").get();

  let attendance = 0;
  let registrations = 0;
  let certificates = 0;
  let approvedPhotos = 0;
  let deletedPhotos = 0;
  let eventsUpdated = 0;

  for (const eventDoc of events.docs) {
    const eventRef = eventDoc.ref;
    const eventData = eventDoc.data();

    const attendanceRef = eventRef.collection("attendance").doc(uid);
    const attendanceDoc = await attendanceRef.get();

    if (attendanceDoc.exists) {
      await moveToAnonymousDocument({
        oldRef: attendanceRef,
        newRef: eventRef.collection("attendance").doc(anonId),
        oldData: attendanceDoc.data() ?? {},
        anonymousData: {
          userId: anonId,
          userName: "Deleted User",
          userEmail: "",
          accountDeleted: true,
          originalUserReferenceRemoved: true,
          anonymizedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      });
      attendance++;
    }

    const registrationRef = eventRef.collection("registrations").doc(uid);
    const registrationDoc = await registrationRef.get();

    if (registrationDoc.exists) {
      await moveToAnonymousDocument({
        oldRef: registrationRef,
        newRef: eventRef.collection("registrations").doc(anonId),
        oldData: registrationDoc.data() ?? {},
        anonymousData: {
          userId: anonId,
          name: "Deleted User",
          email: "",
          profileImageUrl: "",
          accountDeleted: true,
          originalUserReferenceRemoved: true,
          anonymizedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      });
      registrations++;
    }

    const certificateDocs =
      await eventRef.collection("certificates").get();
    const certificateOps: WriteOperation[] = [];

    for (const certificate of certificateDocs.docs) {
      const data = certificate.data();
      if ((data.userId ?? "").toString() !== uid) continue;

      certificateOps.push({
        type: "update",
        ref: certificate.ref,
        data: {
          userId: anonId,
          userName: "Deleted User",
          userEmail: "",
          accountDeleted: true,
          originalUserReferenceRemoved: true,
          anonymizedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      });
      certificates++;
    }

    await commit(certificateOps);

    const photoDocs = await eventRef.collection("eventPhotos").get();
    const photoOps: WriteOperation[] = [];

    for (const photo of photoDocs.docs) {
      const data = photo.data();
      if ((data.userId ?? "").toString() !== uid) continue;

      const status = (data.status ?? "pending")
        .toString()
        .trim()
        .toLowerCase();

      if (status === "approved") {
        photoOps.push({
          type: "update",
          ref: photo.ref,
          data: {
            userId: anonId,
            userName: "Deleted User",
            userEmail: "",
            accountDeleted: true,
            originalUserReferenceRemoved: true,
            anonymizedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
        });
        approvedPhotos++;
      } else {
        await deleteStorageFile((data.storagePath ?? "").toString());
        photoOps.push({type: "delete", ref: photo.ref});
        deletedPhotos++;
      }
    }

    await commit(photoOps);

    const arrayFields = [
      "checkedInAttendees",
      "speakerIds",
      "moderatorIds",
      "staffIds",
      "volunteerIds",
      "attendeeIds",
      "participantIds",
    ];

    const containsUid = arrayFields.some((field) => {
      const value = eventData[field];
      return Array.isArray(value) && value.includes(uid);
    });

    if (containsUid) {
      await eventRef.update({
        checkedInAttendees:
          admin.firestore.FieldValue.arrayRemove(uid),
        speakerIds:
          admin.firestore.FieldValue.arrayRemove(uid),
        moderatorIds:
          admin.firestore.FieldValue.arrayRemove(uid),
        staffIds:
          admin.firestore.FieldValue.arrayRemove(uid),
        volunteerIds:
          admin.firestore.FieldValue.arrayRemove(uid),
        attendeeIds:
          admin.firestore.FieldValue.arrayRemove(uid),
        participantIds:
          admin.firestore.FieldValue.arrayRemove(uid),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      eventsUpdated++;
    }
  }

  summary.eventAttendance = attendance;
  summary.registrations = registrations;
  summary.certificates = certificates;
  summary.approvedPhotosAnonymized = approvedPhotos;
  summary.unapprovedPhotosDeleted = deletedPhotos;
  summary.eventsUpdated = eventsUpdated;
}

async function processSessions(
  uid: string,
  anonId: string,
  summary: Record<string, number>
): Promise<void> {
  const sessions = await db().collection("sessions").get();

  let checkins = 0;
  let legacyCheckins = 0;
  let feedback = 0;
  let messagesDeleted = 0;
  let sessionsUpdated = 0;

  for (const sessionDoc of sessions.docs) {
    const sessionRef = sessionDoc.ref;
    const sessionData = sessionDoc.data();

    const checkinRef = sessionRef.collection("checkins").doc(uid);
    const checkinDoc = await checkinRef.get();

    if (checkinDoc.exists) {
      await moveToAnonymousDocument({
        oldRef: checkinRef,
        newRef: sessionRef.collection("checkins").doc(anonId),
        oldData: checkinDoc.data() ?? {},
        anonymousData: {
          userId: anonId,
          accountDeleted: true,
          originalUserReferenceRemoved: true,
          anonymizedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      });
      checkins++;
    }

    const legacyCheckinRef = sessionRef.collection("checkIns").doc(uid);
    const legacyCheckinDoc = await legacyCheckinRef.get();

    if (legacyCheckinDoc.exists) {
      await moveToAnonymousDocument({
        oldRef: legacyCheckinRef,
        newRef: sessionRef.collection("checkIns").doc(anonId),
        oldData: legacyCheckinDoc.data() ?? {},
        anonymousData: {
          userId: anonId,
          accountDeleted: true,
          originalUserReferenceRemoved: true,
          anonymizedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      });
      legacyCheckins++;
    }

    const feedbackRef = sessionRef.collection("feedback").doc(uid);
    const feedbackDoc = await feedbackRef.get();

    if (feedbackDoc.exists) {
      await moveToAnonymousDocument({
        oldRef: feedbackRef,
        newRef: sessionRef.collection("feedback").doc(anonId),
        oldData: feedbackDoc.data() ?? {},
        anonymousData: {
          userId: anonId,
          userName: "Anonymous Attendee",
          userEmail: "",
          isAnonymous: true,
          accountDeleted: true,
          originalUserReferenceRemoved: true,
          anonymizedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      });
      feedback++;
    }

    const messageDocs = await sessionRef.collection("messages").get();
    const messageOps: WriteOperation[] = [];

    for (const message of messageDocs.docs) {
      const data = message.data();
      const senderId = (data.senderId ?? data.userId ?? "").toString();

      if (senderId === uid) {
        messageOps.push({type: "delete", ref: message.ref});
        messagesDeleted++;
      }
    }

    await commit(messageOps);

    const arrayFields = [
      "checkedInAttendees",
      "speakerIds",
      "moderatorIds",
      "staffIds",
      "volunteerIds",
    ];

    const containsUid = arrayFields.some((field) => {
      const value = sessionData[field];
      return Array.isArray(value) && value.includes(uid);
    });

    if (containsUid) {
      await sessionRef.update({
        checkedInAttendees:
          admin.firestore.FieldValue.arrayRemove(uid),
        speakerIds:
          admin.firestore.FieldValue.arrayRemove(uid),
        moderatorIds:
          admin.firestore.FieldValue.arrayRemove(uid),
        staffIds:
          admin.firestore.FieldValue.arrayRemove(uid),
        volunteerIds:
          admin.firestore.FieldValue.arrayRemove(uid),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      sessionsUpdated++;
    }
  }

  summary.sessionCheckins = checkins;
  summary.legacySessionCheckins = legacyCheckins;
  summary.feedback = feedback;
  summary.sessionMessagesDeleted = messagesDeleted;
  summary.sessionsUpdated = sessionsUpdated;
}

async function processTopLevelPhotos(
  uid: string,
  anonId: string,
  summary: Record<string, number>
): Promise<void> {
  const snapshot = await db()
    .collection("eventPhotos")
    .where("userId", "==", uid)
    .get();

  const operations: WriteOperation[] = [];
  let anonymized = 0;
  let deleted = 0;

  for (const document of snapshot.docs) {
    const data = document.data();
    const status = (data.status ?? "pending")
      .toString()
      .trim()
      .toLowerCase();

    if (status === "approved") {
      operations.push({
        type: "update",
        ref: document.ref,
        data: {
          userId: anonId,
          userName: "Deleted User",
          userEmail: "",
          accountDeleted: true,
          originalUserReferenceRemoved: true,
          anonymizedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      });
      anonymized++;
    } else {
      await deleteStorageFile((data.storagePath ?? "").toString());
      operations.push({type: "delete", ref: document.ref});
      deleted++;
    }
  }

  await commit(operations);
  summary.topLevelApprovedPhotosAnonymized = anonymized;
  summary.topLevelUnapprovedPhotosDeleted = deleted;
}

async function removeConnections(uid: string): Promise<number> {
  const users = await db().collection("users").get();
  const operations: WriteOperation[] = [];
  let count = 0;

  for (const user of users.docs) {
    if (user.id === uid) continue;

    const data = user.data();
    const iScanned = Array.isArray(data.usersIScanned) ?
      data.usersIScanned :
      [];
    const scannedMe = Array.isArray(data.scannedByUsers) ?
      data.scannedByUsers :
      [];

    if (!iScanned.includes(uid) && !scannedMe.includes(uid)) {
      continue;
    }

    operations.push({
      type: "update",
      ref: user.ref,
      data: {
        usersIScanned:
          admin.firestore.FieldValue.arrayRemove(uid),
        scannedByUsers:
          admin.firestore.FieldValue.arrayRemove(uid),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
    });
    count++;
  }

  await commit(operations);
  return count;
}

async function anonymizeHelpTickets(
  uid: string,
  anonId: string
): Promise<number> {
  const snapshot = await db()
    .collection("help_tickets")
    .where("userId", "==", uid)
    .get();

  const operations: WriteOperation[] = snapshot.docs.map((document) => ({
    type: "update",
    ref: document.ref,
    data: {
      userId: anonId,
      userName: "Deleted User",
      userEmail: "",
      accountDeleted: true,
      originalUserReferenceRemoved: true,
      anonymizedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  }));

  await commit(operations);
  return snapshot.size;
}

async function deleteTopLevelMessages(uid: string): Promise<number> {
  let count = 0;

  for (const collectionName of [
    "messages",
    "direct_messages",
    "directMessages",
  ]) {
    const snapshot = await db()
      .collection(collectionName)
      .where("senderId", "==", uid)
      .get();

    await commit(
      snapshot.docs.map((document) => ({
        type: "delete",
        ref: document.ref,
      }))
    );

    count += snapshot.size;
  }

  return count;
}

async function deleteMeetings(uid: string): Promise<number> {
  const references = new Map<string, DocRef>();

  for (const field of ["requesterId", "recipientId"]) {
    const snapshot = await db()
      .collection("meetings")
      .where(field, "==", uid)
      .get();

    for (const document of snapshot.docs) {
      references.set(document.ref.path, document.ref);
    }
  }

  await commit(
    [...references.values()].map((reference) => ({
      type: "delete",
      ref: reference,
    }))
  );

  return references.size;
}

async function deleteProfileStorage(uid: string): Promise<void> {
  const bucket = admin.storage().bucket();

  try {
    await bucket.file(`profile/${uid}.jpg`).delete();
  } catch (error: any) {
    if (error?.code !== 404) {
      console.error("Profile image deletion failed:", error);
    }
  }

  for (const prefix of [
    `profile_images/${uid}/`,
    `users/${uid}/`,
  ]) {
    try {
      await bucket.deleteFiles({prefix});
    } catch (error) {
      console.error(`Storage prefix cleanup failed: ${prefix}`, error);
    }
  }
}

async function verifyLastAdmin(
  uid: string,
  userData: DocumentData
): Promise<void> {
  const role = (userData.role ?? "")
    .toString()
    .trim()
    .toLowerCase();

  if (role !== "admin") return;

  const users = await db().collection("users").get();

  const otherApprovedAdmins = users.docs.filter((document) => {
    if (document.id === uid) return false;

    const data = document.data();
    const otherRole = (data.role ?? "")
      .toString()
      .trim()
      .toLowerCase();
    const status = (data.status ?? "approved")
      .toString()
      .trim()
      .toLowerCase();

    return otherRole === "admin" && status === "approved";
  });

  if (otherApprovedAdmins.length === 0) {
    throw new HttpsError(
      "failed-precondition",
      "This is the only active administrator account. " +
        "Assign another administrator before deleting it."
    );
  }
}

export const deleteMyAccount = onCall(
  {
    region: FUNCTION_REGION,
    timeoutSeconds: 300,
    memory: "1GiB",
  },
  async (request) => {
    const uid = request.auth?.uid;

    if (!uid) {
      throw new HttpsError(
        "unauthenticated",
        "Please sign in before deleting your account."
      );
    }

    if (!recentlyAuthenticated(request.auth?.token?.auth_time)) {
      throw new HttpsError(
        "failed-precondition",
        "Please confirm your password again before deleting your account."
      );
    }

    const userRef = db().collection("users").doc(uid);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
      throw new HttpsError(
        "not-found",
        "The account profile could not be found."
      );
    }

    const userData = userDoc.data() ?? {};
    await verifyLastAdmin(uid, userData);

    const anonId = anonymousId(uid);
    const summary: Record<string, number> = {};

    try {
      await processEvents(uid, anonId, summary);
      await processSessions(uid, anonId, summary);
      await processTopLevelPhotos(uid, anonId, summary);

      summary.connectionProfilesUpdated =
        await removeConnections(uid);
      summary.helpTickets =
        await anonymizeHelpTickets(uid, anonId);
      summary.topLevelMessagesDeleted =
        await deleteTopLevelMessages(uid);
      summary.meetingsDeleted =
        await deleteMeetings(uid);

      await deleteProfileStorage(uid);

      // Deletes users/{uid} and its private subcollections.
      await db().recursiveDelete(userRef);

      // Authentication is deleted last.
      await admin.auth().deleteUser(uid);

      console.log("Account deletion completed.", {
        uid,
        anonId,
        summary,
      });

      return {
        success: true,
        message: "Your account was permanently deleted.",
        summary,
      };
    } catch (error) {
      console.error("deleteMyAccount failed.", {
        uid,
        anonId,
        summary,
        error,
      });

      if (error instanceof HttpsError) {
        throw error;
      }

      throw new HttpsError(
        "internal",
        "Account deletion could not be completed. Please try again.",
        {summary}
      );
    }
  }
);
