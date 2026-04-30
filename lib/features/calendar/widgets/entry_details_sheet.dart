// lib/features/calendar/widgets/entry_details_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/features/calendar/models/calendar_entry.dart';
import 'package:events_app_trueattempt/features/calendar/models/calendar_entry_type.dart';
import 'package:events_app_trueattempt/features/calendar/providers/calendar_providers.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:events_app_trueattempt/features/agenda/screen/session_detail_screen.dart';

class EntryDetailsSheet extends ConsumerStatefulWidget {
  final CalendarEntry entry;
  final ScrollController scrollController;

  const EntryDetailsSheet({
    super.key,
    required this.entry,
    required this.scrollController,
  });

  @override
  ConsumerState<EntryDetailsSheet> createState() => _EntryDetailsSheetState();
}

class _EntryDetailsSheetState extends ConsumerState<EntryDetailsSheet> {
  final TextEditingController _notesController = TextEditingController();
  bool _isEditingNotes = false;
  bool _isSavingNotes = false;

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

  Future<void> _saveNotes() async {
    final user = ref.read(userAppProfileStreamProvider).asData?.value;

    if (user == null) return;

    setState(() {
      _isSavingNotes = true;
    });

    await ref.read(calendarRepositoryProvider).saveEntryNotes(
          userId: user.uid,
          entryId: widget.entry.id,
          entryType: widget.entry.type,
          notes: _notesController.text.trim(),
        );

    ref.invalidate(calendarEntriesProvider);

    if (mounted) {
      setState(() {
        _isSavingNotes = false;
        _isEditingNotes = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 9),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.namaMediumGray.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                controller: widget.scrollController,
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTypeChip(),
                    const SizedBox(height: 12),
                    Text(
                      _getDisplayTitle(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.namaDarkGray,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildInfoRow(Icons.access_time_rounded, _getTimeString()),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      Icons.location_on_outlined,
                      widget.entry.location,
                    ),
                    if (widget.entry.type == CalendarEntryType.meeting) ...[
                      const SizedBox(height: 8),
                      _buildMeetingParticipants(),
                    ],
                    const SizedBox(height: 16),
                    Divider(
                      height: 1,
                      color: AppColors.namaMediumGray.withOpacity(0.45),
                    ),
                    const SizedBox(height: 14),
                    _buildNotesSection(),
                    if (widget.entry.type == CalendarEntryType.session) ...[
                      const SizedBox(height: 18),
                      _buildViewDetailsButton(),
                    ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isSession
            ? AppColors.namaNavyBlue.withOpacity(0.1)
            : AppColors.namaGoldenYellow.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        isSession ? 'Session' : 'Meeting',
        style: TextStyle(
          color: isSession ? AppColors.namaNavyBlue : AppColors.namaGoldenYellow,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 17, color: AppColors.namaMediumGray),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
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

    final otherUserName =
        meeting.requesterInfo['name'] ?? meeting.recipientInfo['name'] ?? 'Unknown';

    return _buildInfoRow(Icons.people_outline_rounded, 'With $otherUserName');
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
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.namaDarkGray,
              ),
            ),
            TextButton.icon(
              onPressed: _isSavingNotes
                  ? null
                  : () {
                      if (_isEditingNotes) {
                        _saveNotes();
                      } else {
                        setState(() {
                          _isEditingNotes = true;
                        });
                      }
                    },
              icon: Icon(
                _isEditingNotes ? Icons.check : Icons.edit_outlined,
                size: 15,
              ),
              label: Text(
                _isSavingNotes
                    ? 'Saving...'
                    : _isEditingNotes
                        ? 'Save'
                        : 'Edit',
                style: const TextStyle(fontSize: 12),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.namaNavyBlue,
                padding: EdgeInsets.zero,
                minimumSize: const Size(56, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (_isEditingNotes)
          TextField(
            controller: _notesController,
            maxLines: 3,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Add your notes here...',
              hintStyle: const TextStyle(fontSize: 13),
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: AppColors.namaMediumGray.withOpacity(0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppColors.namaNavyBlue,
                  width: 1.5,
                ),
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.namaMediumGray.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _notesController.text.isEmpty
                  ? 'No notes added'
                  : _notesController.text,
              style: TextStyle(
                fontSize: 13,
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
    return Center(
      child: SizedBox(
        width: 300,
        height: 40,
        child: ElevatedButton(
          onPressed: () {
            Navigator.pop(context);

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
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 0,
          ),
          child: const Text(
            'View Full Session Details',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  String _getDisplayTitle() {
    if (widget.entry.type == CalendarEntryType.session) {
      return widget.entry.title;
    }

    final meeting = widget.entry.meeting;
    if (meeting != null) {
      final otherUserName =
          meeting.requesterInfo['name'] ?? meeting.recipientInfo['name'] ?? 'Unknown';

      return 'Meeting with $otherUserName';
    }

    return 'Meeting';
  }

  String _getTimeString() {
    final format = DateFormat('h:mm a');
    final start = format.format(widget.entry.startTime);
    final end = format.format(widget.entry.endTime);
    return '$start - $end';
  }
}