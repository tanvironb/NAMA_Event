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
    
    // Check if chat is still available (admins can override closed chat)
    if (!widget.session.isChatAvailable && !isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat has been closed for this session')),
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
    final bool isMuted = widget.session.isUserMuted(widget.currentUser.uid);
    
    // Check if chat is available (admins can override closed chat but still see banner)
    final bool canSendMessages = widget.session.isChatAvailable || isAdmin;
    final bool showClosedBanner = !widget.session.isChatAvailable && isAdmin;

    // User is muted - show muted message
    if (isMuted) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(top: BorderSide(color: Colors.grey[200]!)),
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

    // Chat closed and user is not admin
    if (!canSendMessages) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(top: BorderSide(color: Colors.grey[200]!)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.error,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              widget.session.hasEnded 
                  ? 'Session ended' 
                  : 'Chat has been closed',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Show closed banner for admins (they can still send messages)
        if (showClosedBanner)
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
                  Icons.lock,
                  color: AppColors.warningAmber,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Chat is closed by ${widget.session.closedBy} (you can still send messages)',
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
        
        // Message input
        Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(top: BorderSide(color: Colors.grey[200]!)),
          ),
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
      ],
    );
  }
}