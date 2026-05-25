import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/models/certificate_model.dart';
import 'package:events_app_trueattempt/core/services/certificate_service.dart';
import 'package:events_app_trueattempt/features/certificates/screen/certificate_preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EventAttendanceReportScreen extends StatefulWidget {
  final String eventId;
  final String eventName;

  const EventAttendanceReportScreen({
    super.key,
    required this.eventId,
    required this.eventName,
  });

  @override
  State<EventAttendanceReportScreen> createState() =>
      _EventAttendanceReportScreenState();
}

class _EventAttendanceReportScreenState
    extends State<EventAttendanceReportScreen> {
  late Future<_AttendanceReportData> _attendanceFuture;

  final TextEditingController _searchController = TextEditingController();
  final CertificateService _certificateService = CertificateService();

  String _searchQuery = '';
  bool _isCopyingCsv = false;
  bool _isGeneratingCertificates = false;

  @override
  void initState() {
    super.initState();
    _attendanceFuture =
        _AttendanceReportRepository().getAttendanceData(widget.eventId);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _attendanceFuture =
          _AttendanceReportRepository().getAttendanceData(widget.eventId);
    });
  }

  List<_ParticipantAttendanceItem> _filterParticipants(
    List<_ParticipantAttendanceItem> participants,
  ) {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) return participants;

    return participants.where((participant) {
      return participant.name.toLowerCase().contains(query) ||
          participant.email.toLowerCase().contains(query) ||
          participant.role.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _copyCsv(_AttendanceReportData data) async {
    if (_isCopyingCsv) return;

    try {
      setState(() => _isCopyingCsv = true);

      final csv = _buildCsv(data);

      await Clipboard.setData(
        ClipboardData(text: csv),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Attendance CSV copied. Paste it into Excel or Google Sheets.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to copy CSV: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCopyingCsv = false);
      }
    }
  }

  Future<void> _generateCertificates(_AttendanceReportData data) async {
    if (_isGeneratingCertificates) return;

    try {
      setState(() => _isGeneratingCertificates = true);

      final presentAttendees = data.participants
          .where(
            (participant) =>
                participant.isAttendee && participant.hasEventCheckIn,
          )
          .map(
            (participant) => {
              'userId': participant.userId,
              'userName': participant.name,
              'userEmail': participant.email,
            },
          )
          .toList();

      final result = await _certificateService.generateAllEligibleCertificates(
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
          'generatedBy': 'admin',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Certificates generated: ${result['total']} total (${result['attendees']} attendees, ${result['speakers']} speakers).',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      _refresh();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate certificates: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isGeneratingCertificates = false);
      }
    }
  }

  CertificateModel _getExistingCertificate(
    _ParticipantAttendanceItem participant,
    bool certificateGenerationUnlocked,
  ) {
    if (!participant.isCertificateEligible) {
      throw Exception('This user is not eligible for a certificate.');
    }

    if (!certificateGenerationUnlocked) {
      throw Exception(
        'Certificates are locked. Click Generate Certificates first.',
      );
    }

    if (!participant.hasGeneratedCertificate) {
      throw Exception(
        'Certificate document not found. Click Generate Certificates again.',
      );
    }

    return participant.generatedCertificates.first;
  }

  Future<void> _openCertificate(
    _ParticipantAttendanceItem participant,
    bool certificateGenerationUnlocked, {
    required bool downloadOnly,
  }) async {
    try {
      final certificate = _getExistingCertificate(
        participant,
        certificateGenerationUnlocked,
      );

      if (!mounted) return;

      if (downloadOnly) {
        await CertificatePreviewScreen.downloadCertificatePdf(
          context: context,
          certificate: certificate,
          eventName: widget.eventName,
        );
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CertificatePreviewScreen(
            certificate: certificate,
            eventName: widget.eventName,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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

    for (int i = 0; i < data.participants.length; i++) {
      final participant = data.participants[i];

      String attendanceStatus = 'Not Required';

      if (participant.isAttendee) {
        attendanceStatus = participant.hasEventCheckIn ? 'Present' : 'Absent';
      }

      String certificateStatus = 'Not Eligible';

      if (participant.isCertificateEligible) {
        if (!data.certificateGenerationUnlocked) {
          certificateStatus = 'Locked';
        } else if (participant.hasGeneratedCertificate) {
          certificateStatus = 'Generated';
        } else {
          certificateStatus = 'Missing Certificate Document';
        }
      }

      buffer.writeln(
        [
          '${i + 1}',
          participant.name,
          participant.email,
          participant.role,
          attendanceStatus,
          certificateStatus,
          participant.eventCheckInAt == null
              ? ''
              : _formatDateTime(participant.eventCheckInAt!),
          participant.sessionsJoined.length.toString(),
          participant.sessionsJoined.join(' | '),
        ].map(_csvCell).join(','),
      );
    }

    return buffer.toString();
  }

  String _csvCell(String value) {
    final safeValue = value.replaceAll('"', '""');
    return '"$safeValue"';
  }

  Widget _header() {
    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.of(context).pop(),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 32,
            width: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F2FB),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.namaNavyBlue,
              size: 14,
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Attendance Report',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.namaNavyBlue,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        InkWell(
          onTap: _refresh,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 32,
            width: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F2FB),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.refresh_rounded,
              color: AppColors.namaNavyBlue,
              size: 18,
            ),
          ),
        ),
      ],
    );
  }

  Widget _eventCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.namaNavyBlue,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Event Attendance List',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Certificates stay locked until admin clicks Generate Certificates. Present attendees and assigned speakers are eligible. Absent attendees are not eligible.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBox() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE4E0F2),
        ),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() => _searchQuery = value);
        },
        cursorColor: AppColors.namaNavyBlue,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.namaDarkGray,
        ),
        decoration: const InputDecoration(
          prefixIcon: Icon(
            Icons.search_rounded,
            color: AppColors.namaMediumGray,
            size: 20,
          ),
          hintText: 'Search by name, email, or role',
          hintStyle: TextStyle(
            fontSize: 12,
            color: AppColors.namaMediumGray,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }

  Widget _summaryCards(_AttendanceReportData data) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                title: 'Attendees',
                value: data.totalAttendees.toString(),
                icon: Icons.groups_rounded,
                color: AppColors.namaNavyBlue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryCard(
                title: 'Present',
                value: data.totalCheckedInAttendees.toString(),
                icon: Icons.how_to_reg_rounded,
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                title: 'Absent',
                value: data.totalAbsentAttendees.toString(),
                icon: Icons.person_off_outlined,
                color: Colors.red,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryCard(
                title: 'Certificates',
                value: data.certificateGenerationUnlocked
                    ? data.totalGeneratedCertificates.toString()
                    : 'Locked',
                icon: Icons.workspace_premium_rounded,
                color: AppColors.namaGoldenYellow,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _copyCsvButton(_AttendanceReportData data) {
    return SizedBox(
      height: 44,
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isCopyingCsv ? null : () => _copyCsv(data),
        icon: _isCopyingCsv
            ? const SizedBox(
                height: 17,
                width: 17,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.table_chart_outlined, size: 18),
        label: Text(
          _isCopyingCsv ? 'Copying CSV...' : 'Copy Attendance CSV',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.namaNavyBlue,
          disabledBackgroundColor: AppColors.namaNavyBlue.withOpacity(0.55),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  Widget _generateCertificatesButton(_AttendanceReportData data) {
    return SizedBox(
      height: 44,
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isGeneratingCertificates
            ? null
            : () => _generateCertificates(data),
        icon: _isGeneratingCertificates
            ? const SizedBox(
                height: 17,
                width: 17,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(
                data.certificateGenerationUnlocked
                    ? Icons.lock_open_rounded
                    : Icons.workspace_premium_rounded,
                size: 18,
              ),
        label: Text(
          _isGeneratingCertificates
              ? 'Generating Certificates...'
              : data.certificateGenerationUnlocked
                  ? 'Certificates Generated'
                  : 'Generate Certificates',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.namaGoldenYellow,
          disabledBackgroundColor: AppColors.namaGoldenYellow.withOpacity(0.55),
          foregroundColor: AppColors.namaNavyBlue,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  Widget _participantsSection({
    required String title,
    required List<_ParticipantAttendanceItem> participants,
    required IconData icon,
    required Color color,
    required bool showAttendanceStatus,
    required bool showCertificateActions,
    required bool certificateGenerationUnlocked,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                '$title (${participants.length})',
                style: const TextStyle(
                  color: AppColors.namaNavyBlue,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (participants.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: _cardDecoration(),
            child: const Text(
              'No users found.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.namaMediumGray,
                fontSize: 12,
              ),
            ),
          )
        else
          Column(
            children: participants.map((participant) {
              return _ParticipantCard(
                participant: participant,
                showAttendanceStatus: showAttendanceStatus,
                showCertificateActions: showCertificateActions,
                certificateGenerationUnlocked: certificateGenerationUnlocked,
                onViewCertificate: () => _openCertificate(
                  participant,
                  certificateGenerationUnlocked,
                  downloadOnly: false,
                ),
                onDownloadCertificate: () => _openCertificate(
                  participant,
                  certificateGenerationUnlocked,
                  downloadOnly: true,
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.namaLightGray,
      body: SafeArea(
        child: FutureBuilder<_AttendanceReportData>(
          future: _attendanceFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppColors.namaNavyBlue,
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Colors.red,
                        size: 34,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Unable to load attendance report',
                        style: TextStyle(
                          color: AppColors.namaNavyBlue,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.namaMediumGray,
                          fontSize: 11.5,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton(
                        onPressed: _refresh,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.namaNavyBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final data = snapshot.data ?? _AttendanceReportData.empty();

            final filteredParticipants = _filterParticipants(data.participants);

            final checkedInAttendees = filteredParticipants
                .where(
                  (participant) =>
                      participant.isAttendee && participant.hasEventCheckIn,
                )
                .toList();

            final absentAttendees = filteredParticipants
                .where(
                  (participant) =>
                      participant.isAttendee && !participant.hasEventCheckIn,
                )
                .toList();

            final otherUsers = filteredParticipants
                .where((participant) => !participant.isAttendee)
                .toList();

            return RefreshIndicator(
              color: AppColors.namaNavyBlue,
              onRefresh: () async => _refresh(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                children: [
                  _header(),
                  const SizedBox(height: 18),
                  _eventCard(),
                  const SizedBox(height: 16),
                  _summaryCards(data),
                  const SizedBox(height: 16),
                  _copyCsvButton(data),
                  const SizedBox(height: 10),
                  _generateCertificatesButton(data),
                  const SizedBox(height: 14),
                  _searchBox(),
                  const SizedBox(height: 20),
                  _participantsSection(
                    title: 'Present Attendees',
                    participants: checkedInAttendees,
                    icon: Icons.check_circle_outline_rounded,
                    color: Colors.green,
                    showAttendanceStatus: true,
                    showCertificateActions: true,
                    certificateGenerationUnlocked:
                        data.certificateGenerationUnlocked,
                  ),
                  const SizedBox(height: 18),
                  _participantsSection(
                    title: 'Absent Attendees',
                    participants: absentAttendees,
                    icon: Icons.cancel_outlined,
                    color: Colors.red,
                    showAttendanceStatus: true,
                    showCertificateActions: true,
                    certificateGenerationUnlocked:
                        data.certificateGenerationUnlocked,
                  ),
                  const SizedBox(height: 18),
                  _participantsSection(
                    title: 'Speakers, Staff & Admins',
                    participants: otherUsers,
                    icon: Icons.badge_outlined,
                    color: AppColors.namaNavyBlue,
                    showAttendanceStatus: false,
                    showCertificateActions: true,
                    certificateGenerationUnlocked:
                        data.certificateGenerationUnlocked,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AttendanceReportRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<_AttendanceReportData> getAttendanceData(String eventId) async {
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

    final mergedSessions =
        <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

    for (final doc in topLevelSessionsSnap.docs) {
      mergedSessions[doc.reference.path] = doc;
    }

    for (final doc in eventSubSessionsSnap.docs) {
      mergedSessions[doc.reference.path] = doc;
    }

    final generatedCertificatesByUserId = <String, List<CertificateModel>>{};

    for (final doc in certificatesSnap.docs) {
      final data = doc.data();
      final userId = (data['userId'] ?? '').toString().trim();

      if (userId.isEmpty) continue;

      generatedCertificatesByUserId.putIfAbsent(
        userId,
        () => <CertificateModel>[],
      );

      generatedCertificatesByUserId[userId]!.add(
        CertificateModel.fromFirestore(doc),
      );
    }

    final eventCheckInsByUserId = <String, DateTime?>{};

    for (final doc in eventAttendanceSnap.docs) {
      final data = doc.data();
      final userId = (data['userId'] ?? doc.id).toString().trim();

      eventCheckInsByUserId[userId] = _readDate(
        data['checkedInAt'] ?? data['timestamp'] ?? data['createdAt'],
      );
    }

    final sessionJoinedByUserId = <String, List<String>>{};
    final speakerSessionsByUserId = <String, List<_SpeakerSessionItem>>{};

    for (final sessionDoc in mergedSessions.values) {
      final sessionData = sessionDoc.data();

      final sessionId = sessionDoc.id;
      final sessionTitle =
          (sessionData['title'] ?? 'Untitled Session').toString();

      final speakerIds = List<String>.from(
        sessionData['speakerIds'] as List? ?? [],
      );

      for (final speakerId in speakerIds) {
        final cleanSpeakerId = speakerId.toString().trim();

        if (cleanSpeakerId.isEmpty) continue;

        speakerSessionsByUserId.putIfAbsent(
          cleanSpeakerId,
          () => <_SpeakerSessionItem>[],
        );

        final alreadyAdded = speakerSessionsByUserId[cleanSpeakerId]!.any(
          (session) => session.sessionId == sessionId,
        );

        if (!alreadyAdded) {
          speakerSessionsByUserId[cleanSpeakerId]!.add(
            _SpeakerSessionItem(
              sessionId: sessionId,
              sessionTitle: sessionTitle,
            ),
          );
        }
      }

      final checkedInAttendees =
          List<String>.from(sessionData['checkedInAttendees'] as List? ?? []);

      for (final userId in checkedInAttendees) {
        sessionJoinedByUserId.putIfAbsent(userId, () => <String>[]);

        if (!sessionJoinedByUserId[userId]!.contains(sessionTitle)) {
          sessionJoinedByUserId[userId]!.add(sessionTitle);
        }
      }

      await _readSessionCheckins(
        sessionRef: sessionDoc.reference,
        sessionTitle: sessionTitle,
        sessionJoinedByUserId: sessionJoinedByUserId,
        collectionName: 'checkins',
      );

      await _readSessionCheckins(
        sessionRef: sessionDoc.reference,
        sessionTitle: sessionTitle,
        sessionJoinedByUserId: sessionJoinedByUserId,
        collectionName: 'checkIns',
      );
    }

    final participantsMap = <String, _ParticipantAttendanceItem>{};

    for (final userDoc in registeredUsersSnap.docs) {
      final item = _participantFromUserDoc(
        userDoc: userDoc,
        eventCheckInsByUserId: eventCheckInsByUserId,
        sessionJoinedByUserId: sessionJoinedByUserId,
        speakerSessionsByUserId: speakerSessionsByUserId,
        generatedCertificatesByUserId: generatedCertificatesByUserId,
      );

      participantsMap[item.userId] = item;
    }

    for (final speakerId in speakerSessionsByUserId.keys) {
      if (participantsMap.containsKey(speakerId)) continue;

      final speakerDoc =
          await _firestore.collection('users').doc(speakerId).get();

      if (!speakerDoc.exists) continue;

      final item = _participantFromUserDoc(
        userDoc: speakerDoc,
        eventCheckInsByUserId: eventCheckInsByUserId,
        sessionJoinedByUserId: sessionJoinedByUserId,
        speakerSessionsByUserId: speakerSessionsByUserId,
        generatedCertificatesByUserId: generatedCertificatesByUserId,
      );

      participantsMap[item.userId] = item;
    }

    final participants = participantsMap.values.toList();

    participants.sort((a, b) {
      if (a.isAttendee != b.isAttendee) {
        return a.isAttendee ? -1 : 1;
      }

      if (a.isAttendee && b.isAttendee) {
        if (a.hasEventCheckIn != b.hasEventCheckIn) {
          return a.hasEventCheckIn ? -1 : 1;
        }
      }

      final roleCompare = a.role.toLowerCase().compareTo(b.role.toLowerCase());

      if (roleCompare != 0 && !a.isAttendee && !b.isAttendee) {
        return roleCompare;
      }

      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return _AttendanceReportData(
      participants: participants,
      certificateGenerationUnlocked: certificateGenerationUnlocked,
    );
  }

  _ParticipantAttendanceItem _participantFromUserDoc({
    required DocumentSnapshot<Map<String, dynamic>> userDoc,
    required Map<String, DateTime?> eventCheckInsByUserId,
    required Map<String, List<String>> sessionJoinedByUserId,
    required Map<String, List<_SpeakerSessionItem>> speakerSessionsByUserId,
    required Map<String, List<CertificateModel>> generatedCertificatesByUserId,
  }) {
    final data = userDoc.data() ?? {};
    final userId = userDoc.id;

    final name = (data['name'] ??
            data['fullName'] ??
            data['displayName'] ??
            'Unnamed User')
        .toString();

    final email = (data['email'] ?? '').toString();

    final rawRole = (data['role'] ?? 'attendee').toString();
    final role = rawRole.trim().isEmpty ? 'attendee' : rawRole.trim();

    final sessionsJoined = sessionJoinedByUserId[userId] ?? <String>[];
    final speakerSessions =
        speakerSessionsByUserId[userId] ?? <_SpeakerSessionItem>[];

    final generatedCertificates =
        generatedCertificatesByUserId[userId] ?? <CertificateModel>[];

    return _ParticipantAttendanceItem(
      userId: userId,
      name: name,
      email: email,
      role: role,
      hasEventCheckIn: eventCheckInsByUserId.containsKey(userId),
      eventCheckInAt: eventCheckInsByUserId[userId],
      sessionsJoined: sessionsJoined,
      speakerSessions: speakerSessions,
      generatedCertificates: generatedCertificates,
    );
  }

  Future<void> _readSessionCheckins({
    required DocumentReference<Map<String, dynamic>> sessionRef,
    required String sessionTitle,
    required Map<String, List<String>> sessionJoinedByUserId,
    required String collectionName,
  }) async {
    try {
      final checkinsSnap = await sessionRef.collection(collectionName).get();

      for (final doc in checkinsSnap.docs) {
        final data = doc.data();

        final userId =
            (data['userId'] ?? data['uid'] ?? data['attendeeId'] ?? doc.id)
                .toString()
                .trim();

        if (userId.isEmpty) continue;

        sessionJoinedByUserId.putIfAbsent(userId, () => <String>[]);

        if (!sessionJoinedByUserId[userId]!.contains(sessionTitle)) {
          sessionJoinedByUserId[userId]!.add(sessionTitle);
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
    return participants.where((participant) => participant.isAttendee).toList();
  }

  int get totalAttendees => attendees.length;

  int get totalCheckedInAttendees {
    return attendees.where((participant) => participant.hasEventCheckIn).length;
  }

  int get totalAbsentAttendees => totalAttendees - totalCheckedInAttendees;

  int get totalGeneratedCertificates {
    if (!certificateGenerationUnlocked) return 0;

    return participants
        .where((participant) => participant.hasGeneratedCertificate)
        .length;
  }
}

class _SpeakerSessionItem {
  final String sessionId;
  final String sessionTitle;

  const _SpeakerSessionItem({
    required this.sessionId,
    required this.sessionTitle,
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
  final List<_SpeakerSessionItem> speakerSessions;
  final List<CertificateModel> generatedCertificates;

  const _ParticipantAttendanceItem({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    required this.hasEventCheckIn,
    required this.eventCheckInAt,
    required this.sessionsJoined,
    this.speakerSessions = const [],
    this.generatedCertificates = const [],
  });

  bool get isAttendee {
    return role.trim().toLowerCase() == 'attendee';
  }

  bool get isSpeaker {
    return role.trim().toLowerCase() == 'speaker';
  }

  bool get isCertificateEligible {
    return (isAttendee && hasEventCheckIn) || isSpeaker;
  }

  bool get hasGeneratedCertificate {
    return generatedCertificates.isNotEmpty;
  }

  String get displayRole {
    final cleanRole = role.trim();

    if (cleanRole.isEmpty) return 'User';

    return cleanRole[0].toUpperCase() + cleanRole.substring(1).toLowerCase();
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 105,
      padding: const EdgeInsets.all(13),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.namaMediumGray,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticipantCard extends StatelessWidget {
  final _ParticipantAttendanceItem participant;
  final bool showAttendanceStatus;
  final bool showCertificateActions;
  final bool certificateGenerationUnlocked;
  final VoidCallback? onViewCertificate;
  final VoidCallback? onDownloadCertificate;

  const _ParticipantCard({
    required this.participant,
    required this.showAttendanceStatus,
    required this.showCertificateActions,
    required this.certificateGenerationUnlocked,
    this.onViewCertificate,
    this.onDownloadCertificate,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = participant.hasEventCheckIn ? Colors.green : Colors.red;
    final defaultColor = AppColors.namaNavyBlue;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: showAttendanceStatus
                    ? statusColor.withOpacity(0.12)
                    : defaultColor.withOpacity(0.10),
                child: Icon(
                  showAttendanceStatus
                      ? participant.hasEventCheckIn
                          ? Icons.check_rounded
                          : Icons.close_rounded
                      : Icons.person_outline_rounded,
                  color: showAttendanceStatus ? statusColor : defaultColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  participant.name,
                  style: const TextStyle(
                    color: AppColors.namaNavyBlue,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (showAttendanceStatus)
                _StatusChip(
                  checkedIn: participant.hasEventCheckIn,
                ),
            ],
          ),
          if (participant.email.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _InfoLine(
              icon: Icons.email_outlined,
              text: participant.email,
            ),
          ],
          const SizedBox(height: 6),
          _InfoLine(
            icon: Icons.badge_outlined,
            text: 'Role: ${participant.displayRole}',
          ),
          if (showAttendanceStatus && participant.eventCheckInAt != null) ...[
            const SizedBox(height: 6),
            _InfoLine(
              icon: Icons.access_time_rounded,
              text:
                  'Checked in: ${_formatDateTime(participant.eventCheckInAt!)}',
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Sessions Joined: ${participant.sessionsJoined.length}',
            style: const TextStyle(
              color: AppColors.namaDarkGray,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (participant.sessionsJoined.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: participant.sessionsJoined.map((sessionTitle) {
                return _SmallChip(text: sessionTitle);
              }).toList(),
            ),
          ],
          if (participant.isSpeaker && participant.speakerSessions.isNotEmpty)
            ...[
              const SizedBox(height: 10),
              const Text(
                'Speaker sessions:',
                style: TextStyle(
                  color: AppColors.namaDarkGray,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: participant.speakerSessions.map((session) {
                  return _SmallChip(text: session.sessionTitle);
                }).toList(),
              ),
            ],
          if (showCertificateActions) ...[
            const SizedBox(height: 12),
            if (participant.isCertificateEligible &&
                certificateGenerationUnlocked &&
                participant.hasGeneratedCertificate)
              Row(
                children: [
                  Expanded(
                    child: _SmallActionButton(
                      label: 'View Certificate',
                      icon: Icons.visibility_outlined,
                      backgroundColor: AppColors.namaNavyBlue,
                      textColor: Colors.white,
                      onTap: onViewCertificate,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SmallActionButton(
                      label: 'Download',
                      icon: Icons.download_rounded,
                      backgroundColor: AppColors.namaGoldenYellow,
                      textColor: AppColors.namaNavyBlue,
                      onTap: onDownloadCertificate,
                    ),
                  ),
                ],
              )
            else if (participant.isCertificateEligible)
              _CertificateLockedBox(
                text: certificateGenerationUnlocked
                    ? 'Certificate document not found. Click Generate Certificates again.'
                    : 'Certificate locked. Click Generate Certificates to unlock.',
              )
            else if (participant.isAttendee)
              const _CertificateLockedBox(
                text: 'Not eligible for certificate',
                isError: true,
              ),
          ],
        ],
      ),
    );
  }
}

class _CertificateLockedBox extends StatelessWidget {
  final String text;
  final bool isError;

  const _CertificateLockedBox({
    required this.text,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isError ? Colors.red : AppColors.namaGoldenYellow;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(0.22),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.block_rounded : Icons.lock_outline_rounded,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isError ? Colors.red : AppColors.namaNavyBlue,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  final String text;

  const _SmallChip({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F2FB),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.namaNavyBlue,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback? onTap;

  const _SmallActionButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 15),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool checkedIn;

  const _StatusChip({
    required this.checkedIn,
  });

  @override
  Widget build(BuildContext context) {
    final color = checkedIn ? Colors.green : Colors.red;
    final text = checkedIn ? 'PRESENT' : 'ABSENT';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: color.withOpacity(0.35),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
        ),
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
          color: AppColors.namaGoldenYellow,
          size: 14,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.namaMediumGray,
              fontSize: 11.5,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.045),
        blurRadius: 12,
        offset: const Offset(0, 5),
      ),
    ],
  );
}

DateTime? _readDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String _formatDateTime(DateTime date) {
  return '${_formatDate(date)} - ${_formatTime(date)}';
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
  final minute = date.minute.toString().padLeft(2, '0');
  final suffix = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour == 0 ? 12 : hour > 12 ? hour - 12 : hour;

  return '$displayHour:$minute $suffix';
}