// lib/features/calendar/screens/my_calendar_screen.dart

import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/features/calendar/models/calendar_entry.dart';
import 'package:events_app_trueattempt/features/calendar/models/calendar_entry_type.dart';
import 'package:events_app_trueattempt/features/calendar/providers/calendar_providers.dart';
import 'package:events_app_trueattempt/features/calendar/screens/day_view_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class MyCalendarScreen extends ConsumerStatefulWidget {
  const MyCalendarScreen({super.key});

  @override
  ConsumerState<MyCalendarScreen> createState() => _MyCalendarScreenState();
}

class _MyCalendarScreenState extends ConsumerState<MyCalendarScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Refresh when user opens calendar so active event changes are reflected.
    ref.invalidate(calendarEntriesProvider);
    ref.invalidate(calendarEntriesByDateProvider);
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(calendarEntriesProvider);
    final groupedEntries = ref.watch(calendarEntriesByDateProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: entriesAsync.when(
                data: (entries) {
                  if (entries.isEmpty) {
                    return _buildEmptyState();
                  }

                  final dates = groupedEntries.keys.toList()..sort();

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                    itemCount: dates.length,
                    itemBuilder: (context, index) {
                      final date = dates[index];
                      final entriesForDate = groupedEntries[date] ?? [];

                      return _buildDayCard(
                        context,
                        date,
                        entriesForDate,
                      );
                    },
                  );
                },
                loading: () => const Center(child: LoadingIndicator()),
                error: (error, stack) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        'Error loading calendar: $error',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.namaDarkGray,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 16, 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.namaNavyBlue.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.arrow_back,
                color: AppColors.namaNavyBlue,
                size: 22,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'My Calendar',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: AppColors.namaNavyBlue,
            ),
          ),
        ],
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
            size: 52,
            color: AppColors.namaMediumGray.withOpacity(0.5),
          ),
          const SizedBox(height: 14),
          const Text(
            'No calendar entries',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.namaDarkGray,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Bookmark sessions or schedule meetings\nto see them here',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.namaMediumGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCard(
    BuildContext context,
    DateTime date,
    List<CalendarEntry> entries,
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
        elevation: 1.5,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: isToday
              ? const BorderSide(
                  color: AppColors.namaNavyBlue,
                  width: 1.5,
                )
              : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDateIndicator(dayName, dayNumber, isToday),
              const SizedBox(width: 12),
              Expanded(
                child: _buildEntriesPreview(entries),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.namaMediumGray,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateIndicator(
    String dayName,
    String dayNumber,
    bool isToday,
  ) {
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: isToday
            ? AppColors.namaNavyBlue
            : AppColors.namaMediumGray.withOpacity(0.1),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        children: [
          Text(
            dayName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isToday ? Colors.white : AppColors.namaMediumGray,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            dayNumber,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: isToday ? Colors.white : AppColors.namaDarkGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntriesPreview(List<CalendarEntry> entries) {
    if (entries.isEmpty) {
      return const Text(
        'No entries',
        style: TextStyle(
          color: AppColors.namaMediumGray,
          fontSize: 13,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: _buildEntryChip(entry),
        );
      }).toList(),
    );
  }

  Widget _buildEntryChip(CalendarEntry entry) {
    final isSession = entry.type == CalendarEntryType.session;
    final timeFormat = DateFormat('h:mm a');

    final chipColor =
        isSession ? AppColors.namaNavyBlue : AppColors.namaGoldenYellow;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: chipColor,
          width: 0.9,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSession ? Icons.event_note : Icons.people,
            size: 14,
            color: chipColor,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              entry.title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: chipColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            timeFormat.format(entry.startTime),
            style: TextStyle(
              fontSize: 10,
              color: chipColor.withOpacity(0.75),
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