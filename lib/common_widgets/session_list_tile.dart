import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:events_app_trueattempt/features/agenda/screen/session_detail_screen.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';

class SessionListTile extends StatelessWidget {
  final Session session;
  final VoidCallback? onTap;

  const SessionListTile({
    super.key,
    required this.session,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final formattedTime = DateFormat('hh:mm a').format(session.startTime);

    // ✅ CHECK IF SESSION IS COMPLETED
    final isCompleted = DateTime.now().isAfter(session.endTime);

    return Hero(
      tag: 'session_title_${session.id}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap ??
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        SessionDetailScreen(session: session),
                  ),
                );
              },
          child: Opacity(
            // ✅ FADE COMPLETED SESSIONS
            opacity: isCompleted ? 0.45 : 1,
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
              decoration: BoxDecoration(
                // ✅ DIFFERENT BACKGROUND COLORS
                color: isCompleted
                    ? const Color(0xFFF7F7F7)
                    : const Color(0xFFF1F1F1),
                borderRadius: BorderRadius.circular(16),

                // ✅ REMOVE SHADOW FOR COMPLETED
                boxShadow: isCompleted
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,

                            // ✅ LIGHTER FONT FOR COMPLETED
                            fontWeight: isCompleted
                                ? FontWeight.w400
                                : FontWeight.w600,

                            color: isCompleted
                                ? Colors.grey.shade600
                                : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          '$formattedTime - ${session.location}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9.5,
                            color: isCompleted
                                ? Colors.grey.shade500
                                : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // ✅ CHECK ICON FOR COMPLETED
                  Icon(
                    isCompleted
                        ? Icons.check_circle
                        : Icons.chevron_right,
                    size: isCompleted ? 20 : 24,
                    color: isCompleted
                        ? Colors.grey.shade500
                        : Colors.black,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}