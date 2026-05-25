// lib/features/admin/screen/admin_session_management_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/features/admin/screen/admin_dashboard_screen.dart';
import 'package:events_app_trueattempt/features/admin/screen/admin_session_detail_screen.dart';
import 'package:events_app_trueattempt/features/directories/screen/directories_hub_screen.dart';
import 'package:events_app_trueattempt/features/profile/screen/profile_tab_screen.dart';
import 'package:events_app_trueattempt/features/qr_scanner/screen/qr_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class AdminSessionManagementScreen extends ConsumerStatefulWidget {
  final String? eventId;
  final String? eventName;
  final bool showBottomNav;

  const AdminSessionManagementScreen({
    super.key,
    this.eventId,
    this.eventName,
    this.showBottomNav = true,
  });

  bool get isEventSpecific => eventId != null && eventId!.isNotEmpty;

  @override
  ConsumerState<AdminSessionManagementScreen> createState() =>
      _AdminSessionManagementScreenState();
}

class _AdminSessionManagementScreenState
    extends ConsumerState<AdminSessionManagementScreen> {
  int _selectedBottomIndex = 1;

  static const Color _primaryColor = Color(0xFF1B0F72);
  static const Color _softPurple = Color(0xFFF4F2FB);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textMuted = Color(0xFF6B7280);
  static const Color _fieldBorder = Color(0xFFE1DDF0);

  static const List<String> _categories = [
    'Keynote',
    'Panel Discussion',
    'Workshop',
    'Training',
    'Networking',
    'Forum',
    'Breakout Session',
    'Other',
  ];

  Stream<List<Session>> _eventSessionsStream() {
    if (!widget.isEventSpecific) {
      final activeSessionsAsync = ref.watch(sessionsStreamProvider);

      return activeSessionsAsync.when(
        data: (sessions) => Stream.value(sessions),
        loading: () => Stream.value([]),
        error: (_, __) => Stream.value([]),
      );
    }

    return FirebaseFirestore.instance
        .collection('sessions')
        .where('eventId', isEqualTo: widget.eventId)
        .snapshots()
        .map((snapshot) {
      final sessions = snapshot.docs
          .map((doc) => Session.fromFirestore(doc))
          .toList();

      sessions.sort((a, b) => a.startTime.compareTo(b.startTime));

      return sessions;
    });
  }

  void _onBottomNavTapped(int index) {
    setState(() => _selectedBottomIndex = index);

    if (index == 1) return;

    Widget screen;

    switch (index) {
      case 0:
        screen = const AdminDashboardScreen();
        break;
      case 2:
        screen = const DirectoriesHubScreen();
        break;
      case 3:
        screen = const QRHubScreen();
        break;
      case 4:
        screen = const ProfileTabScreen();
        break;
      default:
        return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  Map<DateTime, List<Session>> _groupSessionsByDate(List<Session> sessions) {
    final groupedSessions = <DateTime, List<Session>>{};

    for (final session in sessions) {
      final dateKey = DateTime(
        session.startTime.year,
        session.startTime.month,
        session.startTime.day,
      );

      groupedSessions.putIfAbsent(dateKey, () => []);
      groupedSessions[dateKey]!.add(session);
    }

    for (final date in groupedSessions.keys) {
      groupedSessions[date]!.sort(
        (a, b) => a.startTime.compareTo(b.startTime),
      );
    }

    return groupedSessions;
  }

  Future<void> _deleteSession(Session session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Delete Session?',
            style: TextStyle(
              color: _primaryColor,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "${session.title}"? This action cannot be undone.',
            style: const TextStyle(
              color: _textMuted,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: _primaryColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.delete_outline, size: 17),
              label: const Text(
                'Delete',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: AppColors.errorRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('sessions')
          .doc(session.id)
          .delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session deleted successfully.'),
          backgroundColor: AppColors.successGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete session: $e'),
          backgroundColor: AppColors.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showEditSessionSheet(Session session) async {
    final titleController = TextEditingController(text: session.title);
    final descriptionController =
        TextEditingController(text: session.description);
    final locationController = TextEditingController(text: session.location);
    final liveStreamController =
        TextEditingController(text: session.liveStreamUrl);

    DateTime selectedDate = DateTime(
      session.startTime.year,
      session.startTime.month,
      session.startTime.day,
    );

    TimeOfDay startTime = TimeOfDay.fromDateTime(session.startTime);
    TimeOfDay endTime = TimeOfDay.fromDateTime(session.endTime);

    final rawCategory = session.category.trim();
    String selectedCategory = _categories.contains(rawCategory)
        ? rawCategory
        : 'Other';

    int selectedPriority = session.priority;
    if (selectedPriority < 1 || selectedPriority > 5) {
      selectedPriority = 3;
    }

    bool isChatEnabled = session.isChatEnabled;
    bool isSaving = false;

    Future<void> pickDate(StateSetter setSheetState) async {
      final now = DateTime.now();

      final picked = await showDatePicker(
        context: context,
        initialDate: selectedDate,
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
        setSheetState(() => selectedDate = picked);
      }
    }

    Future<void> pickStartTime(StateSetter setSheetState) async {
      final picked = await showTimePicker(
        context: context,
        initialTime: startTime,
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
        setSheetState(() => startTime = picked);
      }
    }

    Future<void> pickEndTime(StateSetter setSheetState) async {
      final picked = await showTimePicker(
        context: context,
        initialTime: endTime,
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
        setSheetState(() => endTime = picked);
      }
    }

    DateTime combineDateAndTime(DateTime date, TimeOfDay time) {
      return DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    }

    String formatDate(DateTime date) {
      return DateFormat('MMM d, yyyy').format(date);
    }

    String formatTime(TimeOfDay time) {
      final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
      final minute = time.minute.toString().padLeft(2, '0');
      final period = time.period == DayPeriod.am ? 'AM' : 'PM';

      return '$hour:$minute $period';
    }

    Future<void> saveSession(StateSetter setSheetState) async {
      final title = titleController.text.trim();
      final description = descriptionController.text.trim();
      final location = locationController.text.trim();
      final liveStreamUrl = liveStreamController.text.trim();

      if (title.isEmpty) {
        _showMessage('Session title is required.', isError: true);
        return;
      }

      if (location.isEmpty) {
        _showMessage('Location is required.', isError: true);
        return;
      }

      final newStartTime = combineDateAndTime(selectedDate, startTime);
      final newEndTime = combineDateAndTime(selectedDate, endTime);

      if (!newEndTime.isAfter(newStartTime)) {
        _showMessage('End time must be after start time.', isError: true);
        return;
      }

      setSheetState(() => isSaving = true);

      try {
        await FirebaseFirestore.instance
            .collection('sessions')
            .doc(session.id)
            .update({
          'title': title,
          'description': description,
          'location': location,
          'startTime': Timestamp.fromDate(newStartTime),
          'endTime': Timestamp.fromDate(newEndTime),
          'category': selectedCategory,
          'priority': selectedPriority,
          'liveStreamUrl': liveStreamUrl,
          'isChatEnabled': isChatEnabled,
          'closedBy': isChatEnabled ? '' : session.closedBy,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;

        Navigator.of(context).pop();

        _showMessage('Session updated successfully.');
      } catch (e) {
        if (!mounted) return;

        setSheetState(() => isSaving = false);

        _showMessage('Failed to update session: $e', isError: true);
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 18,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        height: 4,
                        width: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2DEEF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Edit Session',
                            style: TextStyle(
                              color: _primaryColor,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: isSaving
                              ? null
                              : () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: _primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Update the selected session details.',
                      style: TextStyle(
                        color: _textMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _EditInputField(
                      label: 'Session Title',
                      controller: titleController,
                      hint: 'Enter session title',
                      icon: Icons.event_note_outlined,
                    ),
                    const SizedBox(height: 14),
                    _EditInputField(
                      label: 'Description',
                      controller: descriptionController,
                      hint: 'Optional description',
                      icon: Icons.chat_bubble_outline_rounded,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 14),
                    _EditInputField(
                      label: 'Venue / Location',
                      controller: locationController,
                      hint: 'Enter location',
                      icon: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _EditPickerField(
                            label: 'Date',
                            value: formatDate(selectedDate),
                            icon: Icons.calendar_today_outlined,
                            onTap: isSaving
                                ? null
                                : () => pickDate(setSheetState),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _EditPickerField(
                            label: 'Start',
                            value: formatTime(startTime),
                            icon: Icons.access_time_rounded,
                            onTap: isSaving
                                ? null
                                : () => pickStartTime(setSheetState),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _EditPickerField(
                            label: 'End',
                            value: formatTime(endTime),
                            icon: Icons.access_time_rounded,
                            onTap: isSaving
                                ? null
                                : () => pickEndTime(setSheetState),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _EditCategoryDropdown(
                      value: selectedCategory,
                      items: _categories,
                      onChanged: isSaving
                          ? null
                          : (value) {
                              if (value == null) return;
                              setSheetState(() => selectedCategory = value);
                            },
                    ),
                    const SizedBox(height: 14),
                    _EditPriorityDropdown(
                      value: selectedPriority,
                      onChanged: isSaving
                          ? null
                          : (value) {
                              if (value == null) return;
                              setSheetState(() => selectedPriority = value);
                            },
                    ),
                    const SizedBox(height: 14),
                    _EditInputField(
                      label: 'Live Stream URL',
                      controller: liveStreamController,
                      hint: 'Optional',
                      icon: Icons.live_tv_outlined,
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _fieldBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: _primaryColor,
                            size: 21,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Enable Session Chat',
                                  style: TextStyle(
                                    color: _primaryColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Allow attendees to chat during this session.',
                                  style: TextStyle(
                                    color: _textMuted,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: isChatEnabled,
                            activeColor: _primaryColor,
                            onChanged: isSaving
                                ? null
                                : (value) {
                                    setSheetState(() {
                                      isChatEnabled = value;
                                    });
                                  },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isSaving
                                ? null
                                : () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded, size: 18),
                            label: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _primaryColor,
                              side: const BorderSide(color: _fieldBorder),
                              minimumSize: const Size(double.infinity, 46),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isSaving
                                ? null
                                : () => saveSession(setSheetState),
                            icon: isSaving
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check_rounded, size: 18),
                            label: Text(
                              isSaving ? 'Saving...' : 'Save',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor: _primaryColor,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 46),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();
    locationController.dispose();
    liveStreamController.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.errorRed : AppColors.successGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 32,
              width: 32,
              decoration: BoxDecoration(
                color: _softPurple,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _primaryColor,
                size: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.isEventSpecific
                  ? '${widget.eventName ?? 'Event'} Agenda'
                  : 'Event Agenda',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _primaryColor,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy_outlined,
              size: 56,
              color: AppColors.namaMediumGray,
            ),
            const SizedBox(height: 14),
            const Text(
              'No Sessions Found',
              style: TextStyle(
                color: _textDark,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.isEventSpecific
                  ? 'No sessions have been created for this event yet.'
                  : 'No sessions available yet.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _textMuted,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 56,
              color: AppColors.errorRed,
            ),
            const SizedBox(height: 14),
            const Text(
              'Error loading sessions',
              style: TextStyle(
                color: _textDark,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _textMuted,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateHeader(DateTime date, List<Session> sessions) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFE8E4F8),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            size: 19,
            color: _primaryColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              DateFormat('MMM d, yyyy').format(date),
              style: const TextStyle(
                color: _textDark,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            DateFormat('EEEE').format(date),
            style: const TextStyle(
              color: _textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.75),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${sessions.length} Sessions',
              style: const TextStyle(
                color: _primaryColor,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsList(List<Session> sessions) {
    final groupedSessions = _groupSessionsByDate(sessions);
    final sortedDates = groupedSessions.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final date = sortedDates[index];
        final dateSessions = groupedSessions[date] ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateHeader(date, dateSessions),
            ...dateSessions.map(
              (session) => _AdminSessionCard(
                session: session,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AdminSessionDetailScreen(
                        session: session,
                      ),
                    ),
                  );
                },
                onEdit: () => _showEditSessionSheet(session),
                onDelete: () => _deleteSession(session),
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventSessionsStream = _eventSessionsStream();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: StreamBuilder<List<Session>>(
                stream: eventSessionsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LoadingIndicator();
                  }

                  if (snapshot.hasError) {
                    return _buildErrorState(snapshot.error!);
                  }

                  final sessions = snapshot.data ?? [];

                  if (sessions.isEmpty) {
                    return _buildEmptyState();
                  }

                  return _buildSessionsList(sessions);
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: widget.showBottomNav
          ? BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _selectedBottomIndex,
              selectedItemColor: const Color(0xFFF5B51B),
              unselectedItemColor: Colors.white,
              backgroundColor: _primaryColor,
              selectedFontSize: 12,
              unselectedFontSize: 12,
              onTap: _onBottomNavTapped,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.admin_panel_settings_outlined),
                  activeIcon: Icon(Icons.admin_panel_settings),
                  label: 'Admin',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_month_outlined),
                  activeIcon: Icon(Icons.calendar_month),
                  label: 'Agenda',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.people_outline),
                  activeIcon: Icon(Icons.people),
                  label: 'Network',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.qr_code_scanner),
                  activeIcon: Icon(Icons.qr_code_scanner),
                  label: 'QR',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            )
          : null,
    );
  }
}

class _AdminSessionCard extends StatelessWidget {
  final Session session;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AdminSessionCard({
    required this.session,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  static const Color _primaryColor = Color(0xFF1B0F72);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textMuted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isActive =
        now.isAfter(session.startTime) && now.isBefore(session.endTime);
    final hasEnded = now.isAfter(session.endTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: hasEnded ? const Color(0xFFF1F1F1) : const Color(0xFFF7F7FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? AppColors.successGreen : Colors.transparent,
          width: isActive ? 1.6 : 0,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusBadge(
                    isActive: isActive,
                    hasEnded: hasEnded,
                  ),
                  const Spacer(),
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: hasEnded ? Colors.grey : _textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('h:mm a').format(session.startTime),
                    style: TextStyle(
                      color: hasEnded ? Colors.grey : _textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      session.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasEnded ? Colors.grey.shade600 : _textDark,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: hasEnded ? Colors.grey : _primaryColor,
                    size: 24,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: hasEnded ? Colors.grey : _textMuted,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      session.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasEnded ? Colors.grey : _textMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.people_outline,
                    size: 14,
                    color: hasEnded ? Colors.grey : _textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${session.checkedInAttendees.length} attended',
                    style: TextStyle(
                      color: hasEnded ? Colors.grey : _textMuted,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (session.qrCodePayload.isNotEmpty)
                          _MiniChip(
                            icon: Icons.qr_code_rounded,
                            label: 'QR Active',
                            color: AppColors.successGreen,
                            faded: hasEnded,
                          ),
                        if (session.totalMessages > 0)
                          _MiniChip(
                            icon: Icons.chat_bubble_outline_rounded,
                            label: '${session.totalMessages} messages',
                            color: AppColors.infoBlue,
                            faded: hasEnded,
                          ),
                      ],
                    ),
                  ),
                  _SmallActionButton(
                    icon: Icons.edit_outlined,
                    color: _primaryColor,
                    tooltip: 'Edit Session',
                    onTap: onEdit,
                  ),
                  const SizedBox(width: 6),
                  _SmallActionButton(
                    icon: Icons.delete_outline_rounded,
                    color: AppColors.errorRed,
                    tooltip: 'Delete Session',
                    onTap: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _SmallActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          height: 32,
          width: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: color.withOpacity(0.22),
            ),
          ),
          child: Icon(
            icon,
            color: color,
            size: 17,
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  final bool hasEnded;

  const _StatusBadge({
    required this.isActive,
    required this.hasEnded,
  });

  @override
  Widget build(BuildContext context) {
    if (isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.successGreen,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.circle,
              size: 7,
              color: Colors.white,
            ),
            SizedBox(width: 5),
            Text(
              'LIVE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
    }

    if (hasEnded) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'ENDED',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.namaGoldenYellow.withOpacity(0.22),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'UPCOMING',
        style: TextStyle(
          color: Color(0xFF1B0F72),
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool faded;

  const _MiniChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.faded,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = faded ? Colors.grey : color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: chipColor,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: chipColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditInputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final int maxLines;

  const _EditInputField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
  });

  static const Color _primaryColor = Color(0xFF1B0F72);
  static const Color _fieldBorder = Color(0xFFE1DDF0);
  static const Color _textMuted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _EditFieldLabel(label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          cursorColor: _primaryColor,
          style: const TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 12.5,
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
          ),
        ),
      ],
    );
  }
}

class _EditPickerField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  const _EditPickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  static const Color _primaryColor = Color(0xFF1B0F72);
  static const Color _fieldBorder = Color(0xFFE1DDF0);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _EditFieldLabel(label),
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
                    style: const TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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

class _EditCategoryDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String?>? onChanged;

  const _EditCategoryDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  static const Color _primaryColor = Color(0xFF1B0F72);
  static const Color _fieldBorder = Color(0xFFE1DDF0);

  @override
  Widget build(BuildContext context) {
    final safeItems = items.isEmpty ? ['Other'] : items;
    final safeValue = safeItems.contains(value) ? value : safeItems.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _EditFieldLabel('Category'),
        const SizedBox(height: 6),
        SizedBox(
          height: 48,
          child: DropdownButtonFormField<String>(
            value: safeValue,
            isExpanded: true,
            onChanged: onChanged,
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
                Icons.sell_outlined,
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
                borderSide: const BorderSide(color: _fieldBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(
                  color: _primaryColor,
                  width: 1.1,
                ),
              ),
            ),
            items: safeItems.map((item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _EditPriorityDropdown extends StatelessWidget {
  final int value;
  final ValueChanged<int?>? onChanged;

  const _EditPriorityDropdown({
    required this.value,
    required this.onChanged,
  });

  static const Color _primaryColor = Color(0xFF1B0F72);
  static const Color _fieldBorder = Color(0xFFE1DDF0);

  @override
  Widget build(BuildContext context) {
    final safeValue = value >= 1 && value <= 5 ? value : 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _EditFieldLabel('Priority'),
        const SizedBox(height: 6),
        SizedBox(
          height: 48,
          child: DropdownButtonFormField<int>(
            value: safeValue,
            isExpanded: true,
            onChanged: onChanged,
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
                borderSide: const BorderSide(color: _fieldBorder),
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

class _EditFieldLabel extends StatelessWidget {
  final String label;

  const _EditFieldLabel(this.label);

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