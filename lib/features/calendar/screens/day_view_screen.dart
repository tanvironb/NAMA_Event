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

/// Single-day view with Google Calendar-style timeline
class DayViewScreen extends ConsumerStatefulWidget {
  final DateTime selectedDate;

  const DayViewScreen({super.key, required this.selectedDate});

  @override
  ConsumerState<DayViewScreen> createState() => _DayViewScreenState();
}

class _DayViewScreenState extends ConsumerState<DayViewScreen> {
  final ScrollController _scrollController = ScrollController();
  static const double _hourHeight = 80.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentHour();
    });
  }

  void _scrollToCurrentHour() {
    final now = DateTime.now();
    if (_isToday(widget.selectedDate)) {
      final currentHour = now.hour;
      // Scroll to current hour (offset from midnight)
      final offset = currentHour * _hourHeight - 100;
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
      body: SafeArea(
        child: entriesAsync.when(
          data: (entries) => entries.isEmpty
              ? _buildEmptyState()
              : _buildDayTimeline(entries),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Text('Error loading calendar: $error'),
          ),
        ),
      ),
    );
  }

  Widget _buildDayTimeline(List<CalendarEntry> entries) {
    // Get layout information for all entries
    final layouts = OverlapHandler.layoutEntries(entries);

    return SingleChildScrollView(
      controller: _scrollController,
      child: Stack(
        children: [
          // Hour rows (00:00 to 23:00 = 24 hours)
          Column(
            children: List.generate(24, (index) {
              final hour = index; // 0 (midnight) to 23 (11 PM)
              final time = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day, hour);
              return _buildHourRow(time);
            }),
          ),
          
          // Calendar entries
          ..._buildAllEntries(layouts),
          
          // Current time indicator
          if (_isToday(widget.selectedDate)) _buildCurrentTimeIndicator(),
        ],
      ),
    );
  }

  Widget _buildHourRow(DateTime time) {
    // Use 24-hour format (HH:mm), but empty for midnight
    final hour = time.hour;
    final label = hour == 0 ? '' : '${hour.toString().padLeft(2, '0')}:00';
    
    return SizedBox(
      height: _hourHeight,
      child: Stack(
        clipBehavior: Clip.none, // Allow label to overflow above the hour row
        children: [
          // Hour line
          Positioned(
            left: 60,
            right: 0,
            top: 0,
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
          // Hour label (vertically centered on the line)
          Positioned(
            left: 0,
            top: -6, // Centers the label on the hour line
            width: 60,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                label,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.namaMediumGray,
                  height: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAllEntries(List<EntryLayout> layouts) {
    final widgets = <Widget>[];
    
    for (final layout in layouts) {
      widgets.add(_buildEntry(layout));
    }
    
    return widgets;
  }

  Widget _buildEntry(EntryLayout layout) {
    final entry = layout.entry;
    
    // Calculate top position
    final hour = entry.startTime.hour;
    final minute = entry.startTime.minute;
    final topOffset = (hour * _hourHeight) + ((minute / 60.0) * _hourHeight); // Offset from midnight
    
    // Calculate height based on duration
    final durationMinutes = entry.durationMinutes;
    final height = (durationMinutes / 60.0) * _hourHeight;

    // Calculate horizontal positioning
    final availableWidth = MediaQuery.of(context).size.width - 60;
    final leftOffset = 60 + (layout.leftFactor * availableWidth);
    final width = layout.widthFactor * availableWidth;

    final isSession = entry.type == CalendarEntryType.session;
    final color = isSession ? AppColors.namaNavyBlue : AppColors.namaGoldenYellow;

    return Positioned(
      top: topOffset,
      left: leftOffset,
      width: width,
      height: height.clamp(30, double.infinity),
      child: GestureDetector(
        onTap: () => _showEntryDetails(entry),
        child: Container(
          margin: EdgeInsets.only(
            left: layout.isOverlapping ? 8 : 2,
            right: 2,
            top: 2,
            bottom: 3, // Reduced slightly to prevent overflow
          ),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: layout.isOverlapping ? Colors.black : color,
              width: layout.isOverlapping ? 2.0 : 1.5,
            ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today,
            size: 64,
            color: AppColors.namaMediumGray.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No events for this day',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: AppColors.namaDarkGray,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your schedule is clear!',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.namaMediumGray,
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
      isDismissible: true,
      enableDrag: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        expand: false,
        snap: true,
        snapSizes: const [0.6, 0.95],
        builder: (context, scrollController) => EntryDetailsSheet(
          entry: entry,
          scrollController: scrollController,
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

  Widget _buildCurrentTimeIndicator() {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;
    
    // Calculate position from midnight
    final topOffset = (hour * _hourHeight) + ((minute / 60.0) * _hourHeight);
    
    return Positioned(
      top: topOffset,
      left: 60,
      right: 0,
      child: Row(
        children: [
          // Red dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          // Red line
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
}
