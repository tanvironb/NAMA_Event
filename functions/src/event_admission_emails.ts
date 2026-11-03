/* eslint-disable max-len */
/* eslint-disable require-jsdoc */
/* eslint-disable no-multiple-empty-lines */
import {getFirestore, FieldValue} from "firebase-admin/firestore";
import {defineSecret} from "firebase-functions/params";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {Resend} from "resend";
import * as QRCode from "qrcode";
import {createHash} from "node:crypto";

const REGION = "asia-southeast1";
const MAX_EMAILS_PER_REQUEST = 200;
const resendApiKey = defineSecret("RESEND_API_KEY");

type InvitationInput = { admissionId: string; token: string };

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function sha256(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

function escapeHtml(value: string): string {
  return value.replace(/[&<>"']/g, (character) => {
    const entities: Record<string, string> = {
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      "\"": "&quot;",
      "'": "&#39;",
    };
    return entities[character];
  });
}

function validId(value: unknown, label: string): string {
  const id = text(value);
  if (!id || id.includes("/") || id.length > 1500) {
    throw new HttpsError("invalid-argument", `A valid ${label} is required.`);
  }
  return id;
}

function requireToken(value: unknown): string {
  const token = text(value);
  if (!/^[A-Za-z0-9_-]{40,100}$/.test(token)) {
    throw new HttpsError("invalid-argument", "An invitation token is invalid.");
  }
  return token;
}

async function requireEventManager(uid: string, eventId: string): Promise<void> {
  const db = getFirestore();
  const eventRef = db.collection("events").doc(eventId);
  const [eventSnapshot, registrationSnapshot, profileSnapshot] = await Promise.all([
    eventRef.get(),
    eventRef.collection("registrations").doc(uid).get(),
    db.collection("users").doc(uid).get(),
  ]);

  if (!eventSnapshot.exists) {
    throw new HttpsError("not-found", "Event not found.");
  }

  const event = eventSnapshot.data() ?? {};
  const registration = registrationSnapshot.data() ?? {};
  const profile = profileSnapshot.data() ?? {};
  const profileRole = text(profile.role).toLowerCase();
  const registrationRole = text(registration.role).toLowerCase();
  const approved = text(registration.status || "approved").toLowerCase() === "approved";
  const globalAdmin = ["admin", "superadmin", "super_admin"].includes(profileRole);
  const eventOwner = [
    event.organiserId,
    event.organizerId,
    event.ownerUid,
    event.createdBy,
  ].some((owner) => owner === uid);
  const eventManager =
    ["admin", "organiser", "organizer"].includes(registrationRole) && approved;

  if (!globalAdmin && !eventOwner && !eventManager) {
    throw new HttpsError(
      "permission-denied",
      "Approved event organiser access is required.",
    );
  }
}

/** Emails QR attachments for invitation records created by createEventInvitations. */
export const sendEventAdmissionEmails = onCall(
  {
    region: REGION,
    timeoutSeconds: 300,
    memory: "512MiB",
    secrets: [resendApiKey],
  },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Please sign in first.");
    }

    const eventId = validId(request.data?.eventId, "event ID");
    const invitations = request.data?.invitations;
    if (
      !Array.isArray(invitations) ||
      invitations.length === 0 ||
      invitations.length > MAX_EMAILS_PER_REQUEST
    ) {
      throw new HttpsError(
        "invalid-argument",
        `Provide between 1 and ${MAX_EMAILS_PER_REQUEST} invitations.`,
      );
    }

    await requireEventManager(request.auth.uid, eventId);
    const db = getFirestore();
    const eventRef = db.collection("events").doc(eventId);
    const eventSnapshot = await eventRef.get();
    const eventName = text(eventSnapshot.data()?.name) || "NAMA Events";
    const resend = new Resend(resendApiKey.value());
    const sent: string[] = [];
    const failed: Array<{admissionId: string; email: string; reason: string}> = [];
    const alreadySent: string[] = [];

    const sendOne = async (raw: unknown): Promise<void> => {
      if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
        failed.push({admissionId: "", email: "", reason: "Invalid invitation entry."});
        return;
      }

      const input = raw as Partial<InvitationInput>;
      const admissionId = validId(input.admissionId, "admission ID");
      const token = requireToken(input.token);
      const admissionRef = eventRef.collection("admissions").doc(admissionId);
      const admissionSnapshot = await admissionRef.get();
      if (!admissionSnapshot.exists) {
        failed.push({admissionId, email: "", reason: "Invitation record was not found."});
        return;
      }

      const admission = admissionSnapshot.data() ?? {};
      const email = text(admission.email);
      const name = text(admission.name) || "Participant";
      if (
        text(admission.source) !== "invitation" ||
        text(admission.invitationTokenHash) !== sha256(token)
      ) {
        failed.push({admissionId, email, reason: "Invitation token did not match its record."});
        return;
      }
      if (!email) {
        failed.push({admissionId, email: "", reason: "Invitation email is missing."});
        return;
      }
      if (text(admission.invitationEmailStatus).toLowerCase() === "sent") {
        alreadySent.push(admissionId);
        return;
      }

      await admissionRef.update({
        invitationEmailStatus: "sending",
        invitationEmailError: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      try {
        const qrBuffer = await QRCode.toBuffer(token, {
          type: "png",
          width: 420,
          margin: 2,
          errorCorrectionLevel: "M",
        });
        const qrBase64 = qrBuffer.toString("base64");
        const safeName = escapeHtml(name);
        const safeEventName = escapeHtml(eventName);
        const result = await resend.emails.send({
          from: "NAMA Events <ai@namafoundation.org>",
          replyTo: "ai@namafoundation.org",
          to: [email],
          subject: `Your invitation to ${eventName}`,
          html: `
            <div style="font-family:Arial,sans-serif;color:#101828;line-height:1.6;max-width:600px;margin:auto">
              <h2 style="color:#0B1D3A">You’re invited to ${safeEventName}</h2>
              <p>Hello ${safeName},</p>
              <p>Your event invitation QR is attached to this email. Please bring it with you and show it to event staff at check-in.</p>
              <p>If your email app supports inline images, your QR is shown below. The PNG attachment is available if it does not display.</p>
              <p style="text-align:center"><img alt="Event invitation QR" width="260" height="260" src="data:image/png;base64,${qrBase64}" /></p>
              <p>Please keep this QR private. It is linked to your invitation.</p>
              <p>— NAMA Events</p>
            </div>`,
          text:
            `Hello ${name},\n\n` +
            `You are invited to ${eventName}. Your invitation QR is attached as a PNG. ` +
            "Please bring it and show it to event staff at check-in. Keep the QR private.\n\n— NAMA Events",
          attachments: [{
            filename: `nama-event-invitation-${admissionId.slice(0, 8)}.png`,
            content: qrBase64,
          }],
        });

        if (result.error) {
          throw new Error(result.error.message);
        }

        await admissionRef.update({
          invitationEmailStatus: "sent",
          invitationEmailSentAt: FieldValue.serverTimestamp(),
          invitationEmailProvider: "resend",
          invitationEmailId: result.data?.id ?? "",
          updatedAt: FieldValue.serverTimestamp(),
        });
        sent.push(admissionId);
      } catch (error) {
        const reason = error instanceof Error ? error.message : "Email could not be sent.";
        await admissionRef.update({
          invitationEmailStatus: "failed",
          invitationEmailError: reason.slice(0, 500),
          updatedAt: FieldValue.serverTimestamp(),
        });
        failed.push({admissionId, email, reason});
      }
    };

    // Bound concurrency to avoid bursts against the email provider.
    for (let offset = 0; offset < invitations.length; offset += 5) {
      await Promise.all(invitations.slice(offset, offset + 5).map(sendOne));
    }

    return {sent, failed, alreadySent};
  },
);
