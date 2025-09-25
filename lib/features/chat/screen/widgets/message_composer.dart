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

  void _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;
    setState(() => _isSending = true);

    final chatRepo = ref.read(chatRepositoryProvider);
    try {
      await chatRepo.sendMessage(
        sessionId: widget.session.id,
        text: _controller.text.trim(),
        senderId: widget.currentUser.uid,
        senderName: widget.currentUser.name,
        senderImageUrl: widget.currentUser.profileImageUrl,
      );
      _controller.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
            ),
          ),
          IconButton(
            icon: _isSending
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator())
                : const Icon(Icons.send, color: AppColors.navyBlue),
            onPressed: _isSending ? null : _sendMessage,
          ),
        ],
      ),
    );
  }
}