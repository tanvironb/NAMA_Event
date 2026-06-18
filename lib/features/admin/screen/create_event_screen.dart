// lib/features/admin/screen/create_event_screen.dart
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/features/admin/screen/create_session_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class CreateEventScreen extends StatefulWidget {
  final String? eventId;
  final Map<String, dynamic>? existingEventData;

  const CreateEventScreen({
    super.key,
    this.eventId,
    this.existingEventData,
  });

  bool get isEditMode => eventId != null && existingEventData != null;

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();

  final _eventNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _aboutEventController = TextEditingController();
  final _locationController = TextEditingController();
  final _registrationLimitController = TextEditingController();
  final _organizerContactController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();

  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  String? _selectedCategory;
  String _eventFormat = 'In-person';
  String _visibility = 'Public';

  bool _isSaving = false;
  bool _isLoadingExistingSpeakers = false;

  final List<_PartnerInput> _partners = [];
  final List<_SpeakerInput> _speakers = [];

  static const Color _primaryColor = Color(0xFF1B0F72);
  static const Color _goldColor = Color(0xFFE4B544);
  static const Color _softGold = Color(0xFFFFF8E6);
  static const Color _textMuted = Color(0xFF6B7280);

  final List<String> _categories = const [
    'Conference',
    'Summit',
    'Workshop',
    'Seminar',
    'Forum',
    'Networking',
    'Training',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _fillFieldsForEdit();

    if (_partners.isEmpty) {
      _partners.add(_PartnerInput());
    }

    if (_speakers.isEmpty) {
      _speakers.add(_SpeakerInput());
    }

    if (widget.isEditMode) {
      _loadExistingSpeakersForEdit();
    }
  }

  void _fillFieldsForEdit() {
    if (!widget.isEditMode) return;

    final data = widget.existingEventData!;

    _eventNameController.text = (data['name'] ?? '').toString();
    _descriptionController.text = (data['description'] ?? '').toString();
    _aboutEventController.text = (data['aboutEvent'] ?? '').toString();
    _locationController.text = (data['location'] ?? '').toString();
    _organizerContactController.text =
        (data['organizerContact'] ?? '').toString();

    final registrationLimit = data['registrationLimit'];
    if (registrationLimit != null) {
      _registrationLimitController.text = registrationLimit.toString();
    }

    final category = (data['category'] ?? '').toString();
    if (category.isNotEmpty && _categories.contains(category)) {
      _selectedCategory = category;
    }

    final format = (data['eventFormat'] ?? '').toString();
    if (format.isNotEmpty) {
      _eventFormat = format;
    }

    final visibility = (data['visibility'] ?? '').toString();
    if (visibility.isNotEmpty) {
      _visibility = visibility;
    }

    final startTimestamp = data['startDate'];
    final endTimestamp = data['endDate'];

    if (startTimestamp is Timestamp) {
      final startDate = startTimestamp.toDate();
      _startDate = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      );
      _startTime = TimeOfDay(
        hour: startDate.hour,
        minute: startDate.minute,
      );
    }

    if (endTimestamp is Timestamp) {
      final endDateValue = endTimestamp.toDate();
      _endDate = DateTime(
        endDateValue.year,
        endDateValue.month,
        endDateValue.day,
      );
      _endTime = TimeOfDay(
        hour: endDateValue.hour,
        minute: endDateValue.minute,
      );
    }

    final partnersData = data['partners'];
    if (partnersData is List) {
      for (final partner in partnersData) {
        if (partner is Map) {
          final name = (partner['name'] ?? '').toString();
          final logoUrl = (partner['logoUrl'] ?? '').toString();

          if (name.isNotEmpty || logoUrl.isNotEmpty) {
            _partners.add(
              _PartnerInput(
                name: name,
                existingLogoUrl: logoUrl,
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _loadExistingSpeakersForEdit() async {
    if (widget.eventId == null) return;

    setState(() => _isLoadingExistingSpeakers = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'speaker')
          .where('eventIds', arrayContains: widget.eventId)
          .get();

      if (!mounted) return;

      for (final speaker in _speakers) {
        speaker.dispose();
      }

      _speakers.clear();

      for (final doc in snapshot.docs) {
        final data = doc.data();

        _speakers.add(
          _SpeakerInput(
            existingUserId: doc.id,
            existingAuthAccountCreated: data['authAccountCreated'] == true,
            name: (data['name'] ?? '').toString(),
            email: (data['email'] ?? '').toString(),
            company: (data['company'] ?? '').toString(),
            savedPassword: _readSavedSpeakerPassword(data),
          ),
        );
      }

      if (_speakers.isEmpty) {
        _speakers.add(_SpeakerInput());
      }

      setState(() {});
    } catch (e) {
      _showMessage('Failed to load speakers: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingExistingSpeakers = false);
      }
    }
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    _descriptionController.dispose();
    _aboutEventController.dispose();
    _locationController.dispose();
    _registrationLimitController.dispose();
    _organizerContactController.dispose();

    for (final partner in _partners) {
      partner.dispose();
    }

    for (final speaker in _speakers) {
      speaker.dispose();
    }

    super.dispose();
  }

  String _makeSlug(String value) {
    final slug = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    if (slug.isEmpty) {
      return 'event_${DateTime.now().millisecondsSinceEpoch}';
    }

    return slug;
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

  Future<void> _pickStartDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: _primaryColor,
                  secondary: _goldColor,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;

        if (_endDate != null && _endDate!.isBefore(_dateOnly(picked))) {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? now,
      firstDate: _startDate ?? DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: _primaryColor,
                  secondary: _goldColor,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
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
                  secondary: _goldColor,
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
                  secondary: _goldColor,
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

  String _readSavedSpeakerPassword(Map<String, dynamic> data) {
    final password = (data['speakerPassword'] ??
            data['plainPassword'] ??
            data['password'] ??
            '')
        .toString()
        .trim();

    return password;
  }

  void _addPartner() {
    setState(() {
      _partners.add(_PartnerInput());
    });
  }

  void _removePartner(int index) {
    if (_partners.length == 1) {
      setState(() {
        _partners[index].clear();
      });
      return;
    }

    setState(() {
      final removedPartner = _partners.removeAt(index);
      removedPartner.dispose();
    });
  }

  void _addSpeaker() {
    setState(() {
      _speakers.add(_SpeakerInput());
    });
  }

  void _removeSpeaker(int index) {
    if (_speakers.length == 1) {
      setState(() {
        _speakers[index].clear();
      });
      return;
    }

    setState(() {
      final removedSpeaker = _speakers.removeAt(index);
      removedSpeaker.dispose();
    });
  }

  Future<void> _pickPartnerLogo(int index) async {
    try {
      final pickedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
      );

      if (pickedImage == null) return;

      final imageBytes = await pickedImage.readAsBytes();

      setState(() {
        _partners[index].pickedLogoBytes = imageBytes;
      });
    } catch (e) {
      _showMessage('Failed to pick logo: $e');
    }
  }

  bool _validatePartners() {
    for (int i = 0; i < _partners.length; i++) {
      final partner = _partners[i];
      final name = partner.nameController.text.trim();
      final hasLogo = partner.pickedLogoBytes != null ||
          partner.existingLogoUrl.trim().isNotEmpty;

      final isCompletelyEmpty = name.isEmpty && !hasLogo;

      if (isCompletelyEmpty) continue;

      if (name.isEmpty) {
        _showMessage('Please enter partner name for partner ${i + 1}.');
        return false;
      }

      if (!hasLogo) {
        _showMessage('Please add partner logo for $name.');
        return false;
      }
    }

    return true;
  }

  bool _validateSpeakers() {
    final usedEmails = <String>{};

    for (int i = 0; i < _speakers.length; i++) {
      final speaker = _speakers[i];

      final name = speaker.nameController.text.trim();
      final email = speaker.emailController.text.trim().toLowerCase();
      final company = speaker.companyController.text.trim();
      final password = speaker.passwordController.text.trim();

      final isCompletelyEmpty =
          name.isEmpty && email.isEmpty && company.isEmpty && password.isEmpty;

      if (isCompletelyEmpty) continue;

      if (name.isEmpty) {
        _showMessage('Please enter speaker name for speaker ${i + 1}.');
        return false;
      }

      if (email.isEmpty) {
        _showMessage('Please enter speaker email for $name.');
        return false;
      }

      if (!email.contains('@') || !email.contains('.')) {
        _showMessage('Please enter a valid email for $name.');
        return false;
      }

      if (usedEmails.contains(email)) {
        _showMessage('Duplicate speaker email: $email');
        return false;
      }

      usedEmails.add(email);

      final isNewSpeaker = speaker.existingUserId == null ||
          speaker.existingUserId!.trim().isEmpty ||
          speaker.existingAuthAccountCreated == false;

      if (isNewSpeaker && password.length < 6) {
        _showMessage('Password for $name must be at least 6 characters.');
        return false;
      }
    }

    return true;
  }

  Future<List<Map<String, dynamic>>> _uploadAndPreparePartners(
    String eventId,
  ) async {
    final List<Map<String, dynamic>> partnersData = [];

    for (int i = 0; i < _partners.length; i++) {
      final partner = _partners[i];
      final name = partner.nameController.text.trim();

      final hasExistingLogo = partner.existingLogoUrl.trim().isNotEmpty;
      final hasPickedLogo = partner.pickedLogoBytes != null;

      if (name.isEmpty && !hasExistingLogo && !hasPickedLogo) {
        continue;
      }

      String logoUrl = partner.existingLogoUrl.trim();

      if (hasPickedLogo) {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_partner_${i + 1}.jpg';

        final ref = FirebaseStorage.instance
            .ref()
            .child('events')
            .child(eventId)
            .child('partners')
            .child(fileName);

        final uploadTask = await ref.putData(
          partner.pickedLogoBytes!,
          SettableMetadata(contentType: 'image/jpeg'),
        );

        logoUrl = await uploadTask.ref.getDownloadURL();
      }

      partnersData.add({
        'name': name,
        'logoUrl': logoUrl,
      });
    }

    return partnersData;
  }

  Future<String> _createAuthAccountForSpeaker({
    required String name,
    required String email,
    required String password,
  }) async {
    FirebaseApp? secondaryApp;

    try {
      final appName =
          'speaker_creation_${DateTime.now().millisecondsSinceEpoch}';

      secondaryApp = await Firebase.initializeApp(
        name: appName,
        options: Firebase.app().options,
      );

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final createdUser = credential.user;

      if (createdUser == null || createdUser.uid.isEmpty) {
        throw Exception('Speaker user ID was not created.');
      }

      await createdUser.updateDisplayName(name);
      await createdUser.sendEmailVerification();

      await secondaryAuth.signOut();

      return createdUser.uid;
    } finally {
      if (secondaryApp != null) {
        await secondaryApp.delete();
      }
    }
  }

  Future<void> _createOrUpdateSpeakers(String eventId) async {
    for (final speaker in _speakers) {
      final name = speaker.nameController.text.trim();
      final email = speaker.emailController.text.trim().toLowerCase();
      final company = speaker.companyController.text.trim();
      final password = speaker.passwordController.text.trim();

      final isCompletelyEmpty =
          name.isEmpty && email.isEmpty && company.isEmpty && password.isEmpty;

      if (isCompletelyEmpty) continue;

      String uid = speaker.existingUserId ?? '';
      bool authAccountCreated = speaker.existingAuthAccountCreated;
      Map<String, dynamic> existingSpeakerData = {};

      if (uid.isNotEmpty) {
        final currentSpeakerDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();

        if (currentSpeakerDoc.exists) {
          existingSpeakerData = currentSpeakerDoc.data() ?? {};
          authAccountCreated =
              existingSpeakerData['authAccountCreated'] == true;
        }
      }

      if (uid.isEmpty) {
        final existingSpeaker = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (existingSpeaker.docs.isNotEmpty) {
          uid = existingSpeaker.docs.first.id;
          existingSpeakerData = existingSpeaker.docs.first.data();
          authAccountCreated =
              existingSpeakerData['authAccountCreated'] == true;
        }
      }

      if (uid.isEmpty) {
        uid = await _createAuthAccountForSpeaker(
          name: name,
          email: email,
          password: password,
        );
        authAccountCreated = true;
      }

      final savedPassword = password.isNotEmpty
          ? password
          : _readSavedSpeakerPassword(existingSpeakerData);

      final existingEmailVerified =
          existingSpeakerData['emailVerified'] == true;

      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {
          'uid': uid,
          'name': name,
          'email': email,
          'role': 'speaker',
          'company': company,
          'title': 'Speaker',
          'position': existingSpeakerData['position'] ?? '',
          'bio': existingSpeakerData['bio'] ?? '',
          'profileImageUrl': existingSpeakerData['profileImageUrl'] ?? '',
          'status': 'approved',
          'points': existingSpeakerData['points'] ?? 0,
          'eventIds': FieldValue.arrayUnion([eventId]),
          'activeEventId': eventId,
          'currentEventId': eventId,
          'profileVisibility':
              existingSpeakerData['profileVisibility'] ?? 'full',
          'needsPrivacySelection': false,
          'createdByAdmin': true,
          'authAccountCreated': authAccountCreated,
          'emailVerificationRequired': true,
          'emailVerified': existingEmailVerified,
          if (savedPassword.isNotEmpty) 'speakerPassword': savedPassword,
          if (savedPassword.isNotEmpty) 'plainPassword': savedPassword,
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt':
              existingSpeakerData['createdAt'] ?? FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
  }

  Future<String?> _saveEventToFirebase({
    required bool asDraft,
  }) async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return null;

    if (_startDate == null) {
      _showMessage('Please select start date.');
      return null;
    }

    if (_startTime == null) {
      _showMessage('Please select start time.');
      return null;
    }

    if (_endDate == null) {
      _showMessage('Please select end date.');
      return null;
    }

    if (_endTime == null) {
      _showMessage('Please select end time.');
      return null;
    }

    if (!_validatePartners()) return null;
    if (!_validateSpeakers()) return null;

    final startDate = _combineDateAndTime(_startDate!, _startTime!);
    final endDate = _combineDateAndTime(_endDate!, _endTime!);

    if (!endDate.isAfter(startDate)) {
      _showMessage('End date and time must be after start date and time.');
      return null;
    }

    setState(() => _isSaving = true);

    try {
      final name = _eventNameController.text.trim();

      final docId = widget.isEditMode ? widget.eventId! : _makeSlug(name);
      final docRef = FirebaseFirestore.instance.collection('events').doc(docId);

      if (!widget.isEditMode) {
        final existingDoc = await docRef.get();

        if (existingDoc.exists) {
          _showMessage('An event with this name already exists.');
          return null;
        }
      }

      final partnersData = await _uploadAndPreparePartners(docId);

      final eventData = {
        'name': name,
        'description': _descriptionController.text.trim(),
        'aboutEvent': _aboutEventController.text.trim(),
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'location': _locationController.text.trim(),
        'isActive': widget.existingEventData?['isActive'] ?? false,
        'venueMapUrl': widget.existingEventData?['venueMapUrl'] ?? '',
        'website': widget.existingEventData?['website'] ?? '',
        'category': _selectedCategory ?? '',
        'registrationLimit':
            int.tryParse(_registrationLimitController.text.trim()),
        'organizerContact': _organizerContactController.text.trim(),
        'eventFormat': _eventFormat,
        'visibility': _visibility,
        'partners': partnersData,
        'status': asDraft ? 'draft' : 'pending_sessions',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.isEditMode) {
        await docRef.update(eventData);
      } else {
        await docRef.set({
          ...eventData,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await _createOrUpdateSpeakers(docId);

      return docId;
    } catch (e) {
      _showMessage('Failed to save event: $e');
      return null;
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveDraft() async {
    final eventId = await _saveEventToFirebase(asDraft: true);

    if (eventId == null || !mounted) return;

    _showMessage(
      widget.isEditMode
          ? 'Event draft updated successfully.'
          : 'Event draft saved successfully.',
    );

    Navigator.of(context).pop();
  }

  Future<void> _goNextToSessionCreation() async {
    final eventId = await _saveEventToFirebase(asDraft: false);

    if (eventId == null || !mounted) return;

    final eventName = _eventNameController.text.trim();

    _showMessage(
      widget.isEditMode
          ? 'Event updated. Verification email sent to speaker if newly created.'
          : 'Event saved. Verification email sent to speaker if newly created.',
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateSessionScreen(
          eventId: eventId,
          eventName: eventName,
        ),
      ),
    );
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
              color: _softGold,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _goldColor.withOpacity(0.65),
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

  Widget _buildDateTimeFields() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 380;

        if (isSmall) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _PickerField(
                      label: 'Start Date',
                      value: _formatDate(_startDate),
                      icon: Icons.calendar_today_outlined,
                      onTap: _pickStartDate,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PickerField(
                      label: 'Start Time',
                      value: _startTime == null
                          ? 'Start time'
                          : _formatTime(_startTime),
                      icon: Icons.access_time_rounded,
                      onTap: _pickStartTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: _PickerField(
                      label: 'End Date',
                      value: _formatDate(_endDate),
                      icon: Icons.event_available_outlined,
                      onTap: _pickEndDate,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PickerField(
                      label: 'End Time',
                      value: _endTime == null
                          ? 'End time'
                          : _formatTime(_endTime),
                      icon: Icons.access_time_rounded,
                      onTap: _pickEndTime,
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _PickerField(
                    label: 'Start Date',
                    value: _formatDate(_startDate),
                    icon: Icons.calendar_today_outlined,
                    onTap: _pickStartDate,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PickerField(
                    label: 'Start Time',
                    value: _startTime == null
                        ? 'Start time'
                        : _formatTime(_startTime),
                    icon: Icons.access_time_rounded,
                    onTap: _pickStartTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: _PickerField(
                    label: 'End Date',
                    value: _formatDate(_endDate),
                    icon: Icons.event_available_outlined,
                    onTap: _pickEndDate,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PickerField(
                    label: 'End Time',
                    value:
                        _endTime == null ? 'End time' : _formatTime(_endTime),
                    icon: Icons.access_time_rounded,
                    onTap: _pickEndTime,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryAndLimitFields() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 380;

        if (isSmall) {
          return Column(
            children: [
              _DropdownField(
                label: 'Category',
                value: _selectedCategory,
                hint: 'Select category',
                icon: Icons.sell_outlined,
                items: _categories,
                onChanged: (value) {
                  setState(() => _selectedCategory = value);
                },
              ),
              const SizedBox(height: 15),
              _InputField(
                label: 'Registration Limit',
                controller: _registrationLimitController,
                hint: 'Enter limit optional',
                icon: Icons.people_outline_rounded,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
              ),
            ],
          );
        }

        return Row(
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
            const SizedBox(width: 10),
            Expanded(
              child: _InputField(
                label: 'Registration Limit',
                controller: _registrationLimitController,
                hint: 'Enter limit',
                icon: Icons.people_outline_rounded,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPartnersSection() {
    return _SectionContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'Partners',
            subtitle: 'Add event partners and upload their logos.',
            onAdd: _addPartner,
          ),
          const SizedBox(height: 15),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _partners.length,
            separatorBuilder: (_, __) => const SizedBox(height: 13),
            itemBuilder: (context, index) {
              final partner = _partners[index];

              return _PartnerCard(
                index: index,
                partner: partner,
                onPickLogo: () => _pickPartnerLogo(index),
                onRemove: () => _removePartner(index),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSpeakersSection() {
    return _SectionContainer(
      child: _isLoadingExistingSpeakers
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: CircularProgressIndicator(
                  color: _primaryColor,
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  title: 'Speaker Accounts',
                  subtitle:
                      'Admin creates speaker accounts here. Verification email will be sent to new speakers.',
                  onAdd: _addSpeaker,
                ),
                const SizedBox(height: 15),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _speakers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 13),
                  itemBuilder: (context, index) {
                    return _SpeakerAccountCard(
                      index: index,
                      speaker: _speakers[index],
                      onRemove: () => _removeSpeaker(index),
                    );
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildQuickSetupSection() {
    return _SectionContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Quick Setup',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _primaryColor,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Choose the basic event settings.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textMuted,
              fontSize: 11.8,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 340;

              if (isSmall) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Center(
                      child: _ChipGroup(
                        title: 'Event Format',
                        selectedValue: _eventFormat,
                        options: const [
                          _SetupOption(
                            label: 'In-person',
                            icon: Icons.person_outline_rounded,
                          ),
                          _SetupOption(
                            label: 'Online',
                            icon: Icons.language_rounded,
                          ),
                          _SetupOption(
                            label: 'Hybrid',
                            icon: Icons.groups_2_outlined,
                          ),
                        ],
                        onSelected: (value) {
                          setState(() => _eventFormat = value);
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: _ChipGroup(
                        title: 'Visibility',
                        selectedValue: _visibility,
                        options: const [
                          _SetupOption(
                            label: 'Public',
                            icon: Icons.language_rounded,
                          ),
                          _SetupOption(
                            label: 'Private',
                            icon: Icons.lock_outline_rounded,
                          ),
                        ],
                        onSelected: (value) {
                          setState(() => _visibility = value);
                        },
                      ),
                    ),
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Center(
                      child: _ChipGroup(
                        title: 'Event Format',
                        selectedValue: _eventFormat,
                        options: const [
                          _SetupOption(
                            label: 'In-person',
                            icon: Icons.person_outline_rounded,
                          ),
                          _SetupOption(
                            label: 'Online',
                            icon: Icons.language_rounded,
                          ),
                          _SetupOption(
                            label: 'Hybrid',
                            icon: Icons.groups_2_outlined,
                          ),
                        ],
                        onSelected: (value) {
                          setState(() => _eventFormat = value);
                        },
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    width: 1,
                    height: 66,
                    color: const Color(0xFFE4E1EF),
                  ),
                  Flexible(
                    child: Center(
                      child: _ChipGroup(
                        title: 'Visibility',
                        selectedValue: _visibility,
                        options: const [
                          _SetupOption(
                            label: 'Public',
                            icon: Icons.language_rounded,
                          ),
                          _SetupOption(
                            label: 'Private',
                            icon: Icons.lock_outline_rounded,
                          ),
                        ],
                        onSelected: (value) {
                          setState(() => _visibility = value);
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final descriptionLength = _descriptionController.text.length;
    final aboutEventLength = _aboutEventController.text.length;

    return Scaffold(
      backgroundColor: const Color(0xFFFEFCF7),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopHeader(),
              const SizedBox(height: 26),
              Text(
                widget.isEditMode ? 'Edit Event' : 'Create Event',
                style: const TextStyle(
                  color: _primaryColor,
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 3,
                width: 74,
                decoration: BoxDecoration(
                  color: _goldColor,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.isEditMode
                    ? 'Update event details, speaker accounts, and continue to sessions.'
                    : 'Set up a new event and create speaker accounts.',
                style: const TextStyle(
                  color: _textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 22),
              Form(
                key: _formKey,
                child: _SectionContainer(
                  child: Column(
                    children: [
                      _InputField(
                        label: 'Event Name',
                        controller: _eventNameController,
                        hint: 'Enter event name',
                        icon: Icons.confirmation_number_outlined,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Event name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      _InputField(
                        label: 'Short Description',
                        controller: _descriptionController,
                        hint: 'Briefly describe your event',
                        icon: Icons.chat_bubble_outline_rounded,
                        maxLength: 200,
                        suffixText: '$descriptionLength/200',
                        onChanged: (_) => setState(() {}),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Description is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      _InputField(
                        label: 'About Event',
                        controller: _aboutEventController,
                        hint:
                            'Write full event details, explanation, objectives, agenda overview, or any information attendees should know',
                        icon: Icons.info_outline_rounded,
                        maxLength: 2000,
                        maxLines: 6,
                        height: 145,
                        suffixText: '$aboutEventLength/2000',
                        onChanged: (_) => setState(() {}),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'About event is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      _buildDateTimeFields(),
                      const SizedBox(height: 15),
                      _InputField(
                        label: 'Venue / Location',
                        controller: _locationController,
                        hint: 'Enter venue or location',
                        icon: Icons.location_on_outlined,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Location is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      _buildCategoryAndLimitFields(),
                      const SizedBox(height: 15),
                      _InputField(
                        label: 'Organizer Contact',
                        controller: _organizerContactController,
                        hint: 'Email or phone number',
                        icon: Icons.mail_outline_rounded,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Organizer contact is required';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _buildPartnersSection(),
              const SizedBox(height: 14),
              _buildSpeakersSection(),
              const SizedBox(height: 14),
              _buildQuickSetupSection(),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: 'Save Draft',
                      icon: Icons.save_outlined,
                      isPrimary: false,
                      isLoading: _isSaving,
                      onTap: _saveDraft,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionButton(
                      label: 'Next',
                      icon: Icons.arrow_forward_rounded,
                      isPrimary: true,
                      isLoading: _isSaving,
                      onTap: _goNextToSessionCreation,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const _FooterCredit(),
            ],
          ),
        ),
      ),
    );
  }
}

class _PartnerInput {
  final TextEditingController nameController;
  String existingLogoUrl;
  Uint8List? pickedLogoBytes;

  _PartnerInput({
    String name = '',
    this.existingLogoUrl = '',
    this.pickedLogoBytes,
  }) : nameController = TextEditingController(text: name);

  void clear() {
    nameController.clear();
    existingLogoUrl = '';
    pickedLogoBytes = null;
  }

  void dispose() {
    nameController.dispose();
  }
}

class _SpeakerInput {
  final String? existingUserId;
  final bool existingAuthAccountCreated;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController companyController;
  final TextEditingController passwordController;

  _SpeakerInput({
    this.existingUserId,
    this.existingAuthAccountCreated = false,
    String name = '',
    String email = '',
    String company = '',
    String savedPassword = '',
  })  : nameController = TextEditingController(text: name),
        emailController = TextEditingController(text: email),
        companyController = TextEditingController(text: company),
        passwordController = TextEditingController(text: savedPassword);

  void clear() {
    nameController.clear();
    emailController.clear();
    companyController.clear();
    passwordController.clear();
  }

  void dispose() {
    nameController.dispose();
    emailController.dispose();
    companyController.dispose();
    passwordController.dispose();
  }
}
class _SectionContainer extends StatelessWidget {
  final Widget child;

  const _SectionContainer({
    required this.child,
  });

  static const Color _goldColor = Color(0xFFE4B544);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _goldColor.withOpacity(0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: _goldColor.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 4,
            width: 42,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: _goldColor,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onAdd;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.onAdd,
  });

  static const Color _primaryColor = Color(0xFF1B0F72);
  static const Color _goldColor = Color(0xFFE4B544);
  static const Color _softGold = Color(0xFFFFF8E6);
  static const Color _textMuted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: _goldColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                  color: _primaryColor,
                  fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _textMuted,
                  fontSize: 11.8,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        InkWell(
          onTap: onAdd,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _softGold,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _goldColor,
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.add_rounded,
                  color: _primaryColor,
                  size: 17,
                ),
                SizedBox(width: 5),
                Text(
                  'Add',
                  style: TextStyle(
                    color: _primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PartnerCard extends StatelessWidget {
  final int index;
  final _PartnerInput partner;
  final VoidCallback onPickLogo;
  final VoidCallback onRemove;

  const _PartnerCard({
    required this.index,
    required this.partner,
    required this.onPickLogo,
    required this.onRemove,
  });

  static const Color _primaryColor = Color(0xFF1B0F72);
  static const Color _fieldBorder = Color(0xFFEADAA3);
  static const Color _textMuted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    Widget logoChild;

    if (partner.pickedLogoBytes != null) {
      logoChild = ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.memory(
          partner.pickedLogoBytes!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      );
    } else if (partner.existingLogoUrl.trim().isNotEmpty) {
      logoChild = ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          partner.existingLogoUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) {
            return const Icon(
              Icons.broken_image_outlined,
              color: _primaryColor,
              size: 24,
            );
          },
        ),
      );
    } else {
      logoChild = const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_outlined,
            color: _primaryColor,
            size: 23,
          ),
          SizedBox(height: 5),
          Text(
            'Logo',
            style: TextStyle(
              color: _textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _fieldBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Partner',
                style: TextStyle(
                  color: _primaryColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                ' ${index + 1}',
                style: const TextStyle(
                  color: _primaryColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: onRemove,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 30,
                  width: 30,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFE8E4F8),
                    ),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _PartnerNameField(
                  controller: partner.nameController,
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: onPickLogo,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 82,
                  width: 82,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _fieldBorder,
                    ),
                  ),
                  child: logoChild,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: onPickLogo,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 38,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _fieldBorder,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.upload_rounded,
                    color: Color(0xFFE4B544),
                    size: 17,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Upload Partner Logo',
                    style: TextStyle(
                      color: Color(0xFF1B0F72),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PartnerNameField extends StatelessWidget {
  final TextEditingController controller;

  const _PartnerNameField({
    required this.controller,
  });

  static const Color _primaryColor = Color(0xFF1B0F72);
  static const Color _fieldBorder = Color(0xFFEADAA3);
  static const Color _textMuted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('Partner Name'),
        const SizedBox(height: 6),
        SizedBox(
          height: 48,
          child: TextFormField(
            controller: controller,
            cursorColor: _primaryColor,
            style: const TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'Enter partner name',
              hintStyle: const TextStyle(
                color: _textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: const Icon(
                Icons.handshake_outlined,
                color: _primaryColor,
                size: 19,
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 40,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
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
  static const Color _fieldBorder = Color(0xFFEADAA3);
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
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: _fieldBorder),
            ),
            child: Row(
              children: [
                Icon(icon, color: _primaryColor, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isPlaceholder
                          ? _textMuted
                          : const Color(0xFF1F2937),
                      fontSize: 10.7,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF454062),
                  size: 17,
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
  static const Color _fieldBorder = Color(0xFFEADAA3);
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
            isExpanded: true,
            onChanged: onChanged,
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Required';
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
              hintStyle: const TextStyle(color: _textMuted, fontSize: 12),
              prefixIcon: Icon(icon, color: _primaryColor, size: 19),
              prefixIconConstraints: const BoxConstraints(minWidth: 40),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: _fieldBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: _primaryColor, width: 1.1),
              ),
            ),
            items: items
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item,
                    child: Text(
                      item,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

class _SetupOption {
  final String label;
  final IconData icon;

  const _SetupOption({
    required this.label,
    required this.icon,
  });
}

class _ChipGroup extends StatelessWidget {
  final String title;
  final String selectedValue;
  final List<_SetupOption> options;
  final ValueChanged<String> onSelected;

  const _ChipGroup({
    required this.title,
    required this.selectedValue,
    required this.options,
    required this.onSelected,
  });

  static const Color _primaryColor = Color(0xFF1B0F72);
  static const Color _fieldBorder = Color(0xFFEADAA3);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _primaryColor,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 9),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 7,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = option.label == selectedValue;

            return InkWell(
              onTap: () => onSelected(option.label),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFFFF3CC) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFFE4B544) : _fieldBorder,
                    width: isSelected ? 1.3 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(option.icon, size: 15, color: _primaryColor),
                    const SizedBox(width: 5),
                    Text(
                      option.label,
                      style: const TextStyle(
                        color: _primaryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
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
            : Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: isPrimary ? _primaryColor : const Color(0xFFFFF8E6),
          foregroundColor: isPrimary ? Colors.white : _primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: isPrimary ? _primaryColor : const Color(0xFFE4B544),
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterCredit extends StatelessWidget {
  const _FooterCredit();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: Color(0xFFEADAA3), indent: 50)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'By: NAMA Foundation',
                style: TextStyle(
                  color: Color(0xFF1B0F72),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(child: Divider(color: Color(0xFFEADAA3), endIndent: 50)),
          ],
        ),
        SizedBox(height: 8),
        Icon(Icons.circle, color: Color(0xFFF5B51B), size: 7),
      ],
    );
  }
}
class _SpeakerAccountCard extends StatefulWidget {
  final int index;
  final _SpeakerInput speaker;
  final VoidCallback onRemove;

  const _SpeakerAccountCard({
    required this.index,
    required this.speaker,
    required this.onRemove,
  });

  @override
  State<_SpeakerAccountCard> createState() => _SpeakerAccountCardState();
}

class _SpeakerAccountCardState extends State<_SpeakerAccountCard> {
  bool _obscurePassword = true;

  static const Color _primaryColor = Color(0xFF1B0F72);
  static const Color _fieldBorder = Color(0xFFEADAA3);
  static const Color _textMuted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final isExisting = widget.speaker.existingUserId != null &&
        widget.speaker.existingUserId!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _fieldBorder,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Speaker ${widget.index + 1}',
                style: const TextStyle(
                  color: _primaryColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3CC),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Role: Speaker',
                  style: TextStyle(
                    color: _primaryColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: widget.onRemove,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 30,
                  width: 30,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFE8E4F8),
                    ),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InputField(
            label: 'Speaker Name',
            controller: widget.speaker.nameController,
            hint: 'Enter speaker name',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 12),
          _InputField(
            label: 'Speaker Email',
            controller: widget.speaker.emailController,
            hint: 'Enter speaker email',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          _InputField(
            label: 'Company',
            controller: widget.speaker.companyController,
            hint: 'Company / organization optional',
            icon: Icons.business_outlined,
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isExisting ? 'Password (saved for this speaker)' : 'Password',
                style: const TextStyle(
                  color: _primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 48,
                child: TextFormField(
                  controller: widget.speaker.passwordController,
                  obscureText: _obscurePassword,
                  cursorColor: _primaryColor,
                  style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: isExisting
                        ? 'Saved speaker password'
                        : 'Set speaker password',
                    hintStyle: const TextStyle(
                      color: _textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      color: _primaryColor,
                      size: 19,
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 40,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: _primaryColor,
                        size: 19,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
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
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
  final int maxLines;
  final double height;
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
    this.maxLines = 1,
    this.height = 48,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.validator,
  });

  static const Color _primaryColor = Color(0xFF1B0F72);
  static const Color _fieldBorder = Color(0xFFEADAA3);
  static const Color _textMuted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final isMultiLine = maxLines > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 6),
        SizedBox(
          height: height,
          child: TextFormField(
            controller: controller,
            maxLength: maxLength,
            maxLines: maxLines,
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
              hintMaxLines: isMultiLine ? 5 : 1,
              hintStyle: const TextStyle(
                color: _textMuted,
                fontSize: 12,
              ),
              prefixIcon: Padding(
                padding: EdgeInsets.only(top: isMultiLine ? 12 : 0),
                child: Icon(icon, color: _primaryColor, size: 19),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 40),
              suffixText: suffixText,
              suffixStyle: const TextStyle(color: _textMuted, fontSize: 11),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 10,
                vertical: isMultiLine ? 14 : 12,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: _fieldBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: _primaryColor, width: 1.1),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: Colors.redAccent),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: Colors.redAccent),
              ),
            ),
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
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Color(0xFF1B0F72),
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}