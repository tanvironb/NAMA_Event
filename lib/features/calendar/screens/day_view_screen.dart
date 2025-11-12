// lib/features/calendar/screens/day_view_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/features/calendar/providers/calendar_providers.dart';
import 'package:events_app_trueattempt/features/calendar/models/calendar_entry.dart';
import 'package:events_app_trueattempt/features/calendar/models/calendar_entry_type.dart';
import 'package:events_app_trueattempt/features/calendar/widgets/entry_details_sheet.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:intl/intl.dart';

/// Single-day view with hour-by-hour timeline
class DayViewScreen extends ConsumerStatefulWidget {
  final DateTime selectedDate;

  const DayViewScreen({super.key, required this.selectedDate});

  @override
  ConsumerState<DayViewScreen> createState() => _DayViewScreenState();
}

class _DayViewScreenState extends ConsumerState<DayViewScreen> {
  final ScrollController _scrollController = ScrollController();
  static const double _hourHeight = 80.0; // Height of each hour row

  @override
  void initState() {
    super.initState();
    // Scroll to current hour after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentHour();
    });
  }

  void _scrollToCurrentHour() {
    final now = DateTime.now();
    if (_isToday(widget.selectedDate)) {
      final currentHour = now.hour;
      final offset = currentHour * _hourHeight - 100; // Show some context above
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          offset.clamp(0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(entriesForDateProvider(widget.selectedDate));
    final dateFormat = DateFormat('EEEE, MMMM d');

    return Scaffold(
      appBar: AppBar(
        title: Text(dateFormat.format(widget.selectedDate)),
        elevation: 0,
        backgroundColor: AppColors.namaNavyBlue,
        foregroundColor: Colors.white,
      ),
      body: entries.isEmpty
          ? _buildEmptyState()
          : Stack(
              children: [
                // Hour rows and entries
                ListView.builder(
                  controller: _scrollController,
                  itemCount: 24, // 24 hours
                  itemBuilder: (context, hour) {
                    return _buildHourRow(hour, entries);
                  },
                ),

                // Current time indicator (if today)
                if (_isToday(widget.selectedDate))
                  _buildCurrentTimeIndicator(),
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
            Icons.event_busy_outlined,
            size: 64,
            color: AppColors.namaMediumGray.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No entries for this day',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.namaDarkGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourRow(int hour, List<CalendarEntry> allEntries) {
    final hourStart = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
      hour,
    );
    final hourEnd = hourStart.add(const Duration(hours: 1));

    // Find entries that overlap with this hour
    final entriesInHour = allEntries.where((entry) {
      return entry.startTime.isBefore(hourEnd) && entry.endTime.isAfter(hourStart);
    }).toList();

    return SizedBox(
      height: _hourHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hour label
          _buildHourLabel(hour),

          // Entries area
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppColors.namaMediumGray.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              child: entriesInHour.isEmpty
                  ? const SizedBox()
                  : _buildEntriesForHour(hourStart, hourEnd, entriesInHour),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourLabel(int hour) {
    final format = DateFormat('h a');
    final time = DateTime(2000, 1, 1, hour);

    return Container(
      width: 60,
      padding: const EdgeInsets.only(right: 8, top: 4),
      child: Text(
        format.format(time),
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.namaMediumGray,
        ),
      ),
    );
  }

  Widget _buildEntriesForHour(
    DateTime hourStart,
    DateTime hourEnd,
    List<CalendarEntry> entries,
  ) {
    // Group overlapping entries
    final groups = _groupOverlappingEntries(entries);

    return Stack(
      children: groups.map((group) {
        return _buildEntryGroup(group, hourStart);
      }).toList(),
    );
  }

  List<_EntryGroup> _groupOverlappingEntries(List<CalendarEntry> entries) {
    final List<_EntryGroup> groups = [];
    final Set<String> processed = {};

    for (final entry in entries) {
      if (processed.contains(entry.id)) continue;

      // Find overlapping entries
      final overlapping = entries.where((other) {
        return !processed.contains(other.id) && entry.overlapsWith(other);
      }).toList();

      if (overlapping.isEmpty) {
        groups.add(_EntryGroup(entries: [entry]));
        processed.add(entry.id);
      } else {
        // Sort: earlier first, then sessions before meetings
        overlapping.sort((a, b) {
          final timeCompare = a.startTime.compareTo(b.startTime);
          if (timeCompare != 0) return timeCompare;
          return a.type == CalendarEntryType.session ? -1 : 1;
        });

        groups.add(_EntryGroup(entries: overlapping));
        processed.addAll(overlapping.map((e) => e.id));
      }
    }

    return groups;
  }

  Widget _buildEntryGroup(_EntryGroup group, DateTime hourStart) {
    if (group.entries.length == 1) {
      return _buildSingleEntry(group.entries.first, hourStart, 1.0);
    } else if (group.entries.length == 2) {
      return Row(
        children: [
          Expanded(child: _buildSingleEntry(group.entries[0], hourStart, 0.5)),
          Expanded(child: _buildSingleEntry(group.entries[1], hourStart, 0.5)),
        ],
      );
    } else {
      // 3+ entries: Show first 2, then "+N more" box
      return _buildOverflowGroup(group, hourStart);
    }
  }

  Widget _buildOverflowGroup(_EntryGroup group, DateTime hourStart) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildSingleEntry(group.entries[0], hourStart, 0.5)),
            Expanded(child: _buildSingleEntry(group.entries[1], hourStart, 0.5)),
          ],
        ),
        _buildMoreEntriesBox(group.overflowEntries),
      ],
    );
  }

  Widget _buildSingleEntry(
    CalendarEntry entry,
    DateTime hourStart,
    double widthFactor,
  ) {
    final minutesSinceHourStart = entry.startTime.isAfter(hourStart)
        ? entry.startTime.difference(hourStart).inMinutes
        : 0;

    final topOffset = (minutesSinceHourStart / 60.0) * _hourHeight;

    final durationMinutes = entry.durationMinutes;
    final height = (durationMinutes / 60.0) * _hourHeight;

    final isSession = entry.type == CalendarEntryType.session;
    final color = isSession ? AppColors.namaNavyBlue : AppColors.namaGoldenYellow;

    return Positioned(
      top: topOffset,
      left: 0,
      right: 0,
      height: height.clamp(30, double.infinity), // Minimum height
      child: GestureDetector(
        onTap: () => _showEntryDetails(entry),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                entry.title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (height > 40) ...[
                const SizedBox(height: 2),
                Text(
                  DateFormat('h:mm a').format(entry.startTime),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
              if (height > 55 && entry.location.isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 10, color: Colors.white.withOpacity(0.8)),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        entry.location,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoreEntriesBox(List<CalendarEntry> overflowEntries) {
    if (overflowEntries.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.namaMediumGray.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: overflowEntries.map((entry) {
          return _buildOverflowEntryItem(entry);
        }).toList(),
      ),
    );
  }

  Widget _buildOverflowEntryItem(CalendarEntry entry) {
    final isSession = entry.type == CalendarEntryType.session;
    final color = isSession ? AppColors.namaNavyBlue : AppColors.namaGoldenYellow;

    return GestureDetector(
      onTap: () => _showEntryDetails(entry),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                entry.title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTimeIndicator() {
    final now = DateTime.now();
    final minutesSinceMidnight = now.hour * 60 + now.minute;
    final topOffset = (minutesSinceMidnight / 60.0) * _hourHeight;

    return Positioned(
      top: topOffset,
      left: 60,
      right: 0,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Container(
              height: 2,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  void _showEntryDetails(CalendarEntry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) => EntryDetailsSheet(
          entry: entry,
        ),
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

/// Helper class to group overlapping entries
class _EntryGroup {
  final List<CalendarEntry> entries;

  _EntryGroup({required this.entries});

  List<CalendarEntry> get overflowEntries => entries.skip(2).toList();
}
