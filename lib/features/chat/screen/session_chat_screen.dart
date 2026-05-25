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

  const SessionChatScreen({
    super.key,
    required this.session,
  });

  @override
  ConsumerState<SessionChatScreen> createState() => _SessionChatScreenState();
}

class _SessionChatScreenState extends ConsumerState<SessionChatScreen> {
  bool _hasShownFeedbackOnce = false;

  Future<void> _toggleChatEnabled(
    Session currentSession,
    String userRole,
  ) async {
    final chatRepo = ref.read(chatRepositoryProvider);
    final newState = !currentSession.isChatEnabled;

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
      await chatRepo.toggleChatEnabled(
        currentSession.id,
        newState,
        closedByRole,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newState ? 'Chat opened' : 'Chat closed'),
          backgroundColor:
              newState ? AppColors.successGreen : AppColors.errorRed,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update chat status: $e'),
        ),
      );
    }
  }

  Future<void> _muteUser(String userId) async {
    final chatRepo = ref.read(chatRepositoryProvider);

    try {
      await chatRepo.muteUser(widget.session.id, userId);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mute user: $e')),
      );
    }
  }

  Future<void> _unmuteUser(String userId) async {
    final chatRepo = ref.read(chatRepositoryProvider);

    try {
      await chatRepo.unmuteUser(widget.session.id, userId);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to unmute user: $e')),
      );
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    final chatRepo = ref.read(chatRepositoryProvider);

    try {
      await chatRepo.deleteMessage(widget.session.id, messageId);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete message: $e')),
      );
    }
  }

  Future<void> _checkAndShowFeedbackDialog(
    Session session,
    String userId,
  ) async {
    if (!session.hasEnded) return;
    if (_hasShownFeedbackOnce) return;

    final currentUser = ref.read(userAppProfileStreamProvider).asData?.value;
    if (currentUser == null) return;

    final isAdmin = currentUser.role == 'admin';
    final isSessionSpeaker = session.speakerIds.contains(userId);

    if (isAdmin || isSessionSpeaker) return;
    if (!session.checkedInAttendees.contains(userId)) return;

    final feedbackRepo = FeedbackRepository();
    final feedbackStatus = await feedbackRepo.getFeedbackStatus(
      userId: userId,
      sessionId: session.id,
    );

    if (!feedbackStatus.shouldShowPrompt) return;

    _hasShownFeedbackOnce = true;

    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SessionFeedbackDialog(
        sessionId: session.id,
        sessionTitle: session.title,
        currentUser: currentUser,
        onDismissed: () {},
        onSubmitted: () {},
      ),
    );
  }

  void _showAnalyticsDialog(BuildContext context, Session currentSession) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Session Chat Analytics',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.navyBlue,
              ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _analyticsSectionTitle(context, 'Overview'),
              const SizedBox(height: 8),
              _buildAnalyticsRow(
                'Total Messages',
                '${currentSession.totalMessages}',
              ),
              _buildAnalyticsRow(
                'Deleted Messages',
                '${currentSession.deletedMessagesCount}',
              ),
              _buildAnalyticsRow(
                'Unique Participants',
                '${currentSession.uniqueParticipants.length}',
              ),
              _buildAnalyticsRow(
                'Checked-in Attendees',
                '${currentSession.checkedInAttendees.length}',
              ),
              if (currentSession.checkedInAttendees.isNotEmpty)
                _buildAnalyticsRow(
                  'Engagement Rate',
                  '${currentSession.engagementRate.toStringAsFixed(1)}%',
                ),
              const Divider(height: 20),
              _analyticsSectionTitle(context, 'Messages by Role'),
              const SizedBox(height: 8),
              if (currentSession.messagesByRole.isEmpty)
                const Text(
                  'No messages yet',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                  ),
                )
              else
                ...currentSession.messagesByRole.entries.map(
                  (entry) => _buildAnalyticsRow(
                    entry.key.capitalize(),
                    currentSession.totalMessages == 0
                        ? '${entry.value} (0%)'
                        : '${entry.value} (${((entry.value / currentSession.totalMessages) * 100).toStringAsFixed(0)}%)',
                  ),
                ),
              const Divider(height: 20),
              _analyticsSectionTitle(context, 'Activity'),
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
                  currentSession.averageMessagesPerParticipant
                      .toStringAsFixed(1),
                ),
              const Divider(height: 20),
              _analyticsSectionTitle(context, 'Moderation'),
              const SizedBox(height: 8),
              _buildAnalyticsRow(
                'Currently Muted',
                '${currentSession.mutedUsers.length}',
              ),
              _buildAnalyticsRow(
                'Total Mute Actions',
                '${currentSession.totalMuteActions}',
              ),
              _buildAnalyticsRow(
                'Unique Users Muted',
                '${currentSession.muteHistory.length}',
              ),
              if (currentSession.closedBy.isNotEmpty)
                _buildAnalyticsRow(
                  'Chat Status',
                  'Closed by ${currentSession.closedBy}',
                ),
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
  }

  Widget _analyticsSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.navyBlue,
            fontSize: 13,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionStreamProvider(widget.session.id));
    final messagesAsync =
        ref.watch(sessionChatStreamProvider(widget.session.id));
    final currentUserAsync = ref.watch(userAppProfileStreamProvider);

    return sessionAsync.when(
      data: (currentSession) {
        if (currentSession == null) {
          return _SimpleStateScaffold(
            title: 'Session Chat',
            child: const Center(
              child: Text(
                'This session no longer exists.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          );
        }

        return currentUserAsync.when(
          data: (currentUser) {
            if (currentUser == null) {
              return _SimpleStateScaffold(
                title: 'Session Chat',
                child: const Center(
                  child: Text(
                    'You must be logged in to view this chat.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              );
            }

            final bool isAdmin = currentUser.role == 'admin';
            final bool isSessionSpeaker =
                currentSession.speakerIds.contains(currentUser.uid);
            final bool canModerate = isAdmin || isSessionSpeaker;

            WidgetsBinding.instance.addPostFrameCallback((_) {
              _checkAndShowFeedbackDialog(currentSession, currentUser.uid);
            });

            return Scaffold(
              backgroundColor: const Color(0xFFF8F8F8),
              body: SafeArea(
                child: Column(
                  children: [
                    _ChatHeader(
                      title: 'Session Chat',
                      onBack: () => Navigator.of(context).pop(),
                      actions: [
                        if (canModerate && !currentSession.hasEnded)
                          _HeaderIconButton(
                            icon: currentSession.isChatEnabled
                                ? Icons.lock_open
                                : Icons.lock,
                            color: currentSession.isChatEnabled
                                ? AppColors.successGreen
                                : AppColors.errorRed,
                            onTap: () => _toggleChatEnabled(
                              currentSession,
                              currentUser.role,
                            ),
                          ),
                        if (canModerate)
                          _HeaderIconButton(
                            icon: Icons.analytics_outlined,
                            color: AppColors.namaNavyBlue,
                            onTap: () =>
                                _showAnalyticsDialog(context, currentSession),
                          ),
                      ],
                    ),
                    if (currentSession.hasEnded)
                      _StatusBanner(
                        icon: Icons.event_busy,
                        text: 'This session has ended',
                        color: AppColors.errorRed,
                      )
                    else if (!currentSession.isChatEnabled)
                      _StatusBanner(
                        icon: Icons.lock,
                        text: currentSession.closedBy.isNotEmpty
                            ? 'Chat closed by ${currentSession.closedBy}'
                            : 'Chat is closed',
                        color: AppColors.warningAmber,
                      ),
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
                                    size: 48,
                                    color: Colors.grey.shade300,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No messages yet',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: Colors.grey.shade600,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Be the first to say something!',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Colors.grey.shade500,
                                          fontSize: 12,
                                        ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            reverse: true,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final message = messages[index];
                              final isMe = message.senderId == currentUser.uid;
                              final isMessageSenderMuted =
                                  currentSession.isUserMuted(message.senderId);

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
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: AppColors.errorRed,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Error loading messages',
                                  style: TextStyle(
                                    color: AppColors.errorRed,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  err.toString(),
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    MessageComposer(
                      session: currentSession,
                      currentUser: currentUser,
                    ),
                  ],
                ),
              ),
            );
          },
          loading: () => const _SimpleStateScaffold(
            title: 'Session Chat',
            child: LoadingIndicator(),
          ),
          error: (err, stack) => _SimpleStateScaffold(
            title: 'Session Chat',
            child: Center(
              child: Text(
                'Error: $err',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        );
      },
      loading: () => const _SimpleStateScaffold(
        title: 'Session Chat',
        child: LoadingIndicator(),
      ),
      error: (err, stack) => _SimpleStateScaffold(
        title: 'Session Chat',
        child: Center(
          child: Text(
            'Error: $err',
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }

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
      return '${time.hour.toString().padLeft(2, '0')}:'
          '${time.minute.toString().padLeft(2, '0')}';
    }
  }
}

class _ChatHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final List<Widget> actions;

  const _ChatHeader({
    required this.title,
    required this.onBack,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 6),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: AppColors.namaNavyBlue,
              size: 22,
            ),
            onPressed: onBack,
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.namaNavyBlue,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      icon: Icon(
        icon,
        color: color,
        size: 21,
      ),
      onPressed: onTap,
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final bool compact;

  const _StatusBanner({
    required this.icon,
    required this.text,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        border: compact
            ? Border(
                top: BorderSide(color: color.withOpacity(0.25)),
                bottom: BorderSide(color: color.withOpacity(0.25)),
              )
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: compact ? 13 : 15,
            color: color,
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
                fontSize: compact ? 11.5 : 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleStateScaffold extends StatelessWidget {
  final String title;
  final Widget child;

  const _SimpleStateScaffold({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: SafeArea(
        child: Column(
          children: [
            _ChatHeader(
              title: title,
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}