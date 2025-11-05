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
  void _toggleChatEnabled(Session currentSession, String userRole) async {
    final chatRepo = ref.read(chatRepositoryProvider);
    final newState = !currentSession.isChatEnabled;
    
    // Check if admin is trying to override speaker lock
    if (currentSession.isAdminLocked && userRole == 'speaker') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot override admin lock'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }
    
    final closedByRole = userRole == 'admin' ? 'admin' : 'speaker';
    
    try {
      await chatRepo.toggleChatEnabled(currentSession.id, newState, closedByRole);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newState ? 'Chat opened' : 'Chat closed'),
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

  void _muteUser(String userId) async {
    final chatRepo = ref.read(chatRepositoryProvider);
    
    try {
      await chatRepo.muteUser(widget.session.id, userId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mute user: $e')),
        );
      }
    }
  }

  void _unmuteUser(String userId) async {
    final chatRepo = ref.read(chatRepositoryProvider);
    
    try {
      await chatRepo.unmuteUser(widget.session.id, userId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unmute user: $e')),
        );
      }
    }
  }

  void _deleteMessage(String messageId) async {
    final chatRepo = ref.read(chatRepositoryProvider);
    
    try {
      await chatRepo.deleteMessage(widget.session.id, messageId);
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

            // Check permissions
            final bool isAdmin = currentUser.role == 'admin';
            final bool isSessionSpeaker = currentSession.speakerIds.contains(currentUser.uid);
            final bool canModerate = isAdmin || isSessionSpeaker;

            return Scaffold(
              appBar: AppBar(
                title: Text(currentSession.title, overflow: TextOverflow.ellipsis),
                actions: [
                  // Speaker/Admin controls
                  if (canModerate)
                    IconButton(
                      icon: Icon(
                        currentSession.isChatEnabled ? Icons.lock_open : Icons.lock,
                        color: currentSession.isChatEnabled ? AppColors.successGreen : AppColors.errorRed,
                      ),
                      onPressed: () => _toggleChatEnabled(currentSession, currentUser.role),
                      tooltip: currentSession.isChatEnabled ? 'Close Chat' : 'Open Chat',
                    ),
                  // Analytics icon
                  if (canModerate)
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
                                Text('Muted Users: ${currentSession.mutedUsers.length}'),
                                if (currentSession.closedBy.isNotEmpty)
                                  Text('Chat closed by: ${currentSession.closedBy}'),
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
                          Flexible(
                            child: Text(
                              currentSession.closedBy.isNotEmpty
                                  ? 'Chat closed by ${currentSession.closedBy}'
                                  : 'Chat is closed',
                              style: TextStyle(
                                color: AppColors.warningAmber,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
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
                            final isMessageSenderMuted = currentSession.isUserMuted(message.senderId);
                            
                            return ChatBubble(
                              message: message,
                              isMe: isMe,
                              sessionSpeakerIds: currentSession.speakerIds,
                              isUserMuted: isMessageSenderMuted,
                              isSessionChat: true,
                              onMuteUser: canModerate && !isMe
                                  ? () => _muteUser(message.senderId)
                                  : null,
                              onUnmuteUser: canModerate && !isMe
                                  ? () => _unmuteUser(message.senderId)
                                  : null,
                              onDeleteMessage: canModerate && !isMe
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