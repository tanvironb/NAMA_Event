// lib/features/calendar/screens/day_view_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/features/calendar/providers/calendar_providers.dart';
import 'package:events_app_trueattempt/features/calendar/models/calendar_entry.dart';
import 'package:events_app_trueattempt/features/calendar/models/calendar_entry_type.dart';
import 'package:events_app_trueattempt/features/calendar/widgets/entry_details_sheet.dart';
import 'package:events_app_trueattempt/features/calendar/widgets/overlap_handler.dart';
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
    final entriesAsync = ref.watch(entriesForDateProvider(widget.selectedDate));
    final dateFormat = DateFormat('EEEE, MMMM d');

    return Scaffold(
      appBar: AppBar(
        title: Text(dateFormat.format(widget.selectedDate)),
        elevation: 0,
        backgroundColor: AppColors.namaNavyBlue,
        foregroundColor: Colors.white,
      ),
      body: entriesAsync.when(
        data: (entries) => entries.isEmpty
            ? _buildEmptyState()
            : _buildDayTimeline(entries),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error loading calendar: $error'),
        ),
      ),
    );
  }

  Widget _buildDayTimeline(List<CalendarEntry> entries) {
    // Group overlapping entries
    final groups = OverlapHandler.groupOverlappingEntries(entries);
    
    // Calculate overflow box info for each hour
    final Map<int, double> hourPadding = {};
    
    for (final group in groups) {
      if (group.hasOverflow) {
        // Find which hour the overflow box will be in
        final latestEndTime = group.visibleEntries
            .map((e) => e.endTime)
            .reduce((a, b) => a.isAfter(b) ? a : b);
        
        final overflowHour = latestEndTime.hour;
        final overflowBoxHeight = (group.overflowCount * 24.0) + 16.0; // Height needed
        
        // Add padding to this hour and potentially next hours
        final currentPadding = hourPadding[overflowHour] ?? 0.0;
        hourPadding[overflowHour] = currentPadding + overflowBoxHeight;
      }
    }

    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        children: [
          Stack(
            children: [
              // Hour rows with dynamic padding
              Column(
                children: List.generate(24, (hour) {
                  final extraPadding = hourPadding[hour] ?? 0.0;
                  return _buildHourRow(hour, extraPadding);
                }),
              ),
              
              // All entries and overflow boxes positioned absolutely
              ..._buildAllEntries(groups, hourPadding),
              
              // Current time indicator (if today)
              if (_isToday(widget.selectedDate))
                _buildCurrentTimeIndicator(hourPadding),
            ],
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

  Widget _buildHourRow(int hour, double extraPadding) {
    final format = DateFormat('h a');
    final time = DateTime(2000, 1, 1, hour);

    return Container(
      height: _hourHeight + extraPadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hour label
          Container(
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
          ),

          // Hour line
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
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAllEntries(List<OverlapGroup> groups, Map<int, double> hourPadding) {
    final List<Widget> widgets = [];
    
    for (final group in groups) {
      if (group.entries.length == 1) {
        // Single entry - full width
        widgets.add(_buildPositionedEntry(group.entries[0], 0.0, 1.0, hourPadding));
      } else if (group.entries.length == 2) {
        // Two entries - side by side
        widgets.add(_buildPositionedEntry(group.entries[0], 0.0, 0.5, hourPadding));
        widgets.add(_buildPositionedEntry(group.entries[1], 0.5, 0.5, hourPadding));
      } else {
        // 3+ overlapping entries
        // Show first 2 entries (sessions/longest duration based on priority)
        final firstTwo = [group.entries[0], group.entries[1]];
        widgets.add(_buildPositionedEntry(firstTwo[0], 0.0, 0.5, hourPadding));
        widgets.add(_buildPositionedEntry(firstTwo[1], 0.5, 0.5, hourPadding));
        
        // Add overflow box for remaining entries
        final overflowEntries = group.entries.sublist(2);
        widgets.add(_buildOverflowBox(overflowEntries, firstTwo, hourPadding));
      }
    }
    
    return widgets;
  }

  Widget _buildPositionedEntry(
    CalendarEntry entry,
    double leftFactor,
    double widthFactor,
    Map<int, double> hourPadding,
  ) {
    // Calculate cumulative padding up to this entry's start time
    double cumulativePadding = 0.0;
    for (int h = 0; h < entry.startTime.hour; h++) {
      cumulativePadding += hourPadding[h] ?? 0.0;
    }
    
    // Calculate position based on start time
    final hour = entry.startTime.hour;
    final minute = entry.startTime.minute;
    final topOffset = (hour * _hourHeight) + ((minute / 60.0) * _hourHeight) + cumulativePadding;
    
    // Calculate height based on duration
    final durationMinutes = entry.durationMinutes;
    final height = (durationMinutes / 60.0) * _hourHeight;

    final isSession = entry.type == CalendarEntryType.session;
    final color = isSession ? AppColors.namaNavyBlue : AppColors.namaGoldenYellow;

    return Positioned(
      top: topOffset,
      left: 60 + (leftFactor * (MediaQuery.of(context).size.width - 60)),
      width: widthFactor * (MediaQuery.of(context).size.width - 60),
      height: height.clamp(30, double.infinity),
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

  Widget _buildOverflowBox(
    List<CalendarEntry> overflowEntries,
    List<CalendarEntry> displayedEntries,
    Map<int, double> hourPadding,
  ) {
    // Find the latest end time among the displayed entries
    DateTime latestEndTime = displayedEntries[0].endTime;
    for (final entry in displayedEntries) {
      if (entry.endTime.isAfter(latestEndTime)) {
        latestEndTime = entry.endTime;
      }
    }
    
    // Calculate cumulative padding up to overflow box position
    double cumulativePadding = 0.0;
    for (int h = 0; h < latestEndTime.hour; h++) {
      cumulativePadding += hourPadding[h] ?? 0.0;
    }
    
    // Position the overflow box right after the latest end time
    final hour = latestEndTime.hour;
    final minute = latestEndTime.minute;
    final topOffset = (hour * _hourHeight) + ((minute / 60.0) * _hourHeight) + cumulativePadding + 4; // Small gap

    return Positioned(
      top: topOffset,
      left: 60,
      right: 0,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.namaMediumGray.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.namaMediumGray.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.more_horiz,
                  size: 16,
                  color: AppColors.namaDarkGray,
                ),
                const SizedBox(width: 8),
                Text(
                  '+${overflowEntries.length} more overlapping',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.namaDarkGray,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...overflowEntries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: GestureDetector(
                onTap: () => _showEntryDetails(entry),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        color: entry.type == CalendarEntryType.session
                            ? AppColors.namaNavyBlue
                            : AppColors.namaGoldenYellow,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${DateFormat('h:mm a').format(entry.startTime)} - ${entry.title}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.namaDarkGray,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTimeIndicator(Map<int, double> hourPadding) {
    final now = DateTime.now();
    
    // Calculate cumulative padding up to current hour
    double cumulativePadding = 0.0;
    for (int h = 0; h < now.hour; h++) {
      cumulativePadding += hourPadding[h] ?? 0.0;
    }
    
    final minutesSinceMidnight = now.hour * 60 + now.minute;
    final topOffset = (minutesSinceMidnight / 60.0) * _hourHeight + cumulativePadding;

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
