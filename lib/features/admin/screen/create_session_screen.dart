// lib/features/admin/screen/create_session_screen.dart
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/features/admin/screen/admin_dashboard_screen.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class CreateSessionScreen extends StatefulWidget {
  final String eventId;
  final String eventName;

  const CreateSessionScreen({
    super.key,
    required this.eventId,
    required this.eventName,
  });

  @override
  State<CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends State<CreateSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  final _sessionTitleController = TextEditingController();
  final _sessionDescriptionController = TextEditingController();
  final _sessionLocationController = TextEditingController();
  final _liveStreamController = TextEditingController();

  final List<_SpeakerFormData> _speakers = [_SpeakerFormData()];

  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  Uint8List? _sessionImageBytes;
  Uint8List? _venueImageBytes;
  String? _sessionImageName;
  String? _venueImageName;

  String? _selectedCategory;
  int _priority = 3;
  bool _isChatEnabled = true;
  bool _isSaving = false;

  static const Color _primaryColor = Color(0xFF1B0F72);
  static const Color _textMuted = Color(0xFF6B7280);
  static const Color _fieldBorder = Color(0xFFE1DDF0);

  final List<String> _categories = const [
    'Keynote',
    'Panel Discussion',
    'Workshop',
    'Training',
    'Networking',
    'Forum',
    'Breakout Session',
    'Other',
  ];

  @override
  void dispose() {
    _sessionTitleController.dispose();
    _sessionDescriptionController.dispose();
    _sessionLocationController.dispose();
    _liveStreamController.dispose();

    for (final speaker in _speakers) {
      speaker.dispose();
    }

    super.dispose();
  }

  Future<void> _pickSessionImage() async {
    final pickedImage = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );

    if (pickedImage == null) return;

    final imageBytes = await pickedImage.readAsBytes();

    setState(() {
      _sessionImageBytes = imageBytes;
      _sessionImageName = pickedImage.name;
    });
  }

  Future<void> _pickVenueImage() async {
    final pickedImage = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );

    if (pickedImage == null) return;

    final imageBytes = await pickedImage.readAsBytes();

    setState(() {
      _venueImageBytes = imageBytes;
      _venueImageName = pickedImage.name;
    });
  }

  void _removeSessionImage() {
    setState(() {
      _sessionImageBytes = null;
      _sessionImageName = null;
    });
  }

  void _removeVenueImage() {
    setState(() {
      _venueImageBytes = null;
      _venueImageName = null;
    });
  }

  Future<String> _uploadImageToStorage({
    required Uint8List imageBytes,
    required String path,
  }) async {
    final ref = FirebaseStorage.instance.ref().child(path);

    final uploadTask = await ref.putData(
      imageBytes,
      SettableMetadata(
        contentType: 'image/jpeg',
      ),
    );

    return uploadTask.ref.getDownloadURL();
  }

  void _addMoreSpeaker() {
    setState(() {
      _speakers.add(_SpeakerFormData());
    });
  }

  void _removeSpeaker(int index) {
    if (_speakers.length == 1) return;

    setState(() {
      final removedSpeaker = _speakers.removeAt(index);
      removedSpeaker.dispose();
    });
  }

  void _clearFormForMoreSession() {
    _formKey.currentState?.reset();

    _sessionTitleController.clear();
    _sessionDescriptionController.clear();
    _sessionLocationController.clear();
    _liveStreamController.clear();

    for (final speaker in _speakers) {
      speaker.dispose();
    }

    _speakers
      ..clear()
      ..add(_SpeakerFormData());

    setState(() {
      _selectedDate = null;
      _startTime = null;
      _endTime = null;
      _selectedCategory = null;
      _priority = 3;
      _isChatEnabled = true;
      _sessionImageBytes = null;
      _venueImageBytes = null;
      _sessionImageName = null;
      _venueImageName = null;
    });
  }

  DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: _primaryColor,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: _primaryColor,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? _startTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: _primaryColor,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select date';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return '';

    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';

    return '$hour:$minute $period';
  }

  Future<String> _createOrGetSpeakerProfile(_SpeakerFormData speaker) async {
    final email = speaker.emailController.text.trim().toLowerCase();

    if (email.isNotEmpty) {
      final existingSpeaker = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (existingSpeaker.docs.isNotEmpty) {
        final speakerId = existingSpeaker.docs.first.id;

        await FirebaseFirestore.instance
            .collection('users')
            .doc(speakerId)
            .update({
          'name': speaker.nameController.text.trim(),
          'email': email,
          'role': 'speaker',
          'title': speaker.roleController.text.trim(),
          'position': speaker.positionController.text.trim(),
          'company': speaker.companyController.text.trim(),
          'bio': speaker.bioController.text.trim(),
          'status': 'approved',

          // Connect this speaker to the current event.
          'eventIds': FieldValue.arrayUnion([widget.eventId]),

          // AppUser supports: anonymous, minimal, full.
          'profileVisibility': 'full',

          'updatedAt': FieldValue.serverTimestamp(),
        });

        return speakerId;
      }
    }

    final speakerDoc = FirebaseFirestore.instance.collection('users').doc();

    await speakerDoc.set({
      'uid': speakerDoc.id,
      'name': speaker.nameController.text.trim(),
      'email': email,
      'role': 'speaker',
      'title': speaker.roleController.text.trim(),
      'position': speaker.positionController.text.trim(),
      'company': speaker.companyController.text.trim(),
      'bio': speaker.bioController.text.trim(),
      'profileImageUrl': '',
      'status': 'approved',
      'points': 0,

      // Connect this new speaker to the current event.
      'eventIds': [widget.eventId],

      // AppUser supports: anonymous, minimal, full.
      'profileVisibility': 'full',

      'needsPrivacySelection': false,
      'createdByAdmin': true,
      'authAccountCreated': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return speakerDoc.id;
  }

  Future<bool> _saveSessionToFirebase() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return false;

    if (_selectedDate == null) {
      _showMessage('Please select session date.');
      return false;
    }

    if (_startTime == null) {
      _showMessage('Please select start time.');
      return false;
    }

    if (_endTime == null) {
      _showMessage('Please select end time.');
      return false;
    }

    if (_sessionImageBytes == null) {
      _showMessage('Please upload session picture.');
      return false;
    }

    if (_venueImageBytes == null) {
      _showMessage('Please upload venue picture.');
      return false;
    }

    final startDate = _combineDateAndTime(_selectedDate!, _startTime!);
    final endDate = _combineDateAndTime(_selectedDate!, _endTime!);

    if (!endDate.isAfter(startDate)) {
      _showMessage('End time must be after start time.');
      return false;
    }

    setState(() => _isSaving = true);

    try {
      final List<String> speakerIds = [];

      for (final speaker in _speakers) {
        final speakerId = await _createOrGetSpeakerProfile(speaker);
        speakerIds.add(speakerId);
      }

      final sessionDoc = FirebaseFirestore.instance.collection('sessions').doc();

      final sessionImageUrl = await _uploadImageToStorage(
        imageBytes: _sessionImageBytes!,
        path:
            'sessions/${sessionDoc.id}/session_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final venueImageUrl = await _uploadImageToStorage(
        imageBytes: _venueImageBytes!,
        path:
            'sessions/${sessionDoc.id}/venue_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      await sessionDoc.set({
        'eventId': widget.eventId,
        'title': _sessionTitleController.text.trim(),
        'description': _sessionDescriptionController.text.trim(),
        'startTime': Timestamp.fromDate(startDate),
        'endTime': Timestamp.fromDate(endDate),
        'location': _sessionLocationController.text.trim(),
        'speakerIds': speakerIds,
        'liveStreamUrl': _liveStreamController.text.trim(),
        'qrCodePayload': sessionDoc.id,
        'category': _selectedCategory ?? '',
        'imageUrl': sessionImageUrl,
        'venueImageUrl': venueImageUrl,
        'priority': _priority,
        'partnerId': '',
        'isChatEnabled': _isChatEnabled,
        'closedBy': '',
        'checkedInAttendees': [],
        'totalMessages': 0,
        'uniqueParticipants': [],
        'mutedUsers': [],
        'deletedMessagesCount': 0,
        'messagesByRole': {},
        'muteHistory': [],
        'totalMuteActions': 0,
        'totalFeedbacks': 0,
        'totalRating': 0,
        'averageRating': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      _showMessage('Failed to create session: $e');
      return false;
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _createSessionAndGoDashboard() async {
    final saved = await _saveSessionToFirebase();

    if (!saved || !mounted) return;

    _showMessage('Session created successfully.');

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const AdminDashboardScreen(),
      ),
      (route) => false,
    );
  }

  Future<void> _addMoreSession() async {
    final saved = await _saveSessionToFirebase();

    if (!saved || !mounted) return;

    _showMessage('Session created. You can add another session now.');
    _clearFormForMoreSession();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildTopHeader() {
    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.of(context).pop(),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF6F4FD),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFE8E4F8),
              ),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _primaryColor,
              size: 17,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Image.asset(
          'assets/images/logo.png',
          height: 43,
          fit: BoxFit.contain,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final descriptionLength = _sessionDescriptionController.text.length;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopHeader(),
              const SizedBox(height: 26),
              Text(
                widget.eventName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Create Session',
                style: TextStyle(
                  color: _primaryColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Add session details and assign speaker profiles.',
                style: TextStyle(
                  color: _textMuted,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 22),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _SectionCard(
                      title: 'Session Details',
                      child: Column(
                        children: [
                          _InputField(
                            label: 'Session Title',
                            controller: _sessionTitleController,
                            hint: 'Enter session title',
                            icon: Icons.event_note_outlined,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Session title is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 15),
                          _InputField(
                            label: 'Short Description',
                            controller: _sessionDescriptionController,
                            hint: 'Optional session description',
                            icon: Icons.chat_bubble_outline_rounded,
                            maxLength: 200,
                            suffixText: '$descriptionLength/200',
                            onChanged: (_) => setState(() {}),
                            validator: null,
                          ),
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              Expanded(
                                child: _PickerField(
                                  label: 'Date',
                                  value: _formatDate(_selectedDate),
                                  icon: Icons.calendar_today_outlined,
                                  onTap: _pickDate,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _PickerField(
                                  label: 'Start',
                                  value: _startTime == null
                                      ? 'Start time'
                                      : _formatTime(_startTime),
                                  icon: Icons.access_time_rounded,
                                  onTap: _pickStartTime,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _PickerField(
                                  label: 'End',
                                  value: _endTime == null
                                      ? 'End time'
                                      : _formatTime(_endTime),
                                  icon: Icons.access_time_rounded,
                                  onTap: _pickEndTime,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          _InputField(
                            label: 'Venue / Location',
                            controller: _sessionLocationController,
                            hint: 'Enter session venue',
                            icon: Icons.location_on_outlined,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Location is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              Expanded(
                                child: _DropdownField(
                                  label: 'Category',
                                  value: _selectedCategory,
                                  hint: 'Select category',
                                  icon: Icons.sell_outlined,
                                  items: _categories,
                                  onChanged: (value) {
                                    setState(() => _selectedCategory = value);
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _PriorityField(
                                  value: _priority,
                                  onChanged: (value) {
                                    setState(() => _priority = value);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          _InputField(
                            label: 'Live Stream URL',
                            controller: _liveStreamController,
                            hint: 'Optional',
                            icon: Icons.live_tv_outlined,
                          ),
                          const SizedBox(height: 15),
                          _ImageUploadField(
                            label: 'Session Picture',
                            subtitle:
                                'This image will appear in attendee event details and homepage.',
                            imageBytes: _sessionImageBytes,
                            icon: Icons.image_outlined,
                            onTap: _pickSessionImage,
                            onRemove: _removeSessionImage,
                          ),
                          const SizedBox(height: 15),
                          _ImageUploadField(
                            label: 'Venue / Location Picture',
                            subtitle:
                                'This image will appear on attendee homepage under venue section.',
                            imageBytes: _venueImageBytes,
                            icon: Icons.location_city_outlined,
                            onTap: _pickVenueImage,
                            onRemove: _removeVenueImage,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _SectionCard(
                      title: 'Speaker Profile',
                      subtitle:
                          'Create speaker profiles and assign them to this session.',
                      child: Column(
                        children: [
                          ...List.generate(_speakers.length, (index) {
                            return _SpeakerFormCard(
                              index: index,
                              speaker: _speakers[index],
                              canRemove: _speakers.length > 1,
                              onRemove: () => _removeSpeaker(index),
                            );
                          }),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: OutlinedButton.icon(
                              onPressed: _addMoreSpeaker,
                              icon: const Icon(
                                Icons.add_rounded,
                                size: 18,
                              ),
                              label: const Text(
                                'Add More Speaker',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _primaryColor,
                                side: const BorderSide(
                                  color: _fieldBorder,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _SwitchCard(
                      title: 'Enable Session Chat',
                      subtitle: 'Allow attendees to chat during this session.',
                      value: _isChatEnabled,
                      onChanged: (value) {
                        setState(() => _isChatEnabled = value);
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            label: 'Back',
                            icon: Icons.arrow_back_rounded,
                            isPrimary: false,
                            isLoading: false,
                            onTap: () => Navigator.of(context).pop(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ActionButton(
                            label: 'Create',
                            icon: Icons.check_rounded,
                            isPrimary: true,
                            isLoading: _isSaving,
                            onTap: _createSessionAndGoDashboard,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: _ActionButton(
                        label: 'Add More Session',
                        icon: Icons.add_rounded,
                        isPrimary: false,
                        isLoading: _isSaving,
                        onTap: _addMoreSession,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const _FooterCredit(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeakerFormData {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final roleController = TextEditingController();
  final positionController = TextEditingController();
  final companyController = TextEditingController();
  final bioController = TextEditingController();

  void dispose() {
    nameController.dispose();
    emailController.dispose();
    roleController.dispose();
    positionController.dispose();
    companyController.dispose();
    bioController.dispose();
  }
}

class _ImageUploadField extends StatelessWidget {
  final String label;
  final String subtitle;
  final Uint8List? imageBytes;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _ImageUploadField({
    required this.label,
    required this.subtitle,
    required this.imageBytes,
    required this.icon,
    required this.onTap,
    required this.onRemove,
  });

  static const Color _primaryColor = Color(0xFF1B0F72);
  static const Color _fieldBorder = Color(0xFFE1DDF0);
  static const Color _textMuted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            width: double.infinity,
            height: imageBytes == null ? 92 : 160,
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFF),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: _fieldBorder,
              ),
            ),
            child: imageBytes == null
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Container(
                          height: 42,
                          width: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1EEFB),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            icon,
                            color: _primaryColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Upload $label',
                                style: const TextStyle(
                                  color: _primaryColor,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                style: const TextStyle(
                                  color: _textMuted,
                                  fontSize: 11.3,
                                  fontWeight: FontWeight.w500,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.upload_rounded,
                          color: _primaryColor,
                          size: 21,
                        ),
                      ],
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.memory(
                            imageBytes!,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: InkWell(
                            onTap: onRemove,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              height: 30,
                              width: 30,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.55),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 10,
                          bottom: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.white,
                                  size: 15,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'Image selected',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _SpeakerFormCard extends StatelessWidget {
  final int index;
  final _SpeakerFormData speaker;
  final bool canRemove;
  final VoidCallback onRemove;

  const _SpeakerFormCard({
    required this.index,
    required this.speaker,
    required this.canRemove,
    required this.onRemove,
  });

  static const Color _primaryColor = Color(0xFF1B0F72);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: index == 0 ? 0 : 14),
      padding: EdgeInsets.only(top: index == 0 ? 0 : 14),
      decoration: BoxDecoration(
        border: index == 0
            ? null
            : const Border(
                top: BorderSide(
                  color: Color(0xFFE8E4F8),
                ),
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (index > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Text(
                    'Speaker ${index + 1}',
                    style: const TextStyle(
                      color: _primaryColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  if (canRemove)
                    InkWell(
                      onTap: onRemove,
                      borderRadius: BorderRadius.circular(10),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.red,
                          size: 20,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          _InputField(
            label: 'Speaker Name',
            controller: speaker.nameController,
            hint: 'Enter speaker name',
            icon: Icons.person_outline_rounded,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Speaker name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 15),
          _InputField(
            label: 'Speaker Email',
            controller: speaker.emailController,
            hint: 'Optional speaker email',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              final email = value?.trim() ?? '';

              if (email.isEmpty) return null;

              if (!email.contains('@')) {
                return 'Enter valid email';
              }

              return null;
            },
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _InputField(
                  label: 'Role',
                  controller: speaker.roleController,
                  hint: 'Speaker / Moderator',
                  icon: Icons.badge_outlined,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Role is required';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InputField(
                  label: 'Position',
                  controller: speaker.positionController,
                  hint: 'Optional',
                  icon: Icons.work_outline_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          _InputField(
            label: 'Company',
            controller: speaker.companyController,
            hint: 'Organization',
            icon: Icons.business_outlined,
          ),
          const SizedBox(height: 15),
          _InputField(
            label: 'Bio',
            controller: speaker.bioController,
            hint: 'Optional short bio',
            icon: Icons.info_outline_rounded,
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    this.subtitle,
    required this.child,
  });

  static const Color _primaryColor = Color(0xFF1B0F72);
  static const Color _textMuted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE8E4F8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.018),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _primaryColor,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(
                color: _textMuted,
                fontSize: 11.8,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _SwitchCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  static const Color _primaryColor = Color(0xFF1B0F72);
  static const Color _textMuted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE8E4F8),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.chat_bubble_outline_rounded,
            color: _primaryColor,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _primaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _textMuted,
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: _primaryColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _PriorityField extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _PriorityField({
    required this.value,
    required this.onChanged,
  });

  static const Color _primaryColor = Color(0xFF1B0F72);
  static const Color _fieldBorder = Color(0xFFE1DDF0);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('Priority'),
        const SizedBox(height: 6),
        SizedBox(
          height: 48,
          child: DropdownButtonFormField<int>(
            value: value,
            onChanged: (newValue) {
              if (newValue != null) onChanged(newValue);
            },
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF454062),
              size: 18,
            ),
            style: const TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              prefixIcon: const Icon(
                Icons.priority_high_rounded,
                color: _primaryColor,
                size: 19,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 11,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(
                  color: _fieldBorder,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(
                  color: _primaryColor,
                  width: 1.1,
                ),
              ),
            ),
            items: const [
              DropdownMenuItem(value: 1, child: Text('1 - Low')),
              DropdownMenuItem(value: 2, child: Text('2')),
              DropdownMenuItem(value: 3, child: Text('3 - Normal')),
              DropdownMenuItem(value: 4, child: Text('4')),
              DropdownMenuItem(value: 5, child: Text('5 - High')),
            ],
          ),
        ),
      ],
    );
  }
}

class _InputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final String? suffixText;
  final int? maxLength;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;

  const _InputField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.icon,
    this.suffixText,
    this.maxLength,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.validator,
  });

  static const Color _primaryColor = Color(0xFF1B0F72);
  static const Color _fieldBorder = Color(0xFFE1DDF0);
  static const Color _textMuted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 6),
        SizedBox(
          height: 48,
          child: TextFormField(
            controller: controller,
            maxLength: maxLength,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            onChanged: onChanged,
            validator: validator,
            cursorColor: _primaryColor,
            style: const TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: hint,
              hintStyle: const TextStyle(
                color: _textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Icon(
                icon,
                color: _primaryColor,
                size: 19,
              ),
              suffixText: suffixText,
              suffixStyle: const TextStyle(
                color: _textMuted,
                fontSize: 11,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(
                  color: _fieldBorder,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(
                  color: _primaryColor,
                  width: 1.1,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(
                  color: Colors.redAccent,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(
                  color: Colors.redAccent,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PickerField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  static const Color _primaryColor = Color(0xFF1B0F72);
  static const Color _fieldBorder = Color(0xFFE1DDF0);
  static const Color _textMuted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final isPlaceholder =
        value == 'Select date' || value == 'Start time' || value == 'End time';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: _fieldBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: _primaryColor,
                  size: 18,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isPlaceholder
                          ? _textMuted
                          : const Color(0xFF1F2937),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF454062),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final String hint;
  final IconData icon;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.hint,
    required this.icon,
    required this.items,
    required this.onChanged,
  });

  static const Color _primaryColor = Color(0xFF1B0F72);
  static const Color _fieldBorder = Color(0xFFE1DDF0);
  static const Color _textMuted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 6),
        SizedBox(
          height: 48,
          child: DropdownButtonFormField<String>(
            value: value,
            onChanged: onChanged,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Required';
              }
              return null;
            },
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF454062),
              size: 18,
            ),
            style: const TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: _textMuted,
                fontSize: 12,
              ),
              prefixIcon: Icon(
                icon,
                color: _primaryColor,
                size: 19,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 11,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(
                  color: _fieldBorder,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(
                  color: _primaryColor,
                  width: 1.1,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(
                  color: Colors.redAccent,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(
                  color: Colors.redAccent,
                ),
              ),
            ),
            items: items
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item,
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: Color(0xFF1F2937),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF1B0F72),
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isPrimary;
  final bool isLoading;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.isPrimary,
    required this.isLoading,
    required this.onTap,
  });

  static const Color _primaryColor = Color(0xFF1B0F72);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onTap,
        icon: isLoading
            ? SizedBox(
                height: 15,
                width: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isPrimary ? Colors.white : _primaryColor,
                ),
              )
            : Icon(
                icon,
                size: 18,
              ),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: isPrimary ? _primaryColor : Colors.white,
          foregroundColor: isPrimary ? Colors.white : _primaryColor,
          disabledBackgroundColor:
              isPrimary ? _primaryColor.withOpacity(0.55) : Colors.white,
          disabledForegroundColor:
              isPrimary ? Colors.white70 : _primaryColor.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: isPrimary ? _primaryColor : const Color(0xFFE1DDF0),
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterCredit extends StatelessWidget {
  const _FooterCredit();

  static const Color _primaryColor = Color(0xFF1B0F72);

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Divider(
                color: Color(0xFFE2DEEF),
                thickness: 1,
                indent: 50,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'By: NAMA Foundation',
                style: TextStyle(
                  color: _primaryColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: Color(0xFFE2DEEF),
                thickness: 1,
                endIndent: 50,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Icon(
          Icons.circle,
          color: Color(0xFFF5B51B),
          size: 7,
        ),
      ],
    );
  }
}