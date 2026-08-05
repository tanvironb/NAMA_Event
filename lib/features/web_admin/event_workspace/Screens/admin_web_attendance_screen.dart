// lib/features/web_admin/event_workspace/Screens/admin_web_attendance_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:events_app_trueattempt/core/models/certificate_model.dart';
import 'package:events_app_trueattempt/core/services/certificate_service.dart';
import 'package:events_app_trueattempt/features/certificates/screen/certificate_preview_screen.dart';

import '../../admin_web_theme.dart';

class AdminWebAttendanceScreen extends StatefulWidget {
  final String eventId;
  final String eventName;

  const AdminWebAttendanceScreen({
    super.key,
    required this.eventId,
    required this.eventName,
  });

  @override
  State<AdminWebAttendanceScreen> createState() =>
      _AdminWebAttendanceScreenState();
}

class _AdminWebAttendanceScreenState
    extends State<AdminWebAttendanceScreen> {
  late Future<_AttendanceReportData> _attendanceFuture;

  final TextEditingController _searchController =
      TextEditingController();
  final TextEditingController _registrationSearchController =
      TextEditingController();

  final CertificateService _certificateService =
      CertificateService();

  String _searchQuery = '';
  String _registrationSearchQuery = '';
  String _selectedAttendanceFilter = 'All';
  String _selectedRegistrationFilter = 'All';
  _AttendancePageMode _pageMode =
      _AttendancePageMode.attendance;

  bool _isCopyingCsv = false;
  bool _isGeneratingCertificates = false;
  bool _isSyncingRegistrations = false;
  bool _isAddingAllToReport = false;

  @override
  void initState() {
    super.initState();
    _attendanceFuture = _AttendanceReportRepository()
        .getAttendanceData(widget.eventId);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _registrationSearchController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _attendanceFuture = _AttendanceReportRepository()
          .getAttendanceData(widget.eventId);
    });
  }

  Future<void> _copyCsv(_AttendanceReportData data) async {
    if (_isCopyingCsv) return;

    setState(() => _isCopyingCsv = true);

    try {
      final csv = _buildCsv(data);
      await Clipboard.setData(ClipboardData(text: csv));

      if (!mounted) return;

      _showMessage(
        'Attendance CSV copied. Paste it into Excel or Google Sheets.',
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage('Failed to copy CSV: $error', error: true);
    } finally {
      if (mounted) {
        setState(() => _isCopyingCsv = false);
      }
    }
  }

  Future<void> _generateCertificates(
    _AttendanceReportData data,
  ) async {
    if (_isGeneratingCertificates) return;

    setState(() => _isGeneratingCertificates = true);

    try {
      final presentAttendees = data.participants
          .where(
            (participant) =>
                participant.isAttendee &&
                participant.hasEventCheckIn,
          )
          .map(
            (participant) => {
              'userId': participant.userId,
              'userName': participant.name,
              'userEmail': participant.email,
            },
          )
          .toList();

      final result = await _certificateService
          .generateAllEligibleCertificates(
        eventId: widget.eventId,
        presentAttendees: presentAttendees,
      );

      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('certificateSettings')
          .doc('main')
          .set(
        {
          'isGenerated': true,
          'generatedAt': FieldValue.serverTimestamp(),
          'generatedBy': 'admin_web',
          'attendeeCount': result['attendees'] ?? 0,
          'speakerCount': result['speakers'] ?? 0,
          'moderatorCount': result['moderators'] ?? 0,
          'staffCount': result['staff'] ?? 0,
          'totalGenerated': result['total'] ?? 0,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      _showMessage(
        'Certificates generated: ${result['total'] ?? 0} total.',
      );
      _refresh();
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        'Failed to generate certificates: $error',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isGeneratingCertificates = false);
      }
    }
  }

  Future<void> _openCertificate(
    _ParticipantAttendanceItem participant,
    bool certificateGenerationUnlocked, {
    required bool downloadOnly,
  }) async {
    try {
      if (!participant.isCertificateEligible) {
        throw Exception(
          'This user is not eligible for a certificate.',
        );
      }

      if (!certificateGenerationUnlocked) {
        throw Exception(
          'Certificates are locked. Generate certificates first.',
        );
      }

      final certificate = participant.generatedCertificate;

      if (certificate == null) {
        throw Exception(
          'Certificate document not found. Generate certificates again.',
        );
      }

      if (!mounted) return;

      if (downloadOnly) {
        await CertificatePreviewScreen.downloadCertificatePdf(
          context: context,
          certificate: certificate,
          eventName: widget.eventName,
          eventDate: DateTime.now(),
        );
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CertificatePreviewScreen(
            certificate: certificate,
            eventName: widget.eventName,
            eventDate: DateTime.now(),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        error.toString().replaceFirst('Exception: ', ''),
        error: true,
      );
    }
  }

  Future<void> _syncExistingUsers() async {
    if (_isSyncingRegistrations) return;

    setState(() => _isSyncingRegistrations = true);

    try {
      final firestore = FirebaseFirestore.instance;

      final usersSnapshot = await firestore
          .collection('users')
          .where('eventIds', arrayContains: widget.eventId)
          .get();

      final batch = firestore.batch();

      for (final userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final registrationReference = firestore
            .collection('events')
            .doc(widget.eventId)
            .collection('registrations')
            .doc(userDoc.id);

        final normalizedRole = _normalizeRole(
          (userData['role'] ??
                  userData['userRole'] ??
                  userData['userType'] ??
                  'attendee')
              .toString(),
        );

        batch.set(
          registrationReference,
          {
            'userId': userDoc.id,
            'eventId': widget.eventId,
            'name': (userData['name'] ??
                    userData['fullName'] ??
                    userData['displayName'] ??
                    'Unnamed User')
                .toString(),
            'email': (userData['email'] ?? '').toString(),
            'role': normalizedRole,
            'company':
                (userData['company'] ?? '').toString(),
            'title': (userData['title'] ??
                    userData['jobTitle'] ??
                    '')
                .toString(),
            'profileImageUrl':
                (userData['profileImageUrl'] ?? '').toString(),
            'status': 'registered',
            'source': 'admin_web_sync',
            'registeredAt': userData['createdAt'] ??
                FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();

      if (!mounted) return;

      _showMessage(
        '${usersSnapshot.docs.length} event users synchronized with registration.',
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Failed to synchronize registrations: $error',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isSyncingRegistrations = false);
      }
    }
  }

  Future<void> _addAllRegistrationsToReport(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> registrations,
  ) async {
    if (_isAddingAllToReport || registrations.isEmpty) return;

    setState(() => _isAddingAllToReport = true);

    try {
      final batch = FirebaseFirestore.instance.batch();

      for (final registration in registrations) {
        batch.set(
          registration.reference,
          {
            'includedInReport': true,
            'includedInReportAt':
                FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();

      if (!mounted) return;
      _showMessage(
        'All registered users were added to the event report.',
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Failed to add registrations to report: $error',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isAddingAllToReport = false);
      }
    }
  }

  Future<void> _toggleRegistrationReport(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
    bool include,
  ) async {
    try {
      await document.reference.set(
        {
          'includedInReport': include,
          'includedInReportAt':
              include ? FieldValue.serverTimestamp() : null,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        'Failed to update registration: $error',
        error: true,
      );
    }
  }

  void _showMessage(
    String message, {
    bool error = false,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              error ? Colors.redAccent : AdminWebTheme.primary,
        ),
      );
  }

  List<_ParticipantAttendanceItem> _filterParticipants(
    List<_ParticipantAttendanceItem> participants,
  ) {
    final query = _searchQuery.trim().toLowerCase();

    return participants.where((participant) {
      final matchesQuery = query.isEmpty ||
          participant.name.toLowerCase().contains(query) ||
          participant.email.toLowerCase().contains(query) ||
          participant.displayRole.toLowerCase().contains(query);

      if (!matchesQuery) return false;

      switch (_selectedAttendanceFilter) {
        case 'Present':
          return participant.isAttendee &&
              participant.hasEventCheckIn;
        case 'Absent':
          return participant.isAttendee &&
              !participant.hasEventCheckIn;
        case 'Speakers':
          return participant.isSpeaker;
        case 'Moderators':
          return participant.isModerator;
        case 'Staff':
          return participant.isStaff;
        default:
          return true;
      }
    }).toList();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>>
      _filterRegistrations(
    List<QueryDocumentSnapshot<Map<String, dynamic>>>
        registrations,
  ) {
    final query =
        _registrationSearchQuery.trim().toLowerCase();

    return registrations.where((document) {
      final data = document.data();
      final name = (data['name'] ?? '').toString().toLowerCase();
      final email =
          (data['email'] ?? '').toString().toLowerCase();
      final role =
          (data['role'] ?? '').toString().toLowerCase();
      final included = data['includedInReport'] == true;

      final matchesQuery = query.isEmpty ||
          name.contains(query) ||
          email.contains(query) ||
          role.contains(query);

      if (!matchesQuery) return false;

      switch (_selectedRegistrationFilter) {
        case 'Included':
          return included;
        case 'Not Included':
          return !included;
        case 'Attendees':
          return _normalizeRole(role) == 'attendee';
        case 'Speakers':
          return _normalizeRole(role) == 'speaker';
        case 'Moderators':
          return _normalizeRole(role) == 'moderator';
        case 'Staff':
          return _normalizeRole(role) == 'staff';
        default:
          return true;
      }
    }).toList();
  }

  String _buildCsv(_AttendanceReportData data) {
    final buffer = StringBuffer();

    buffer.writeln(
      [
        'No',
        'Name',
        'Email',
        'Role',
        'Attendance Status',
        'Certificate Status',
        'Event Check-in Time',
        'Total Sessions Joined',
        'Sessions Joined',
      ].map(_csvCell).join(','),
    );

    for (int index = 0;
        index < data.participants.length;
        index++) {
      final participant = data.participants[index];

      final attendanceStatus = participant.isAttendee
          ? (participant.hasEventCheckIn
              ? 'Present'
              : 'Absent')
          : 'Not Required';

      final certificateStatus =
          !participant.isCertificateEligible
              ? 'Not Eligible'
              : !data.certificateGenerationUnlocked
                  ? 'Locked'
                  : participant.hasGeneratedCertificate
                      ? 'Generated'
                      : 'Missing Certificate';

      buffer.writeln(
        [
          '${index + 1}',
          participant.name,
          participant.email,
          participant.displayRole,
          attendanceStatus,
          certificateStatus,
          participant.eventCheckInAt == null
              ? ''
              : _formatDateTime(
                  participant.eventCheckInAt!,
                ),
          '${participant.sessionsJoined.length}',
          participant.sessionsJoined.join(' | '),
        ].map(_csvCell).join(','),
      );
    }

    return buffer.toString();
  }

  String _csvCell(String value) {
    return '"${value.replaceAll('"', '""')}"';
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>
      _registrationsStream() {
    return FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .collection('registrations')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AttendanceReportData>(
      future: _attendanceFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: AdminWebTheme.primary,
            ),
          );
        }

        if (snapshot.hasError) {
          return _AttendanceErrorState(
            message: snapshot.error.toString(),
            onRetry: _refresh,
          );
        }

        final data =
            snapshot.data ?? _AttendanceReportData.empty();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(
                eventName: widget.eventName,
                onRefresh: _refresh,
              ),
              const SizedBox(height: 18),
              _ModeSelector(
                selectedMode: _pageMode,
                onChanged: (mode) {
                  setState(() => _pageMode = mode);
                },
              ),
              const SizedBox(height: 18),
              if (_pageMode ==
                  _AttendancePageMode.attendance)
                _buildAttendancePage(data)
              else
                _buildRegistrationPage(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttendancePage(
    _AttendanceReportData data,
  ) {
    final participants =
        _filterParticipants(data.participants);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AttendanceBanner(
          eventName: widget.eventName,
          certificateGenerationUnlocked:
              data.certificateGenerationUnlocked,
        ),
        const SizedBox(height: 18),
        _SummaryGrid(data: data),
        const SizedBox(height: 18),
        _ToolbarCard(
          searchController: _searchController,
          searchHint:
              'Search by name, email, or role',
          selectedFilter: _selectedAttendanceFilter,
          filters: const [
            'All',
            'Present',
            'Absent',
            'Speakers',
            'Moderators',
            'Staff',
          ],
          onSearchChanged: (value) {
            setState(() => _searchQuery = value);
          },
          onFilterChanged: (value) {
            setState(
              () => _selectedAttendanceFilter = value,
            );
          },
          actions: [
            OutlinedButton.icon(
              onPressed: _isCopyingCsv
                  ? null
                  : () => _copyCsv(data),
              icon: _isCopyingCsv
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.table_chart_outlined,
                      size: 17,
                    ),
              label: Text(
                _isCopyingCsv
                    ? 'Copying...'
                    : 'Copy CSV',
              ),
            ),
            FilledButton.icon(
              onPressed: _isGeneratingCertificates
                  ? null
                  : () => _generateCertificates(data),
              icon: _isGeneratingCertificates
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.workspace_premium_outlined,
                      size: 17,
                    ),
              label: Text(
                _isGeneratingCertificates
                    ? 'Generating...'
                    : data.certificateGenerationUnlocked
                        ? 'Regenerate Certificates'
                        : 'Generate Certificates',
              ),
              style: FilledButton.styleFrom(
                backgroundColor:
                    AdminWebTheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _AttendanceTableCard(
          participants: participants,
          certificateGenerationUnlocked:
              data.certificateGenerationUnlocked,
          onViewCertificate: (participant) {
            _openCertificate(
              participant,
              data.certificateGenerationUnlocked,
              downloadOnly: false,
            );
          },
          onDownloadCertificate: (participant) {
            _openCertificate(
              participant,
              data.certificateGenerationUnlocked,
              downloadOnly: true,
            );
          },
        ),
      ],
    );
  }

  Widget _buildRegistrationPage() {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: _registrationsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _AttendanceErrorState(
            message: snapshot.error.toString(),
            onRetry: () => setState(() {}),
          );
        }

        final registrations =
            snapshot.data?.docs ?? const [];
        final filtered =
            _filterRegistrations(registrations);

        final includedCount = registrations
            .where(
              (document) =>
                  document.data()['includedInReport'] ==
                  true,
            )
            .length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RegistrationBanner(
              eventName: widget.eventName,
              registrationCount:
                  registrations.length,
              includedCount: includedCount,
            ),
            const SizedBox(height: 18),
            _RegistrationSummaryGrid(
              registrations: registrations,
            ),
            const SizedBox(height: 18),
            _ToolbarCard(
              searchController:
                  _registrationSearchController,
              searchHint:
                  'Search registrations by name, email, or role',
              selectedFilter:
                  _selectedRegistrationFilter,
              filters: const [
                'All',
                'Included',
                'Not Included',
                'Attendees',
                'Speakers',
                'Moderators',
                'Staff',
              ],
              onSearchChanged: (value) {
                setState(
                  () =>
                      _registrationSearchQuery = value,
                );
              },
              onFilterChanged: (value) {
                setState(
                  () =>
                      _selectedRegistrationFilter = value,
                );
              },
              actions: [
                OutlinedButton.icon(
                  onPressed: _isSyncingRegistrations
                      ? null
                      : _syncExistingUsers,
                  icon: _isSyncingRegistrations
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.sync_rounded,
                          size: 17,
                        ),
                  label: Text(
                    _isSyncingRegistrations
                        ? 'Syncing...'
                        : 'Sync Event Users',
                  ),
                ),
                FilledButton.icon(
                  onPressed:
                      _isAddingAllToReport ||
                              registrations.isEmpty
                          ? null
                          : () =>
                              _addAllRegistrationsToReport(
                                registrations,
                              ),
                  icon: _isAddingAllToReport
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.playlist_add_check_rounded,
                          size: 17,
                        ),
                  label: Text(
                    _isAddingAllToReport
                        ? 'Adding...'
                        : 'Add All to Report',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        AdminWebTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _RegistrationsTableCard(
              registrations: filtered,
              onIncludeChanged:
                  _toggleRegistrationReport,
            ),
          ],
        );
      },
    );
  }
}

enum _AttendancePageMode {
  attendance,
  registration,
}

class _Header extends StatelessWidget {
  final String eventName;
  final VoidCallback onRefresh;

  const _Header({
    required this.eventName,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                eventName.toUpperCase(),
                style: const TextStyle(
                  color: AdminWebTheme.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Attendance & Certificates',
                style: TextStyle(
                  color: AdminWebTheme.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Review attendance, inspect registrations, export data, and manage certificate eligibility.',
                style: TextStyle(
                  color: AdminWebTheme.textSecondary,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(
            Icons.refresh_rounded,
            size: 17,
          ),
          label: const Text('Refresh'),
        ),
      ],
    );
  }
}

class _ModeSelector extends StatelessWidget {
  final _AttendancePageMode selectedMode;
  final ValueChanged<_AttendancePageMode> onChanged;

  const _ModeSelector({
    required this.selectedMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AdminWebTheme.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeButton(
            label: 'Attendance Report',
            icon: Icons.fact_check_outlined,
            selected: selectedMode ==
                _AttendancePageMode.attendance,
            onTap: () => onChanged(
              _AttendancePageMode.attendance,
            ),
          ),
          const SizedBox(width: 5),
          _ModeButton(
            label: 'Check Registration',
            icon: Icons.how_to_reg_outlined,
            selected: selectedMode ==
                _AttendancePageMode.registration,
            onTap: () => onChanged(
              _AttendancePageMode.registration,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AdminWebTheme.primary
          : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 10,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 17,
                color: selected
                    ? Colors.white
                    : AdminWebTheme.textSecondary,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : AdminWebTheme.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttendanceBanner extends StatelessWidget {
  final String eventName;
  final bool certificateGenerationUnlocked;

  const _AttendanceBanner({
    required this.eventName,
    required this.certificateGenerationUnlocked,
  });

  @override
  Widget build(BuildContext context) {
    return _TopBanner(
      eyebrow: 'ATTENDANCE REPORT',
      title: eventName,
      description:
          'Present attendees and assigned speakers, moderators, and staff are eligible for certificates. Absent attendees are not eligible.',
      icon: certificateGenerationUnlocked
          ? Icons.lock_open_rounded
          : Icons.workspace_premium_outlined,
      statusText: certificateGenerationUnlocked
          ? 'Certificates Generated'
          : 'Certificates Locked',
    );
  }
}

class _RegistrationBanner extends StatelessWidget {
  final String eventName;
  final int registrationCount;
  final int includedCount;

  const _RegistrationBanner({
    required this.eventName,
    required this.registrationCount,
    required this.includedCount,
  });

  @override
  Widget build(BuildContext context) {
    return _TopBanner(
      eyebrow: 'CHECK REGISTRATION',
      title: eventName,
      description:
          '$registrationCount registered users found. $includedCount currently included in the event report.',
      icon: Icons.how_to_reg_rounded,
      statusText: '$registrationCount Registered',
    );
  }
}

class _TopBanner extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String description;
  final IconData icon;
  final String statusText;

  const _TopBanner({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.icon,
    required this.statusText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF11117A),
            Color(0xFF08084B),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: const TextStyle(
                    color: AdminWebTheme.gold,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 9),
                ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: 760),
                  child: Text(
                    description,
                    style: const TextStyle(
                      color: Color(0xFFC7CAE1),
                      fontSize: 11.5,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.09),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: AdminWebTheme.gold,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  statusText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final _AttendanceReportData data;

  const _SummaryGrid({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _SummaryItem(
        label: 'Attendees',
        value: '${data.totalAttendees}',
        icon: Icons.groups_outlined,
        color: const Color(0xFF246BFD),
      ),
      _SummaryItem(
        label: 'Present',
        value: '${data.totalCheckedInAttendees}',
        icon: Icons.how_to_reg_outlined,
        color: const Color(0xFF18A66F),
      ),
      _SummaryItem(
        label: 'Absent',
        value: '${data.totalAbsentAttendees}',
        icon: Icons.person_off_outlined,
        color: const Color(0xFFEF476F),
      ),
      _SummaryItem(
        label: 'Certificates',
        value: data.certificateGenerationUnlocked
            ? '${data.totalGeneratedCertificates}'
            : 'Locked',
        icon: Icons.workspace_premium_outlined,
        color: const Color(0xFFF59E0B),
      ),
    ];

    return _SummaryCards(items: items);
  }
}

class _RegistrationSummaryGrid extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>>
      registrations;

  const _RegistrationSummaryGrid({
    required this.registrations,
  });

  @override
  Widget build(BuildContext context) {
    int attendees = 0;
    int speakers = 0;
    int moderators = 0;
    int included = 0;

    for (final document in registrations) {
      final data = document.data();
      final role = _normalizeRole(
        (data['role'] ?? 'attendee').toString(),
      );

      if (role == 'speaker') {
        speakers++;
      } else if (role == 'moderator') {
        moderators++;
      } else if (role == 'attendee') {
        attendees++;
      }

      if (data['includedInReport'] == true) {
        included++;
      }
    }

    return _SummaryCards(
      items: [
        _SummaryItem(
          label: 'Registered',
          value: '${registrations.length}',
          icon: Icons.app_registration_outlined,
          color: const Color(0xFF246BFD),
        ),
        _SummaryItem(
          label: 'Attendees',
          value: '$attendees',
          icon: Icons.groups_outlined,
          color: const Color(0xFF18A66F),
        ),
        _SummaryItem(
          label: 'Speakers & Moderators',
          value: '${speakers + moderators}',
          icon: Icons.record_voice_over_outlined,
          color: const Color(0xFF7B4DFF),
        ),
        _SummaryItem(
          label: 'Included in Report',
          value: '$included',
          icon: Icons.playlist_add_check_rounded,
          color: const Color(0xFFF59E0B),
        ),
      ],
    );
  }
}

class _SummaryItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _SummaryCards extends StatelessWidget {
  final List<_SummaryItem> items;

  const _SummaryCards({
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 950
            ? 4
            : constraints.maxWidth >= 560
                ? 2
                : 1;

        const spacing = 12.0;
        final itemWidth =
            (constraints.maxWidth - spacing * (count - 1)) /
                count;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items.map((item) {
            return Container(
              width: itemWidth,
              height: 112,
              padding: const EdgeInsets.all(15),
              decoration: _cardDecoration(),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: item.color.withOpacity(0.10),
                          borderRadius:
                              BorderRadius.circular(11),
                        ),
                        child: Icon(
                          item.icon,
                          color: item.color,
                          size: 20,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        item.value,
                        style: const TextStyle(
                          color:
                              AdminWebTheme.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color:
                          AdminWebTheme.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ToolbarCard extends StatelessWidget {
  final TextEditingController searchController;
  final String searchHint;
  final String selectedFilter;
  final List<String> filters;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onFilterChanged;
  final List<Widget> actions;

  const _ToolbarCard({
    required this.searchController,
    required this.searchHint,
    required this.selectedFilter,
    required this.filters,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final search = TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            style: const TextStyle(fontSize: 11.5),
            decoration: InputDecoration(
              hintText: searchHint,
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 18,
              ),
              isDense: true,
            ),
          );

          final filter = SizedBox(
            width: 180,
            child: DropdownButtonFormField<String>(
              value: selectedFilter,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Filter',
                isDense: true,
              ),
              items: filters.map((item) {
                return DropdownMenuItem(
                  value: item,
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontSize: 10.5,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  onFilterChanged(value);
                }
              },
            ),
          );

          if (constraints.maxWidth < 850) {
            return Column(
              children: [
                search,
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: filter),
                    const SizedBox(width: 10),
                    ...actions
                        .map(
                          (action) => Padding(
                            padding:
                                const EdgeInsets.only(
                              left: 8,
                            ),
                            child: action,
                          ),
                        )
                        .toList(),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 10),
              filter,
              const SizedBox(width: 10),
              ...actions
                  .map(
                    (action) => Padding(
                      padding:
                          const EdgeInsets.only(left: 8),
                      child: action,
                    ),
                  )
                  .toList(),
            ],
          );
        },
      ),
    );
  }
}

class _AttendanceTableCard extends StatelessWidget {
  final List<_ParticipantAttendanceItem> participants;
  final bool certificateGenerationUnlocked;
  final ValueChanged<_ParticipantAttendanceItem>
      onViewCertificate;
  final ValueChanged<_ParticipantAttendanceItem>
      onDownloadCertificate;

  const _AttendanceTableCard({
    required this.participants,
    required this.certificateGenerationUnlocked,
    required this.onViewCertificate,
    required this.onDownloadCertificate,
  });

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) {
      return const _EmptyState(
        icon: Icons.people_outline_rounded,
        title: 'No participants found',
        message:
            'Try changing the search text or attendance filter.',
      );
    }

    return Container(
      width: double.infinity,
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 820) {
            return Column(
              children: participants.map((participant) {
                return _ParticipantMobileCard(
                  participant: participant,
                  certificateGenerationUnlocked:
                      certificateGenerationUnlocked,
                  onViewCertificate: () =>
                      onViewCertificate(participant),
                  onDownloadCertificate: () =>
                      onDownloadCertificate(participant),
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
                headingRowHeight: 46,
                dataRowMinHeight: 56,
                dataRowMaxHeight: 70,
                headingRowColor:
                    WidgetStateProperty.all(
                  const Color(0xFFFAFBFD),
                ),
                horizontalMargin: 16,
                columnSpacing: 24,
                headingTextStyle: const TextStyle(
                  color:
                      AdminWebTheme.textSecondary,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
                dataTextStyle: const TextStyle(
                  color: AdminWebTheme.textPrimary,
                  fontSize: 10,
                ),
                columns: const [
                  DataColumn(label: Text('PARTICIPANT')),
                  DataColumn(label: Text('ROLE')),
                  DataColumn(label: Text('ATTENDANCE')),
                  DataColumn(label: Text('CHECK-IN TIME')),
                  DataColumn(label: Text('SESSIONS')),
                  DataColumn(label: Text('CERTIFICATE')),
                  DataColumn(label: Text('ACTIONS')),
                ],
                rows: participants.map((participant) {
                  return DataRow(
                    cells: [
                      DataCell(
                        _UserCell(
                          name: participant.name,
                          email: participant.email,
                        ),
                      ),
                      DataCell(
                        _RoleBadge(
                          role: participant.displayRole,
                        ),
                      ),
                      DataCell(
                        participant.isAttendee
                            ? _StatusBadge(
                                label:
                                    participant.hasEventCheckIn
                                        ? 'Present'
                                        : 'Absent',
                                positive: participant
                                    .hasEventCheckIn,
                              )
                            : const Text('Not Required'),
                      ),
                      DataCell(
                        Text(
                          participant.eventCheckInAt ==
                                  null
                              ? '-'
                              : _formatDateTime(
                                  participant
                                      .eventCheckInAt!,
                                ),
                        ),
                      ),
                      DataCell(
                        Text(
                          '${participant.sessionsJoined.length}',
                        ),
                      ),
                      DataCell(
                        _CertificateStatusBadge(
                          participant: participant,
                          unlocked:
                              certificateGenerationUnlocked,
                        ),
                      ),
                      DataCell(
                        _CertificateActions(
                          participant: participant,
                          unlocked:
                              certificateGenerationUnlocked,
                          onView: () =>
                              onViewCertificate(participant),
                          onDownload: () =>
                              onDownloadCertificate(
                                  participant),
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

class _RegistrationsTableCard extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>>
      registrations;
  final Future<void> Function(
    QueryDocumentSnapshot<Map<String, dynamic>>,
    bool,
  ) onIncludeChanged;

  const _RegistrationsTableCard({
    required this.registrations,
    required this.onIncludeChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (registrations.isEmpty) {
      return const _EmptyState(
        icon: Icons.how_to_reg_outlined,
        title: 'No registrations found',
        message:
            'Use Sync Event Users to create registration records for users linked to this event.',
      );
    }

    return Container(
      width: double.infinity,
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 760) {
            return Column(
              children: registrations.map((document) {
                final data = document.data();
                final included =
                    data['includedInReport'] == true;

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: AdminWebTheme.border,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _UserCell(
                          name: (data['name'] ??
                                  'Unknown User')
                              .toString(),
                          email:
                              (data['email'] ?? '')
                                  .toString(),
                        ),
                      ),
                      Switch(
                        value: included,
                        onChanged: (value) {
                          onIncludeChanged(
                            document,
                            value,
                          );
                        },
                      ),
                    ],
                  ),
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
                headingRowHeight: 46,
                dataRowMinHeight: 54,
                dataRowMaxHeight: 64,
                headingRowColor:
                    WidgetStateProperty.all(
                  const Color(0xFFFAFBFD),
                ),
                horizontalMargin: 16,
                columnSpacing: 26,
                headingTextStyle: const TextStyle(
                  color:
                      AdminWebTheme.textSecondary,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
                dataTextStyle: const TextStyle(
                  color: AdminWebTheme.textPrimary,
                  fontSize: 10,
                ),
                columns: const [
                  DataColumn(label: Text('REGISTERED USER')),
                  DataColumn(label: Text('ROLE')),
                  DataColumn(label: Text('COMPANY')),
                  DataColumn(label: Text('STATUS')),
                  DataColumn(label: Text('REGISTERED AT')),
                  DataColumn(label: Text('IN REPORT')),
                ],
                rows: registrations.map((document) {
                  final data = document.data();
                  final included =
                      data['includedInReport'] == true;
                  final registeredAt =
                      _readDate(data['registeredAt']);

                  return DataRow(
                    cells: [
                      DataCell(
                        _UserCell(
                          name: (data['name'] ??
                                  'Unknown User')
                              .toString(),
                          email:
                              (data['email'] ?? '')
                                  .toString(),
                        ),
                      ),
                      DataCell(
                        _RoleBadge(
                          role: _displayRole(
                            (data['role'] ??
                                    'attendee')
                                .toString(),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          (data['company'] ?? '-')
                              .toString(),
                        ),
                      ),
                      DataCell(
                        _StatusBadge(
                          label: (data['status'] ??
                                  'registered')
                              .toString(),
                          positive: true,
                        ),
                      ),
                      DataCell(
                        Text(
                          registeredAt == null
                              ? '-'
                              : _formatDateTime(
                                  registeredAt,
                                ),
                        ),
                      ),
                      DataCell(
                        Switch(
                          value: included,
                          onChanged: (value) {
                            onIncludeChanged(
                              document,
                              value,
                            );
                          },
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

class _UserCell extends StatelessWidget {
  final String name;
  final String email;

  const _UserCell({
    required this.name,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty
        ? '?'
        : name.trim().substring(0, 1).toUpperCase();

    return SizedBox(
      width: 210,
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor:
                AdminWebTheme.primary.withOpacity(0.08),
            child: Text(
              initial,
              style: const TextStyle(
                color: AdminWebTheme.primary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color:
                        AdminWebTheme.textPrimary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (email.trim().isNotEmpty)
                  Text(
                    email,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: const TextStyle(
                      color:
                          AdminWebTheme.textSecondary,
                      fontSize: 8.5,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;

  const _RoleBadge({
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: AdminWebTheme.primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        role,
        style: const TextStyle(
          color: AdminWebTheme.primary,
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final bool positive;

  const _StatusBadge({
    required this.label,
    required this.positive,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        positive ? const Color(0xFF159A62) : Colors.redAccent;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CertificateStatusBadge extends StatelessWidget {
  final _ParticipantAttendanceItem participant;
  final bool unlocked;

  const _CertificateStatusBadge({
    required this.participant,
    required this.unlocked,
  });

  @override
  Widget build(BuildContext context) {
    if (!participant.isCertificateEligible) {
      return const _StatusBadge(
        label: 'Not Eligible',
        positive: false,
      );
    }

    if (!unlocked) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: AdminWebTheme.gold.withOpacity(0.13),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Locked',
          style: TextStyle(
            color: Color(0xFFA26A00),
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return _StatusBadge(
      label: participant.hasGeneratedCertificate
          ? 'Generated'
          : 'Missing',
      positive: participant.hasGeneratedCertificate,
    );
  }
}

class _CertificateActions extends StatelessWidget {
  final _ParticipantAttendanceItem participant;
  final bool unlocked;
  final VoidCallback onView;
  final VoidCallback onDownload;

  const _CertificateActions({
    required this.participant,
    required this.unlocked,
    required this.onView,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = participant.isCertificateEligible &&
        unlocked &&
        participant.hasGeneratedCertificate;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'View certificate',
          onPressed: enabled ? onView : null,
          icon: const Icon(
            Icons.visibility_outlined,
            size: 18,
          ),
        ),
        IconButton(
          tooltip: 'Download certificate',
          onPressed: enabled ? onDownload : null,
          icon: const Icon(
            Icons.download_rounded,
            size: 18,
          ),
        ),
      ],
    );
  }
}

class _ParticipantMobileCard extends StatelessWidget {
  final _ParticipantAttendanceItem participant;
  final bool certificateGenerationUnlocked;
  final VoidCallback onViewCertificate;
  final VoidCallback onDownloadCertificate;

  const _ParticipantMobileCard({
    required this.participant,
    required this.certificateGenerationUnlocked,
    required this.onViewCertificate,
    required this.onDownloadCertificate,
  });

  @override
  Widget build(BuildContext context) {
    final canUseCertificate =
        participant.isCertificateEligible &&
            certificateGenerationUnlocked &&
            participant.hasGeneratedCertificate;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AdminWebTheme.border,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _UserCell(
            name: participant.name,
            email: participant.email,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _RoleBadge(
                role: participant.displayRole,
              ),
              if (participant.isAttendee)
                _StatusBadge(
                  label: participant.hasEventCheckIn
                      ? 'Present'
                      : 'Absent',
                  positive:
                      participant.hasEventCheckIn,
                ),
              _CertificateStatusBadge(
                participant: participant,
                unlocked:
                    certificateGenerationUnlocked,
              ),
            ],
          ),
          if (canUseCertificate) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: onViewCertificate,
                  icon: const Icon(
                    Icons.visibility_outlined,
                    size: 16,
                  ),
                  label: const Text('View'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed:
                      onDownloadCertificate,
                  icon: const Icon(
                    Icons.download_rounded,
                    size: 16,
                  ),
                  label: const Text('Download'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 38,
      ),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Icon(
            icon,
            size: 34,
            color: AdminWebTheme.primary,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: AdminWebTheme.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AdminWebTheme.textSecondary,
              fontSize: 10,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _AttendanceErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints:
            const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: _cardDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 42,
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load attendance data',
              style: TextStyle(
                color: AdminWebTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AdminWebTheme.textSecondary,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 15),
            FilledButton.icon(
              onPressed: onRetry,
              icon:
                  const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceReportRepository {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  Future<_AttendanceReportData> getAttendanceData(
    String eventId,
  ) async {
    final registeredUsersSnap = await _firestore
        .collection('users')
        .where('eventIds', arrayContains: eventId)
        .get();

    final eventAttendanceSnap = await _firestore
        .collection('events')
        .doc(eventId)
        .collection('attendance')
        .get();

    final certificateSettingsDoc = await _firestore
        .collection('events')
        .doc(eventId)
        .collection('certificateSettings')
        .doc('main')
        .get();

    final certificateGenerationUnlocked =
        certificateSettingsDoc.data()?['isGenerated'] == true;

    final certificatesSnap = await _firestore
        .collection('events')
        .doc(eventId)
        .collection('certificates')
        .get();

    final topLevelSessionsSnap = await _firestore
        .collection('sessions')
        .where('eventId', isEqualTo: eventId)
        .get();

    final eventSubSessionsSnap = await _firestore
        .collection('events')
        .doc(eventId)
        .collection('sessions')
        .get();

    final mergedSessions = <
        String,
        QueryDocumentSnapshot<Map<String, dynamic>>>{};

    for (final document
        in topLevelSessionsSnap.docs) {
      mergedSessions[document.reference.path] =
          document;
    }

    for (final document
        in eventSubSessionsSnap.docs) {
      mergedSessions[document.reference.path] =
          document;
    }

    final generatedCertificatesByUserId =
        <String, List<CertificateModel>>{};

    for (final document in certificatesSnap.docs) {
      final data = document.data();
      final userId =
          (data['userId'] ?? '').toString().trim();

      if (userId.isEmpty) continue;

      generatedCertificatesByUserId.putIfAbsent(
        userId,
        () => <CertificateModel>[],
      );

      generatedCertificatesByUserId[userId]!.add(
        CertificateModel.fromFirestore(document),
      );
    }

    final eventCheckInsByUserId =
        <String, DateTime?>{};

    for (final document
        in eventAttendanceSnap.docs) {
      final data = document.data();
      final userId =
          (data['userId'] ?? document.id)
              .toString()
              .trim();

      eventCheckInsByUserId[userId] = _readDate(
        data['checkedInAt'] ??
            data['timestamp'] ??
            data['createdAt'],
      );
    }

    final sessionJoinedByUserId =
        <String, List<String>>{};
    final assignedSessionsByUserId =
        <String, List<_AssignedSessionItem>>{};
    final assignedRoleByUserId = <String, String>{};

    for (final sessionDocument
        in mergedSessions.values) {
      final sessionData = sessionDocument.data();
      final sessionId = sessionDocument.id;
      final sessionTitle =
          (sessionData['title'] ??
                  'Untitled Session')
              .toString();

      _collectAssignedUsers(
        sessionData: sessionData,
        sessionId: sessionId,
        sessionTitle: sessionTitle,
        role: 'speaker',
        listKeys: const ['speakerIds'],
        singleKeys: const ['speakerId'],
        assignedSessionsByUserId:
            assignedSessionsByUserId,
        assignedRoleByUserId: assignedRoleByUserId,
      );

      _collectAssignedUsers(
        sessionData: sessionData,
        sessionId: sessionId,
        sessionTitle: sessionTitle,
        role: 'moderator',
        listKeys: const ['moderatorIds'],
        singleKeys: const ['moderatorId'],
        assignedSessionsByUserId:
            assignedSessionsByUserId,
        assignedRoleByUserId: assignedRoleByUserId,
      );

      _collectAssignedUsers(
        sessionData: sessionData,
        sessionId: sessionId,
        sessionTitle: sessionTitle,
        role: 'staff',
        listKeys: const [
          'staffIds',
          'volunteerIds',
        ],
        singleKeys: const [
          'staffId',
          'volunteerId',
        ],
        assignedSessionsByUserId:
            assignedSessionsByUserId,
        assignedRoleByUserId: assignedRoleByUserId,
      );

      final checkedInAttendees =
          List<String>.from(
        sessionData['checkedInAttendees']
                as List? ??
            [],
      );

      for (final userId in checkedInAttendees) {
        sessionJoinedByUserId.putIfAbsent(
          userId,
          () => <String>[],
        );

        if (!sessionJoinedByUserId[userId]!
            .contains(sessionTitle)) {
          sessionJoinedByUserId[userId]!
              .add(sessionTitle);
        }
      }

      await _readSessionCheckins(
        sessionRef: sessionDocument.reference,
        sessionTitle: sessionTitle,
        sessionJoinedByUserId:
            sessionJoinedByUserId,
        collectionName: 'checkins',
      );

      await _readSessionCheckins(
        sessionRef: sessionDocument.reference,
        sessionTitle: sessionTitle,
        sessionJoinedByUserId:
            sessionJoinedByUserId,
        collectionName: 'checkIns',
      );
    }

    final participantsMap =
        <String, _ParticipantAttendanceItem>{};

    for (final userDocument
        in registeredUsersSnap.docs) {
      final item = _participantFromUserDoc(
        userDoc: userDocument,
        eventCheckInsByUserId:
            eventCheckInsByUserId,
        sessionJoinedByUserId:
            sessionJoinedByUserId,
        assignedSessionsByUserId:
            assignedSessionsByUserId,
        assignedRoleByUserId: assignedRoleByUserId,
        generatedCertificatesByUserId:
            generatedCertificatesByUserId,
      );

      participantsMap[item.userId] = item;
    }

    for (final assignedUserId
        in assignedRoleByUserId.keys) {
      if (participantsMap
          .containsKey(assignedUserId)) {
        continue;
      }

      final userDocument = await _firestore
          .collection('users')
          .doc(assignedUserId)
          .get();

      if (!userDocument.exists) continue;

      final item = _participantFromUserDoc(
        userDoc: userDocument,
        eventCheckInsByUserId:
            eventCheckInsByUserId,
        sessionJoinedByUserId:
            sessionJoinedByUserId,
        assignedSessionsByUserId:
            assignedSessionsByUserId,
        assignedRoleByUserId: assignedRoleByUserId,
        generatedCertificatesByUserId:
            generatedCertificatesByUserId,
      );

      participantsMap[item.userId] = item;
    }

    final participants =
        participantsMap.values.toList()
          ..sort((a, b) {
            if (a.isAttendee != b.isAttendee) {
              return a.isAttendee ? -1 : 1;
            }

            if (a.isAttendee && b.isAttendee) {
              if (a.hasEventCheckIn !=
                  b.hasEventCheckIn) {
                return a.hasEventCheckIn ? -1 : 1;
              }
            }

            final roleCompare = a.displayRole
                .compareTo(b.displayRole);

            if (roleCompare != 0) {
              return roleCompare;
            }

            return a.name
                .toLowerCase()
                .compareTo(b.name.toLowerCase());
          });

    return _AttendanceReportData(
      participants: participants,
      certificateGenerationUnlocked:
          certificateGenerationUnlocked,
    );
  }

  _ParticipantAttendanceItem _participantFromUserDoc({
    required DocumentSnapshot<Map<String, dynamic>>
        userDoc,
    required Map<String, DateTime?>
        eventCheckInsByUserId,
    required Map<String, List<String>>
        sessionJoinedByUserId,
    required Map<String, List<_AssignedSessionItem>>
        assignedSessionsByUserId,
    required Map<String, String>
        assignedRoleByUserId,
    required Map<String, List<CertificateModel>>
        generatedCertificatesByUserId,
  }) {
    final data = userDoc.data() ?? {};
    final userId = userDoc.id;

    final name = (data['name'] ??
            data['fullName'] ??
            data['displayName'] ??
            'Unnamed User')
        .toString();

    final email =
        (data['email'] ?? '').toString();

    final savedRole = _normalizeRole(
      (data['role'] ?? 'attendee').toString(),
    );

    final role =
        assignedRoleByUserId[userId] ?? savedRole;

    return _ParticipantAttendanceItem(
      userId: userId,
      name: name,
      email: email,
      role: role,
      hasEventCheckIn:
          eventCheckInsByUserId.containsKey(userId),
      eventCheckInAt:
          eventCheckInsByUserId[userId],
      sessionsJoined:
          sessionJoinedByUserId[userId] ?? const [],
      assignedSessions:
          assignedSessionsByUserId[userId] ??
              const [],
      generatedCertificates:
          generatedCertificatesByUserId[userId] ??
              const [],
    );
  }

  void _collectAssignedUsers({
    required Map<String, dynamic> sessionData,
    required String sessionId,
    required String sessionTitle,
    required String role,
    required List<String> listKeys,
    required List<String> singleKeys,
    required Map<String, List<_AssignedSessionItem>>
        assignedSessionsByUserId,
    required Map<String, String>
        assignedRoleByUserId,
  }) {
    final userIds = <String>{};

    for (final key in listKeys) {
      final value = sessionData[key];

      if (value is List) {
        for (final item in value) {
          final userId = item.toString().trim();
          if (userId.isNotEmpty) {
            userIds.add(userId);
          }
        }
      }
    }

    for (final key in singleKeys) {
      final userId =
          (sessionData[key] ?? '').toString().trim();

      if (userId.isNotEmpty) {
        userIds.add(userId);
      }
    }

    for (final userId in userIds) {
      assignedRoleByUserId[userId] = role;
      assignedSessionsByUserId.putIfAbsent(
        userId,
        () => <_AssignedSessionItem>[],
      );

      final alreadyAdded =
          assignedSessionsByUserId[userId]!.any(
        (session) =>
            session.sessionId == sessionId,
      );

      if (!alreadyAdded) {
        assignedSessionsByUserId[userId]!.add(
          _AssignedSessionItem(
            sessionId: sessionId,
            sessionTitle: sessionTitle,
            role: role,
          ),
        );
      }
    }
  }

  Future<void> _readSessionCheckins({
    required DocumentReference<Map<String, dynamic>>
        sessionRef,
    required String sessionTitle,
    required Map<String, List<String>>
        sessionJoinedByUserId,
    required String collectionName,
  }) async {
    try {
      final snapshot =
          await sessionRef.collection(collectionName).get();

      for (final document in snapshot.docs) {
        final data = document.data();

        final userId = (data['userId'] ??
                data['uid'] ??
                data['attendeeId'] ??
                document.id)
            .toString()
            .trim();

        if (userId.isEmpty) continue;

        sessionJoinedByUserId.putIfAbsent(
          userId,
          () => <String>[],
        );

        if (!sessionJoinedByUserId[userId]!
            .contains(sessionTitle)) {
          sessionJoinedByUserId[userId]!
              .add(sessionTitle);
        }
      }
    } catch (_) {}
  }
}

class _AttendanceReportData {
  final List<_ParticipantAttendanceItem> participants;
  final bool certificateGenerationUnlocked;

  const _AttendanceReportData({
    required this.participants,
    required this.certificateGenerationUnlocked,
  });

  factory _AttendanceReportData.empty() {
    return const _AttendanceReportData(
      participants: [],
      certificateGenerationUnlocked: false,
    );
  }

  List<_ParticipantAttendanceItem> get attendees {
    return participants
        .where((participant) => participant.isAttendee)
        .toList();
  }

  int get totalAttendees => attendees.length;

  int get totalCheckedInAttendees {
    return attendees
        .where(
          (participant) =>
              participant.hasEventCheckIn,
        )
        .length;
  }

  int get totalAbsentAttendees =>
      totalAttendees - totalCheckedInAttendees;

  int get totalGeneratedCertificates {
    if (!certificateGenerationUnlocked) return 0;

    return participants
        .where(
          (participant) =>
              participant.hasGeneratedCertificate,
        )
        .length;
  }
}

class _AssignedSessionItem {
  final String sessionId;
  final String sessionTitle;
  final String role;

  const _AssignedSessionItem({
    required this.sessionId,
    required this.sessionTitle,
    required this.role,
  });
}

class _ParticipantAttendanceItem {
  final String userId;
  final String name;
  final String email;
  final String role;
  final bool hasEventCheckIn;
  final DateTime? eventCheckInAt;
  final List<String> sessionsJoined;
  final List<_AssignedSessionItem> assignedSessions;
  final List<CertificateModel> generatedCertificates;

  const _ParticipantAttendanceItem({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    required this.hasEventCheckIn,
    required this.eventCheckInAt,
    required this.sessionsJoined,
    this.assignedSessions = const [],
    this.generatedCertificates = const [],
  });

  String get normalizedRole =>
      _normalizeRole(role);

  bool get isAttendee =>
      normalizedRole == 'attendee';

  bool get isSpeaker =>
      normalizedRole == 'speaker';

  bool get isModerator =>
      normalizedRole == 'moderator';

  bool get isStaff =>
      normalizedRole == 'staff';

  bool get isCertificateEligible {
    return (isAttendee && hasEventCheckIn) ||
        isSpeaker ||
        isModerator ||
        isStaff;
  }

  CertificateModel? get generatedCertificate {
    for (final certificate
        in generatedCertificates) {
      if (certificate.normalizedRole ==
              normalizedRole ||
          certificate.normalizedTemplateRole ==
              normalizedRole) {
        return certificate;
      }
    }

    return generatedCertificates.isEmpty
        ? null
        : generatedCertificates.first;
  }

  bool get hasGeneratedCertificate =>
      generatedCertificate != null;

  String get displayRole =>
      _displayRole(normalizedRole);
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(
      color: AdminWebTheme.border,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.025),
        blurRadius: 14,
        offset: const Offset(0, 5),
      ),
    ],
  );
}

String _normalizeRole(String role) {
  final value = role.trim().toLowerCase();

  if (value == 'delegate' ||
      value == 'participant' ||
      value == 'user') {
    return 'attendee';
  }

  if (value == 'volunteer' ||
      value == 'employee' ||
      value == 'crew') {
    return 'staff';
  }

  if (value == 'speaker_user' ||
      value == 'speaker user' ||
      value == 'speaker-user') {
    return 'speaker';
  }

  if (value == 'moderator_user' ||
      value == 'moderator user' ||
      value == 'moderator-user' ||
      value == 'mod') {
    return 'moderator';
  }

  if (value == 'administrator' ||
      value == 'admins') {
    return 'admin';
  }

  return value.isEmpty ? 'attendee' : value;
}

String _displayRole(String role) {
  switch (_normalizeRole(role)) {
    case 'attendee':
      return 'Attendee';
    case 'speaker':
      return 'Speaker';
    case 'moderator':
      return 'Moderator';
    case 'staff':
      return 'Staff / Volunteer';
    case 'admin':
      return 'Admin';
    default:
      final clean = role.trim();
      if (clean.isEmpty) return 'User';
      return '${clean[0].toUpperCase()}${clean.substring(1)}';
  }
}

DateTime? _readDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

String _formatDateTime(DateTime date) {
  return '${_formatDate(date)} • ${_formatTime(date)}';
}

String _formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _formatTime(DateTime date) {
  final hour = date.hour;
  final minute =
      date.minute.toString().padLeft(2, '0');
  final suffix = hour >= 12 ? 'PM' : 'AM';
  final displayHour =
      hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);

  return '$displayHour:$minute $suffix';
}
