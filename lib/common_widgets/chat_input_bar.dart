import 'package:flutter/material.dart';

class ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback? onAttach;
  final bool isSending;
  final String hintText;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    this.onAttach,
    this.isSending = false,
    this.hintText = 'Type a message...',
  });

  static const _primary = Color(0xFF0B0B83);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF5F6FC),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: const Color(0xFFE6E9F2),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (onAttach != null)
                        IconButton(
                          tooltip: 'Attach file',
                          onPressed: isSending ? null : onAttach,
                          icon: const Icon(
                            Icons.attach_file_rounded,
                            color: _primary,
                            size: 22,
                          ),
                        )
                      else
                        const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          minLines: 1,
                          maxLines: 4,
                          textCapitalization:
                              TextCapitalization.sentences,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF18223C),
                          ),
                          decoration: InputDecoration(
                            hintText: hintText,
                            hintStyle: const TextStyle(
                              color: Color(0xFF788197),
                              fontSize: 14,
                            ),
                            filled: false,
                            isDense: true,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.fromLTRB(
                              0, 14, 14, 14,
                            ),
                          ),
                          onSubmitted: (_) {
                            if (!isSending) onSend();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 46,
                height: 46,
                child: IconButton.filled(
                  tooltip: 'Send message',
                  onPressed: isSending ? null : onSend,
                  style: IconButton.styleFrom(
                    backgroundColor: _primary,
                    disabledBackgroundColor:
                        _primary.withOpacity(.5),
                    shape: const CircleBorder(),
                  ),
                  icon: isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}