// lib/features/messaging/screen/widgets/conversation_list_tile.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:events_app_trueattempt/core/models/conversation_model.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/features/messaging/screen/direct_message_screen.dart';

class ConversationListTile extends ConsumerWidget {
  final Conversation conversation;
  const ConversationListTile({super.key, required this.conversation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(firebaseAuthProvider).currentUser?.uid;
    // Find the other user's ID
    final otherUserId = conversation.members.firstWhere((id) => id != currentUserId, orElse: () => '');
    
    if (otherUserId.isEmpty) return const SizedBox.shrink(); // Should not happen

    final otherUserName = conversation.memberInfo[otherUserId]?['name'] ?? 'User';
    final otherUserImage = conversation.memberInfo[otherUserId]?['profileImageUrl'] ?? '';
    final timeAgo = DateFormat.jm().format(conversation.lastMessageTimestamp.toDate());

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: otherUserImage.isNotEmpty ? NetworkImage(otherUserImage) : null,
        child: otherUserImage.isEmpty ? Text(otherUserName[0].toUpperCase()) : null,
      ),
      title: Text(otherUserName, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(
        conversation.lastMessageText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(timeAgo),
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => DirectMessageScreen(
            conversationId: conversation.id,
            otherUserName: otherUserName,
            otherUserProfileImage: otherUserImage,
          ),
        ));
      },
    );
  }
}