// lib/features/messaging/screen/widgets/conversation_list_tile.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/models/conversation_model.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/features/messaging/screen/direct_message_screen.dart';
import 'package:events_app_trueattempt/utils/date_time_utils.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';

class ConversationListTile extends ConsumerWidget {
  final Conversation conversation;
  const ConversationListTile({super.key, required this.conversation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(firebaseAuthProvider).currentUser?.uid;
    // Find the other user's ID
    final otherUserId = conversation.members.firstWhere((id) => id != currentUserId, orElse: () => '');
    
    if (otherUserId.isEmpty || currentUserId == null) return const SizedBox.shrink();

    final otherUserName = conversation.memberInfo[otherUserId]?['name'] ?? 'User';
    final otherUserImage = conversation.memberInfo[otherUserId]?['profileImageUrl'] ?? '';
    
    // Get unread count for current user
    final unreadCount = conversation.getUnreadCountForUser(currentUserId);
    final hasUnread = unreadCount > 0;
    
    // Smart time formatting
    final formattedTime = DateTimeUtils.formatMessageTimestamp(
      conversation.lastMessageTimestamp.toDate(),
    );

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        radius: 28,
        backgroundImage: otherUserImage.isNotEmpty ? NetworkImage(otherUserImage) : null,
        backgroundColor: AppColors.namaLightGray,
        child: otherUserImage.isEmpty 
          ? Text(
              otherUserName[0].toUpperCase(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.namaNavyBlue,
              ),
            )
          : null,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              otherUserName,
              style: TextStyle(
                fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
                fontSize: 16,
                color: AppColors.namaDarkGray,
              ),
            ),
          ),
          Text(
            formattedTime,
            style: TextStyle(
              fontSize: 12,
              color: hasUnread ? AppColors.namaNavyBlue : AppColors.namaMediumGray,
              fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              conversation.lastMessageText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.namaMediumGray,
                fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          if (hasUnread)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.namaNavyBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                unreadCount.toString(),
                style: const TextStyle(
                  color: AppColors.namaWhite,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => DirectMessageScreen(
            conversationId: conversation.id,
            otherUserId: otherUserId,
            otherUserName: otherUserName,
            otherUserProfileImage: otherUserImage,
          ),
        ));
      },
    );
  }
}