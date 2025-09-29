// lib/features/messaging/screen/direct_message_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/features/chat/screen/widgets/chat_bubble.dart';
import 'package:events_app_trueattempt/features/messaging/screen/widgets/direct_message_composer.dart';

class DirectMessageScreen extends ConsumerWidget {
  final String conversationId;
  final String otherUserName;
  final String otherUserProfileImage;

  const DirectMessageScreen({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    this.otherUserProfileImage = '',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(directMessagesStreamProvider(conversationId));
    final currentUserAsync = ref.watch(userAppProfileStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: otherUserProfileImage.isNotEmpty
                  ? NetworkImage(otherUserProfileImage)
                  : null,
              child: otherUserProfileImage.isEmpty
                  ? Text(
                      otherUserName.isNotEmpty ? otherUserName[0].toUpperCase() : 'U',
                      style: const TextStyle(fontSize: 14),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                otherUserName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: currentUserAsync.when(
        data: (currentUser) {
          if (currentUser == null) {
            return const Center(child: Text('You must be logged in to chat.'));
          }
          
          return Column(
            children: [
              Expanded(
                child: messagesAsync.when(
                  data: (messages) {
                    if (messages.isEmpty) return const Center(child: Text('Say hello!'));
                    
                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(8.0),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMe = message.senderId == currentUser.uid;
                        return ChatBubble(message: message, isMe: isMe);
                      },
                    );
                  },
                  loading: () => const LoadingIndicator(),
                  error: (err, stack) => Center(child: Text('Error: $err')),
                ),
              ),
              DirectMessageComposer(
                conversationId: conversationId,
                currentUser: currentUser,
              ),
            ],
          );
        },
        loading: () => const LoadingIndicator(),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}