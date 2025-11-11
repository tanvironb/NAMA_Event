import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/models/message_model.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/features/chat/screen/widgets/message_moderation_dialog.dart';
import 'package:events_app_trueattempt/features/profile/screen/user_details_screen.dart';

class ChatBubble extends ConsumerWidget {
  final Message message;
  final bool isMe;
  final List<String> sessionSpeakerIds; // Speaker IDs for this session
  final bool isUserMuted; // Whether this message sender is muted
  final VoidCallback? onMuteUser; // Callback for muting user
  final VoidCallback? onUnmuteUser; // Callback for unmuting user
  final VoidCallback? onDeleteMessage; // Callback for message deletion
  final bool isSessionChat; // Whether this is a session chat (not DM)

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.sessionSpeakerIds = const [],
    this.isUserMuted = false,
    this.onMuteUser,
    this.onUnmuteUser,
    this.onDeleteMessage,
    this.isSessionChat = true,
  });

  /// Get color for user role name display
  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return AppColors.adminColor;
      case 'speaker':
        return AppColors.speakerColor;
      case 'staff':
        return AppColors.staffColor;
      case 'attendee':
      default:
        return AppColors.attendeeColor;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(userAppProfileStreamProvider).asData?.value;
    
    // Check if current user is authorized moderator for this session
    final bool isAdmin = currentUser?.role == 'admin';
    final bool isSessionSpeaker = currentUser != null && sessionSpeakerIds.contains(currentUser.uid);
    final bool canModerate = isSessionChat && (isAdmin || isSessionSpeaker) && !isMe;

    return GestureDetector(
      // Long-press to show moderation options (session chat only)
      onLongPress: canModerate ? () {
        MessageModerationDialog.show(
          context: context,
          message: message,
          isUserMuted: isUserMuted,
          onMute: () {
            onMuteUser?.call();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${message.senderName} has been muted'),
                backgroundColor: AppColors.warningAmber,
              ),
            );
          },
          onUnmute: () {
            onUnmuteUser?.call();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${message.senderName} has been unmuted'),
                backgroundColor: AppColors.successGreen,
              ),
            );
          },
          onDelete: () {
            onDeleteMessage?.call();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Message deleted'),
                backgroundColor: AppColors.errorRed,
              ),
            );
          },
        );
      } : null,
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chat bubble
          Flexible(
            child: Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isMe ? AppColors.navyBlue : AppColors.lightGray,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                    bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                  ),
                  // Add subtle border if user is muted (for moderators to see)
                  border: canModerate && isUserMuted 
                      ? Border.all(color: AppColors.warningAmber, width: 2)
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    // Show sender name and role for others' messages (WhatsApp style)
                    if (!isMe)
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UserDetailsScreen(userId: message.senderId),
                            ),
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              message.senderName,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: _getRoleColor(message.senderRole),
                                    decoration: TextDecoration.underline,
                                  ),
                            ),
                            // Show muted indicator to moderators
                            if (canModerate && isUserMuted) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.volume_off,
                                size: 12,
                                color: AppColors.warningAmber,
                              ),
                            ],
                          ],
                        ),
                      ),
                    if (!isMe) const SizedBox(height: 4),
                    Text(
                      message.text,
                      style: TextStyle(color: isMe ? Colors.white : Colors.black87),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}