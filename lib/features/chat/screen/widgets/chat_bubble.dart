import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/models/message_model.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/providers.dart';

class ChatBubble extends ConsumerWidget {
  final Message message;
  final bool isMe;
  final String? sessionSpeakerId; // Optional speaker ID for this session
  final VoidCallback? onDeleteMessage; // Callback for message deletion

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.sessionSpeakerId,
    this.onDeleteMessage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(userAppProfileStreamProvider).asData?.value;
    final bool isSpeakerOrAdmin = currentUser != null && 
        (currentUser.role == 'admin' || 
         currentUser.role == 'speaker' ||
         (sessionSpeakerId != null && currentUser.uid == sessionSpeakerId));

    return Row(
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Delete button for speakers/admins on other users' messages
        if (isSpeakerOrAdmin && !isMe && onDeleteMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 4),
            child: IconButton(
              icon: Icon(
                Icons.delete_outline,
                size: 18,
                color: Colors.grey.shade600,
              ),
              onPressed: () => _showDeleteConfirmation(context),
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
              padding: EdgeInsets.zero,
            ),
          ),
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
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Text(
                      message.senderName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.navyBlue,
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
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Message'),
          content: const Text(
            'Are you sure you want to delete this message? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onDeleteMessage?.call();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}