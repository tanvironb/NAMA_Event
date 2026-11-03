import * as admin from "firebase-admin";

const ANDROID_CHANNEL_ID =
  "nama_events_high_importance_channel";

/**
 * Sends a notification with phone banner settings.
 * @param {admin.messaging.Message} message Original push message.
 * @return {Promise<string>} Firebase message ID.
 */
export async function sendNamaPush(
  message: admin.messaging.Message
): Promise<string> {
  const hasVisibleNotification =
    message.notification !== undefined;

  const configuredMessage: admin.messaging.Message = {
    ...message,

    android: {
      ...message.android,
      priority: "high",

      ...(hasVisibleNotification ? {
        notification: {
          ...message.android?.notification,
          channelId: ANDROID_CHANNEL_ID,
          priority: "high",
          sound: "default",
        },
      } : {}),
    },

    apns: {
      ...message.apns,

      headers: {
        ...message.apns?.headers,

        ...(hasVisibleNotification ? {
          "apns-push-type": "alert",
          "apns-priority": "10",
        } : {}),
      },

      payload: {
        ...message.apns?.payload,

        aps: {
          ...message.apns?.payload?.aps,

          ...(hasVisibleNotification ? {
            sound: "default",
          } : {}),
        },
      },
    },
  };

  return admin.messaging().send(configuredMessage);
}
