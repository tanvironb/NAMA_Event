import 'package:intl/intl.dart';

class DateTimeUtils {
  /// Format timestamp for message lists
  /// - Shows time (e.g., "2:30 PM") if today
  /// - Shows day name (e.g., "Monday") if within current week (0-6 days ago)
  /// - Shows date (e.g., "Oct 15") if 7+ days ago
  static String formatMessageTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);
    
    final difference = today.difference(messageDate).inDays;
    
    if (difference == 0) {
      // Today - show time
      return DateFormat.jm().format(timestamp); // e.g., "2:30 PM"
    } else if (difference >= 1 && difference <= 6) {
      // Within current week - show day name
      return DateFormat.EEEE().format(timestamp); // e.g., "Monday"
    } else {
      // 7+ days ago - show date
      return DateFormat.MMMd().format(timestamp); // e.g., "Oct 15"
    }
  }

  /// Format timestamp for message details (within chat)
  static String formatMessageDetailTime(DateTime timestamp) {
    return DateFormat.jm().format(timestamp); // e.g., "2:30 PM"
  }

  /// Check if a date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  /// Check if a date is within the current week
  static bool isThisWeek(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);
    final difference = today.difference(messageDate).inDays;
    return difference >= 0 && difference <= 6;
  }

  /// Get a date separator text for grouping messages
  static String getDateSeparator(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);
    final difference = today.difference(messageDate).inDays;
    
    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference <= 6) {
      return DateFormat.EEEE().format(timestamp); // Day name
    } else {
      return DateFormat.yMMMd().format(timestamp); // Full date
    }
  }
}
