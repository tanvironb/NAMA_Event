import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/core/models/app_user.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';

class MessageComposer extends ConsumerStatefulWidget {
  final Session session;
  final AppUser currentUser;

  const MessageComposer({super.key, required this.session, required this.currentUser});

  @override
  ConsumerState<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends ConsumerState<MessageComposer> {
  final _controller = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;
    
    final bool isAdmin = widget.currentUser.role == 'admin';
    final bool isSessionSpeaker = widget.session.speakerIds.contains(widget.currentUser.uid);
    final bool canOverrideClosedChat = isAdmin || isSessionSpeaker;
    
    // Check if user is muted
    if (widget.session.isUserMuted(widget.currentUser.uid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have been muted by a moderator'),
          backgroundColor: AppColors.warningAmber,
        ),
      );
      return;
    }
    
    // Session ended - check grace period for speakers, admins always allowed
    if (widget.session.hasEnded) {
      if (isAdmin) {
        // Admins can always send
      } else if (isSessionSpeaker && widget.session.isWithinGracePeriod) {
        // Speakers can send within 35 minutes after session ends
      } else {
        // Grace period expired or not a speaker/admin
        final gracePeriodEnd = widget.session.endTime.add(const Duration(minutes: 35));
        final minutesRemaining = gracePeriodEnd.difference(DateTime.now()).inMinutes;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isSessionSpeaker && minutesRemaining <= 0
                  ? 'Speaker grace period (35 minutes) has expired'
                  : 'Session has ended',
            ),
            backgroundColor: AppColors.errorRed,
          ),
        );
        return;
      }
    }
    
    // Check if chat is closed (admins and session speakers can override)
    if (!widget.session.isChatEnabled && !canOverrideClosedChat) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chat has been closed for this session'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    final chatRepo = ref.read(chatRepositoryProvider);
    try {
      await chatRepo.sendMessage(
        sessionId: widget.session.id,
        text: _controller.text.trim(),
        senderId: widget.currentUser.uid,
        senderName: widget.currentUser.name,
        senderImageUrl: widget.currentUser.profileImageUrl,
        senderRole: widget.currentUser.role,
      );
      _controller.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = widget.currentUser.role == 'admin';
    final bool isSessionSpeaker = widget.session.speakerIds.contains(widget.currentUser.uid);
    final bool canOverrideClosedChat = isAdmin || isSessionSpeaker;
    final bool isMuted = widget.session.isUserMuted(widget.currentUser.uid);
    
    // Check session ended status with grace period
    final bool sessionEndedForUser = widget.session.hasEnded && 
                                      !isAdmin && 
                                      !(isSessionSpeaker && widget.session.isWithinGracePeriod);
    
    // Show banner if chat is closed but user can still send (moderator override)
    final bool showModeratorOverrideBanner = !sessionEndedForUser && 
                                              !widget.session.isChatEnabled && 
                                              canOverrideClosedChat && 
                                              !isMuted;
    
    // Show grace period banner for speakers
    final bool showGracePeriodBanner = widget.session.hasEnded && 
                                        isSessionSpeaker && 
                                        widget.session.isWithinGracePeriod && 
                                        !isMuted;

    // User is muted - show muted message
    if (isMuted) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.lightGray)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.volume_off,
              color: AppColors.warningAmber,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'You have been muted by a moderator',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.warningAmber,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      );
    }

    // Session ended - check if user can still send
    if (sessionEndedForUser) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.lightGray)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.event_busy,
              color: AppColors.errorRed,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Session has ended',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.errorRed,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      );
    }

    // Chat closed and user cannot override
    if (!widget.session.isChatEnabled && !canOverrideClosedChat) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.lightGray)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock,
              color: AppColors.errorRed,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Chat has been closed',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.errorRed,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      );
    }

    // Show input field with optional banners
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Show grace period banner for speakers after session ends
        if (showGracePeriodBanner)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            decoration: BoxDecoration(
              color: AppColors.infoBlue.withOpacity(0.1),
              border: Border(
                top: BorderSide(color: AppColors.infoBlue.withOpacity(0.3)),
                bottom: BorderSide(color: AppColors.infoBlue.withOpacity(0.3)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.access_time,
                  color: AppColors.infoBlue,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Builder(
                    builder: (context) {
                      final gracePeriodEnd = widget.session.endTime.add(const Duration(minutes: 35));
                      final minutesLeft = gracePeriodEnd.difference(DateTime.now()).inMinutes + 1;
                      return Text(
                        'Session ended - Grace period: $minutesLeft min remaining',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.infoBlue,
                              fontWeight: FontWeight.w500,
                            ),
                        textAlign: TextAlign.center,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        
        // Show banner for moderators when chat is closed (they can still send)
        if (showModeratorOverrideBanner)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            decoration: BoxDecoration(
              color: AppColors.warningAmber.withOpacity(0.1),
              border: Border(
                top: BorderSide(color: AppColors.warningAmber.withOpacity(0.3)),
                bottom: BorderSide(color: AppColors.warningAmber.withOpacity(0.3)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.lock_open,
                  color: AppColors.warningAmber,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Chat closed by ${widget.session.closedBy} (you can still send as ${isAdmin ? 'admin' : 'speaker'})',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.warningAmber,
                          fontWeight: FontWeight.w500,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        
        // Message input field
        Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.lightGray)),
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: _isSending
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send, color: AppColors.navyBlue),
                  onPressed: _isSending ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}