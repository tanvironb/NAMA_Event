// lib/features/calendar/screens/my_calendar_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/features/calendar/providers/calendar_providers.dart';
import 'package:events_app_trueattempt/features/calendar/screens/day_view_screen.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:intl/intl.dart';

/// Multi-day calendar view showing scrollable list of days
class MyCalendarScreen extends ConsumerWidget {
  const MyCalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(calendarEntriesProvider);
    final groupedEntries = ref.watch(calendarEntriesByDateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Calendar'),
        elevation: 0,
        backgroundColor: AppColors.namaNavyBlue,
        foregroundColor: Colors.white,
      ),
      body: entriesAsync.when(
        data: (entries) {
          if (entries.isEmpty) {
            return _buildEmptyState();
          }

          // Get sorted list of dates
          final dates = groupedEntries.keys.toList()..sort();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: dates.length,
            itemBuilder: (context, index) {
              final date = dates[index];
              final entriesForDate = groupedEntries[date] ?? [];

              return _buildDayCard(
                context,
                ref,
                date,
                entriesForDate,
              );
            },
          );
        },
        loading: () => const Center(child: LoadingIndicator()),
        error: (error, stack) => Center(
          child: Text('Error loading calendar: $error'),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 64,
            color: AppColors.namaMediumGray.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No calendar entries',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.namaDarkGray,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bookmark sessions or schedule meetings\nto see them here',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.namaMediumGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCard(
    BuildContext context,
    WidgetRef ref,
    DateTime date,
    List<dynamic> entries,
  ) {
    final isToday = _isToday(date);
    final dayName = DateFormat('EEE').format(date);
    final dayNumber = DateFormat('d').format(date);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DayViewScreen(selectedDate: date),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isToday
              ? const BorderSide(color: AppColors.namaNavyBlue, width: 2)
              : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date indicator
              _buildDateIndicator(dayName, dayNumber, isToday),
              const SizedBox(width: 16),

              // Entries preview
              Expanded(
                child: _buildEntriesPreview(entries),
              ),

              // Arrow icon
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.namaMediumGray,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateIndicator(String dayName, String dayNumber, bool isToday) {
    return Container(
      width: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isToday ? AppColors.namaNavyBlue : AppColors.namaMediumGray.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            dayName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isToday ? Colors.white : AppColors.namaMediumGray,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            dayNumber,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isToday ? Colors.white : AppColors.namaDarkGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntriesPreview(List<dynamic> entries) {
    if (entries.isEmpty) {
      return const Text(
        'No entries',
        style: TextStyle(
          color: AppColors.namaMediumGray,
          fontSize: 14,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildEntryChip(entry),
        );
      }).toList(),
    );
  }

  Widget _buildEntryChip(dynamic entry) {
    final isSession = entry.type.toString().contains('session');
    final timeFormat = DateFormat('h:mm a');
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isSession 
            ? AppColors.namaNavyBlue.withOpacity(0.1)
            : AppColors.namaGoldenYellow.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSession ? AppColors.namaNavyBlue : AppColors.namaGoldenYellow,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSession ? Icons.event_note : Icons.people,
            size: 16,
            color: isSession ? AppColors.namaNavyBlue : AppColors.namaGoldenYellow,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSession ? AppColors.namaNavyBlue : AppColors.namaGoldenYellow,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            timeFormat.format(entry.startTime),
            style: TextStyle(
              fontSize: 11,
              color: (isSession ? AppColors.namaNavyBlue : AppColors.namaGoldenYellow).withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}
