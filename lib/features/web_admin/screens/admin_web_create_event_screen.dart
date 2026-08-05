
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/features/admin/screen/create_session_screen.dart';
import 'package:events_app_trueattempt/features/web_admin/admin_web_theme.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class AdminWebCreateEventScreen extends StatefulWidget {
  final String? eventId;
  final Map<String, dynamic>? existingEventData;

  const AdminWebCreateEventScreen({
    super.key,
    this.eventId,
    this.existingEventData,
  });

  bool get isEditMode => eventId != null && existingEventData != null;

  @override
  State<AdminWebCreateEventScreen> createState() =>
      _AdminWebCreateEventScreenState();
}

class _AdminWebCreateEventScreenState
    extends State<AdminWebCreateEventScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _eventNameController = TextEditingController();
  final TextEditingController _shortDescriptionController =
      TextEditingController();
  final TextEditingController _aboutController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _onlineLinkController = TextEditingController();
  final TextEditingController _registrationLimitController =
      TextEditingController();
  final TextEditingController _organizerNameController =
      TextEditingController();
  final TextEditingController _organizerEmailController =
      TextEditingController();
  final TextEditingController _organizerPhoneController =
      TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();

  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  DateTime? _registrationOpenDate;
  DateTime? _registrationCloseDate;

  String? _selectedCategory;
  String _eventFormat = 'In-person';
  String _visibility = 'Public';
  String _timeZone = 'Asia/Kuala_Lumpur';

  bool _registrationEnabled = true;
  bool _approvalRequired = false;
  bool _allowCheckIns = true;
  bool _allowUploads = true;
  bool _isSaving = false;

  Uint8List? _selectedCoverBytes;
  String _existingCoverUrl = '';

  final List<_PartnerDraft> _partners = [];

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

  final List<String> _timeZones = const [
    'Asia/Kuala_Lumpur',
    'Asia/Dhaka',
    'Asia/Riyadh',
    'Asia/Dubai',
    'Asia/Muscat',
    'Africa/Dar_es_Salaam',
    'Europe/London',
    'UTC',
  ];

  @override
  void initState() {
    super.initState();
    _fillExistingData();
  }

  void _fillExistingData() {
    if (!widget.isEditMode) return;

    final data = widget.existingEventData!;

    _eventNameController.text = (data['name'] ?? '').toString();
    _shortDescriptionController.text =
        (data['description'] ?? '').toString();
    _aboutController.text =
        (data['aboutEvent'] ?? data['about'] ?? '').toString();
    _locationController.text = (data['location'] ?? '').toString();
    _addressController.text = (data['address'] ?? '').toString();
    _cityController.text = (data['city'] ?? '').toString();
    _countryController.text = (data['country'] ?? '').toString();
    _onlineLinkController.text =
        (data['onlineLink'] ?? data['website'] ?? '').toString();
    _organizerNameController.text =
        (data['organizerName'] ?? '').toString();
    _organizerEmailController.text =
        (data['organizerContact'] ?? data['organizerEmail'] ?? '').toString();
    _organizerPhoneController.text =
        (data['organizerPhone'] ?? '').toString();

    final registrationLimit = data['registrationLimit'];
    if (registrationLimit != null) {
      _registrationLimitController.text = registrationLimit.toString();
    }

    _selectedCategory = (data['category'] ?? '').toString().trim().isEmpty
        ? null
        : (data['category'] ?? '').toString();

    _eventFormat = (data['eventFormat'] ?? 'In-person').toString();
    _visibility = (data['visibility'] ?? 'Public').toString();
    _timeZone = (data['timeZone'] ?? 'Asia/Kuala_Lumpur').toString();

    _registrationEnabled = data['allowRegistrations'] != false;
    _approvalRequired = data['registrationApprovalRequired'] == true;
    _allowCheckIns = data['allowCheckIns'] != false;
    _allowUploads = data['allowUploads'] != false;

    _existingCoverUrl = (data['imageUrl'] ??
            data['coverImageUrl'] ??
            data['eventImageUrl'] ??
            '')
        .toString();

    final rawPartners = data['partners'];
    if (rawPartners is List) {
      for (final rawPartner in rawPartners) {
        if (rawPartner is Map) {
          final partnerData = Map<String, dynamic>.from(rawPartner);
          final name = (partnerData['name'] ??
                  partnerData['partnerName'] ??
                  partnerData['title'] ??
                  '')
              .toString()
              .trim();
          final logoUrl = (partnerData['logoUrl'] ??
                  partnerData['imageUrl'] ??
                  partnerData['logo'] ??
                  '')
              .toString()
              .trim();

          if (name.isNotEmpty || logoUrl.isNotEmpty) {
            _partners.add(
              _PartnerDraft(
                name: name,
                existingLogoUrl: logoUrl,
                existingStoragePath:
                    (partnerData['storagePath'] ?? '').toString(),
              ),
            );
          }
        } else if (rawPartner != null &&
            rawPartner.toString().trim().isNotEmpty) {
          _partners.add(
            _PartnerDraft(name: rawPartner.toString().trim()),
          );
        }
      }
    }

    final startTimestamp = data['startDate'];
    if (startTimestamp is Timestamp) {
      final date = startTimestamp.toDate();
      _startDate = DateTime(date.year, date.month, date.day);
      _startTime = TimeOfDay(hour: date.hour, minute: date.minute);
    }

    final endTimestamp = data['endDate'];
    if (endTimestamp is Timestamp) {
      final date = endTimestamp.toDate();
      _endDate = DateTime(date.year, date.month, date.day);
      _endTime = TimeOfDay(hour: date.hour, minute: date.minute);
    }

    final registrationOpen = data['registrationOpenDate'];
    if (registrationOpen is Timestamp) {
      _registrationOpenDate = registrationOpen.toDate();
    }

    final registrationClose = data['registrationCloseDate'];
    if (registrationClose is Timestamp) {
      _registrationCloseDate = registrationClose.toDate();
    }
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    _shortDescriptionController.dispose();
    _aboutController.dispose();
    _locationController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _onlineLinkController.dispose();
    _registrationLimitController.dispose();
    _organizerNameController.dispose();
    _organizerEmailController.dispose();
    _organizerPhoneController.dispose();

    for (final partner in _partners) {
      partner.dispose();
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

    return slug.isEmpty
        ? 'event_${DateTime.now().millisecondsSinceEpoch}'
        : slug;
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

  Future<DateTime?> _pickDate(
    DateTime? current, {
    DateTime? firstDate,
  }) async {
    final now = DateTime.now();

    return showDatePicker(
      context: context,
      initialDate: current ?? firstDate ?? now,
      firstDate: firstDate ?? DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
  }

  Future<TimeOfDay?> _pickTime(TimeOfDay? current) {
    return showTimePicker(
      context: context,
      initialTime: current ?? TimeOfDay.now(),
    );
  }

  Future<void> _pickCoverImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1800,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();

      if (!mounted) return;

      setState(() {
        _selectedCoverBytes = bytes;
      });
    } catch (error) {
      _showMessage('Could not select the cover image: $error');
    }
  }


  void _addPartner() {
    setState(() {
      _partners.add(_PartnerDraft());
    });
  }

  void _removePartner(int index) {
    if (index < 0 || index >= _partners.length) return;

    final partner = _partners.removeAt(index);
    partner.dispose();

    setState(() {});
  }

  Future<void> _pickPartnerLogo(int index) async {
    if (index < 0 || index >= _partners.length) return;

    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 1200,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();

      if (!mounted) return;

      setState(() {
        _partners[index].selectedLogoBytes = bytes;
      });
    } catch (error) {
      _showMessage('Could not select the partner logo: $error');
    }
  }

  String _safeFileName(String value) {
    final result = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    return result.isEmpty ? 'partner' : result;
  }

  Future<List<Map<String, dynamic>>> _uploadPartnerLogos(
    String eventId,
  ) async {
    final savedPartners = <Map<String, dynamic>>[];

    for (var index = 0; index < _partners.length; index++) {
      final partner = _partners[index];
      final name = partner.nameController.text.trim();

      if (name.isEmpty &&
          partner.selectedLogoBytes == null &&
          partner.existingLogoUrl.trim().isEmpty) {
        continue;
      }

      if (name.isEmpty) {
        throw StateError(
          'Please enter the name for partner ${index + 1}.',
        );
      }

      var logoUrl = partner.existingLogoUrl.trim();
      var storagePath = partner.existingStoragePath.trim();

      if (partner.selectedLogoBytes != null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = _safeFileName(name);

        storagePath =
            'events/$eventId/partners/${fileName}_${timestamp}.jpg';

        final reference = FirebaseStorage.instance.ref(storagePath);

        await reference.putData(
          partner.selectedLogoBytes!,
          SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {
              'eventId': eventId,
              'partnerName': name,
            },
          ),
        );

        logoUrl = await reference.getDownloadURL();
      }

      if (logoUrl.isEmpty) {
        throw StateError(
          'Please upload a logo for "$name".',
        );
      }

      savedPartners.add({
        'name': name,
        'logoUrl': logoUrl,
        'imageUrl': logoUrl,
        'storagePath': storagePath,
        'order': savedPartners.length,
      });
    }

    return savedPartners;
  }

  Future<String> _uploadCoverImage(String eventId) async {
    if (_selectedCoverBytes == null) return _existingCoverUrl;

    final path =
        'events/$eventId/cover_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final reference = FirebaseStorage.instance.ref(path);

    await reference.putData(
      _selectedCoverBytes!,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    return reference.getDownloadURL();
  }

  Future<String?> _saveEvent({required bool asDraft}) async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return null;

    if (_startDate == null || _startTime == null) {
      _showMessage('Please select the event start date and time.');
      return null;
    }

    if (_endDate == null || _endTime == null) {
      _showMessage('Please select the event end date and time.');
      return null;
    }

    final startDate = _combineDateAndTime(_startDate!, _startTime!);
    final endDate = _combineDateAndTime(_endDate!, _endTime!);

    if (!endDate.isAfter(startDate)) {
      _showMessage('The end date and time must be after the start.');
      return null;
    }

    if (_registrationOpenDate != null &&
        _registrationCloseDate != null &&
        _registrationCloseDate!.isBefore(_registrationOpenDate!)) {
      _showMessage(
        'The registration closing date must be after the opening date.',
      );
      return null;
    }

    setState(() => _isSaving = true);

    try {
      final eventName = _eventNameController.text.trim();
      final eventId =
          widget.isEditMode ? widget.eventId! : _makeSlug(eventName);

      final reference =
          FirebaseFirestore.instance.collection('events').doc(eventId);

      if (!widget.isEditMode) {
        final existing = await reference.get();
        if (existing.exists) {
          _showMessage(
            'An event with this name already exists. Please use another name.',
          );
          return null;
        }
      }

      final coverUrl = await _uploadCoverImage(eventId);
      final partners = await _uploadPartnerLogos(eventId);

      final eventData = <String, dynamic>{
        'name': eventName,
        'description': _shortDescriptionController.text.trim(),
        'aboutEvent': _aboutController.text.trim(),
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'timeZone': _timeZone,
        'location': _locationController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'country': _countryController.text.trim(),
        'onlineLink': _onlineLinkController.text.trim(),
        'website': _onlineLinkController.text.trim(),
        'category': _selectedCategory ?? '',
        'eventFormat': _eventFormat,
        'visibility': _visibility,
        'registrationLimit':
            int.tryParse(_registrationLimitController.text.trim()),
        'registrationOpenDate': _registrationOpenDate == null
            ? null
            : Timestamp.fromDate(_registrationOpenDate!),
        'registrationCloseDate': _registrationCloseDate == null
            ? null
            : Timestamp.fromDate(_registrationCloseDate!),
        'allowRegistrations': _registrationEnabled,
        'registrationApprovalRequired': _approvalRequired,
        'allowCheckIns': _allowCheckIns,
        'allowUploads': _allowUploads,
        'organizerName': _organizerNameController.text.trim(),
        'organizerEmail': _organizerEmailController.text.trim(),
        'organizerContact': _organizerEmailController.text.trim(),
        'organizerPhone': _organizerPhoneController.text.trim(),
        'imageUrl': coverUrl,
        'coverImageUrl': coverUrl,
        'partners': partners,
        'partnerCount': partners.length,
        'isActive': widget.existingEventData?['isActive'] ?? false,
        'isArchived': widget.existingEventData?['isArchived'] ?? false,
        'status': asDraft
            ? 'draft'
            : widget.existingEventData?['status'] == 'archived'
                ? 'archived'
                : 'pending_sessions',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.isEditMode) {
        await reference.set(eventData, SetOptions(merge: true));
      } else {
        await reference.set({
          ...eventData,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return eventId;
    } catch (error) {
      _showMessage('Could not save the event: $error');
      return null;
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveDraft() async {
    final eventId = await _saveEvent(asDraft: true);
    if (eventId == null || !mounted) return;

    _showMessage(
      widget.isEditMode
          ? 'Event draft updated successfully.'
          : 'Event draft saved successfully.',
    );

    Navigator.of(context).pop(true);
  }

  Future<void> _saveAndContinue() async {
    final eventId = await _saveEvent(asDraft: false);
    if (eventId == null || !mounted) return;

    final eventName = _eventNameController.text.trim();

    if (widget.isEditMode) {
      _showMessage('Event updated successfully.');
      Navigator.of(context).pop(true);
      return;
    }

    await _showNextStepDialog(
      eventId: eventId,
      eventName: eventName,
    );
  }

  Future<void> _showNextStepDialog({
    required String eventId,
    required String eventName,
  }) async {
    final action = await showDialog<_NextEventAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: Colors.green,
                size: 28,
              ),
              SizedBox(width: 10),
              Text(
                'Event Created',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          content: const SizedBox(
            width: 480,
            child: Text(
              'The event has been saved. Speakers and moderators can now be assigned from their dedicated pages. Choose the next setup step.',
              style: TextStyle(
                color: AdminWebTheme.textSecondary,
                height: 1.45,
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext)
                  .pop(_NextEventAction.backToEvents),
              child: const Text('Back to Events'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(dialogContext)
                  .pop(_NextEventAction.createSession),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create First Session'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    if (action == _NextEventAction.createSession) {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CreateSessionScreen(
            eventId: eventId,
            eventName: eventName,
          ),
        ),
      );
      return;
    }

    Navigator.of(context).pop(true);
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminWebTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _PageHeader(
              isEditMode: widget.isEditMode,
              isSaving: _isSaving,
              onBack: () => Navigator.of(context).pop(),
              onSaveDraft: _saveDraft,
              onSave: _saveAndContinue,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1220),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _WebSectionCard(
                            title: 'Event Details',
                            subtitle:
                                'Add the core information attendees will see.',
                            icon: Icons.event_note_rounded,
                            child: Column(
                              children: [
                                _WebTextField(
                                  label: 'Event Name',
                                  controller: _eventNameController,
                                  hint: 'Enter event name',
                                  icon: Icons.badge_outlined,
                                  validator: _requiredValidator(
                                    'Event name is required.',
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _WebTextField(
                                  label: 'Short Description',
                                  controller:
                                      _shortDescriptionController,
                                  hint:
                                      'Summarize the event in one or two sentences',
                                  icon: Icons.short_text_rounded,
                                  maxLines: 2,
                                  validator: _requiredValidator(
                                    'Short description is required.',
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _WebTextField(
                                  label: 'About Event',
                                  controller: _aboutController,
                                  hint:
                                      'Explain the event objectives, audience and main topics',
                                  icon: Icons.info_outline_rounded,
                                  maxLines: 6,
                                  validator: _requiredValidator(
                                    'About event is required.',
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _ResponsiveTwoColumns(
                                  left: _WebDropdownField<String>(
                                    label: 'Category',
                                    value: _selectedCategory,
                                    hint: 'Select category',
                                    icon: Icons.sell_outlined,
                                    items: _categories,
                                    itemLabel: (item) => item,
                                    onChanged: (value) {
                                      setState(
                                        () => _selectedCategory = value,
                                      );
                                    },
                                  ),
                                  right: _CoverImagePicker(
                                    selectedBytes: _selectedCoverBytes,
                                    existingUrl: _existingCoverUrl,
                                    onPick: _pickCoverImage,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          _ResponsiveTwoColumns(
                            left: _WebSectionCard(
                              title: 'Date & Time',
                              subtitle:
                                  'Set the event schedule and time zone.',
                              icon: Icons.schedule_rounded,
                              child: Column(
                                children: [
                                  _ResponsiveTwoColumns(
                                    left: _PickerField(
                                      label: 'Start Date',
                                      value: _formatDate(_startDate),
                                      icon:
                                          Icons.calendar_today_outlined,
                                      onTap: () async {
                                        final value = await _pickDate(
                                          _startDate,
                                        );
                                        if (value == null) return;
                                        setState(() => _startDate = value);
                                      },
                                    ),
                                    right: _PickerField(
                                      label: 'Start Time',
                                      value: _formatTime(_startTime),
                                      icon: Icons.access_time_rounded,
                                      onTap: () async {
                                        final value =
                                            await _pickTime(_startTime);
                                        if (value == null) return;
                                        setState(() => _startTime = value);
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _ResponsiveTwoColumns(
                                    left: _PickerField(
                                      label: 'End Date',
                                      value: _formatDate(_endDate),
                                      icon:
                                          Icons.event_available_outlined,
                                      onTap: () async {
                                        final value = await _pickDate(
                                          _endDate,
                                          firstDate: _startDate,
                                        );
                                        if (value == null) return;
                                        setState(() => _endDate = value);
                                      },
                                    ),
                                    right: _PickerField(
                                      label: 'End Time',
                                      value: _formatTime(_endTime),
                                      icon: Icons.access_time_rounded,
                                      onTap: () async {
                                        final value =
                                            await _pickTime(_endTime);
                                        if (value == null) return;
                                        setState(() => _endTime = value);
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _WebDropdownField<String>(
                                    label: 'Time Zone',
                                    value: _timeZones.contains(_timeZone)
                                        ? _timeZone
                                        : _timeZones.first,
                                    hint: 'Select time zone',
                                    icon: Icons.public_rounded,
                                    items: _timeZones,
                                    itemLabel: (item) => item,
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setState(() => _timeZone = value);
                                    },
                                  ),
                                ],
                              ),
                            ),
                            right: _WebSectionCard(
                              title: 'Location',
                              subtitle:
                                  'Configure the physical or online venue.',
                              icon: Icons.location_on_rounded,
                              child: Column(
                                children: [
                                  _WebChoiceChips(
                                    label: 'Event Format',
                                    selected: _eventFormat,
                                    options: const [
                                      'In-person',
                                      'Online',
                                      'Hybrid',
                                    ],
                                    onSelected: (value) {
                                      setState(() => _eventFormat = value);
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  _WebTextField(
                                    label: 'Venue / Location',
                                    controller: _locationController,
                                    hint: 'Enter venue or platform name',
                                    icon: Icons.location_on_outlined,
                                    validator: _requiredValidator(
                                      'Location is required.',
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _WebTextField(
                                    label: 'Full Address',
                                    controller: _addressController,
                                    hint: 'Enter the full address',
                                    icon: Icons.map_outlined,
                                  ),
                                  const SizedBox(height: 16),
                                  _ResponsiveTwoColumns(
                                    left: _WebTextField(
                                      label: 'City',
                                      controller: _cityController,
                                      hint: 'City',
                                      icon: Icons.location_city_outlined,
                                    ),
                                    right: _WebTextField(
                                      label: 'Country',
                                      controller: _countryController,
                                      hint: 'Country',
                                      icon: Icons.flag_outlined,
                                    ),
                                  ),
                                  if (_eventFormat != 'In-person') ...[
                                    const SizedBox(height: 16),
                                    _WebTextField(
                                      label: 'Online / Livestream Link',
                                      controller: _onlineLinkController,
                                      hint: 'https://',
                                      icon: Icons.link_rounded,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          _ResponsiveTwoColumns(
                            left: _WebSectionCard(
                              title: 'Registration',
                              subtitle:
                                  'Control registration availability and capacity.',
                              icon: Icons.how_to_reg_rounded,
                              child: Column(
                                children: [
                                  _WebSwitchTile(
                                    title: 'Enable Registration',
                                    subtitle:
                                        'Allow users to register for this event.',
                                    value: _registrationEnabled,
                                    onChanged: (value) {
                                      setState(
                                        () => _registrationEnabled = value,
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  _WebSwitchTile(
                                    title: 'Require Approval',
                                    subtitle:
                                        'Admin approval is required before registration is accepted.',
                                    value: _approvalRequired,
                                    onChanged: _registrationEnabled
                                        ? (value) {
                                            setState(
                                              () =>
                                                  _approvalRequired = value,
                                            );
                                          }
                                        : null,
                                  ),
                                  const SizedBox(height: 16),
                                  _WebTextField(
                                    label: 'Registration Limit',
                                    controller:
                                        _registrationLimitController,
                                    hint: 'Leave blank for unlimited',
                                    icon: Icons.groups_outlined,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter
                                          .digitsOnly,
                                    ],
                                    enabled: _registrationEnabled,
                                  ),
                                  const SizedBox(height: 16),
                                  _ResponsiveTwoColumns(
                                    left: _PickerField(
                                      label: 'Registration Opens',
                                      value: _formatDate(
                                        _registrationOpenDate,
                                      ),
                                      icon:
                                          Icons.event_available_outlined,
                                      enabled: _registrationEnabled,
                                      onTap: () async {
                                        final value = await _pickDate(
                                          _registrationOpenDate,
                                        );
                                        if (value == null) return;
                                        setState(
                                          () =>
                                              _registrationOpenDate = value,
                                        );
                                      },
                                    ),
                                    right: _PickerField(
                                      label: 'Registration Closes',
                                      value: _formatDate(
                                        _registrationCloseDate,
                                      ),
                                      icon:
                                          Icons.event_busy_outlined,
                                      enabled: _registrationEnabled,
                                      onTap: () async {
                                        final value = await _pickDate(
                                          _registrationCloseDate,
                                          firstDate:
                                              _registrationOpenDate,
                                        );
                                        if (value == null) return;
                                        setState(
                                          () =>
                                              _registrationCloseDate = value,
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            right: _WebSectionCard(
                              title: 'Organizer & Access',
                              subtitle:
                                  'Add contact information and operational settings.',
                              icon: Icons.admin_panel_settings_rounded,
                              child: Column(
                                children: [
                                  _WebTextField(
                                    label: 'Organizer Name',
                                    controller:
                                        _organizerNameController,
                                    hint: 'Organizer or department',
                                    icon: Icons.business_outlined,
                                  ),
                                  const SizedBox(height: 16),
                                  _WebTextField(
                                    label: 'Organizer Email',
                                    controller:
                                        _organizerEmailController,
                                    hint: 'name@example.com',
                                    icon: Icons.email_outlined,
                                    keyboardType:
                                        TextInputType.emailAddress,
                                    validator: _optionalEmailValidator,
                                  ),
                                  const SizedBox(height: 16),
                                  _WebTextField(
                                    label: 'Organizer Phone',
                                    controller:
                                        _organizerPhoneController,
                                    hint: 'Phone number',
                                    icon: Icons.phone_outlined,
                                    keyboardType: TextInputType.phone,
                                  ),
                                  const SizedBox(height: 16),
                                  _WebChoiceChips(
                                    label: 'Visibility',
                                    selected: _visibility,
                                    options: const ['Public', 'Private'],
                                    onSelected: (value) {
                                      setState(() => _visibility = value);
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  _WebSwitchTile(
                                    title: 'Allow Check-ins',
                                    subtitle:
                                        'Enable event and session attendance check-ins.',
                                    value: _allowCheckIns,
                                    onChanged: (value) {
                                      setState(
                                        () => _allowCheckIns = value,
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  _WebSwitchTile(
                                    title: 'Allow Uploads',
                                    subtitle:
                                        'Allow event photo and related uploads.',
                                    value: _allowUploads,
                                    onChanged: (value) {
                                      setState(
                                        () => _allowUploads = value,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          _WebSectionCard(
                            title: 'Event Partners',
                            subtitle:
                                'Add partner organizations and upload their logos.',
                            icon: Icons.handshake_outlined,
                            child: _PartnersEditor(
                              partners: _partners,
                              onAddPartner: _addPartner,
                              onRemovePartner: _removePartner,
                              onPickLogo: _pickPartnerLogo,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _NextStepsNotice(),
                          const SizedBox(height: 18),
                          _BottomActions(
                            isEditMode: widget.isEditMode,
                            isSaving: _isSaving,
                            onCancel: () => Navigator.of(context).pop(),
                            onSaveDraft: _saveDraft,
                            onSave: _saveAndContinue,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  FormFieldValidator<String> _requiredValidator(String message) {
    return (value) {
      if (value == null || value.trim().isEmpty) return message;
      return null;
    };
  }

  String? _optionalEmailValidator(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return null;

    final expression = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return expression.hasMatch(email)
        ? null
        : 'Enter a valid email address.';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select date';
    return DateFormat('MMM d, yyyy').format(date);
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return 'Select time';

    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final suffix = time.period == DayPeriod.am ? 'AM' : 'PM';

    return '$hour:$minute $suffix';
  }
}


class _PartnerDraft {
  final TextEditingController nameController;
  Uint8List? selectedLogoBytes;
  String existingLogoUrl;
  String existingStoragePath;

  _PartnerDraft({
    String name = '',
    this.selectedLogoBytes,
    this.existingLogoUrl = '',
    this.existingStoragePath = '',
  }) : nameController = TextEditingController(text: name);

  void dispose() {
    nameController.dispose();
  }
}

class _PartnersEditor extends StatelessWidget {
  final List<_PartnerDraft> partners;
  final VoidCallback onAddPartner;
  final ValueChanged<int> onRemovePartner;
  final ValueChanged<int> onPickLogo;

  const _PartnersEditor({
    required this.partners,
    required this.onAddPartner,
    required this.onRemovePartner,
    required this.onPickLogo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (partners.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 22,
              vertical: 30,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFBFD),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AdminWebTheme.border),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.handshake_outlined,
                  color: AdminWebTheme.primary,
                  size: 34,
                ),
                SizedBox(height: 10),
                Text(
                  'No partners added yet',
                  style: TextStyle(
                    color: AdminWebTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Add partner organizations and their logos. They will be saved with this event.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AdminWebTheme.textSecondary,
                    fontSize: 10.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          )
        else
          ...List.generate(
            partners.length,
            (index) => Padding(
              padding: EdgeInsets.only(
                bottom: index == partners.length - 1 ? 0 : 14,
              ),
              child: _PartnerEditorCard(
                index: index,
                partner: partners[index],
                onRemove: () => onRemovePartner(index),
                onPickLogo: () => onPickLogo(index),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: onAddPartner,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Partner'),
          ),
        ),
      ],
    );
  }
}

class _PartnerEditorCard extends StatelessWidget {
  final int index;
  final _PartnerDraft partner;
  final VoidCallback onRemove;
  final VoidCallback onPickLogo;

  const _PartnerEditorCard({
    required this.index,
    required this.partner,
    required this.onRemove,
    required this.onPickLogo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminWebTheme.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final editor = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Partner ${index + 1}',
                    style: const TextStyle(
                      color: AdminWebTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Remove partner',
                    onPressed: onRemove,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _WebTextField(
                label: 'Partner Name',
                controller: partner.nameController,
                hint: 'Enter organization or partner name',
                icon: Icons.business_outlined,
              ),
            ],
          );

          final logo = _PartnerLogoPicker(
            selectedBytes: partner.selectedLogoBytes,
            existingUrl: partner.existingLogoUrl,
            onPick: onPickLogo,
          );

          if (constraints.maxWidth < 720) {
            return Column(
              children: [
                editor,
                const SizedBox(height: 16),
                logo,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: editor),
              const SizedBox(width: 18),
              Expanded(flex: 2, child: logo),
            ],
          );
        },
      ),
    );
  }
}

class _PartnerLogoPicker extends StatelessWidget {
  final Uint8List? selectedBytes;
  final String existingUrl;
  final VoidCallback onPick;

  const _PartnerLogoPicker({
    required this.selectedBytes,
    required this.existingUrl,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    Widget preview;

    if (selectedBytes != null) {
      preview = Image.memory(
        selectedBytes!,
        fit: BoxFit.contain,
      );
    } else if (existingUrl.trim().isNotEmpty) {
      preview = Image.network(
        existingUrl,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            const _PartnerLogoPlaceholder(),
      );
    } else {
      preview = const _PartnerLogoPlaceholder();
    }

    return _FieldLabel(
      label: 'Partner Logo',
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 132,
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AdminWebTheme.border),
          ),
          child: Stack(
            children: [
              Positioned.fill(child: preview),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: AdminWebTheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    tooltip: 'Choose partner logo',
                    onPressed: onPick,
                    icon: const Icon(
                      Icons.upload_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
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

class _PartnerLogoPlaceholder extends StatelessWidget {
  const _PartnerLogoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.image_outlined,
          color: AdminWebTheme.primary,
          size: 30,
        ),
        SizedBox(height: 7),
        Text(
          'Upload logo',
          style: TextStyle(
            color: AdminWebTheme.textSecondary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

enum _NextEventAction {
  createSession,
  backToEvents,
}

class _PageHeader extends StatelessWidget {
  final bool isEditMode;
  final bool isSaving;
  final VoidCallback onBack;
  final VoidCallback onSaveDraft;
  final VoidCallback onSave;

  const _PageHeader({
    required this.isEditMode,
    required this.isSaving,
    required this.onBack,
    required this.onSaveDraft,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AdminWebTheme.border),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: isSaving ? null : onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditMode ? 'Edit Event' : 'Create Event',
                  style: const TextStyle(
                    color: AdminWebTheme.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isEditMode
                      ? 'Update the event information and settings.'
                      : 'Create the event first, then configure sessions and people.',
                  style: const TextStyle(
                    color: AdminWebTheme.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: isSaving ? null : onSaveDraft,
            child: const Text('Save Draft'),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: isSaving ? null : onSave,
            icon: isSaving
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Icon(
                    isEditMode
                        ? Icons.save_rounded
                        : Icons.arrow_forward_rounded,
                  ),
            label: Text(
              isEditMode ? 'Save Changes' : 'Create Event',
            ),
          ),
        ],
      ),
    );
  }
}

class _WebSectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  const _WebSectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminWebTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AdminWebTheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  color: AdminWebTheme.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AdminWebTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AdminWebTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          child,
        ],
      ),
    );
  }
}

class _ResponsiveTwoColumns extends StatelessWidget {
  final Widget left;
  final Widget right;

  const _ResponsiveTwoColumns({
    required this.left,
    required this.right,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(
            children: [
              left,
              const SizedBox(height: 16),
              right,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 18),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _WebTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldValidator<String>? validator;
  final bool enabled;

  const _WebTextField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return _FieldLabel(
      label: label,
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: maxLines == 1 ? Icon(icon, size: 19) : null,
          alignLabelWithHint: maxLines > 1,
        ),
      ),
    );
  }
}

class _WebDropdownField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final String hint;
  final IconData icon;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;

  const _WebDropdownField({
    required this.label,
    required this.value,
    required this.hint,
    required this.icon,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _FieldLabel(
      label: label,
      child: DropdownButtonFormField<T>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 19),
        ),
        hint: Text(hint),
        items: items
            .map(
              (item) => DropdownMenuItem<T>(
                value: item,
                child: Text(itemLabel(item)),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return _FieldLabel(
      label: label,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 51,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: enabled ? Colors.white : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AdminWebTheme.border),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: enabled
                    ? AdminWebTheme.primary
                    : AdminWebTheme.textSecondary,
                size: 19,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    color: value.startsWith('Select')
                        ? AdminWebTheme.textSecondary
                        : AdminWebTheme.textPrimary,
                    fontSize: 12,
                  ),
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AdminWebTheme.textSecondary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final Widget child;

  const _FieldLabel({
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AdminWebTheme.textPrimary,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        child,
      ],
    );
  }
}

class _CoverImagePicker extends StatelessWidget {
  final Uint8List? selectedBytes;
  final String existingUrl;
  final VoidCallback onPick;

  const _CoverImagePicker({
    required this.selectedBytes,
    required this.existingUrl,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    Widget preview;

    if (selectedBytes != null) {
      preview = Image.memory(
        selectedBytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else if (existingUrl.trim().isNotEmpty) {
      preview = Image.network(
        existingUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => const _CoverPlaceholder(),
      );
    } else {
      preview = const _CoverPlaceholder();
    }

    return _FieldLabel(
      label: 'Event Cover Image',
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 155,
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFD),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AdminWebTheme.border),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              preview,
              Positioned(
                right: 10,
                bottom: 10,
                child: ElevatedButton.icon(
                  onPressed: onPick,
                  icon: const Icon(Icons.upload_rounded, size: 17),
                  label: const Text('Choose Image'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.image_outlined,
          color: AdminWebTheme.primary,
          size: 34,
        ),
        SizedBox(height: 7),
        Text(
          'Recommended 16:9 cover image',
          style: TextStyle(
            color: AdminWebTheme.textSecondary,
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }
}

class _WebChoiceChips extends StatelessWidget {
  final String label;
  final String selected;
  final List<String> options;
  final ValueChanged<String> onSelected;

  const _WebChoiceChips({
    required this.label,
    required this.selected,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return _FieldLabel(
      label: label,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((option) {
          final isSelected = option == selected;

          return ChoiceChip(
            label: Text(option),
            selected: isSelected,
            onSelected: (_) => onSelected(option),
            selectedColor: AdminWebTheme.primary.withOpacity(0.12),
            side: BorderSide(
              color: isSelected
                  ? AdminWebTheme.primary
                  : AdminWebTheme.border,
            ),
            labelStyle: TextStyle(
              color: isSelected
                  ? AdminWebTheme.primary
                  : AdminWebTheme.textSecondary,
              fontWeight:
                  isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _WebSwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _WebSwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminWebTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AdminWebTheme.textPrimary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AdminWebTheme.textSecondary,
                    fontSize: 9.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _NextStepsNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6FF),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: AdminWebTheme.primary.withOpacity(0.18),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.route_rounded,
            color: AdminWebTheme.primary,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'After creating the event, create its first session or return to the Events page. Speakers and moderators are managed separately and remain restricted to the events assigned to them.',
              style: TextStyle(
                color: AdminWebTheme.textSecondary,
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  final bool isEditMode;
  final bool isSaving;
  final VoidCallback onCancel;
  final VoidCallback onSaveDraft;
  final VoidCallback onSave;

  const _BottomActions({
    required this.isEditMode,
    required this.isSaving,
    required this.onCancel,
    required this.onSaveDraft,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: isSaving ? null : onCancel,
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: isSaving ? null : onSaveDraft,
          child: const Text('Save Draft'),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: isSaving ? null : onSave,
          icon: const Icon(Icons.check_rounded),
          label: Text(
            isEditMode ? 'Save Changes' : 'Create Event',
          ),
        ),
      ],
    );
  }
}
