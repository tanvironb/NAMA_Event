// lib/features/speaker/screen/widget/speaker_session_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/features/chat/screen/session_chat_screen.dart';
import 'package:intl/intl.dart';

class SpeakerSessionDetailScreen extends ConsumerStatefulWidget {
  final Session session;

  const SpeakerSessionDetailScreen({
    super.key,
    required this.session,
  });

  @override
  ConsumerState<SpeakerSessionDetailScreen> createState() =>
      _SpeakerSessionDetailScreenState();
}

class _SpeakerSessionDetailScreenState
    extends ConsumerState<SpeakerSessionDetailScreen> {
  void _openSessionChat() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SessionChatScreen(session: widget.session),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final startTime = DateFormat.jm().format(widget.session.startTime);
    final endTime = DateFormat.jm().format(widget.session.endTime);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 18, 6),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back,
                      color: AppColors.namaNavyBlue,
                      size: 22,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      'Details',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.namaNavyBlue,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(15, 15, 15, 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.035),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.session.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: const Color(0xFF202124),
                                  fontSize: 18,
                                  height: 1.18,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),

                          const SizedBox(height: 14),

                          _InfoRow(
                            icon: Icons.access_time,
                            text: '$startTime - $endTime',
                          ),
                          const SizedBox(height: 7),
                          _InfoRow(
                            icon: Icons.location_on_outlined,
                            text: widget.session.location,
                          ),

                          const SizedBox(height: 16),

                          Divider(
                            height: 1,
                            thickness: 1,
                            color: Colors.grey.shade300,
                          ),

                          const SizedBox(height: 16),

                          Text(
                            'Session Description',
                            style:
                                Theme.of(context).textTheme.titleLarge?.copyWith(
                                      color: const Color(0xFF202124),
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            widget.session.description.trim().isEmpty
                                ? 'No description added yet.'
                                : widget.session.description,
                            style:
                                Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey.shade700,
                                      fontSize: 12.5,
                                      height: 1.38,
                                    ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: ElevatedButton.icon(
                        icon: const Icon(
                          Icons.chat_outlined,
                          size: 17,
                        ),
                        label: const Text(
                          'Open Session Chat',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: _openSessionChat,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: AppColors.namaNavyBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 15,
          color: Colors.grey.shade700,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade700,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ],
    );
  }
}