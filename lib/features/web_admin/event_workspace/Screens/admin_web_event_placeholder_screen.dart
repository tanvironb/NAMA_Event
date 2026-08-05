
import 'package:flutter/material.dart';

import '../../admin_web_theme.dart';

class AdminWebEventPlaceholderScreen extends StatelessWidget {
  final String title;
  final String eventId;
  final String eventName;
  final IconData icon;

  const AdminWebEventPlaceholderScreen({
    super.key,
    required this.title,
    required this.eventId,
    required this.eventName,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(34),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AdminWebTheme.border,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: AdminWebTheme.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: AdminWebTheme.primary,
                size: 31,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                color: AdminWebTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$title for "$eventName" will be connected next. '
              'This screen already receives the selected event ID: $eventId',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AdminWebTheme.textSecondary,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
