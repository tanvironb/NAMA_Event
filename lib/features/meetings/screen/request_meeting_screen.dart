// lib/features/meetings/screen/request_meeting_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/models/app_user.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:intl/intl.dart';

class RequestMeetingScreen extends ConsumerStatefulWidget {
  final AppUser recipient;

  const RequestMeetingScreen({super.key, required this.recipient});

  @override
  ConsumerState<RequestMeetingScreen> createState() =>
      _RequestMeetingScreenState();
}

class _RequestMeetingScreenState extends ConsumerState<RequestMeetingScreen> {
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 14, minute: 0);
  final _locationController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );

    if (time != null) {
      setState(() {
        _selectedTime = time;
      });
    }
  }

  Future<void> _proposeMeeting() async {
    final currentUserAsync = ref.read(userAppProfileStreamProvider);
    final currentUser = currentUserAsync.asData?.value;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to get current user information')),
      );
      return;
    }

    if (_locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a meeting location')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final proposedDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      await ref.read(meetingRepositoryProvider).requestMeeting(
        requesterId: currentUser.uid,
        recipientId: widget.recipient.uid,
        requesterInfo: {
          'name': currentUser.name,
          'profileImageUrl': currentUser.profileImageUrl,
        },
        recipientInfo: {
          'name': widget.recipient.name,
          'profileImageUrl': widget.recipient.profileImageUrl,
        },
        proposedTime: Timestamp.fromDate(proposedDateTime),
        location: _locationController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Meeting request sent to ${widget.recipient.name}!'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending meeting request: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildTopHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, left: 6, right: 6, bottom: 14),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: AppColors.namaNavyBlue,
              size: 22,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Meeting Request',
                style: TextStyle(
                  color: AppColors.namaNavyBlue,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildRecipientCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.namaWhite,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundImage: widget.recipient.profileImageUrl.isNotEmpty
                ? NetworkImage(widget.recipient.profileImageUrl)
                : null,
            backgroundColor: AppColors.avatarPlaceholder,
            child: widget.recipient.profileImageUrl.isEmpty
                ? Text(
                    widget.recipient.name.isNotEmpty
                        ? widget.recipient.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.avatarPlaceholderText,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.recipient.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (widget.recipient.title.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    widget.recipient.title,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textPrimary.withOpacity(0.65),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.namaWhite,
        borderRadius: BorderRadius.circular(13),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        dense: true,
        minLeadingWidth: 24,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Icon(icon, color: AppColors.navyBlue, size: 22),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary.withOpacity(0.72),
            ),
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 15,
          color: AppColors.textPrimary,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.namaWhite,
        borderRadius: BorderRadius.circular(13),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.location_on, color: AppColors.navyBlue, size: 22),
              SizedBox(width: 8),
              Text(
                'Location',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          TextField(
            controller: _locationController,
            style: const TextStyle(fontSize: 13.5),
            decoration: InputDecoration(
              hintText: 'e.g., Coffee shop, Conference room, Virtual meeting',
              hintStyle: TextStyle(
                fontSize: 13.5,
                color: AppColors.textPrimary.withOpacity(0.55),
              ),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMMM d, y');
    final timeFormat = DateFormat.jm();

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRecipientCard(context),

                    const SizedBox(height: 28),

                    const Text(
                      'Propose a Meeting',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      'Choose a convenient time and place to meet.',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: AppColors.textPrimary.withOpacity(0.6),
                      ),
                    ),

                    const SizedBox(height: 28),

                    _buildSelectionCard(
                      icon: Icons.calendar_today,
                      title: 'Date',
                      subtitle: dateFormat.format(_selectedDate),
                      onTap: _selectDate,
                    ),

                    const SizedBox(height: 16),

                    _buildSelectionCard(
                      icon: Icons.access_time,
                      title: 'Time',
                      subtitle: timeFormat.format(
                        DateTime(
                          2023,
                          1,
                          1,
                          _selectedTime.hour,
                          _selectedTime.minute,
                        ),
                      ),
                      onTap: _selectTime,
                    ),

                    const SizedBox(height: 16),

                    _buildLocationCard(),

                    const SizedBox(height: 38),

                    Center(
                      child: SizedBox(
                        width: 330,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _proposeMeeting,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.namaGoldenYellow,
                            foregroundColor: AppColors.namaWhite,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 19,
                                  width: 19,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.namaWhite,
                                  ),
                                )
                              : const Text(
                                  'Send Meeting Request',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    Text(
                      'Note: The recipient will receive a notification and can accept or decline your meeting request.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textPrimary.withOpacity(0.55),
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}