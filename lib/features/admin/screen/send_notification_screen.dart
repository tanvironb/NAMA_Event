// lib/features/admin/screen/send_notification_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/enums/notification_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

class SendNotificationScreen extends ConsumerStatefulWidget {
  final String? eventId;
  final String? eventName;

  final String? initialTitle;
  final String? initialSubtitle;
  final String? initialBody;
  final String? initialAudience;
  final AppNotificationType? initialType;

  final String? initialQrPayload;
  final String? initialSessionCode;
  final String? initialSessionTitle;
  final DateTime? initialSessionDate;

  const SendNotificationScreen({
    super.key,
    this.eventId,
    this.eventName,
    this.initialTitle,
    this.initialSubtitle,
    this.initialBody,
    this.initialAudience,
    this.initialType,
    this.initialQrPayload,
    this.initialSessionCode,
    this.initialSessionTitle,
    this.initialSessionDate,
  });

  bool get isEventSpecific => eventId != null && eventId!.isNotEmpty;

  @override
  ConsumerState<SendNotificationScreen> createState() =>
      _SendNotificationScreenState();
}

class _SendNotificationScreenState
    extends ConsumerState<SendNotificationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _bodyController = TextEditingController();

  late AppNotificationType _selectedType;

  String _selectedAudience = 'all';

  bool _isSending = false;
  bool _hasTimestamp = false;
  bool _includeDate = true;
  DateTime? _selectedDateTime;

  static const Color _primaryColor = Color(0xFF1B0F72);
  static const Color _textMuted = Color(0xFF6B7280);
  static const Color _borderColor = Color(0xFFE1DDF0);
  static const Color _softPurple = Color(0xFFF6F4FD);

  List<AppNotificationType> get _availableTypes {
    final sendable = AppNotificationType.values
        .where((type) => type.isAdminSendable)
        .toList();

    if (sendable.isEmpty) {
      return [AppNotificationType.generic];
    }

    return sendable;
  }

  final List<_AudienceOption> _audiences = const [
    _AudienceOption(
      value: 'all',
      label: 'All Event Users',
      icon: Icons.groups_rounded,
    ),
    _AudienceOption(
      value: 'attendee',
      label: 'Attendees',
      icon: Icons.person_outline_rounded,
    ),
    _AudienceOption(
      value: 'speaker',
      label: 'Speakers',
      icon: Icons.record_voice_over_outlined,
    ),
    _AudienceOption(
      value: 'staff',
      label: 'Staff',
      icon: Icons.badge_outlined,
    ),
    _AudienceOption(
      value: 'admin',
      label: 'Admins',
      icon: Icons.admin_panel_settings_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();

    final availableTypes = _availableTypes;

    if (widget.initialType != null &&
        availableTypes.contains(widget.initialType)) {
      _selectedType = widget.initialType!;
    } else {
      _selectedType = availableTypes.first;
    }

    _selectedAudience = _isValidAudience(widget.initialAudience)
        ? widget.initialAudience!
        : 'all';

    _titleController.text = widget.initialTitle ?? '';
    _subtitleController.text = widget.initialSubtitle ?? '';
    _bodyController.text = widget.initialBody ?? '';
  }

  bool _isValidAudience(String? audience) {
    if (audience == null || audience.trim().isEmpty) return false;
    return _audiences.any((item) => item.value == audience);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _eventSessionsStream() {
    if (!widget.isEventSpecific) {
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('sessions')
        .where('eventId', isEqualTo: widget.eventId)
        .snapshots();
  }

  Set<String> _extractUserIdsFromEventSessions(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> sessionDocs,
  ) {
    final Set<String> userIds = {};

    for (final doc in sessionDocs) {
      final data = doc.data();

      void addListField(String fieldName) {
        final value = data[fieldName];

        if (value is List) {
          for (final item in value) {
            final id = item.toString().trim();
            if (id.isNotEmpty) userIds.add(id);
          }
        }
      }

      addListField('speakerIds');
      addListField('moderatorIds');
      addListField('checkedInAttendees');
      addListField('uniqueParticipants');
      addListField('bookmarkedBy');
      addListField('registeredUsers');
      addListField('attendeeIds');
      addListField('staffIds');
      addListField('adminIds');
    }

    return userIds;
  }

  bool _userBelongsToEvent({
    required String userId,
    required Map<String, dynamic> userData,
    required Set<String> eventUserIds,
  }) {
    if (!widget.isEventSpecific) return true;

    final eventId = widget.eventId!;
    final role = (userData['role'] ?? '').toString().toLowerCase();

    if (role == 'admin') return true;
    if (eventUserIds.contains(userId)) return true;

    final directEventId = userData['eventId']?.toString();
    final currentEventId = userData['currentEventId']?.toString();
    final activeEventId = userData['activeEventId']?.toString();

    if (directEventId == eventId ||
        currentEventId == eventId ||
        activeEventId == eventId) {
      return true;
    }

    bool arrayContainsEvent(String fieldName) {
      final value = userData[fieldName];

      if (value is List) {
        return value.map((e) => e.toString()).contains(eventId);
      }

      return false;
    }

    return arrayContainsEvent('eventIds') ||
        arrayContainsEvent('registeredEventIds') ||
        arrayContainsEvent('registeredEvents') ||
        arrayContainsEvent('joinedEvents') ||
        arrayContainsEvent('assignedEventIds');
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _getTargetUsers() async {
    Query<Map<String, dynamic>> usersQuery = FirebaseFirestore.instance
        .collection('users')
        .where('status', isEqualTo: 'approved');

    if (_selectedAudience != 'all') {
      usersQuery = usersQuery.where('role', isEqualTo: _selectedAudience);
    }

    final usersSnapshot = await usersQuery.get();
    final allUsers = usersSnapshot.docs;

    if (!widget.isEventSpecific) return allUsers;

    final sessionSnapshot = await _eventSessionsStream().first;
    final eventUserIds = _extractUserIdsFromEventSessions(sessionSnapshot.docs);

    return allUsers.where((userDoc) {
      return _userBelongsToEvent(
        userId: userDoc.id,
        userData: userDoc.data(),
        eventUserIds: eventUserIds,
      );
    }).toList();
  }

  Future<void> _sendNotification() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (_selectedType == AppNotificationType.alert) {
      final confirmed = await _showAlertConfirmation();
      if (!confirmed) return;
    }

    setState(() => _isSending = true);

    int successCount = 0;
    int failureCount = 0;

    try {
      final users = await _getTargetUsers();

      if (users.isEmpty) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEventSpecific
                  ? 'No users found for this event and selected audience.'
                  : 'No users found for the selected audience.',
            ),
            backgroundColor: AppColors.warningAmber,
          ),
        );
        return;
      }

      final timestamp = Timestamp.now();
      final sharedNotificationId =
          FirebaseFirestore.instance.collection('adminNotifications').doc().id;

      final adminNotificationData = <String, dynamic>{
        'title': _titleController.text.trim(),
        'subtitle': _subtitleController.text.trim(),
        'body': _bodyController.text.trim(),
        'timestamp': timestamp,
        'type': _selectedType.toString().split('.').last,
        'targetRole': _selectedAudience,
        'eventId': widget.eventId ?? '',
        'eventName': widget.eventName ?? '',
        'qrPayload': widget.initialQrPayload ?? '',
        'sessionCode': widget.initialSessionCode ?? '',
        'sessionTitle': widget.initialSessionTitle ?? '',
      };

      if (_hasTimestamp && _selectedDateTime != null) {
        adminNotificationData['eventTimestamp'] =
            Timestamp.fromDate(_selectedDateTime!);
        adminNotificationData['includeDate'] = _includeDate;
      }

      await FirebaseFirestore.instance
          .collection('adminNotifications')
          .doc(sharedNotificationId)
          .set(adminNotificationData);

      for (final userDoc in users) {
        try {
          final notificationRef = FirebaseFirestore.instance
              .collection('users')
              .doc(userDoc.id)
              .collection('notifications')
              .doc();

          final notificationData = <String, dynamic>{
            'title': _titleController.text.trim(),
            'subtitle': _subtitleController.text.trim(),
            'body': _bodyController.text.trim(),
            'timestamp': timestamp,
            'isRead': false,
            'type': _selectedType.toString().split('.').last,
            'targetRole': _selectedAudience,
            'eventId': widget.eventId ?? '',
            'eventName': widget.eventName ?? '',
            'qrPayload': widget.initialQrPayload ?? '',
            'sessionCode': widget.initialSessionCode ?? '',
            'sessionTitle': widget.initialSessionTitle ?? '',
            'data': {
              'notificationId': sharedNotificationId,
              'type': 'admin_notification',
              'eventId': widget.eventId ?? '',
              'eventName': widget.eventName ?? '',
              'qrPayload': widget.initialQrPayload ?? '',
              'sessionCode': widget.initialSessionCode ?? '',
              'sessionTitle': widget.initialSessionTitle ?? '',
            },
          };

          if (_hasTimestamp && _selectedDateTime != null) {
            notificationData['eventTimestamp'] =
                Timestamp.fromDate(_selectedDateTime!);
            notificationData['includeDate'] = _includeDate;
          }

          await notificationRef.set(notificationData);
          successCount++;
        } catch (e) {
          failureCount++;
          debugPrint('Failed to send notification to ${userDoc.id}: $e');
        }
      }

      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failureCount == 0
                ? 'Notification sent to $successCount user(s).'
                : 'Sent to $successCount user(s), failed for $failureCount.',
          ),
          backgroundColor: failureCount == 0
              ? AppColors.successGreen
              : AppColors.warningAmber,
        ),
      );
    } catch (e) {
      debugPrint('Error sending notification: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send notification: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
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
      builder: (context) {
        return _AlertConfirmationDialog(
          targetAudience: _selectedAudience,
          onConfirm: () {
            confirmed = true;
            Navigator.of(context).pop();
          },
          onCancel: () {
            confirmed = false;
            Navigator.of(context).pop();
          },
        );
      },
    );

    return confirmed;
  }

  Future<bool> _showAlertTypeConfirmation() async {
    bool confirmed = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _AlertTypeSelectionDialog(
          onConfirm: () {
            confirmed = true;
            Navigator.of(context).pop();
          },
          onCancel: () {
            confirmed = false;
            Navigator.of(context).pop();
          },
        );
      },
    );

    return confirmed;
  }

  Future<void> _pickNotificationDateTime() async {
    if (_includeDate) {
      final date = await showDatePicker(
        context: context,
        initialDate: _selectedDateTime ?? DateTime.now(),
        firstDate: DateTime.now().subtract(const Duration(days: 1)),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );

      if (date == null || !mounted) return;

      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(
          _selectedDateTime ?? DateTime.now(),
        ),
      );

      if (time == null) return;

      setState(() {
        _selectedDateTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
      });

      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _selectedDateTime ?? DateTime.now(),
      ),
    );

    if (time == null) return;

    final now = DateTime.now();

    setState(() {
      _selectedDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _selectNotificationType(AppNotificationType type) async {
    if (type == AppNotificationType.alert) {
      final confirmed = await _showAlertTypeConfirmation();
      if (!confirmed) return;
    }

    setState(() => _selectedType = type);
  }

  Widget _buildQrPreviewCard() {
    final qrPayload = widget.initialQrPayload ?? '';
    final sessionCode = widget.initialSessionCode ?? '';
    final sessionTitle = widget.initialSessionTitle ?? widget.eventName ?? '';
    final sessionDate = widget.initialSessionDate == null
        ? ''
        : DateFormat('EEEE, MMM d, yyyy').format(widget.initialSessionDate!);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F6FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE1DDF0),
        ),
      ),
      child: Column(
        children: [
          const Text(
            'QR Announcement Preview',
            style: TextStyle(
              color: _primaryColor,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (sessionTitle.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              sessionTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          ],
          if (sessionDate.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              sessionDate,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.namaGoldenYellow,
                width: 1.4,
              ),
            ),
            child: QrImageView(
              data: qrPayload,
              version: QrVersions.auto,
              size: 150,
              backgroundColor: Colors.white,
              foregroundColor: AppColors.namaNavyBlue,
            ),
          ),
          if (sessionCode.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: 210,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 11,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF1EEFB),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text(
                    'Session Code',
                    style: TextStyle(
                      color: _textMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sessionCode,
                    style: const TextStyle(
                      color: _primaryColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            'This QR preview will be included with this announcement data.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textMuted,
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final availableTypes = _availableTypes;
    final hasQrPreview =
        widget.initialQrPayload != null && widget.initialQrPayload!.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isSending
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.namaNavyBlue,
                ),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 18, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => Navigator.of(context).pop(),
                          child: const Padding(
                            padding: EdgeInsets.only(top: 3, right: 10),
                            child: Icon(
                              Icons.arrow_back,
                              color: AppColors.namaNavyBlue,
                              size: 20,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Send Notifications',
                                style: TextStyle(
                                  fontSize: 22,
                                  height: 1.1,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.namaNavyBlue,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              if (widget.isEventSpecific) ...[
                                const SizedBox(height: 4),
                                Text(
                                  widget.eventName ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    height: 1.1,
                                    color: _textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionLabel('Notification Type'),
                            const SizedBox(height: 9),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: availableTypes.map((type) {
                                final isSelected = _selectedType == type;

                                return _SelectableBox(
                                  label: type.displayName,
                                  icon: type.icon,
                                  color: type.color,
                                  selected: isSelected,
                                  onTap: () => _selectNotificationType(type),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 21),
                            _sectionLabel('Target Audience'),
                            const SizedBox(height: 9),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _audiences.map((audience) {
                                final isSelected =
                                    _selectedAudience == audience.value;

                                return _SelectableBox(
                                  label: audience.label,
                                  icon: audience.icon,
                                  color: _primaryColor,
                                  selected: isSelected,
                                  onTap: () {
                                    setState(() {
                                      _selectedAudience = audience.value;
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 21),
                            if (hasQrPreview) ...[
                              _buildQrPreviewCard(),
                              const SizedBox(height: 21),
                            ],
                            _sectionLabel('Notification Title'),
                            const SizedBox(height: 7),
                            TextFormField(
                              controller: _titleController,
                              style: const TextStyle(fontSize: 12.5),
                              decoration: _inputDecoration(
                                hintText: 'Enter notification title',
                              ),
                              maxLength: 100,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter a title';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            _sectionLabel('Subtitle / Side Note (Optional)'),
                            const SizedBox(height: 7),
                            TextFormField(
                              controller: _subtitleController,
                              style: const TextStyle(fontSize: 12.5),
                              decoration: _inputDecoration(
                                hintText: 'Enter subtitle or side note',
                              ),
                              maxLength: 120,
                            ),
                            const SizedBox(height: 12),
                            _sectionLabel('Notification Message'),
                            const SizedBox(height: 7),
                            TextFormField(
                              controller: _bodyController,
                              style: const TextStyle(fontSize: 12.5),
                              decoration: _inputDecoration(
                                hintText: 'Enter notification message',
                              ),
                              maxLines: 7,
                              maxLength: 700,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter a message';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _softPurple,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _borderColor),
                              ),
                              child: Row(
                                children: [
                                  Transform.scale(
                                    scale: 0.9,
                                    child: Checkbox(
                                      value: _hasTimestamp,
                                      activeColor: AppColors.namaNavyBlue,
                                      onChanged: (value) {
                                        setState(() {
                                          _hasTimestamp = value ?? false;
                                          if (!_hasTimestamp) {
                                            _selectedDateTime = null;
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  const Expanded(
                                    child: Text(
                                      'Add Event Timestamp (optional)',
                                      style: TextStyle(
                                        color: _primaryColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_hasTimestamp) ...[
                              const SizedBox(height: 11),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7F7FA),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _borderColor,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _sectionLabel('Timestamp Display'),
                                    const SizedBox(height: 9),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _SmallToggleButton(
                                            title: 'Date + Time',
                                            selected: _includeDate,
                                            onTap: () {
                                              setState(() {
                                                _includeDate = true;
                                                _selectedDateTime = null;
                                              });
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _SmallToggleButton(
                                            title: 'Time Only',
                                            selected: !_includeDate,
                                            onTap: () {
                                              setState(() {
                                                _includeDate = false;
                                                _selectedDateTime = null;
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 11),
                                    OutlinedButton.icon(
                                      onPressed: _pickNotificationDateTime,
                                      icon: Icon(
                                        _includeDate
                                            ? Icons.calendar_today
                                            : Icons.access_time,
                                        size: 17,
                                      ),
                                      label: Text(
                                        _selectedDateTime == null
                                            ? (_includeDate
                                                ? 'Select Date & Time'
                                                : 'Select Time')
                                            : (_includeDate
                                                ? DateFormat('M/d/yyyy h:mm a')
                                                    .format(_selectedDateTime!)
                                                : DateFormat('h:mm a')
                                                    .format(_selectedDateTime!)),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        minimumSize:
                                            const Size(double.infinity, 42),
                                        foregroundColor: AppColors.namaNavyBlue,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 22),
                            if (_selectedType == AppNotificationType.alert) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.errorRed.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.errorRed,
                                    width: 1.4,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.warning,
                                      color: AppColors.errorRed,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: Text(
                                        'Alert notifications will appear as popup warnings on user screens.',
                                        style: TextStyle(
                                          color: AppColors.errorRed,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                            Center(
                              child: SizedBox(
                                width: MediaQuery.of(context).size.width * 0.62,
                                height: 44,
                                child: ElevatedButton.icon(
                                  onPressed: _sendNotification,
                                  icon: const Icon(
                                    Icons.send,
                                    size: 17,
                                  ),
                                  label: Text(
                                    widget.isEventSpecific
                                        ? 'Send to Event Users'
                                        : 'Send Notification',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _selectedType ==
                                            AppNotificationType.alert
                                        ? AppColors.errorRed
                                        : AppColors.namaNavyBlue,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _primaryColor,
        fontWeight: FontWeight.w800,
        fontSize: 12.5,
      ),
    );
  }

  InputDecoration _inputDecoration({
    String? hintText,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: _textMuted,
        fontSize: 12,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ),
      counterStyle: const TextStyle(
        fontSize: 11,
        color: _textMuted,
      ),
      errorStyle: const TextStyle(
        fontSize: 11,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: _borderColor,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppColors.namaNavyBlue,
          width: 1.2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppColors.errorRed,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppColors.errorRed,
        ),
      ),
    );
  }
}

class _AudienceOption {
  final String value;
  final String label;
  final IconData icon;

  const _AudienceOption({
    required this.value,
    required this.label,
    required this.icon,
  });
}

class _SelectableBox extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _SelectableBox({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  static const Color _primaryColor = Color(0xFF1B0F72);
  static const Color _borderColor = Color(0xFFE1DDF0);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : _borderColor,
              width: selected ? 1.3 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: selected ? color : _primaryColor,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? color : _primaryColor,
                  fontSize: 11.3,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallToggleButton extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _SmallToggleButton({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  static const Color _primaryColor = Color(0xFF1B0F72);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: onTap,
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: selected ? _primaryColor : const Color(0xFFE1DDF0),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: selected ? Colors.white : _primaryColor,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _AlertTypeSelectionDialog extends StatefulWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _AlertTypeSelectionDialog({
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<_AlertTypeSelectionDialog> createState() =>
      _AlertTypeSelectionDialogState();
}

class _AlertTypeSelectionDialogState
    extends State<_AlertTypeSelectionDialog> {
  int _secondsLeft = 3;
  bool _canConfirm = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;

      setState(() {
        _secondsLeft--;

        if (_secondsLeft <= 0) {
          _canConfirm = true;
        } else {
          _startCountdown();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Select Alert Type?',
        style: TextStyle(fontSize: 16),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning,
            color: AppColors.errorRed,
            size: 36,
          ),
          const SizedBox(height: 12),
          const Text(
            'Alert notifications are high priority and should only be used for important warnings.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13),
          ),
          if (!_canConfirm) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: (3 - _secondsLeft) / 3,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.errorRed),
            ),
            const SizedBox(height: 8),
            Text(
              'Please wait $_secondsLeft second(s)...',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: const Text(
            'Cancel',
            style: TextStyle(fontSize: 12),
          ),
        ),
        ElevatedButton(
          onPressed: _canConfirm ? widget.onConfirm : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.errorRed,
            foregroundColor: Colors.white,
          ),
          child: const Text(
            'Use Alert',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}

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
  State<_AlertConfirmationDialog> createState() =>
      _AlertConfirmationDialogState();
}

class _AlertConfirmationDialogState
    extends State<_AlertConfirmationDialog> {
  int _secondsLeft = 3;
  bool _canConfirm = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;

      setState(() {
        _secondsLeft--;

        if (_secondsLeft <= 0) {
          _canConfirm = true;
        } else {
          _startCountdown();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final audienceText = widget.targetAudience == 'all'
        ? 'all selected event users'
        : widget.targetAudience;

    return AlertDialog(
      title: const Text(
        'Confirm Alert Notification',
        style: TextStyle(fontSize: 16),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning,
            color: AppColors.errorRed,
            size: 38,
          ),
          const SizedBox(height: 12),
          Text(
            'This will send an alert popup to $audienceText.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13),
          ),
          if (!_canConfirm) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: (3 - _secondsLeft) / 3,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.errorRed),
            ),
            const SizedBox(height: 8),
            Text(
              'Please wait $_secondsLeft second(s)...',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: const Text(
            'Cancel',
            style: TextStyle(fontSize: 12),
          ),
        ),
        ElevatedButton(
          onPressed: _canConfirm ? widget.onConfirm : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.errorRed,
            foregroundColor: Colors.white,
          ),
          child: const Text(
            'Send Alert',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}