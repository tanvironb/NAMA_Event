// lib/features/web_admin/event_workspace/screens/admin_web_sessions_screen.dart

import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../admin_web_theme.dart';

class AdminWebSessionsScreen extends StatefulWidget {
  final String eventId;
  final String eventName;

  const AdminWebSessionsScreen({
    super.key,
    required this.eventId,
    required this.eventName,
  });

  @override
  State<AdminWebSessionsScreen> createState() =>
      _AdminWebSessionsScreenState();
}

class _AdminWebSessionsScreenState
    extends State<AdminWebSessionsScreen> {
  bool _showCreateForm = false;
  QueryDocumentSnapshot<Map<String, dynamic>>? _editingSession;
  String _searchQuery = '';
  String _categoryFilter = 'All';

  void _openCreateForm() {
    setState(() {
      _editingSession = null;
      _showCreateForm = true;
    });
  }

  void _openEditForm(
    QueryDocumentSnapshot<Map<String, dynamic>> session,
  ) {
    setState(() {
      _editingSession = session;
      _showCreateForm = true;
    });
  }

  Future<void> _openSessionManagement(
    QueryDocumentSnapshot<Map<String, dynamic>> session,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _WebSessionManagementDialog(
        eventId: widget.eventId,
        eventName: widget.eventName,
        sessionReference: session.reference,
        initialData: session.data(),
      ),
    );
  }

  void _closeCreateForm() {
    setState(() {
      _showCreateForm = false;
      _editingSession = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showCreateForm) {
      return _AdminWebCreateSessionForm(
        eventId: widget.eventId,
        eventName: widget.eventName,
        sessionDocument: _editingSession,
        onCancel: _closeCreateForm,
        onSaved: _closeCreateForm,
      );
    }

    return _SessionsListView(
      eventId: widget.eventId,
      eventName: widget.eventName,
      searchQuery: _searchQuery,
      categoryFilter: _categoryFilter,
      onSearchChanged: (value) {
        setState(() => _searchQuery = value);
      },
      onCategoryChanged: (value) {
        setState(() => _categoryFilter = value);
      },
      onCreateSession: _openCreateForm,
      onEditSession: _openEditForm,
      onManageSession: _openSessionManagement,
    );
  }
}

class _SessionsListView extends StatelessWidget {
  final String eventId;
  final String eventName;
  final String searchQuery;
  final String categoryFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onCategoryChanged;
  final VoidCallback onCreateSession;
  final ValueChanged<QueryDocumentSnapshot<Map<String, dynamic>>>
      onEditSession;
  final ValueChanged<QueryDocumentSnapshot<Map<String, dynamic>>>
      onManageSession;

  const _SessionsListView({
    required this.eventId,
    required this.eventName,
    required this.searchQuery,
    required this.categoryFilter,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onCreateSession,
    required this.onEditSession,
    required this.onManageSession,
  });

  static const List<String> _categories = [
    'All',
    'Keynote',
    'Panel Discussion',
    'Workshop',
    'Training',
    'Networking',
    'Forum',
    'Breakout Session',
    'Opening',
    'Break',
    'Closing',
    'Other',
  ];

  Stream<QuerySnapshot<Map<String, dynamic>>> _sessionsStream() {
    return FirebaseFirestore.instance
        .collection('sessions')
        .where('eventId', isEqualTo: eventId)
        .snapshots();
  }

  String _formatDateTime(dynamic value) {
    if (value is! Timestamp) return 'Not scheduled';

    final date = value.toDate();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hourValue = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '$day/$month/$year • $hourValue:$minute $period';
  }

  Future<void> _deleteSession(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final title = (document.data()['title'] ?? 'this session').toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Session?',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Text(
            '"$title" will be permanently removed. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await document.reference.delete();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$title was deleted.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete session: $error'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PageHeader(
            eyebrow: eventName,
            title: 'Sessions',
            subtitle:
                'Create and manage the programme for this event. Speaker and moderator assignments are handled from their own pages.',
            actionLabel: 'Create Session',
            actionIcon: Icons.add_rounded,
            onAction: onCreateSession,
          ),
          const SizedBox(height: 20),
          _FilterBar(
            searchHint: 'Search sessions by title, venue, or category',
            searchQuery: searchQuery,
            categoryValue: categoryFilter,
            categories: _categories,
            onSearchChanged: onSearchChanged,
            onCategoryChanged: onCategoryChanged,
          ),
          const SizedBox(height: 18),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _sessionsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _LoadingCard();
              }

              if (snapshot.hasError) {
                return _MessageCard(
                  icon: Icons.error_outline_rounded,
                  title: 'Could not load sessions',
                  message: snapshot.error.toString(),
                );
              }

              final documents = [...?snapshot.data?.docs];

              documents.sort((a, b) {
                final aValue = a.data()['startTime'];
                final bValue = b.data()['startTime'];

                if (aValue is Timestamp && bValue is Timestamp) {
                  return aValue.compareTo(bValue);
                }

                if (aValue is Timestamp) return -1;
                if (bValue is Timestamp) return 1;
                return 0;
              });

              final normalizedSearch = searchQuery.trim().toLowerCase();

              final filtered = documents.where((document) {
                final data = document.data();
                final title = (data['title'] ?? '').toString().toLowerCase();
                final location =
                    (data['location'] ?? '').toString().toLowerCase();
                final category =
                    (data['category'] ?? '').toString().toLowerCase();

                final matchesSearch = normalizedSearch.isEmpty ||
                    title.contains(normalizedSearch) ||
                    location.contains(normalizedSearch) ||
                    category.contains(normalizedSearch);

                final matchesCategory = categoryFilter == 'All' ||
                    (data['category'] ?? '').toString() == categoryFilter;

                return matchesSearch && matchesCategory;
              }).toList();

              if (filtered.isEmpty) {
                return _MessageCard(
                  icon: Icons.event_note_outlined,
                  title: documents.isEmpty
                      ? 'No sessions created yet'
                      : 'No matching sessions',
                  message: documents.isEmpty
                      ? 'Create the first session for $eventName.'
                      : 'Try changing the search text or category filter.',
                  buttonLabel:
                      documents.isEmpty ? 'Create Session' : null,
                  onPressed:
                      documents.isEmpty ? onCreateSession : null,
                );
              }

              return _SessionsTableCard(
                documents: filtered,
                formatDateTime: _formatDateTime,
                onEdit: onEditSession,
                onManage: onManageSession,
                onDelete: (document) {
                  _deleteSession(context, document);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AdminWebCreateSessionForm extends StatefulWidget {
  final String eventId;
  final String eventName;
  final QueryDocumentSnapshot<Map<String, dynamic>>? sessionDocument;
  final VoidCallback onCancel;
  final VoidCallback onSaved;

  const _AdminWebCreateSessionForm({
    required this.eventId,
    required this.eventName,
    required this.sessionDocument,
    required this.onCancel,
    required this.onSaved,
  });

  bool get isEditing => sessionDocument != null;

  @override
  State<_AdminWebCreateSessionForm> createState() =>
      _AdminWebCreateSessionFormState();
}

class _AdminWebCreateSessionFormState
    extends State<_AdminWebCreateSessionForm> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _liveStreamController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  String? _selectedCategory;
  int _priority = 3;
  bool _isChatEnabled = true;
  bool _isSaving = false;

  Uint8List? _sessionImageBytes;
  Uint8List? _venueImageBytes;
  String? _sessionImageName;
  String? _venueImageName;
  String _existingSessionImageUrl = '';
  String _existingVenueImageUrl = '';

  static const List<String> _categories = [
    'Keynote',
    'Panel Discussion',
    'Workshop',
    'Training',
    'Networking',
    'Forum',
    'Breakout Session',
    'Opening',
    'Break',
    'Closing',
    'Other',
  ];

  @override
  void initState() {
    super.initState();

    final document = widget.sessionDocument;
    if (document == null) return;

    final data = document.data();

    _titleController.text = (data['title'] ?? '').toString();
    _descriptionController.text = (data['description'] ?? '').toString();
    _locationController.text = (data['location'] ?? '').toString();
    _liveStreamController.text = (data['liveStreamUrl'] ?? '').toString();
    _selectedCategory = (data['category'] ?? '').toString().trim().isEmpty
        ? null
        : (data['category'] ?? '').toString();
    _priority = data['priority'] is int ? data['priority'] as int : 3;
    _isChatEnabled = data['isChatEnabled'] != false;
    _existingSessionImageUrl = (data['imageUrl'] ?? '').toString();
    _existingVenueImageUrl = (data['venueImageUrl'] ?? '').toString();

    final startValue = data['startTime'];
    final endValue = data['endTime'];

    if (startValue is Timestamp) {
      final start = startValue.toDate();
      _selectedDate = DateTime(start.year, start.month, start.day);
      _startTime = TimeOfDay(hour: start.hour, minute: start.minute);
    }

    if (endValue is Timestamp) {
      final end = endValue.toDate();
      _endTime = TimeOfDay(hour: end.hour, minute: end.minute);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _liveStreamController.dispose();
    super.dispose();
  }

  DateTime _combineDateAndTime(
    DateTime date,
    TimeOfDay time,
  ) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select date';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return 'Select time';

    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';

    return '$hour:$minute $period';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();

    final result = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );

    if (result != null) {
      setState(() => _selectedDate = result);
    }
  }

  Future<void> _pickStartTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
    );

    if (result != null) {
      setState(() => _startTime = result);
    }
  }

  Future<void> _pickEndTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: _endTime ?? _startTime ?? TimeOfDay.now(),
    );

    if (result != null) {
      setState(() => _endTime = result);
    }
  }

  Future<void> _pickSessionImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image == null) return;

    final bytes = await image.readAsBytes();

    if (!mounted) return;

    setState(() {
      _sessionImageBytes = bytes;
      _sessionImageName = image.name;
    });
  }

  Future<void> _pickVenueImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image == null) return;

    final bytes = await image.readAsBytes();

    if (!mounted) return;

    setState(() {
      _venueImageBytes = bytes;
      _venueImageName = image.name;
    });
  }

  Future<String> _uploadImage({
    required Uint8List bytes,
    required String path,
  }) async {
    final reference = FirebaseStorage.instance.ref().child(path);

    final task = await reference.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    return task.ref.getDownloadURL();
  }

  String _randomToken(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();

    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  String _generateSessionCode() {
    final random = Random.secure();
    return 'SES-${100000 + random.nextInt(900000)}';
  }

  void _showMessage(
    String message, {
    bool error = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? Colors.redAccent : null,
      ),
    );
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _titleController.clear();
    _descriptionController.clear();
    _locationController.clear();
    _liveStreamController.clear();

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

  Future<bool> _saveSession() async {
    FocusScope.of(context).unfocus();

    if (_isSaving) return false;
    if (!_formKey.currentState!.validate()) return false;

    if (_selectedDate == null) {
      _showMessage('Please select the session date.', error: true);
      return false;
    }

    if (_startTime == null) {
      _showMessage('Please select the start time.', error: true);
      return false;
    }

    if (_endTime == null) {
      _showMessage('Please select the end time.', error: true);
      return false;
    }

    final startDate = _combineDateAndTime(
      _selectedDate!,
      _startTime!,
    );

    final endDate = _combineDateAndTime(
      _selectedDate!,
      _endTime!,
    );

    if (!endDate.isAfter(startDate)) {
      _showMessage(
        'End time must be after the start time.',
        error: true,
      );
      return false;
    }

    setState(() => _isSaving = true);

    try {
      final sessionReference = widget.sessionDocument?.reference ??
          FirebaseFirestore.instance.collection('sessions').doc();

      String sessionImageUrl = _existingSessionImageUrl;
      String venueImageUrl = _existingVenueImageUrl;

      if (_sessionImageBytes != null) {
        sessionImageUrl = await _uploadImage(
          bytes: _sessionImageBytes!,
          path:
              'sessions/${sessionReference.id}/session_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      }

      if (_venueImageBytes != null) {
        venueImageUrl = await _uploadImage(
          bytes: _venueImageBytes!,
          path:
              'sessions/${sessionReference.id}/venue_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      }

      final existingData = widget.sessionDocument?.data() ??
          <String, dynamic>{};

      final payload = <String, dynamic>{
        'eventId': widget.eventId,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'startTime': Timestamp.fromDate(startDate),
        'endTime': Timestamp.fromDate(endDate),
        'location': _locationController.text.trim(),

        // Speaker and moderator assignment is handled from their pages.
        'speakerIds': widget.isEditing
            ? (existingData['speakerIds'] ?? <String>[])
            : <String>[],
        'moderatorIds': widget.isEditing
            ? (existingData['moderatorIds'] ?? <String>[])
            : <String>[],

        'liveStreamUrl': _liveStreamController.text.trim(),
        'qrCodePayload': widget.isEditing
            ? (existingData['qrCodePayload'] ??
                'session::${sessionReference.id}_${_randomToken(16)}')
            : 'session::${sessionReference.id}_${_randomToken(16)}',
        'checkInCode': widget.isEditing
            ? (existingData['checkInCode'] ?? _generateSessionCode())
            : _generateSessionCode(),
        'category': _selectedCategory ?? '',
        'imageUrl': sessionImageUrl,
        'venueImageUrl': venueImageUrl,
        'priority': _priority,
        'partnerId': '',
        'isChatEnabled': _isChatEnabled,
        'closedBy': widget.isEditing
            ? (existingData['closedBy'] ?? '')
            : '',
        'checkedInAttendees': widget.isEditing
            ? (existingData['checkedInAttendees'] ?? <String>[])
            : <String>[],
        'totalMessages': widget.isEditing
            ? (existingData['totalMessages'] ?? 0)
            : 0,
        'uniqueParticipants': widget.isEditing
            ? (existingData['uniqueParticipants'] ?? <String>[])
            : <String>[],
        'mutedUsers': widget.isEditing
            ? (existingData['mutedUsers'] ?? <String>[])
            : <String>[],
        'deletedMessagesCount': widget.isEditing
            ? (existingData['deletedMessagesCount'] ?? 0)
            : 0,
        'messagesByRole': widget.isEditing
            ? (existingData['messagesByRole'] ??
                <String, dynamic>{})
            : <String, dynamic>{},
        'muteHistory': widget.isEditing
            ? (existingData['muteHistory'] ?? <dynamic>[])
            : <dynamic>[],
        'totalMuteActions': widget.isEditing
            ? (existingData['totalMuteActions'] ?? 0)
            : 0,
        'totalFeedbacks': widget.isEditing
            ? (existingData['totalFeedbacks'] ?? 0)
            : 0,
        'totalRating': widget.isEditing
            ? (existingData['totalRating'] ?? 0)
            : 0,
        'averageRating': widget.isEditing
            ? (existingData['averageRating'] ?? 0.0)
            : 0.0,
        'createdAt': widget.isEditing
            ? (existingData['createdAt'] ?? FieldValue.serverTimestamp())
            : FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.isEditing) {
        await sessionReference.set(payload, SetOptions(merge: true));
      } else {
        await sessionReference.set(payload);
      }

      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .set({
        'status': 'active_sessions',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return true;
    } catch (error) {
      _showMessage(
        'Failed to create session: $error',
        error: true,
      );
      return false;
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _createAndReturn() async {
    final created = await _saveSession();

    if (!created || !mounted) return;

    _showMessage(
      widget.isEditing
          ? 'Session updated successfully.'
          : 'Session created successfully.',
    );
    widget.onSaved();
  }

  Future<void> _createAnother() async {
    final created = await _saveSession();

    if (!created || !mounted) return;

    _showMessage('Session created. Add another session below.');
    _clearForm();
  }

  @override
  Widget build(BuildContext context) {
    final descriptionLength = _descriptionController.text.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PageHeader(
              eyebrow: widget.eventName,
              title: widget.isEditing ? 'Edit Session' : 'Create Session',
              subtitle: widget.isEditing
                  ? 'Update the session programme, schedule, location, images, and chat setting.'
                  : 'Add the session programme, schedule, location, images, and chat setting. Speakers and moderators will be assigned from their own pages.',
              actionLabel: 'Back to Sessions',
              actionIcon: Icons.arrow_back_rounded,
              outlinedAction: true,
              onAction: _isSaving ? null : widget.onCancel,
            ),
            const SizedBox(height: 20),
            _FormSection(
              icon: Icons.event_note_outlined,
              title: 'Session Details',
              subtitle:
                  'Enter the information attendees will see in the programme.',
              child: Column(
                children: [
                  _ResponsiveFields(
                    children: [
                      _WebTextField(
                        label: 'Session Title',
                        hint: 'Enter session title',
                        controller: _titleController,
                        icon: Icons.title_rounded,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Session title is required';
                          }
                          return null;
                        },
                      ),
                      _WebDropdownField(
                        label: 'Category',
                        hint: 'Select category',
                        value: _selectedCategory,
                        items: _categories,
                        icon: Icons.sell_outlined,
                        onChanged: (value) {
                          setState(() => _selectedCategory = value);
                        },
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Category is required';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _WebTextField(
                    label: 'Short Description',
                    hint: 'Add an optional description',
                    controller: _descriptionController,
                    icon: Icons.notes_rounded,
                    maxLines: 4,
                    maxLength: 200,
                    helperText: '$descriptionLength/200 characters',
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  _PrioritySelector(
                    value: _priority,
                    onChanged: (value) {
                      setState(() => _priority = value);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 900) {
                  return Column(
                    children: [
                      _buildScheduleSection(),
                      const SizedBox(height: 18),
                      _buildLocationSection(),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildScheduleSection()),
                    const SizedBox(width: 18),
                    Expanded(child: _buildLocationSection()),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            _FormSection(
              icon: Icons.image_outlined,
              title: 'Session Media',
              subtitle:
                  'Upload optional images for the programme and venue.',
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 760) {
                    return Column(
                      children: [
                        _ImagePickerCard(
                          label: 'Session Picture',
                          subtitle:
                              'Shown in session details and featured areas.',
                          imageBytes: _sessionImageBytes,
                          fileName: _sessionImageName,
                          icon: Icons.photo_outlined,
                          onPick: _pickSessionImage,
                          onRemove: () {
                            setState(() {
                              _sessionImageBytes = null;
                              _sessionImageName = null;
                            });
                          },
                        ),
                        const SizedBox(height: 14),
                        _ImagePickerCard(
                          label: 'Venue / Location Picture',
                          subtitle:
                              'Shown in the venue section for attendees.',
                          imageBytes: _venueImageBytes,
                          fileName: _venueImageName,
                          icon: Icons.location_city_outlined,
                          onPick: _pickVenueImage,
                          onRemove: () {
                            setState(() {
                              _venueImageBytes = null;
                              _venueImageName = null;
                            });
                          },
                        ),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _ImagePickerCard(
                          label: 'Session Picture',
                          subtitle:
                              'Shown in session details and featured areas.',
                          imageBytes: _sessionImageBytes,
                          fileName: _sessionImageName,
                          icon: Icons.photo_outlined,
                          onPick: _pickSessionImage,
                          onRemove: () {
                            setState(() {
                              _sessionImageBytes = null;
                              _sessionImageName = null;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _ImagePickerCard(
                          label: 'Venue / Location Picture',
                          subtitle:
                              'Shown in the venue section for attendees.',
                          imageBytes: _venueImageBytes,
                          fileName: _venueImageName,
                          icon: Icons.location_city_outlined,
                          onPick: _pickVenueImage,
                          onRemove: () {
                            setState(() {
                              _venueImageBytes = null;
                              _venueImageName = null;
                            });
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            _FormSection(
              icon: Icons.tune_rounded,
              title: 'Session Settings',
              subtitle:
                  'Configure attendee interaction for this session.',
              child: _SettingSwitchTile(
                title: 'Enable Session Chat',
                subtitle:
                    'Allow attendees to participate in the session chat.',
                value: _isChatEnabled,
                onChanged: (value) {
                  setState(() => _isChatEnabled = value);
                },
              ),
            ),
            const SizedBox(height: 22),
            _FormActions(
              isSaving: _isSaving,
              onCancel: widget.onCancel,
              onCreateAnother:
                  widget.isEditing ? null : _createAnother,
              onCreate: _createAndReturn,
              isEditing: widget.isEditing,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleSection() {
    return _FormSection(
      icon: Icons.schedule_rounded,
      title: 'Schedule',
      subtitle: 'Set the date and duration of the session.',
      child: Column(
        children: [
          _PickerButton(
            label: 'Session Date',
            value: _formatDate(_selectedDate),
            icon: Icons.calendar_today_outlined,
            onTap: _pickDate,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _PickerButton(
                  label: 'Start Time',
                  value: _formatTime(_startTime),
                  icon: Icons.access_time_rounded,
                  onTap: _pickStartTime,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PickerButton(
                  label: 'End Time',
                  value: _formatTime(_endTime),
                  icon: Icons.access_time_filled_rounded,
                  onTap: _pickEndTime,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    return _FormSection(
      icon: Icons.location_on_outlined,
      title: 'Location & Streaming',
      subtitle: 'Add the physical venue and optional online stream.',
      child: Column(
        children: [
          _WebTextField(
            label: 'Venue / Location',
            hint: 'Example: Main Hall, Level 2',
            controller: _locationController,
            icon: Icons.room_outlined,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Venue or location is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          _WebTextField(
            label: 'Live Stream URL',
            hint: 'Optional YouTube, Zoom, or streaming URL',
            controller: _liveStreamController,
            icon: Icons.live_tv_outlined,
            keyboardType: TextInputType.url,
          ),
        ],
      ),
    );
  }
}


class _WebSessionManagementDialog extends StatefulWidget {
  final String eventId;
  final String eventName;
  final DocumentReference<Map<String, dynamic>> sessionReference;
  final Map<String, dynamic> initialData;

  const _WebSessionManagementDialog({
    required this.eventId,
    required this.eventName,
    required this.sessionReference,
    required this.initialData,
  });

  @override
  State<_WebSessionManagementDialog> createState() =>
      _WebSessionManagementDialogState();
}

class _WebSessionManagementDialogState
    extends State<_WebSessionManagementDialog> {
  final TextEditingController _notificationTitleController =
      TextEditingController();
  final TextEditingController _notificationMessageController =
      TextEditingController();

  late Map<String, dynamic> _sessionData;

  String _targetRole = 'all';
  bool _isPreparing = true;
  bool _isSending = false;
  bool _isRegenerating = false;

  @override
  void initState() {
    super.initState();
    _sessionData = Map<String, dynamic>.from(widget.initialData);
    _notificationTitleController.text =
        'Session Check-in: ${_sessionTitle}';
    _prepareCodes();
  }

  @override
  void dispose() {
    _notificationTitleController.dispose();
    _notificationMessageController.dispose();
    super.dispose();
  }

  String get _sessionTitle =>
      (_sessionData['title'] ?? 'Session').toString();

  String get _checkInCode =>
      (_sessionData['checkInCode'] ?? '').toString().trim();

  String get _qrPayload =>
      (_sessionData['qrCodePayload'] ?? '').toString().trim();

  String _randomToken(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();

    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  String _generateSessionCode() {
    final random = Random.secure();
    return 'SES-${100000 + random.nextInt(900000)}';
  }

  Future<void> _prepareCodes() async {
    try {
      final snapshot = await widget.sessionReference.get();
      final data = snapshot.data() ?? _sessionData;

      var checkInCode =
          (data['checkInCode'] ?? '').toString().trim();
      var qrPayload =
          (data['qrCodePayload'] ?? '').toString().trim();

      final updates = <String, dynamic>{};

      if (checkInCode.isEmpty) {
        checkInCode = _generateSessionCode();
        updates['checkInCode'] = checkInCode;
      }

      if (qrPayload.isEmpty ||
          (!qrPayload.startsWith('session::') &&
              !qrPayload.startsWith('session-'))) {
        qrPayload =
            'session::${widget.sessionReference.id}_${_randomToken(16)}';
        updates['qrCodePayload'] = qrPayload;
      }

      if (updates.isNotEmpty) {
        updates['updatedAt'] = FieldValue.serverTimestamp();
        await widget.sessionReference.update(updates);
      }

      if (!mounted) return;

      setState(() {
        _sessionData = {
          ...data,
          'checkInCode': checkInCode,
          'qrCodePayload': qrPayload,
        };
        _notificationMessageController.text =
            'Use session code $checkInCode to join "$_sessionTitle". '
            'Open the session in the NAMA Events app and enter this code.';
        _isPreparing = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() => _isPreparing = false);
      _showMessage(
        'Could not prepare the session QR and code: $error',
        error: true,
      );
    }
  }

  Future<void> _copyValue(String value, String label) async {
    if (value.trim().isEmpty) return;

    await Clipboard.setData(ClipboardData(text: value));

    if (!mounted) return;
    _showMessage('$label copied.');
  }

  Future<void> _regenerateCodes() async {
    if (_isRegenerating || _isSending) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Regenerate Session Access?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'The current QR code and session code will stop working. '
          'Users must use the newly generated code.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isRegenerating = true);

    try {
      final checkInCode = _generateSessionCode();
      final qrPayload =
          'session::${widget.sessionReference.id}_${_randomToken(16)}';

      await widget.sessionReference.update({
        'checkInCode': checkInCode,
        'qrCodePayload': qrPayload,
        'lastQRRegenerationAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        _sessionData = {
          ..._sessionData,
          'checkInCode': checkInCode,
          'qrCodePayload': qrPayload,
        };
        _notificationMessageController.text =
            'Use session code $checkInCode to join "$_sessionTitle". '
            'Open the session in the NAMA Events app and enter this code.';
      });

      _showMessage('Session QR and code regenerated.');
    } catch (error) {
      _showMessage(
        'Failed to regenerate session access: $error',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isRegenerating = false);
      }
    }
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _loadTargetUsers() async {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('users')
        .where('status', isEqualTo: 'approved');

    if (_targetRole != 'all') {
      query = query.where('role', isEqualTo: _targetRole);
    }

    final snapshot = await query.get();

    return snapshot.docs.where((document) {
      final data = document.data();
      final eventIds = data['eventIds'];

      if (eventIds is List && eventIds.contains(widget.eventId)) {
        return true;
      }

      final directEventId =
          (data['eventId'] ?? data['activeEventId'] ?? '')
              .toString();

      return directEventId == widget.eventId;
    }).toList();
  }

  Future<void> _sendAccessNotification() async {
    if (_isSending || _isPreparing) return;

    final title = _notificationTitleController.text.trim();
    final message = _notificationMessageController.text.trim();

    if (title.isEmpty || message.isEmpty) {
      _showMessage(
        'Notification title and message are required.',
        error: true,
      );
      return;
    }

    if (_checkInCode.isEmpty || _qrPayload.isEmpty) {
      _showMessage(
        'The session QR and code are not ready.',
        error: true,
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final targetUsers = await _loadTargetUsers();

      if (targetUsers.isEmpty) {
        _showMessage(
          'No approved users matched this event and target group.',
          error: true,
        );
        return;
      }

      final adminNotificationReference =
          FirebaseFirestore.instance.collection('adminNotifications').doc();

      final notificationData = <String, dynamic>{
        'title': title,
        'subtitle': widget.eventName,
        'body': message,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'announcement',
        'targetRole': _targetRole,
        'eventId': widget.eventId,
        'eventName': widget.eventName,
        'sessionId': widget.sessionReference.id,
        'sessionTitle': _sessionTitle,
        'checkInCode': _checkInCode,
        'qrCodePayload': _qrPayload,
        'recipientCount': targetUsers.length,
        'data': {
          'notificationId': adminNotificationReference.id,
          'type': 'session_access',
          'eventId': widget.eventId,
          'eventName': widget.eventName,
          'sessionId': widget.sessionReference.id,
          'sessionTitle': _sessionTitle,
          'checkInCode': _checkInCode,
          'qrCodePayload': _qrPayload,
        },
      };

      await adminNotificationReference.set(notificationData);

      const batchLimit = 400;

      for (var start = 0;
          start < targetUsers.length;
          start += batchLimit) {
        final end = min(start + batchLimit, targetUsers.length);
        final batch = FirebaseFirestore.instance.batch();

        for (final user in targetUsers.sublist(start, end)) {
          final userNotificationReference = user.reference
              .collection('notifications')
              .doc();

          batch.set(userNotificationReference, {
            ...notificationData,
            'isRead': false,
            'timeFrom': null,
            'timeTo': null,
            'data': {
              ...Map<String, dynamic>.from(
                notificationData['data'] as Map,
              ),
              'notificationId': adminNotificationReference.id,
            },
          });
        }

        await batch.commit();
      }

      await widget.sessionReference.update({
        'lastAccessNotificationAt': FieldValue.serverTimestamp(),
        'lastAccessNotificationTarget': _targetRole,
        'lastAccessNotificationRecipientCount': targetUsers.length,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      _showMessage(
        'Session access sent to ${targetUsers.length} user'
        '${targetUsers.length == 1 ? '' : 's'}.',
      );
    } catch (error) {
      _showMessage(
        'Failed to send session access: $error',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _showMessage(
    String message, {
    bool error = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? Colors.redAccent : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final startTime = _sessionData['startTime'];
    final location =
        (_sessionData['location'] ?? 'Location not set').toString();

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 1080,
          maxHeight: 760,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 18, 16, 18),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AdminWebTheme.border),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AdminWebTheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.qr_code_2_rounded,
                      color: AdminWebTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _sessionTitle,
                          style: const TextStyle(
                            color: AdminWebTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          startTime is Timestamp
                              ? '${_formatTimestamp(startTime)} • $location'
                              : location,
                          style: const TextStyle(
                            color: AdminWebTheme.textSecondary,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed:
                        _isSending ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isPreparing
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AdminWebTheme.primary,
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final qrPanel = _buildQrPanel();
                          final notificationPanel =
                              _buildNotificationPanel();

                          if (constraints.maxWidth < 820) {
                            return Column(
                              children: [
                                qrPanel,
                                const SizedBox(height: 18),
                                notificationPanel,
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 5,
                                child: qrPanel,
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                flex: 7,
                                child: notificationPanel,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFD),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AdminWebTheme.border),
      ),
      child: Column(
        children: [
          const Text(
            'Session QR Code',
            style: TextStyle(
              color: AdminWebTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: 230,
            height: 230,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AdminWebTheme.border),
            ),
            child: QrImageView(
              data: _qrPayload,
              version: QrVersions.auto,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: AdminWebTheme.primary,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: AdminWebTheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'SESSION CODE',
            style: TextStyle(
              color: AdminWebTheme.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            _checkInCode,
            style: const TextStyle(
              color: AdminWebTheme.primary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () =>
                    _copyValue(_checkInCode, 'Session code'),
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy Code'),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    _copyValue(_qrPayload, 'QR payload'),
                icon: const Icon(Icons.data_object_rounded, size: 16),
                label: const Text('Copy QR Data'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed:
                _isRegenerating ? null : _regenerateCodes,
            icon: _isRegenerating
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.refresh_rounded, size: 17),
            label: Text(
              _isRegenerating
                  ? 'Regenerating...'
                  : 'Regenerate QR & Code',
            ),
            style: TextButton.styleFrom(
              foregroundColor: Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AdminWebTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Share Through Notifications',
            style: TextStyle(
              color: AdminWebTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'The selected approved users assigned to this event receive '
            'an in-app notification and push notification.',
            style: TextStyle(
              color: AdminWebTheme.textSecondary,
              fontSize: 10.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            value: _targetRole,
            decoration: const InputDecoration(
              labelText: 'Target users',
              prefixIcon: Icon(Icons.groups_2_outlined),
            ),
            items: const [
              DropdownMenuItem(
                value: 'all',
                child: Text('All event users'),
              ),
              DropdownMenuItem(
                value: 'attendee',
                child: Text('Attendees only'),
              ),
              DropdownMenuItem(
                value: 'speaker',
                child: Text('Speakers only'),
              ),
              DropdownMenuItem(
                value: 'moderator',
                child: Text('Moderators only'),
              ),
              DropdownMenuItem(
                value: 'staff',
                child: Text('Staff only'),
              ),
            ],
            onChanged: _isSending
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() => _targetRole = value);
                  },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _notificationTitleController,
            enabled: !_isSending,
            decoration: const InputDecoration(
              labelText: 'Notification title',
              prefixIcon: Icon(Icons.title_rounded),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _notificationMessageController,
            enabled: !_isSending,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Notification message',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AdminWebTheme.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AdminWebTheme.primary.withOpacity(0.13),
              ),
            ),
            child: Text(
              'The QR payload and session code are attached as notification '
              'data. The visible message includes code $_checkInCode.',
              style: const TextStyle(
                color: AdminWebTheme.textSecondary,
                fontSize: 9.5,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton.icon(
              onPressed:
                  _isSending ? null : _sendAccessNotification,
              icon: _isSending
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(
                _isSending
                    ? 'Sending Notifications...'
                    : 'Send Session Access',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AdminWebTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '${date.day}/${date.month}/${date.year} • '
        '$hour:$minute $period';
  }
}


class _PageHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback? onAction;
  final bool outlinedAction;

  const _PageHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
    this.outlinedAction = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow.toUpperCase(),
              style: const TextStyle(
                color: AdminWebTheme.primary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              title,
              style: const TextStyle(
                color: AdminWebTheme.textPrimary,
                fontSize: 27,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Text(
                subtitle,
                style: const TextStyle(
                  color: AdminWebTheme.textSecondary,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          ],
        );

        final button = SizedBox(
          height: 43,
          child: outlinedAction
              ? OutlinedButton.icon(
                  onPressed: onAction,
                  icon: Icon(actionIcon, size: 18),
                  label: Text(actionLabel),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AdminWebTheme.primary,
                    side: const BorderSide(
                      color: AdminWebTheme.border,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                )
              : FilledButton.icon(
                  onPressed: onAction,
                  icon: Icon(actionIcon, size: 18),
                  label: Text(actionLabel),
                  style: FilledButton.styleFrom(
                    backgroundColor: AdminWebTheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
        );

        if (constraints.maxWidth < 720) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              const SizedBox(height: 16),
              button,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: heading),
            const SizedBox(width: 20),
            button,
          ],
        );
      },
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String searchHint;
  final String searchQuery;
  final String categoryValue;
  final List<String> categories;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onCategoryChanged;

  const _FilterBar({
    required this.searchHint,
    required this.searchQuery,
    required this.categoryValue,
    required this.categories,
    required this.onSearchChanged,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AdminWebTheme.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final search = TextFormField(
            initialValue: searchQuery,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: searchHint,
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 19,
              ),
              filled: true,
              fillColor: const Color(0xFFFAFBFD),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AdminWebTheme.border,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AdminWebTheme.border,
                ),
              ),
            ),
          );

          final category = DropdownButtonFormField<String>(
            value: categoryValue,
            isExpanded: true,
            items: categories
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(value),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) onCategoryChanged(value);
            },
            decoration: InputDecoration(
              labelText: 'Category',
              filled: true,
              fillColor: const Color(0xFFFAFBFD),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AdminWebTheme.border,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AdminWebTheme.border,
                ),
              ),
            ),
          );

          if (constraints.maxWidth < 700) {
            return Column(
              children: [
                search,
                const SizedBox(height: 12),
                category,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 12),
              SizedBox(width: 230, child: category),
            ],
          );
        },
      ),
    );
  }
}

class _SessionsTableCard extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> documents;
  final String Function(dynamic value) formatDateTime;
  final ValueChanged<QueryDocumentSnapshot<Map<String, dynamic>>> onEdit;
  final ValueChanged<QueryDocumentSnapshot<Map<String, dynamic>>> onManage;
  final ValueChanged<QueryDocumentSnapshot<Map<String, dynamic>>> onDelete;

  const _SessionsTableCard({
    required this.documents,
    required this.formatDateTime,
    required this.onEdit,
    required this.onManage,
    required this.onDelete,
  });

  int _listLength(dynamic value) {
    return value is List ? value.length : 0;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AdminWebTheme.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 850) {
            return Column(
              children: documents.map((document) {
                final data = document.data();

                return _MobileSessionCard(
                  title: (data['title'] ?? 'Untitled Session').toString(),
                  category: (data['category'] ?? 'Uncategorized').toString(),
                  schedule: formatDateTime(data['startTime']),
                  location: (data['location'] ?? 'No location').toString(),
                  speakerCount: _listLength(data['speakerIds']),
                  moderatorCount: _listLength(data['moderatorIds']),
                  chatEnabled: data['isChatEnabled'] == true,
                  onManage: () => onManage(document),
                  onEdit: () => onEdit(document),
                  onDelete: () => onDelete(document),
                );
              }).toList(),
            );
          }

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: constraints.maxWidth,
              ),
              child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                const Color(0xFFFAFBFD),
              ),
              headingRowHeight: 46,
              dataRowMinHeight: 54,
              dataRowMaxHeight: 62,
              columnSpacing: 28,
              horizontalMargin: 18,
              headingTextStyle: const TextStyle(
                color: AdminWebTheme.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
              dataTextStyle: const TextStyle(
                color: AdminWebTheme.textPrimary,
                fontSize: 10.5,
              ),
              columns: const [
                DataColumn(label: Text('SESSION')),
                DataColumn(label: Text('SCHEDULE')),
                DataColumn(label: Text('LOCATION')),
                DataColumn(label: Text('CATEGORY')),
                DataColumn(label: Text('SPEAKERS')),
                DataColumn(label: Text('MODERATORS')),
                DataColumn(label: Text('CHAT')),
                DataColumn(label: Text('ACTIONS')),
              ],
              rows: documents.map((document) {
                final data = document.data();
                final title =
                    (data['title'] ?? 'Untitled Session').toString();
                final category =
                    (data['category'] ?? 'Uncategorized').toString();
                final location =
                    (data['location'] ?? 'No location').toString();

                return DataRow(
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 180,
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AdminWebTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    DataCell(Text(formatDateTime(data['startTime']))),
                    DataCell(
                      SizedBox(
                        width: 155,
                        child: Text(
                          location,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(_CategoryBadge(label: category)),
                    DataCell(Text(_listLength(data['speakerIds']).toString())),
                    DataCell(
                      Text(_listLength(data['moderatorIds']).toString()),
                    ),
                    DataCell(
                      _StatusBadge(
                        active: data['isChatEnabled'] == true,
                        activeText: 'Enabled',
                        inactiveText: 'Disabled',
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FilledButton.icon(
                            onPressed: () => onManage(document),
                            icon: const Icon(
                              Icons.qr_code_2_rounded,
                              size: 16,
                            ),
                            label: const Text('Open'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AdminWebTheme.primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              minimumSize: Size.zero,
                            ),
                          ),
                          const SizedBox(width: 6),
                          OutlinedButton.icon(
                            onPressed: () => onEdit(document),
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 16,
                            ),
                            label: const Text('Edit'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AdminWebTheme.primary,
                              side: const BorderSide(
                                color: AdminWebTheme.border,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              minimumSize: Size.zero,
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            tooltip: 'Delete session',
                            onPressed: () => onDelete(document),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.redAccent,
                              size: 19,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MobileSessionCard extends StatelessWidget {
  final String title;
  final String category;
  final String schedule;
  final String location;
  final int speakerCount;
  final int moderatorCount;
  final bool chatEnabled;
  final VoidCallback onManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MobileSessionCard({
    required this.title,
    required this.category,
    required this.schedule,
    required this.location,
    required this.speakerCount,
    required this.moderatorCount,
    required this.chatEnabled,
    required this.onManage,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AdminWebTheme.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AdminWebTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton.filled(
                tooltip: 'Open session management',
                onPressed: onManage,
                icon: const Icon(
                  Icons.qr_code_2_rounded,
                  color: Colors.white,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: AdminWebTheme.primary,
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Edit session',
                onPressed: onEdit,
                icon: const Icon(
                  Icons.edit_outlined,
                  color: AdminWebTheme.primary,
                ),
              ),
              IconButton(
                tooltip: 'Delete session',
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _CategoryBadge(label: category),
          const SizedBox(height: 12),
          _InfoLine(
            icon: Icons.schedule_rounded,
            text: schedule,
          ),
          const SizedBox(height: 7),
          _InfoLine(
            icon: Icons.location_on_outlined,
            text: location,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              Text('Speakers: $speakerCount'),
              Text('Moderators: $moderatorCount'),
              _StatusBadge(
                active: chatEnabled,
                activeText: 'Chat enabled',
                inactiveText: 'Chat disabled',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoLine({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: AdminWebTheme.textSecondary,
          size: 17,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AdminWebTheme.textSecondary,
              fontSize: 11.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _FormSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _FormSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AdminWebTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                  color: AdminWebTheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: AdminWebTheme.primary,
                  size: 20,
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
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AdminWebTheme.textSecondary,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _ResponsiveFields extends StatelessWidget {
  final List<Widget> children;

  const _ResponsiveFields({
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  const SizedBox(height: 14),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < children.length; i++) ...[
              Expanded(child: children[i]),
              if (i < children.length - 1)
                const SizedBox(width: 14),
            ],
          ],
        );
      },
    );
  }
}

class _WebTextField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData icon;
  final String? Function(String?)? validator;
  final int maxLines;
  final int? maxLength;
  final String? helperText;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;

  const _WebTextField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.icon,
    this.validator,
    this.maxLines = 1,
    this.maxLength,
    this.helperText,
    this.onChanged,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          maxLength: maxLength,
          onChanged: onChanged,
          keyboardType: keyboardType,
          decoration: _inputDecoration(
            hint: hint,
            icon: icon,
            helperText: helperText,
          ).copyWith(counterText: ''),
        ),
      ],
    );
  }
}

class _WebDropdownField extends StatelessWidget {
  final String label;
  final String hint;
  final String? value;
  final List<String> items;
  final IconData icon;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;

  const _WebDropdownField({
    required this.label,
    required this.hint,
    required this.value,
    required this.items,
    required this.icon,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 7),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          validator: validator,
          onChanged: onChanged,
          items: items
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(item),
                ),
              )
              .toList(),
          decoration: _inputDecoration(
            hint: hint,
            icon: icon,
          ),
        ),
      ],
    );
  }
}

InputDecoration _inputDecoration({
  required String hint,
  required IconData icon,
  String? helperText,
}) {
  return InputDecoration(
    hintText: hint,
    helperText: helperText,
    prefixIcon: Icon(
      icon,
      color: AdminWebTheme.primary,
      size: 19,
    ),
    filled: true,
    fillColor: const Color(0xFFFAFBFD),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 14,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(
        color: AdminWebTheme.border,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(
        color: AdminWebTheme.primary,
        width: 1.2,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Colors.redAccent),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Colors.redAccent),
    ),
  );
}

class _PickerButton extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _PickerButton({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 7),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFBFD),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AdminWebTheme.border),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: AdminWebTheme.primary,
                  size: 19,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: AdminWebTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AdminWebTheme.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PrioritySelector extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _PrioritySelector({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('Priority'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: List.generate(5, (index) {
            final priority = index + 1;
            final selected = value == priority;

            return InkWell(
              onTap: () => onChanged(priority),
              borderRadius: BorderRadius.circular(9),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 44,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? AdminWebTheme.primary
                      : const Color(0xFFFAFBFD),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: selected
                        ? AdminWebTheme.primary
                        : AdminWebTheme.border,
                  ),
                ),
                child: Text(
                  '$priority',
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : AdminWebTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _ImagePickerCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final Uint8List? imageBytes;
  final String? fileName;
  final IconData icon;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _ImagePickerCard({
    required this.label,
    required this.subtitle,
    required this.imageBytes,
    required this.fileName,
    required this.icon,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFD),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AdminWebTheme.border),
      ),
      child: imageBytes == null
          ? InkWell(
              onTap: onPick,
              borderRadius: BorderRadius.circular(9),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: AdminWebTheme.primary,
                    size: 30,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AdminWebTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AdminWebTheme.textSecondary,
                      fontSize: 10,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: onPick,
                    icon: const Icon(Icons.upload_rounded, size: 17),
                    label: const Text('Choose Image'),
                  ),
                ],
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.memory(
                    imageBytes!,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton.filled(
                    tooltip: 'Remove image',
                    onPressed: onRemove,
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      fileName ?? 'Selected image',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SettingSwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingSwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 8, 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminWebTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: value
                  ? Colors.green.withOpacity(0.10)
                  : AdminWebTheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              color: value ? Colors.green : AdminWebTheme.primary,
              size: 19,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AdminWebTheme.textPrimary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AdminWebTheme.textSecondary,
                    fontSize: 9.5,
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

class _FormActions extends StatelessWidget {
  final bool isSaving;
  final VoidCallback onCancel;
  final VoidCallback? onCreateAnother;
  final VoidCallback onCreate;
  final bool isEditing;

  const _FormActions({
    required this.isSaving,
    required this.onCancel,
    required this.onCreateAnother,
    required this.onCreate,
    required this.isEditing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AdminWebTheme.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cancel = OutlinedButton(
            onPressed: isSaving ? null : onCancel,
            child: const Text('Cancel'),
          );

          final createAnother = OutlinedButton.icon(
            onPressed: isSaving ? null : onCreateAnother,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Create & Add Another'),
          );

          final create = FilledButton.icon(
            onPressed: isSaving ? null : onCreate,
            icon: isSaving
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_rounded, size: 18),
            label: Text(
              isSaving
                  ? (isEditing ? 'Saving...' : 'Creating...')
                  : (isEditing ? 'Save Changes' : 'Create Session'),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AdminWebTheme.primary,
            ),
          );

          if (constraints.maxWidth < 650) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                cancel,
                const SizedBox(height: 10),
                if (!isEditing) ...[
                  createAnother,
                  const SizedBox(height: 10),
                ],
                create,
              ],
            );
          }

          return Row(
            children: [
              cancel,
              const Spacer(),
              if (!isEditing) ...[
                createAnother,
                const SizedBox(width: 10),
              ],
              create,
            ],
          );
        },
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AdminWebTheme.textPrimary,
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String label;

  const _CategoryBadge({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: AdminWebTheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AdminWebTheme.primary,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool active;
  final String activeText;
  final String inactiveText;

  const _StatusBadge({
    required this.active,
    required this.activeText,
    required this.inactiveText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: active
            ? Colors.green.withOpacity(0.10)
            : Colors.grey.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active ? activeText : inactiveText,
        style: TextStyle(
          color: active ? Colors.green.shade700 : Colors.grey.shade700,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 230,
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? buttonLabel;
  final VoidCallback? onPressed;

  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
    this.buttonLabel,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 52,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AdminWebTheme.border),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: AdminWebTheme.primary,
            size: 38,
          ),
          const SizedBox(height: 13),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AdminWebTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AdminWebTheme.textSecondary,
              fontSize: 11,
            ),
          ),
          if (buttonLabel != null && onPressed != null) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.add_rounded),
              label: Text(buttonLabel!),
              style: FilledButton.styleFrom(
                backgroundColor: AdminWebTheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
