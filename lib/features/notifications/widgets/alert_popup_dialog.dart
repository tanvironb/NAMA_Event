import 'package:flutter/material.dart';
import 'package:events_app_trueattempt/core/models/notification_model.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/features/notifications/screen/widgets/notification_detail_view.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Alert popup dialog that shows for high-priority notifications
/// Displays with 3-second timer and red outline styling
/// Tracks dismissed warnings to prevent re-showing
class AlertPopupDialog extends StatefulWidget {
  final AppNotification notification;
  final VoidCallback? onDismiss;

  const AlertPopupDialog({
    super.key,
    required this.notification,
    this.onDismiss,
  });

  /// Check if a warning has been dismissed before
  static Future<bool> hasBeenDismissed(String notificationId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('dismissed_warning_$notificationId') ?? false;
  }

  /// Save that a warning has been dismissed
  static Future<void> markAsDismissed(String notificationId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dismissed_warning_$notificationId', true);
  }

  @override
  State<AlertPopupDialog> createState() => _AlertPopupDialogState();
}

class _AlertPopupDialogState extends State<AlertPopupDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _remainingSeconds = 3;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    // Start countdown
    _controller.forward();
    _startCountdown();
  }

  void _startCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      
      setState(() {
        _remainingSeconds--;
      });
      
      return _remainingSeconds > 0;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatTimeRange() {
    if (widget.notification.timeFrom == null) return '';
    
    final dateFormat = DateFormat('MMM d, h:mm a');
    final from = widget.notification.timeFrom!;
    final to = widget.notification.timeTo;
    
    if (to == null) {
      return 'From: ${dateFormat.format(from)}';
    }
    
    // If same day, show date once
    if (from.year == to.year && from.month == to.month && from.day == to.day) {
      final dayFormat = DateFormat('MMM d, yyyy');
      final timeFormat = DateFormat('h:mm a');
      return '${dayFormat.format(from)} • ${timeFormat.format(from)} - ${timeFormat.format(to)}';
    } else {
      return '${dateFormat.format(from)} - ${dateFormat.format(to)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final canDismiss = _remainingSeconds <= 0;

    return PopScope(
      canPop: canDismiss,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.errorRed, width: 3),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with icon and close button
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.errorRed.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.errorRed, width: 2),
                    ),
                    child: const Icon(
                      Icons.warning_rounded,
                      color: AppColors.errorRed,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'ALERT',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.errorRed,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  // Close button (disabled for 3 seconds)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: canDismiss ? () async {
                      // Mark as dismissed before closing
                      final notificationId = widget.notification.data['notificationId'] ?? 
                                             widget.notification.id;
                      await AlertPopupDialog.markAsDismissed(notificationId);
                      widget.onDismiss?.call();
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    } : null,
                    color: canDismiss ? AppColors.namaDeepNavy : Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Title
              Text(
                widget.notification.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.namaDeepNavy,
                ),
              ),
              
              // Subtitle (if present)
              if (widget.notification.subtitle != null && widget.notification.subtitle!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  widget.notification.subtitle!,
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[700],
                  ),
                ),
              ],
              
              const SizedBox(height: 12),
              
              // Body (truncated to 30-50 chars)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.errorRed.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.errorRed.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.notification.body.length > 50
                          ? '${widget.notification.body.substring(0, 47)}...'
                          : widget.notification.body,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: AppColors.namaDeepNavy,
                      ),
                    ),
                    // View More button if text is truncated
                    if (widget.notification.body.length > 50) ...[
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => NotificationDetailView(
                                notification: widget.notification,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('View More'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.errorRed,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Time range (if present)
              if (widget.notification.timeFrom != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.event, size: 18, color: AppColors.errorRed),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _formatTimeRange(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.namaDeepNavy,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              
              const SizedBox(height: 20),
              
              // Countdown timer and progress bar
              if (!canDismiss) ...[
                Column(
                  children: [
                    // Progress bar
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return LinearProgressIndicator(
                          value: _controller.value,
                          backgroundColor: Colors.grey[300],
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.errorRed),
                          minHeight: 6,
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    // Countdown text
                    Text(
                      'You can dismiss this in $_remainingSeconds second${_remainingSeconds != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // OK button (enabled after countdown)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      // Mark as dismissed before closing
                      final notificationId = widget.notification.data['notificationId'] ?? 
                                             widget.notification.id;
                      await AlertPopupDialog.markAsDismissed(notificationId);
                      widget.onDismiss?.call();
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.errorRed,
                      foregroundColor: AppColors.namaWhite,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'GOT IT',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
