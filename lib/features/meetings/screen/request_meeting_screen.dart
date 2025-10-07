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
  ConsumerState<RequestMeetingScreen> createState() => _RequestMeetingScreenState();
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
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending meeting request: $e'),
            backgroundColor: Colors.red,
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

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMMM d, y');
    final timeFormat = DateFormat.jm();

    return Scaffold(
      appBar: AppBar(
        title: Text('Meet with ${widget.recipient.name}'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recipient Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: widget.recipient.profileImageUrl.isNotEmpty
                          ? NetworkImage(widget.recipient.profileImageUrl)
                          : null,
                      child: widget.recipient.profileImageUrl.isEmpty
                          ? Text(
                              widget.recipient.name.isNotEmpty 
                                  ? widget.recipient.name[0].toUpperCase() 
                                  : '?',
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.recipient.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (widget.recipient.title.isNotEmpty)
                            Text(
                              widget.recipient.title,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            Text(
              'Propose a Meeting',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              'Choose a convenient time and place to meet.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            
            const SizedBox(height: 24),

            // Date Selection
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today, color: AppColors.navyBlue),
                title: const Text('Date'),
                subtitle: Text(dateFormat.format(_selectedDate)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _selectDate,
              ),
            ),
            
            const SizedBox(height: 16),

            // Time Selection
            Card(
              child: ListTile(
                leading: const Icon(Icons.access_time, color: AppColors.navyBlue),
                title: const Text('Time'),
                subtitle: Text(timeFormat.format(DateTime(
                  2023, 1, 1, _selectedTime.hour, _selectedTime.minute,
                ))),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _selectTime,
              ),
            ),
            
            const SizedBox(height: 16),

            // Location Input
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: AppColors.navyBlue),
                        const SizedBox(width: 8),
                        Text(
                          'Location',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        hintText: 'e.g., Coffee shop, Conference room, Virtual meeting',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),

            // Send Request Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _proposeMeeting,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.namaGoldenYellow,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Send Meeting Request',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            Text(
              'Note: The recipient will receive a notification and can accept or decline your meeting request.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}