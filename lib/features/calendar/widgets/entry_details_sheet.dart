// lib/features/calendar/widgets/entry_details_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/features/calendar/models/calendar_entry.dart';
import 'package:events_app_trueattempt/features/calendar/models/calendar_entry_type.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:events_app_trueattempt/features/agenda/screen/session_detail_screen.dart';

/// Bottom sheet showing calendar entry details
class EntryDetailsSheet extends ConsumerStatefulWidget {
  final CalendarEntry entry;

  const EntryDetailsSheet({super.key, required this.entry});

  @override
  ConsumerState<EntryDetailsSheet> createState() => _EntryDetailsSheetState();
}

class _EntryDetailsSheetState extends ConsumerState<EntryDetailsSheet> {
  final TextEditingController _notesController = TextEditingController();
  bool _isEditingNotes = false;

  @override
  void initState() {
    super.initState();
    _notesController.text = widget.entry.notes ?? '';
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.namaMediumGray.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type indicator
                  _buildTypeChip(),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    _getDisplayTitle(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.namaDarkGray,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Time
                  _buildInfoRow(
                    Icons.access_time_rounded,
                    _getTimeString(),
                  ),
                  const SizedBox(height: 12),

                  // Location
                  _buildInfoRow(
                    Icons.location_on_outlined,
                    widget.entry.location,
                  ),

                  // Additional info for meetings
                  if (widget.entry.type == CalendarEntryType.meeting) ...[
                    const SizedBox(height: 12),
                    _buildMeetingParticipants(),
                  ],

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Notes section
                  _buildNotesSection(),

                  const SizedBox(height: 24),

                  // Action buttons
                  if (widget.entry.type == CalendarEntryType.session)
                    _buildViewDetailsButton(),
                ],
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildTypeChip() {
    final isSession = widget.entry.type == CalendarEntryType.session;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSession 
            ? AppColors.namaNavyBlue.withOpacity(0.1) 
            : AppColors.namaGoldenYellow.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        isSession ? 'Session' : 'Meeting',
        style: TextStyle(
          color: isSession ? AppColors.namaNavyBlue : AppColors.namaGoldenYellow,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.namaMediumGray),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.namaDarkGray,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMeetingParticipants() {
    final meeting = widget.entry.meeting;
    if (meeting == null) return const SizedBox();

    final otherUserName = meeting.requesterInfo['name'] ?? 
                          meeting.recipientInfo['name'] ?? 
                          'Unknown';

    return _buildInfoRow(
      Icons.people_outline_rounded,
      'With $otherUserName',
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Notes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.namaDarkGray,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _isEditingNotes = !_isEditingNotes;
                });
              },
              icon: Icon(
                _isEditingNotes ? Icons.check : Icons.edit_outlined,
                size: 18,
              ),
              label: Text(_isEditingNotes ? 'Save' : 'Edit'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.namaNavyBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_isEditingNotes)
          TextField(
            controller: _notesController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Add your notes here...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.namaMediumGray.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.namaMediumGray.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.namaNavyBlue, width: 2),
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.namaMediumGray.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _notesController.text.isEmpty
                  ? 'No notes added'
                  : _notesController.text,
              style: TextStyle(
                fontSize: 14,
                color: _notesController.text.isEmpty
                    ? AppColors.namaMediumGray
                    : AppColors.namaDarkGray,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildViewDetailsButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.pop(context); // Close bottom sheet
          
          // Navigate to session details
          if (widget.entry.session != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SessionDetailScreen(
                  session: widget.entry.session!,
                ),
              ),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.namaNavyBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: const Text(
          'View Full Session Details',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  String _getDisplayTitle() {
    if (widget.entry.type == CalendarEntryType.session) {
      return widget.entry.title;
    } else {
      // For meetings, show "Meeting with [Name]"
      final meeting = widget.entry.meeting;
      if (meeting != null) {
        final otherUserName = meeting.requesterInfo['name'] ?? 
                              meeting.recipientInfo['name'] ?? 
                              'Unknown';
        return 'Meeting with $otherUserName';
      }
      return 'Meeting';
    }
  }

  String _getTimeString() {
    final format = DateFormat('h:mm a');
    final start = format.format(widget.entry.startTime);
    final end = format.format(widget.entry.endTime);
    return '$start - $end';
  }
}
