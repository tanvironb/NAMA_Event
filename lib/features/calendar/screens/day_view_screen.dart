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

class DayViewScreen extends ConsumerStatefulWidget {
  final DateTime selectedDate;

  const DayViewScreen({super.key, required this.selectedDate});

  @override
  ConsumerState<DayViewScreen> createState() => _DayViewScreenState();
}

class _DayViewScreenState extends ConsumerState<DayViewScreen> {
  final ScrollController _scrollController = ScrollController();

  static const double _hourHeight = 72.0;
  static const double _timeColumnWidth = 58.0;

  // Smaller session/meeting boxes.
  static const double _minEntryHeight = 32.0;
  static const double _maxEntryHeight = 64.0;

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
      final offset = now.hour * _hourHeight - 100;

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
        title: Text(
          dateFormat.format(widget.selectedDate),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        elevation: 0,
        backgroundColor: AppColors.namaNavyBlue,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: entriesAsync.when(
          data: (entries) =>
              entries.isEmpty ? _buildEmptyState() : _buildDayTimeline(entries),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Error loading calendar: $error',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDayTimeline(List<CalendarEntry> entries) {
    final layouts = OverlapHandler.layoutEntries(entries);

    return SingleChildScrollView(
      controller: _scrollController,
      child: Stack(
        children: [
          Column(
            children: List.generate(24, (index) {
              final time = DateTime(
                widget.selectedDate.year,
                widget.selectedDate.month,
                widget.selectedDate.day,
                index,
              );
              return _buildHourRow(time);
            }),
          ),
          ..._buildAllEntries(layouts),
          if (_isToday(widget.selectedDate)) _buildCurrentTimeIndicator(),
        ],
      ),
    );
  }

  Widget _buildHourRow(DateTime time) {
    final hour = time.hour;
    final label = hour == 0 ? '' : '${hour.toString().padLeft(2, '0')}:00';

    return SizedBox(
      height: _hourHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: _timeColumnWidth,
            right: 0,
            top: 0,
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppColors.namaMediumGray.withOpacity(0.18),
                    width: 0.8,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: -5,
            width: _timeColumnWidth,
            child: Padding(
              padding: const EdgeInsets.only(right: 7),
              child: Text(
                label,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppColors.namaMediumGray,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAllEntries(List<EntryLayout> layouts) {
    return List.generate(layouts.length, (index) {
      return _buildEntry(layouts[index], index);
    });
  }

  Widget _buildEntry(EntryLayout layout, int index) {
    final entry = layout.entry;

    final hour = entry.startTime.hour;
    final minute = entry.startTime.minute;

    final topOffset =
        (hour * _hourHeight) + ((minute / 60.0) * _hourHeight);

    final durationMinutes = entry.durationMinutes;
    final calculatedHeight = (durationMinutes / 60.0) * _hourHeight;
    final entryHeight = calculatedHeight.clamp(_minEntryHeight, _maxEntryHeight);

    final availableWidth = MediaQuery.of(context).size.width - _timeColumnWidth;
    final leftOffset = _timeColumnWidth + (layout.leftFactor * availableWidth);
    final width = layout.widthFactor * availableWidth;

    final color = _getEntryColor(entry, index);

    return Positioned(
      top: topOffset,
      left: leftOffset,
      width: width,
      height: entryHeight,
      child: GestureDetector(
        onTap: () => _showEntryDetails(entry),
        child: Container(
          margin: EdgeInsets.only(
            left: layout.isOverlapping ? 6 : 2,
            right: 2,
            top: 2,
            bottom: 2,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.92),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: color,
              width: 1,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final showTime = constraints.maxHeight >= 27;
              final showLocation =
                  constraints.maxHeight >= 48 && entry.location.isNotEmpty;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.05,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (showTime) ...[
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('h:mm a').format(entry.startTime),
                      style: TextStyle(
                        fontSize: 8.8,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.95),
                        height: 1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (showLocation) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 8,
                          color: Colors.white.withOpacity(0.85),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            entry.location,
                            style: TextStyle(
                              fontSize: 8.5,
                              color: Colors.white.withOpacity(0.85),
                              height: 1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Color _getEntryColor(CalendarEntry entry, int index) {
    if (entry.type != CalendarEntryType.session) {
      return AppColors.namaGoldenYellow;
    }

    final colors = [
      AppColors.namaNavyBlue,
      const Color(0xFF4A3B95),
      const Color(0xFF006D77),
      const Color(0xFF065F46),
      const Color(0xFF9A3412),
      const Color(0xFF7C2D12),
    ];

    return colors[index % colors.length];
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today,
            size: 52,
            color: AppColors.namaMediumGray.withOpacity(0.5),
          ),
          const SizedBox(height: 14),
          const Text(
            'No events for this day',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.namaDarkGray,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your schedule is clear!',
            style: TextStyle(
              fontSize: 13,
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
        initialChildSize: 0.54,
        minChildSize: 0.28,
        maxChildSize: 0.9,
        expand: false,
        snap: true,
        snapSizes: const [0.54, 0.9],
        builder: (context, scrollController) => EntryDetailsSheet(
          entry: entry,
          scrollController: scrollController,
        ),
      ),
    );
  }

  Widget _buildCurrentTimeIndicator() {
    final now = DateTime.now();
    final topOffset =
        (now.hour * _hourHeight) + ((now.minute / 60.0) * _hourHeight);

    return Positioned(
      top: topOffset,
      left: _timeColumnWidth,
      right: 0,
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Container(
              height: 1.5,
              color: Colors.red,
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