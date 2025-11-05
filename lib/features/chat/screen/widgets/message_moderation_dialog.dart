import 'package:flutter/material.dart';
import 'package:events_app_trueattempt/core/models/message_model.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:intl/intl.dart';

/// Dialog for moderating session chat messages (mute/unmute user, delete message)
/// Only shown when a moderator (admin or registered session speaker) long-presses a message
class MessageModerationDialog {
  /// Show the moderation dialog as a bottom sheet
  static void show({
    required BuildContext context,
    required Message message,
    required bool isUserMuted,
    required VoidCallback onMute,
    required VoidCallback onUnmute,
    required VoidCallback onDelete,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.shield_outlined, color: AppColors.navyBlue, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Moderation Options',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.navyBlue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Message from ${message.senderName}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            
            // Message preview
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          message.senderName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        DateFormat('HH:mm:ss').format(message.timestamp.toDate()),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message.text,
                    style: const TextStyle(fontSize: 14),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Moderation Actions
            // Mute/Unmute Action
            ListTile(
              leading: Icon(
                isUserMuted ? Icons.volume_up : Icons.volume_off,
                color: AppColors.warningAmber,
              ),
              title: Text(
                isUserMuted ? 'Unmute User' : 'Mute User',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                isUserMuted
                    ? 'Allow ${message.senderName} to send messages'
                    : 'Prevent ${message.senderName} from sending messages',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              onTap: () {
                Navigator.pop(context); // Close bottom sheet
                _showMuteConfirmation(
                  context: context,
                  message: message,
                  isUnmute: isUserMuted,
                  onConfirm: isUserMuted ? onUnmute : onMute,
                );
              },
            ),
            
            const Divider(height: 8),
            
            // Delete Action
            ListTile(
              leading: const Icon(Icons.delete, color: AppColors.errorRed),
              title: const Text(
                'Delete Message',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'Remove this message from the chat',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              onTap: () {
                Navigator.pop(context); // Close bottom sheet
                _showDeleteConfirmation(
                  context: context,
                  message: message,
                  onConfirm: onDelete,
                );
              },
            ),
            
            const SizedBox(height: 8),
            
            // Cancel button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show confirmation dialog for mute/unmute action
  static void _showMuteConfirmation({
    required BuildContext context,
    required Message message,
    required bool isUnmute,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isUnmute ? Icons.volume_up : Icons.volume_off,
              color: AppColors.warningAmber,
            ),
            const SizedBox(width: 8),
            Text(isUnmute ? 'Unmute User?' : 'Mute User?'),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: DefaultTextStyle.of(context).style,
            children: [
              TextSpan(
                text: isUnmute
                    ? 'Are you sure you want to unmute '
                    : 'Are you sure you want to mute ',
              ),
              TextSpan(
                text: message.senderName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text: isUnmute
                    ? '?\n\nThey will be able to send messages in this session again.'
                    : '?\n\nThey will not be able to send messages in this session until unmuted.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warningAmber,
              foregroundColor: Colors.white,
            ),
            child: Text(isUnmute ? 'Unmute' : 'Mute'),
          ),
        ],
      ),
    );
  }

  /// Show confirmation dialog for delete action
  static void _showDeleteConfirmation({
    required BuildContext context,
    required Message message,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete, color: AppColors.errorRed),
            SizedBox(width: 8),
            Text('Delete Message?'),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: DefaultTextStyle.of(context).style,
            children: [
              const TextSpan(text: 'Are you sure you want to delete this message from '),
              TextSpan(
                text: message.senderName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text: '?\n\n"',
              ),
              TextSpan(
                text: message.text,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
              const TextSpan(
                text: '"\n\nThis action cannot be undone.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
