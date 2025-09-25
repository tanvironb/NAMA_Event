import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/features/chat/screen/widgets/chat_bubble.dart';
import 'package:events_app_trueattempt/features/chat/screen/widgets/message_composer.dart';

class SessionChatScreen extends ConsumerWidget {
  final Session session;

  const SessionChatScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(sessionChatStreamProvider(session.id));
    final currentUserAsync = ref.watch(userAppProfileStreamProvider);

    return Scaffold(
      appBar: AppBar(title: Text(session.title, overflow: TextOverflow.ellipsis)),
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
                    if (messages.isEmpty) {
                      return const Center(child: Text('Be the first to say something!'));
                    }
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
              MessageComposer(
                session: session,
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