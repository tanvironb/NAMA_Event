import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/features/chat/screen/widgets/chat_bubble.dart';
import 'package:events_app_trueattempt/features/chat/screen/widgets/message_composer.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';

class SessionChatScreen extends ConsumerStatefulWidget {
  final Session session;

  const SessionChatScreen({super.key, required this.session});

  @override
  ConsumerState<SessionChatScreen> createState() => _SessionChatScreenState();
}

class _SessionChatScreenState extends ConsumerState<SessionChatScreen> {
  void _toggleChatEnabled() async {
    final chatRepo = ref.read(chatRepositoryProvider);
    final newState = !widget.session.isChatEnabled;
    
    try {
      await chatRepo.toggleChatEnabled(widget.session.id, newState);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newState ? 'Chat enabled' : 'Chat closed'),
            backgroundColor: newState ? AppColors.successGreen : AppColors.errorRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update chat status: $e')),
        );
      }
    }
  }

  void _deleteMessage(String messageId) async {
    final chatRepo = ref.read(chatRepositoryProvider);
    
    try {
      await chatRepo.deleteMessage(widget.session.id, messageId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete message: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch for real-time session updates
    final sessionAsync = ref.watch(sessionStreamProvider(widget.session.id));
    final messagesAsync = ref.watch(sessionChatStreamProvider(widget.session.id));
    final currentUserAsync = ref.watch(userAppProfileStreamProvider);

    return sessionAsync.when(
      data: (currentSession) {
        if (currentSession == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Session Not Found')),
            body: const Center(child: Text('This session no longer exists.')),
          );
        }

        return currentUserAsync.when(
          data: (currentUser) {
            if (currentUser == null) {
              return Scaffold(
                appBar: AppBar(title: Text(currentSession.title)),
                body: const Center(child: Text('You must be logged in to view this chat.')),
              );
            }

            // Check if user is speaker or admin
            final bool isSpeakerOrAdmin = currentUser.role == 'admin' || 
                currentUser.role == 'speaker' ||
                currentSession.speakerIds.contains(currentUser.uid);

            return Scaffold(
              appBar: AppBar(
                title: Text(currentSession.title, overflow: TextOverflow.ellipsis),
                actions: [
                  // Speaker/Admin controls
                  if (isSpeakerOrAdmin)
                    IconButton(
                      icon: Icon(
                        currentSession.isChatEnabled ? Icons.lock_open : Icons.lock,
                        color: currentSession.isChatEnabled ? AppColors.successGreen : AppColors.errorRed,
                      ),
                      onPressed: _toggleChatEnabled,
                      tooltip: currentSession.isChatEnabled ? 'Close Chat' : 'Open Chat',
                    ),
                  // Analytics icon
                  if (isSpeakerOrAdmin)
                    IconButton(
                      icon: const Icon(Icons.analytics_outlined),
                      onPressed: () {
                        // Show analytics info
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Session Analytics'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Total Messages: ${currentSession.totalMessages}'),
                                Text('Unique Participants: ${currentSession.uniqueParticipants.length}'),
                                Text('Checked-in Attendees: ${currentSession.checkedInAttendees.length}'),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        );
                      },
                      tooltip: 'View Analytics',
                    ),
                ],
              ),
              body: Column(
                children: [
                  // Session status banner
                  if (currentSession.hasEnded)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      color: AppColors.errorRed.withOpacity(0.1),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy, size: 16, color: AppColors.errorRed),
                          const SizedBox(width: 8),
                          Text(
                            'This session has ended',
                            style: TextStyle(
                              color: AppColors.errorRed,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (!currentSession.isChatEnabled)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      color: AppColors.warningAmber.withOpacity(0.1),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock, size: 16, color: AppColors.warningAmber),
                          const SizedBox(width: 8),
                          Text(
                            isSpeakerOrAdmin 
                                ? 'Chat is closed (you can still view messages)'
                                : 'Chat is closed by speaker',
                            style: TextStyle(
                              color: AppColors.warningAmber,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Messages list
                  Expanded(
                    child: messagesAsync.when(
                      data: (messages) {
                        if (messages.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 64,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No messages yet',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: Colors.grey.shade600,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Be the first to say something!',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.grey.shade500,
                                      ),
                                ),
                              ],
                            ),
                          );
                        }
                        return ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.all(8.0),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            final isMe = message.senderId == currentUser.uid;
                            
                            return ChatBubble(
                              message: message,
                              isMe: isMe,
                              sessionSpeakerId: currentSession.speakerIds.isNotEmpty 
                                  ? currentSession.speakerIds.first 
                                  : null,
                              onDeleteMessage: isSpeakerOrAdmin && !isMe
                                  ? () => _deleteMessage(message.id)
                                  : null,
                            );
                          },
                        );
                      },
                      loading: () => const LoadingIndicator(),
                      error: (err, stack) => Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 64, color: AppColors.errorRed),
                            const SizedBox(height: 16),
                            Text('Error loading messages', style: TextStyle(color: AppColors.errorRed)),
                            const SizedBox(height: 8),
                            Text(err.toString(), style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Message composer
                  MessageComposer(
                    session: currentSession,
                    currentUser: currentUser,
                  ),
                ],
              ),
            );
          },
          loading: () => Scaffold(
            appBar: AppBar(title: Text(currentSession.title)),
            body: const LoadingIndicator(),
          ),
          error: (err, stack) => Scaffold(
            appBar: AppBar(title: Text(currentSession.title)),
            body: Center(child: Text('Error: $err')),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: Text(widget.session.title)),
        body: const LoadingIndicator(),
      ),
      error: (err, stack) => Scaffold(
        appBar: AppBar(title: Text(widget.session.title)),
        body: Center(child: Text('Error: $err')),
      ),
    );
  }
}