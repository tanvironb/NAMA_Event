// lib/features/admin/screen/send_notification_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/enums/notification_type.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';

class SendNotificationScreen extends ConsumerStatefulWidget {
  const SendNotificationScreen({super.key});

  @override
  ConsumerState<SendNotificationScreen> createState() => _SendNotificationScreenState();
}

class _SendNotificationScreenState extends ConsumerState<SendNotificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _bodyController = TextEditingController();
  
  AppNotificationType _selectedType = AppNotificationType.announcement;
  String _selectedAudience = 'all';
  bool _isSending = false;
  bool _hasTimeRange = false;
  DateTime? _timeFrom;
  DateTime? _timeTo;

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _sendNotification() async {
    if (!_formKey.currentState!.validate()) return;

    // If alert type, show special confirmation
    if (_selectedType == AppNotificationType.alert) {
      final confirmed = await _showAlertConfirmation();
      if (!confirmed) return;
    }

    setState(() => _isSending = true);

    try {
      // Get all users based on audience
      final usersQuery = _selectedAudience == 'all'
          ? FirebaseFirestore.instance.collection('users').where('status', isEqualTo: 'approved')
          : FirebaseFirestore.instance.collection('users')
              .where('status', isEqualTo: 'approved')
              .where('role', isEqualTo: _selectedAudience);

      final usersSnapshot = await usersQuery.get();
      
      // Create notification for each user
      final batch = FirebaseFirestore.instance.batch();
      final timestamp = Timestamp.now();
      // Generate a single shared notification ID for all users
      final sharedNotificationId = FirebaseFirestore.instance.collection('temp').doc().id;

      // First, save to central adminNotifications collection
      final adminNotificationData = {
        'title': _titleController.text.trim(),
        'body': _bodyController.text.trim(),
        'timestamp': timestamp,
        'type': _selectedType.toString().split('.').last,
        'targetRole': _selectedAudience,
      };

      // Add optional fields
      if (_subtitleController.text.trim().isNotEmpty) {
        adminNotificationData['subtitle'] = _subtitleController.text.trim();
      }
      if (_hasTimeRange && _timeFrom != null) {
        adminNotificationData['timeFrom'] = Timestamp.fromDate(_timeFrom!);
      }
      if (_hasTimeRange && _timeTo != null) {
        adminNotificationData['timeTo'] = Timestamp.fromDate(_timeTo!);
      }

      final adminNotifRef = FirebaseFirestore.instance
          .collection('adminNotifications')
          .doc(sharedNotificationId);
      
      batch.set(adminNotifRef, adminNotificationData);

      // Then distribute to all users
      for (final userDoc in usersSnapshot.docs) {
        final notificationRef = FirebaseFirestore.instance
            .collection('users')
            .doc(userDoc.id)
            .collection('notifications')
            .doc();

        final notificationData = {
          'title': _titleController.text.trim(),
          'body': _bodyController.text.trim(),
          'timestamp': timestamp,
          'isRead': false,
          'type': _selectedType.toString().split('.').last,
          'targetRole': _selectedAudience,
          'data': {
            'notificationId': sharedNotificationId, // Shared ID for all users - enables edit/delete
            'type': 'admin_notification',
          },
        };

        // Add optional fields
        if (_subtitleController.text.trim().isNotEmpty) {
          notificationData['subtitle'] = _subtitleController.text.trim();
        }
        if (_hasTimeRange && _timeFrom != null) {
          notificationData['timeFrom'] = Timestamp.fromDate(_timeFrom!);
        }
        if (_hasTimeRange && _timeTo != null) {
          notificationData['timeTo'] = Timestamp.fromDate(_timeTo!);
        }

        batch.set(notificationRef, notificationData);
      }

      await batch.commit();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notification sent to ${usersSnapshot.docs.length} user(s)'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send notification: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<bool> _showAlertConfirmation() async {
    bool confirmed = false;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AlertConfirmationDialog(
        targetAudience: _selectedAudience,
        onConfirm: () {
          confirmed = true;
          Navigator.of(context).pop();
        },
        onCancel: () {
          confirmed = false;
          Navigator.of(context).pop();
        },
      ),
    );
    return confirmed;
  }

  Future<bool> _showAlertTypeConfirmation() async {
    bool confirmed = false;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AlertTypeSelectionDialog(
        onConfirm: () {
          confirmed = true;
          Navigator.of(context).pop();
        },
        onCancel: () {
          confirmed = false;
          Navigator.of(context).pop();
        },
      ),
    );
    return confirmed;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Push Notification'),
        backgroundColor: AppColors.namaNavyBlue,
        foregroundColor: Colors.white,
      ),
      body: _isSending
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Notification Type Dropdown
                    Text(
                      'Notification Type',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<AppNotificationType>(
                      value: _selectedType,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                      items: AppNotificationType.values
                          .where((type) => type.isAdminSendable)
                          .map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Row(
                            children: [
                              Icon(type.icon, color: type.color, size: 20),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(type.displayName),
                                  Text(
                                    '${type.priority.toUpperCase()} priority',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: type.color.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) async {
                        if (value != null) {
                          // Show confirmation if selecting Alert type
                          if (value == AppNotificationType.alert && _selectedType != AppNotificationType.alert) {
                            final confirmed = await _showAlertTypeConfirmation();
                            if (confirmed) {
                              setState(() => _selectedType = value);
                            } else {
                              // If user cancels, reset to Information type
                              setState(() => _selectedType = AppNotificationType.information);
                            }
                          } else {
                            setState(() => _selectedType = value);
                          }
                        }
                      },
                    ),
                    
                    const SizedBox(height: 24),

                    // Target Audience Dropdown
                    Text(
                      'Target Audience',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedAudience,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Users')),
                        DropdownMenuItem(value: 'attendee', child: Text('Attendees Only')),
                        DropdownMenuItem(value: 'speaker', child: Text('Speakers Only')),
                        DropdownMenuItem(value: 'staff', child: Text('Staff Only')),
                        DropdownMenuItem(value: 'admin', child: Text('Admins Only')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedAudience = value);
                        }
                      },
                    ),

                    const SizedBox(height: 24),

                    // Title Field
                    Text(
                      'Notification Title',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Enter notification title',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                      maxLength: 100,
                    ),

                    const SizedBox(height: 16),

                    // Subtitle Field (optional)
                    Text(
                      'Subtitle / Side Note (Optional)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _subtitleController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Enter subtitle or side note (shown below title)',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                      maxLength: 50,
                    ),

                    const SizedBox(height: 16),

                    // Body Field
                    Text(
                      'Notification Message',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _bodyController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Enter notification message',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a message';
                        }
                        return null;
                      },
                      maxLines: 5,
                      maxLength: 500,
                    ),

                    const SizedBox(height: 24),

                    // Time Range Toggle
                    Row(
                      children: [
                        Checkbox(
                          value: _hasTimeRange,
                          onChanged: (value) {
                            setState(() => _hasTimeRange = value ?? false);
                          },
                        ),
                        Text(
                          'Add Time Range (for events/maintenance)',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    if (_hasTimeRange) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('From:'),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate: DateTime.now(),
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now().add(const Duration(days: 365)),
                                    );
                                    if (date != null && mounted) {
                                      final time = await showTimePicker(
                                        context: context,
                                        initialTime: TimeOfDay.now(),
                                      );
                                      if (time != null) {
                                        setState(() {
                                          _timeFrom = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                                        });
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.calendar_today),
                                  label: Text(_timeFrom == null ? 'Select' : '${_timeFrom!.month}/${_timeFrom!.day} ${_timeFrom!.hour}:${_timeFrom!.minute.toString().padLeft(2, '0')}'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('To:'),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate: _timeFrom ?? DateTime.now(),
                                      firstDate: _timeFrom ?? DateTime.now(),
                                      lastDate: DateTime.now().add(const Duration(days: 365)),
                                    );
                                    if (date != null && mounted) {
                                      final time = await showTimePicker(
                                        context: context,
                                        initialTime: TimeOfDay.now(),
                                      );
                                      if (time != null) {
                                        setState(() {
                                          _timeTo = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                                        });
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.calendar_today),
                                  label: Text(_timeTo == null ? 'Select' : '${_timeTo!.month}/${_timeTo!.day} ${_timeTo!.hour}:${_timeTo!.minute.toString().padLeft(2, '0')}'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Warning notice for alert type
                    if (_selectedType == AppNotificationType.alert) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.errorRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.errorRed, width: 2),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning, color: AppColors.errorRed, size: 32),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'WARNING notifications will appear as a popup on all users\' screens with a 3-second delay before they can dismiss it.',
                                style: TextStyle(
                                  color: AppColors.errorRed,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Send Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _sendNotification,
                        icon: const Icon(Icons.send),
                        label: const Text('Send Notification'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedType == AppNotificationType.alert
                              ? AppColors.errorRed
                              : AppColors.namaNavyBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// Alert type selection confirmation dialog with 3-second timer
class _AlertTypeSelectionDialog extends StatefulWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _AlertTypeSelectionDialog({
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<_AlertTypeSelectionDialog> createState() => _AlertTypeSelectionDialogState();
}

class _AlertTypeSelectionDialogState extends State<_AlertTypeSelectionDialog> {
  int _secondsLeft = 3;
  bool _canConfirm = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _secondsLeft--;
          if (_secondsLeft <= 0) {
            _canConfirm = true;
          } else {
            _startCountdown();
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning, color: AppColors.errorRed, size: 28),
          const SizedBox(width: 12),
          const Expanded(child: Text('Select Alert Type?')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.errorRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.errorRed, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ALERT notifications are HIGH PRIORITY and will:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.errorRed,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '• Show as POPUP on all users\' screens\n'
                  '• Appear even if app was closed\n'
                  '• Force 3-second wait before dismissal\n'
                  '• Display with RED OUTLINE\n'
                  '• Should be used ONLY for emergencies',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          if (!_canConfirm) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: (3 - _secondsLeft) / 3,
              backgroundColor: AppColors.namaLightGray,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.errorRed),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Please wait $_secondsLeft second${_secondsLeft != 1 ? 's' : ''}...',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _canConfirm ? widget.onConfirm : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _canConfirm ? AppColors.errorRed : Colors.grey,
            foregroundColor: Colors.white,
          ),
          child: Text(_canConfirm ? 'Yes, Use Alert' : 'Wait...'),
        ),
      ],
    );
  }
}

// Alert send confirmation dialog with 3-second timer
class _AlertConfirmationDialog extends StatefulWidget {
  final String targetAudience;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _AlertConfirmationDialog({
    required this.targetAudience,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<_AlertConfirmationDialog> createState() => _AlertConfirmationDialogState();
}

class _AlertConfirmationDialogState extends State<_AlertConfirmationDialog> {
  int _secondsLeft = 3;
  bool _canConfirm = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _secondsLeft--;
          if (_secondsLeft <= 0) {
            _canConfirm = true;
          } else {
            _startCountdown();
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Format target audience for display
    String audienceText;
    switch (widget.targetAudience) {
      case 'all':
        audienceText = 'ALL users';
        break;
      case 'attendee':
        audienceText = 'all ATTENDEES';
        break;
      case 'speaker':
        audienceText = 'all SPEAKERS';
        break;
      case 'staff':
        audienceText = 'all STAFF members';
        break;
      case 'admin':
        audienceText = 'all ADMINS';
        break;
      default:
        audienceText = 'selected users';
    }
    
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning, color: AppColors.errorRed, size: 32),
          const SizedBox(width: 12),
          const Expanded(child: Text('Confirm Warning Notification')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.errorRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.errorRed, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.errorRed, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This will send a POPUP to $audienceText\' screens!',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.errorRed,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '• The popup will appear immediately\n'
                  '• Users must wait 3 seconds before closing it\n'
                  '• It has a RED OUTLINE (emergency alert)\n'
                  '• Use only for critical situations',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          if (!_canConfirm) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: (3 - _secondsLeft) / 3,
              backgroundColor: AppColors.namaLightGray,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.errorRed),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Please wait $_secondsLeft second${_secondsLeft != 1 ? 's' : ''}...',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _canConfirm ? widget.onConfirm : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _canConfirm ? AppColors.errorRed : Colors.grey,
            foregroundColor: Colors.white,
          ),
          child: Text(_canConfirm ? 'Yes, Send Warning' : 'Wait...'),
        ),
      ],
    );
  }
}
