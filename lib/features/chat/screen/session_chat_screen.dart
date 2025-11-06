import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/features/chat/screen/widgets/chat_bubble.dart';
import 'package:events_app_trueattempt/features/chat/screen/widgets/message_composer.dart';
import 'package:events_app_trueattempt/features/feedback/widgets/session_feedback_dialog.dart';
import 'package:events_app_trueattempt/features/feedback/data/feedback_repository.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';

class SessionChatScreen extends ConsumerStatefulWidget {
  final Session session;

  const SessionChatScreen({super.key, required this.session});

  @override
  ConsumerState<SessionChatScreen> createState() => _SessionChatScreenState();
}

class _SessionChatScreenState extends ConsumerState<SessionChatScreen> {
  bool _hasShownFeedbackOnce = false; // Track if feedback was shown this session
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

  Future<void> _checkAndShowFeedbackDialog(Session session, String userId) async {
    // Only show feedback if:
    // 1. Session has ended
    // 2. User is checked in
    // 3. User is not a moderator (admin or session speaker)
    // 4. Haven't shown feedback in this screen session
    
    if (!session.hasEnded) return;
    if (_hasShownFeedbackOnce) return;
    
    final isAdmin = ref.read(userAppProfileStreamProvider).asData?.value?.role == 'admin';
    final isSessionSpeaker = session.speakerIds.contains(userId);
    if (isAdmin == true || isSessionSpeaker) return;
    
    if (!session.checkedInAttendees.contains(userId)) return;
    
    // Check feedback status
    final feedbackRepo = FeedbackRepository();
    final feedbackStatus = await feedbackRepo.getFeedbackStatus(
      userId: userId,
      sessionId: session.id,
    );
    
    if (!feedbackStatus.shouldShowPrompt) return;
    
    // Mark as shown for this screen session to prevent loops
    _hasShownFeedbackOnce = true;
    
    // Show dialog after a brief delay to let the screen settle
    if (mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        final currentUser = ref.read(userAppProfileStreamProvider).asData?.value;
        if (currentUser != null) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => SessionFeedbackDialog(
              sessionId: session.id,
              sessionTitle: session.title,
              currentUser: currentUser,
              onDismissed: () {
                // Feedback was dismissed
              },
              onSubmitted: () {
                // Feedback was submitted
              },
            ),
          );
        }
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

            // Check and show feedback dialog if appropriate
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _checkAndShowFeedbackDialog(currentSession, currentUser.uid);
            });

            return Scaffold(
              appBar: AppBar(
                title: Text(currentSession.title, overflow: TextOverflow.ellipsis),
                actions: [
                  // Speaker/Admin controls - only show if session hasn't ended
                  if (canModerate && !currentSession.hasEnded)
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
                        // Show enhanced analytics info
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Session Chat Analytics'),
                            content: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Basic Stats
                                  Text(
                                    'Overview',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.navyBlue,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildAnalyticsRow('Total Messages', '${currentSession.totalMessages}'),
                                  _buildAnalyticsRow('Deleted Messages', '${currentSession.deletedMessagesCount}'),
                                  _buildAnalyticsRow('Unique Participants', '${currentSession.uniqueParticipants.length}'),
                                  _buildAnalyticsRow('Checked-in Attendees', '${currentSession.checkedInAttendees.length}'),
                                  if (currentSession.checkedInAttendees.isNotEmpty)
                                    _buildAnalyticsRow(
                                      'Engagement Rate',
                                      '${currentSession.engagementRate.toStringAsFixed(1)}%',
                                    ),
                                  
                                  const Divider(height: 20),
                                  
                                  // Messages by Role
                                  Text(
                                    'Messages by Role',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.navyBlue,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (currentSession.messagesByRole.isEmpty)
                                    const Text('No messages yet', style: TextStyle(color: AppColors.textSecondary))
                                  else
                                    ...currentSession.messagesByRole.entries.map((entry) =>
                                      _buildAnalyticsRow(
                                        entry.key.capitalize(),
                                        '${entry.value} (${((entry.value / currentSession.totalMessages) * 100).toStringAsFixed(0)}%)',
                                      ),
                                    ),
                                  
                                  const Divider(height: 20),
                                  
                                  // Activity Stats
                                  Text(
                                    'Activity',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.navyBlue,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (currentSession.firstMessageAt != null)
                                    _buildAnalyticsRow(
                                      'First Message',
                                      _formatTime(currentSession.firstMessageAt!),
                                    ),
                                  if (currentSession.lastMessageAt != null)
                                    _buildAnalyticsRow(
                                      'Last Message',
                                      _formatTime(currentSession.lastMessageAt!),
                                    ),
                                  if (currentSession.chatDurationMinutes > 0)
                                    _buildAnalyticsRow(
                                      'Chat Duration',
                                      '${currentSession.chatDurationMinutes} min',
                                    ),
                                  if (currentSession.uniqueParticipants.isNotEmpty)
                                    _buildAnalyticsRow(
                                      'Avg Messages/User',
                                      currentSession.averageMessagesPerParticipant.toStringAsFixed(1),
                                    ),
                                  
                                  const Divider(height: 20),
                                  
                                  // Moderation Stats
                                  Text(
                                    'Moderation',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.navyBlue,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildAnalyticsRow('Currently Muted', '${currentSession.mutedUsers.length}'),
                                  _buildAnalyticsRow('Total Mute Actions', '${currentSession.totalMuteActions}'),
                                  _buildAnalyticsRow('Unique Users Muted', '${currentSession.muteHistory.length}'),
                                  if (currentSession.closedBy.isNotEmpty)
                                    _buildAnalyticsRow('Chat Status', 'Closed by ${currentSession.closedBy}'),
                                ],
                              ),
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
  
  // Helper method to build analytics row
  Widget _buildAnalyticsRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
  
  // Helper method to format time
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}

// Extension to capitalize first letter
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}