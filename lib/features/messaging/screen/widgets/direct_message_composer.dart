// lib/features/messaging/screen/widgets/direct_message_composer.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:events_app_trueattempt/core/models/app_user.dart';
import 'package:events_app_trueattempt/core/providers.dart';

class DirectMessageComposer extends ConsumerStatefulWidget {
  final String? conversationId;
  final String otherUserId;
  final AppUser currentUser;
  final void Function(String newConversationId) onConversationCreated;

  const DirectMessageComposer({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    required this.currentUser,
    required this.onConversationCreated,
  });

  @override
  ConsumerState<DirectMessageComposer> createState() =>
      _DirectMessageComposerState();
}

class _DirectMessageComposerState extends ConsumerState<DirectMessageComposer> {
  final TextEditingController _messageController = TextEditingController();

  bool _isSending = false;

  static const Color _primaryColor = Color(0xFF0D1496);
  static const Color _sendButtonColor = Color(0xFFF4BE32);

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<String?> _getOrCreateConversationId() async {
    if (widget.conversationId != null && widget.conversationId!.isNotEmpty) {
      return widget.conversationId;
    }

    final activeEvent = await ref.read(activeEventFutureProvider.future);

    final conversationId =
        await ref.read(messagingRepositoryProvider).createOrGetConversation(
              currentUserId: widget.currentUser.uid,
              otherUserId: widget.otherUserId,
              eventId: activeEvent.id,
            );

    widget.onConversationCreated(conversationId);

    return conversationId;
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();

    if (text.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      final conversationId = await _getOrCreateConversationId();

      if (conversationId == null || conversationId.isEmpty) {
        throw Exception('Could not create conversation.');
      }

      await ref.read(messagingRepositoryProvider).sendDirectMessage(
            conversationId: conversationId,
            text: text,
            senderId: widget.currentUser.uid,
            senderName: widget.currentUser.name,
            senderImageUrl: widget.currentUser.profileImageUrl,
          );

      _messageController.clear();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeEventAsync = ref.watch(activeEventFutureProvider);

    return activeEventAsync.when(
      data: (_) {
        return Container(
          color: const Color(0xFFF7F7F7),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  enabled: !_isSending,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(right: 5),
                child: InkWell(
                  onTap: _isSending ? null : _sendMessage,
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    height: 38,
                    width: 38,
                    decoration: BoxDecoration(
                      color: _isSending
                          ? Colors.grey.shade300
                          : _sendButtonColor,
                      shape: BoxShape.circle,
                    ),
                    child: _isSending
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _primaryColor,
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                            color: _primaryColor,
                            size: 19,
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () {
        return Container(
          height: 50,
          alignment: Alignment.center,
          child: const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
      error: (err, stack) {
        return Container(
          height: 50,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: const Text(
            'Unable to load active event. Message disabled.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.red,
            ),
          ),
        );
      },
    );
  }
}