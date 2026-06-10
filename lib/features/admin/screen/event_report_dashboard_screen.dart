// lib/features/admin/screen/event_report_dashboard_screen.dart

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/features/admin/screen/edit_report_notes_screen.dart';
import 'package:events_app_trueattempt/features/admin/screen/event_attendance_report_screen.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class EventReportDashboardScreen extends StatefulWidget {
  final String eventId;
  final String eventName;

  const EventReportDashboardScreen({
    super.key,
    required this.eventId,
    required this.eventName,
  });

  @override
  State<EventReportDashboardScreen> createState() =>
      _EventReportDashboardScreenState();
}

class _EventReportDashboardScreenState
    extends State<EventReportDashboardScreen> {
  late Future<_EventReportDashboardData> _future;
  bool _isGeneratingPdf = false;

  static const int maxReportPhotos = 10;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  void _refresh() {
    setState(() {
      _future = _loadData();
    });
  }

  Future<_EventReportDashboardData> _loadData() async {
    final firestore = FirebaseFirestore.instance;

    final eventDoc =
        await firestore.collection('events').doc(widget.eventId).get();

    final eventData = eventDoc.data() ?? {};

    final usersSnap = await firestore
        .collection('users')
        .where('eventIds', arrayContains: widget.eventId)
        .get();

    final attendanceSnap = await firestore
        .collection('events')
        .doc(widget.eventId)
        .collection('attendance')
        .get();

    final certificatesSnap = await firestore
        .collection('events')
        .doc(widget.eventId)
        .collection('certificates')
        .get();

    final topSessionsSnap = await firestore
        .collection('sessions')
        .where('eventId', isEqualTo: widget.eventId)
        .get();

    final subSessionsSnap = await firestore
        .collection('events')
        .doc(widget.eventId)
        .collection('sessions')
        .get();

    final feedbackSnap = await firestore
        .collection('events')
        .doc(widget.eventId)
        .collection('feedback')
        .get();

    final topFeedbackSnap = await firestore
        .collection('feedback')
        .where('eventId', isEqualTo: widget.eventId)
        .get();

    final approvedPhotosSnap = await firestore
        .collection('events')
        .doc(widget.eventId)
        .collection('eventPhotos')
        .where('status', isEqualTo: 'approved')
        .get();

    final topPhotosSnap = await firestore
        .collection('eventPhotos')
        .where('eventId', isEqualTo: widget.eventId)
        .where('status', isEqualTo: 'approved')
        .get();

    final registrationsSnap = await firestore
        .collection('events')
        .doc(widget.eventId)
        .collection('registrations')
        .where('includedInReport', isEqualTo: true)
        .get();

    final reportNotesDoc = await firestore
        .collection('events')
        .doc(widget.eventId)
        .collection('reportNotes')
        .doc('main')
        .get();

    int attendeeCount = 0;
    int speakerCount = 0;
    int staffAdminCount = 0;

    for (final doc in usersSnap.docs) {
      final role = (doc.data()['role'] ?? '').toString().trim().toLowerCase();

      if (role == 'attendee') {
        attendeeCount++;
      } else if (role == 'speaker') {
        speakerCount++;
      } else {
        staffAdminCount++;
      }
    }

    final sessionsMap = <String, _SessionReportItem>{};

    for (final doc in topSessionsSnap.docs) {
      sessionsMap[doc.reference.path] = _SessionReportItem.fromDoc(doc);
    }

    for (final doc in subSessionsSnap.docs) {
      sessionsMap[doc.reference.path] = _SessionReportItem.fromDoc(doc);
    }

    final sessions = sessionsMap.values.toList()
      ..sort((a, b) {
        if (a.startTime == null && b.startTime == null) {
          return a.title.compareTo(b.title);
        }

        if (a.startTime == null) return 1;
        if (b.startTime == null) return -1;

        return a.startTime!.compareTo(b.startTime!);
      });

    final feedbackMap = <String, _FeedbackReportItem>{};

    for (final doc in feedbackSnap.docs) {
      feedbackMap[doc.reference.path] = _FeedbackReportItem.fromDoc(doc);
    }

    for (final doc in topFeedbackSnap.docs) {
      feedbackMap[doc.reference.path] = _FeedbackReportItem.fromDoc(doc);
    }

    final feedbacks = feedbackMap.values.toList()
      ..sort((a, b) {
        if (a.createdAt == null && b.createdAt == null) {
          return a.userName.compareTo(b.userName);
        }

        if (a.createdAt == null) return 1;
        if (b.createdAt == null) return -1;

        return b.createdAt!.compareTo(a.createdAt!);
      });

    final photosMap = <String, _EventPhotoReportItem>{};

    for (final doc in approvedPhotosSnap.docs) {
      photosMap[doc.reference.path] = _EventPhotoReportItem.fromDoc(doc);
    }

    for (final doc in topPhotosSnap.docs) {
      photosMap[doc.reference.path] = _EventPhotoReportItem.fromDoc(doc);
    }

    final photos = photosMap.values.toList()
      ..sort((a, b) {
        if (a.uploadedAt == null && b.uploadedAt == null) {
          final userCompare = a.userName.compareTo(b.userName);
          if (userCompare != 0) return userCompare;
          return a.sessionTitle.compareTo(b.sessionTitle);
        }

        if (a.uploadedAt == null) return 1;
        if (b.uploadedAt == null) return -1;

        return b.uploadedAt!.compareTo(a.uploadedAt!);
      });

    final registeredParticipants = registrationsSnap.docs
        .map((doc) => _RegistrationReportItem.fromDoc(doc))
        .toList()
      ..sort((a, b) {
        if (a.registeredAt == null && b.registeredAt == null) {
          return a.name.compareTo(b.name);
        }

        if (a.registeredAt == null) return 1;
        if (b.registeredAt == null) return -1;

        return a.registeredAt!.compareTo(b.registeredAt!);
      });

    final eventStartDate = _readDate(
      eventData['startDate'] ??
          eventData['startTime'] ??
          eventData['eventStartDate'] ??
          eventData['date'],
    );

    final eventEndDate = _readDate(
      eventData['endDate'] ??
          eventData['endTime'] ??
          eventData['eventEndDate'] ??
          eventData['eventEndTime'],
    );

    final reportNotes = _ReportNotes.fromMap(reportNotesDoc.data() ?? {});

    final totalMessages = sessions.fold<int>(
      0,
      (total, session) => total + session.totalMessages,
    );

    final totalSessionCheckIns = sessions.fold<int>(
      0,
      (total, session) => total + session.checkedInCount,
    );

    double overallTotal = 0;
    double sessionQualityTotal = 0;
    double speakerTotal = 0;
    double venueTotal = 0;
    double appTotal = 0;

    for (final feedback in feedbacks) {
      overallTotal += feedback.overallRating;
      sessionQualityTotal += feedback.sessionQualityRating;
      speakerTotal += feedback.speakerRating;
      venueTotal += feedback.venueRating;
      appTotal += feedback.appExperienceRating;
    }

    final feedbackCount = feedbacks.isEmpty ? 0 : feedbacks.length;

    return _EventReportDashboardData(
      eventId: widget.eventId,
      eventName: (eventData['name'] ??
              eventData['title'] ??
              eventData['eventName'] ??
              widget.eventName)
          .toString(),
      description: (eventData['description'] ?? '').toString(),
      location: (eventData['location'] ?? '').toString(),
      startDate: eventStartDate,
      endDate: eventEndDate,
      totalUsers: usersSnap.docs.length,
      attendees: attendeeCount,
      speakers: speakerCount,
      staffAdmins: staffAdminCount,
      present: attendanceSnap.docs.length,
      absent: attendeeCount - attendanceSnap.docs.length < 0
          ? 0
          : attendeeCount - attendanceSnap.docs.length,
      certificates: certificatesSnap.docs.length,
      sessions: sessions,
      feedbacks: feedbacks,
      approvedPhotos: photos,
      registeredParticipants: registeredParticipants,
      totalMessages: totalMessages,
      totalSessionCheckIns: totalSessionCheckIns,
      averageOverallRating:
          feedbackCount == 0 ? 0 : overallTotal / feedbackCount,
      averageSessionQualityRating:
          feedbackCount == 0 ? 0 : sessionQualityTotal / feedbackCount,
      averageSpeakerRating:
          feedbackCount == 0 ? 0 : speakerTotal / feedbackCount,
      averageVenueRating: feedbackCount == 0 ? 0 : venueTotal / feedbackCount,
      averageAppExperienceRating:
          feedbackCount == 0 ? 0 : appTotal / feedbackCount,
      reportNotes: reportNotes,
    );
  }

  Future<void> _openEditReportNotes() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditReportNotesScreen(
          eventId: widget.eventId,
          eventName: widget.eventName,
        ),
      ),
    );

    if (result == true) {
      _refresh();
    }
  }

  void _openAttendanceDetails() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventAttendanceReportScreen(
          eventId: widget.eventId,
          eventName: widget.eventName,
        ),
      ),
    );
  }

  Future<void> _generatePdf(_EventReportDashboardData data) async {
    if (_isGeneratingPdf) return;

    try {
      setState(() => _isGeneratingPdf = true);

      final bytes = await _EventReportPdfGenerator.build(data);

      final safeName = data.eventName
          .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
          .replaceAll(RegExp(r'_+'), '_');

      await Printing.sharePdf(
        bytes: bytes,
        filename: '${safeName}_event_report.pdf',
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate PDF: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  List<_EventPhotoGroup> _groupPhotosForReport(
    List<_EventPhotoReportItem> photos,
  ) {
    final limitedPhotos = photos.take(maxReportPhotos).toList();
    final groupsMap = <String, _EventPhotoGroup>{};

    for (final photo in limitedPhotos) {
      final userKey = photo.userEmail.trim().isNotEmpty
          ? photo.userEmail.trim().toLowerCase()
          : photo.userName.trim().toLowerCase();

      final key = '$userKey-${photo.sessionTitle.trim().toLowerCase()}';

      if (!groupsMap.containsKey(key)) {
        groupsMap[key] = _EventPhotoGroup(
          userName: photo.userName,
          userEmail: photo.userEmail,
          sessionTitle: photo.sessionTitle,
          photos: [],
        );
      }

      groupsMap[key]!.photos.add(photo);
    }

    return groupsMap.values.toList();
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
            'Event Report Dashboard',
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

  Widget _overviewCard(_EventReportDashboardData data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.namaNavyBlue,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Report Overview',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            data.eventName,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          if (data.dateText.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              data.dateText,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11.5,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            data.description.trim().isEmpty
                ? 'View event attendance, certificates, feedback, photos, notes, and full report details.'
                : data.description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCards(_EventReportDashboardData data) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Total Users',
                value: data.totalUsers.toString(),
                icon: Icons.people_alt_outlined,
                color: AppColors.namaNavyBlue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                title: 'Attendees',
                value: data.attendees.toString(),
                icon: Icons.groups_rounded,
                color: AppColors.namaGoldenYellow,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Present',
                value: data.present.toString(),
                icon: Icons.how_to_reg_rounded,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                title: 'Absent',
                value: data.absent.toString(),
                icon: Icons.person_off_outlined,
                color: Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Speakers',
                value: data.speakers.toString(),
                icon: Icons.record_voice_over_rounded,
                color: AppColors.namaNavyBlue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                title: 'Certificates',
                value: data.certificates.toString(),
                icon: Icons.workspace_premium_rounded,
                color: AppColors.namaGoldenYellow,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _reportActions() {
    return Column(
      children: [
        _ActionCard(
          icon: Icons.fact_check_outlined,
          title: 'Attendance Details',
          subtitle:
              'View present attendees, absent attendees, speakers, staff, admins, and certificate status.',
          color: AppColors.namaGoldenYellow,
          onTap: _openAttendanceDetails,
        ),
        _ActionCard(
          icon: Icons.edit_note_rounded,
          title: 'Edit Report Notes',
          subtitle:
              'Add objectives, highlights, outcomes, challenges, recommendations, and conclusion.',
          color: AppColors.namaNavyBlue,
          onTap: _openEditReportNotes,
        ),
      ],
    );
  }

  Widget _detailsSection(_EventReportDashboardData data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _MetricRow(
            label: 'Total Sessions',
            value: data.sessions.length.toString(),
          ),
          _MetricRow(
            label: 'Feedback Responses',
            value: data.feedbacks.length.toString(),
          ),
          _MetricRow(
            label: 'Approved Photos',
            value: data.approvedPhotos.length.toString(),
          ),
          _MetricRow(
            label: 'Registered Participants',
            value: data.registeredParticipants.length.toString(),
          ),
          _MetricRow(
            label: 'Report Photos Limit',
            value:
                '${data.approvedPhotos.take(maxReportPhotos).length}/$maxReportPhotos',
          ),
          _MetricRow(
            label: 'Staff & Admins',
            value: data.staffAdmins.toString(),
          ),
          _MetricRow(
            label: 'Attendance Rate',
            value: '${data.attendanceRate}%',
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _reportNotesSection(_EventReportDashboardData data) {
    if (!data.reportNotes.hasContent) {
      return _EmptyCard(
        icon: Icons.edit_note_rounded,
        title: 'No report notes yet',
        subtitle:
            'Add report notes to include objectives, outcomes, challenges, and recommendations.',
        actionText: 'Add Notes',
        onActionTap: _openEditReportNotes,
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NoteBlock(
            title: 'Event Objectives',
            value: data.reportNotes.eventObjectives,
          ),
          _NoteBlock(
            title: 'Key Highlights',
            value: data.reportNotes.keyHighlights,
          ),
          _NoteBlock(
            title: 'Main Outcomes',
            value: data.reportNotes.mainOutcomes,
          ),
          _NoteBlock(
            title: 'Challenges',
            value: data.reportNotes.challenges,
          ),
          _NoteBlock(
            title: 'Recommendations',
            value: data.reportNotes.recommendations,
          ),
          _NoteBlock(
            title: 'Conclusion',
            value: data.reportNotes.conclusion,
          ),
        ],
      ),
    );
  }

  Widget _sessionsSection(_EventReportDashboardData data) {
    if (data.sessions.isEmpty) {
      return const _EmptyCard(
        icon: Icons.event_busy_rounded,
        title: 'No sessions found',
        subtitle: 'Sessions created for this event will appear here.',
      );
    }

    return Column(
      children: data.sessions.map((session) {
        return _SessionCard(session: session);
      }).toList(),
    );
  }

  Widget _engagementSection(_EventReportDashboardData data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _MetricRow(
            label: 'Session Check-ins',
            value: data.totalSessionCheckIns.toString(),
          ),
          _MetricRow(
            label: 'Chat Messages',
            value: data.totalMessages.toString(),
          ),
          _MetricRow(
            label: 'Feedback Responses',
            value: data.feedbacks.length.toString(),
          ),
          _MetricRow(
            label: 'Approved Photos',
            value: data.approvedPhotos.length.toString(),
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _feedbackSummarySection(_EventReportDashboardData data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _MetricRow(
            label: 'Total Feedback Responses',
            value: data.feedbacks.length.toString(),
          ),
          _MetricRow(
            label: 'Average Overall Rating',
            value: _formatRating(data.averageOverallRating),
          ),
          _MetricRow(
            label: 'Average Session Quality',
            value: _formatRating(data.averageSessionQualityRating),
          ),
          _MetricRow(
            label: 'Average Speaker Rating',
            value: _formatRating(data.averageSpeakerRating),
          ),
          _MetricRow(
            label: 'Average Venue Rating',
            value: _formatRating(data.averageVenueRating),
          ),
          _MetricRow(
            label: 'Average App Experience',
            value: _formatRating(data.averageAppExperienceRating),
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _feedbackDetailsSection(_EventReportDashboardData data) {
    if (data.feedbacks.isEmpty) {
      return const _EmptyCard(
        icon: Icons.rate_review_outlined,
        title: 'No feedback submitted yet',
        subtitle:
            'Attendee feedback will appear here after users submit the event feedback form.',
      );
    }

    return Column(
      children: data.feedbacks.map((feedback) {
        return _FeedbackCard(feedback: feedback);
      }).toList(),
    );
  }

  Widget _photosSection(_EventReportDashboardData data) {
    if (data.approvedPhotos.isEmpty) {
      return const _EmptyCard(
        icon: Icons.photo_library_outlined,
        title: 'No approved photos yet',
        subtitle:
            'Approved attendee session photos will appear here and inside the PDF report.',
      );
    }

    final groups = _groupPhotosForReport(data.approvedPhotos);
    final totalShown = data.approvedPhotos.take(maxReportPhotos).length;
    final totalAvailable = data.approvedPhotos.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.namaGoldenYellow.withOpacity(0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.namaGoldenYellow.withOpacity(0.25),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: AppColors.namaGoldenYellow,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  totalAvailable > maxReportPhotos
                      ? 'Showing $totalShown photos only. Report limit is max $maxReportPhotos photos.'
                      : 'Showing $totalShown approved photo${totalShown == 1 ? '' : 's'} in the report.',
                  style: const TextStyle(
                    color: AppColors.namaNavyBlue,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...groups.map((group) {
          return _PhotoGroupCard(group: group);
        }),
      ],
    );
  }

  Widget _registeredParticipantsSection(_EventReportDashboardData data) {
    if (data.registeredParticipants.isEmpty) {
      return const _EmptyCard(
        icon: Icons.fact_check_outlined,
        title: 'No registered participants added',
        subtitle:
            'Click Add to Report from Check Registration to include registered participants here and inside the PDF report.',
      );
    }

    return Column(
      children: data.registeredParticipants.map((participant) {
        return _RegistrationCard(participant: participant);
      }).toList(),
    );
  }

  Widget _systemNotes() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: _cardDecoration(),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BulletText(
            text:
                'Attendance rate is calculated using event check-ins compared with registered attendees.',
          ),
          SizedBox(height: 7),
          _BulletText(
            text:
                'Only photos approved by admin are included in the event report and PDF gallery.',
          ),
          SizedBox(height: 7),
          _BulletText(
            text:
                'Event report photo gallery shows maximum 10 photos, grouped by attendee and session, with maximum 3 photos per row.',
          ),
          SizedBox(height: 7),
          _BulletText(
            text:
                'Feedback details are collected directly from attendee event feedback forms.',
          ),
          SizedBox(height: 7),
          _BulletText(
            text:
                'Certificates are generated inside Attendance Details for present attendees and assigned speakers.',
          ),
        ],
      ),
    );
  }

  Widget _generatePdfButton(_EventReportDashboardData data) {
    return SizedBox(
      height: 46,
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isGeneratingPdf ? null : () => _generatePdf(data),
        icon: _isGeneratingPdf
            ? const SizedBox(
                height: 17,
                width: 17,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.picture_as_pdf_rounded, size: 18),
        label: Text(
          _isGeneratingPdf ? 'Generating PDF...' : 'Generate Event Report PDF',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.namaLightGray,
      body: SafeArea(
        child: FutureBuilder<_EventReportDashboardData>(
          future: _future,
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
                        'Unable to load event report',
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

            final data = snapshot.data ??
                _EventReportDashboardData.empty(
                  eventId: widget.eventId,
                  eventName: widget.eventName,
                );

            return RefreshIndicator(
              color: AppColors.namaNavyBlue,
              onRefresh: () async => _refresh(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                children: [
                  _header(),
                  const SizedBox(height: 18),
                  _overviewCard(data),
                  const SizedBox(height: 16),
                  _summaryCards(data),
                  const SizedBox(height: 18),
                  const _SectionTitle('Report Actions'),
                  const SizedBox(height: 10),
                  _reportActions(),
                  const SizedBox(height: 18),
                  const _SectionTitle('Report Details'),
                  const SizedBox(height: 10),
                  _detailsSection(data),
                  const SizedBox(height: 18),
                  const _SectionTitle('Management Report Notes'),
                  const SizedBox(height: 10),
                  _reportNotesSection(data),
                  const SizedBox(height: 18),
                  const _SectionTitle('Session Performance'),
                  const SizedBox(height: 10),
                  _sessionsSection(data),
                  const SizedBox(height: 18),
                  const _SectionTitle('Engagement Overview'),
                  const SizedBox(height: 10),
                  _engagementSection(data),
                  const SizedBox(height: 18),
                  const _SectionTitle('Feedback Summary'),
                  const SizedBox(height: 10),
                  _feedbackSummarySection(data),
                  const SizedBox(height: 18),
                  const _SectionTitle('Attendee Feedback'),
                  const SizedBox(height: 10),
                  _feedbackDetailsSection(data),
                  const SizedBox(height: 18),
                  const _SectionTitle('Event Photo Gallery'),
                  const SizedBox(height: 10),
                  _photosSection(data),
                  const SizedBox(height: 18),
                  const _SectionTitle('Registered Participants'),
                  const SizedBox(height: 10),
                  _registeredParticipantsSection(data),
                  const SizedBox(height: 18),
                  const _SectionTitle('System Notes'),
                  const SizedBox(height: 10),
                  _systemNotes(),
                  const SizedBox(height: 22),
                  _generatePdfButton(data),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EventReportPdfGenerator {
  static const int maxReportPhotos = 10;

  static Future<Uint8List> build(_EventReportDashboardData data) async {
    final pdf = pw.Document();

    final regularFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();

    final limitedPhotos = data.approvedPhotos.take(maxReportPhotos).toList();
    final photoGroups = _groupPhotosForPdf(limitedPhotos);

    final photoImages = <String, pw.ImageProvider?>{};

    for (final photo in limitedPhotos) {
      if (photo.photoUrl.trim().isEmpty) continue;

      try {
        photoImages[photo.id] = await networkImage(photo.photoUrl.trim());
      } catch (_) {
        photoImages[photo.id] = null;
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        theme: pw.ThemeData.withFont(
          base: regularFont,
          bold: boldFont,
        ),
        build: (context) {
          return [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.indigo900,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'NAMA Foundation',
                    style: pw.TextStyle(
                      color: PdfColors.amber,
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Event Report',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    _pdfSafe(data.eventName),
                    style: const pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 18),
            _pdfTitle('Report Summary'),
            pw.SizedBox(height: 8),
            _pdfInfoTable([
              ['Event Name', data.eventName],
              ['Date', data.dateText.isEmpty ? '-' : data.dateText],
              ['Location', data.location.isEmpty ? '-' : data.location],
              ['Total Users', data.totalUsers.toString()],
              ['Attendees', data.attendees.toString()],
              ['Present', data.present.toString()],
              ['Absent', data.absent.toString()],
              ['Speakers', data.speakers.toString()],
              ['Certificates', data.certificates.toString()],
              ['Attendance Rate', '${data.attendanceRate}%'],
            ]),
            pw.SizedBox(height: 18),
            _pdfTitle('Report Details'),
            pw.SizedBox(height: 8),
            _pdfInfoTable([
              ['Total Sessions', data.sessions.length.toString()],
              ['Feedback Responses', data.feedbacks.length.toString()],
              ['Approved Photos', data.approvedPhotos.length.toString()],
              [
                'Report Photos Included',
                '${limitedPhotos.length}/$maxReportPhotos',
              ],
              [
                'Registered Participants',
                data.registeredParticipants.length.toString(),
              ],
              ['Session Check-ins', data.totalSessionCheckIns.toString()],
              ['Chat Messages', data.totalMessages.toString()],
              [
                'Average Overall Rating',
                _formatRating(data.averageOverallRating),
              ],
            ]),
            if (data.reportNotes.hasContent) ...[
              pw.SizedBox(height: 18),
              _pdfTitle('Management Report Notes'),
              pw.SizedBox(height: 8),
              ..._pdfNotes(data.reportNotes),
            ],
            pw.SizedBox(height: 18),
            _pdfTitle('Session Performance'),
            pw.SizedBox(height: 8),
            if (data.sessions.isEmpty)
              pw.Text('No sessions found.')
            else
              _pdfSessionTable(data.sessions),
            pw.SizedBox(height: 18),
            _pdfTitle('Feedback Summary'),
            pw.SizedBox(height: 8),
            _pdfInfoTable([
              [
                'Average Overall Rating',
                _formatRating(data.averageOverallRating),
              ],
              [
                'Average Session Quality',
                _formatRating(data.averageSessionQualityRating),
              ],
              [
                'Average Speaker Rating',
                _formatRating(data.averageSpeakerRating),
              ],
              ['Average Venue Rating', _formatRating(data.averageVenueRating)],
              [
                'Average App Experience',
                _formatRating(data.averageAppExperienceRating),
              ],
            ]),
            pw.SizedBox(height: 18),
            _pdfTitle('Attendee Feedback'),
            pw.SizedBox(height: 8),
            if (data.feedbacks.isEmpty)
              pw.Text('No attendee feedback submitted yet.')
            else
              ...data.feedbacks.map((feedback) {
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        _pdfSafe(feedback.userName),
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if (feedback.additionalComments.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          _pdfSafe(feedback.additionalComments),
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            pw.SizedBox(height: 18),
            _pdfTitle('Photo Gallery'),
            pw.SizedBox(height: 8),
            if (limitedPhotos.isEmpty)
              pw.Text('No approved photos available.')
            else ...[
              pw.Text(
                'Showing ${limitedPhotos.length} approved photo(s). Maximum $maxReportPhotos photos are included in this report.',
                style: const pw.TextStyle(fontSize: 9.5),
              ),
              pw.SizedBox(height: 8),
              ...photoGroups.map((group) {
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 10),
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        _pdfSafe(group.sessionTitle),
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.indigo900,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Uploaded by: ${_pdfSafe(group.userName)}',
                        style: const pw.TextStyle(
                          fontSize: 8.5,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      _pdfPhotoGrid(group.photos, photoImages),
                    ],
                  ),
                );
              }),
            ],
            pw.SizedBox(height: 18),
            _pdfTitle('Registered Participants'),
            pw.SizedBox(height: 8),
            if (data.registeredParticipants.isEmpty)
              pw.Text('No registered participants added to report yet.')
            else
              _pdfRegisteredParticipantsTable(data.registeredParticipants),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static List<_EventPhotoGroup> _groupPhotosForPdf(
    List<_EventPhotoReportItem> photos,
  ) {
    final groupsMap = <String, _EventPhotoGroup>{};

    for (final photo in photos) {
      final userKey = photo.userEmail.trim().isNotEmpty
          ? photo.userEmail.trim().toLowerCase()
          : photo.userName.trim().toLowerCase();

      final key = '$userKey-${photo.sessionTitle.trim().toLowerCase()}';

      if (!groupsMap.containsKey(key)) {
        groupsMap[key] = _EventPhotoGroup(
          userName: photo.userName,
          userEmail: photo.userEmail,
          sessionTitle: photo.sessionTitle,
          photos: [],
        );
      }

      groupsMap[key]!.photos.add(photo);
    }

    return groupsMap.values.toList();
  }

  static pw.Widget _pdfPhotoGrid(
    List<_EventPhotoReportItem> photos,
    Map<String, pw.ImageProvider?> photoImages,
  ) {
    final rows = <pw.Widget>[];

    for (int i = 0; i < photos.length; i += 3) {
      final rowPhotos = photos.skip(i).take(3).toList();

      rows.add(
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: List.generate(3, (index) {
            if (index >= rowPhotos.length) {
              return pw.Expanded(child: pw.SizedBox());
            }

            final photo = rowPhotos[index];
            final image = photoImages[photo.id];

            return pw.Expanded(
              child: pw.Container(
                height: 70,
                margin: pw.EdgeInsets.only(
                  right: index == 2 ? 0 : 5,
                  bottom: 5,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: image == null
                    ? pw.Center(
                        child: pw.Text(
                          'Photo unavailable',
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(
                            fontSize: 7,
                            color: PdfColors.grey700,
                          ),
                        ),
                      )
                    : pw.ClipRRect(
                        horizontalRadius: 4,
                        verticalRadius: 4,
                        child: pw.Image(
                          image,
                          fit: pw.BoxFit.cover,
                        ),
                      ),
              ),
            );
          }),
        ),
      );
    }

    return pw.Column(children: rows);
  }

  static pw.Widget _pdfTitle(String text) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 13,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.indigo900,
      ),
    );
  }

  static pw.Widget _pdfInfoTable(List<List<String>> rows) {
    return pw.Table.fromTextArray(
      border: pw.TableBorder.all(
        color: PdfColors.grey300,
        width: 0.6,
      ),
      cellPadding: const pw.EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 6,
      ),
      headerStyle: pw.TextStyle(
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(
        color: PdfColors.indigo900,
      ),
      cellStyle: const pw.TextStyle(
        fontSize: 9.5,
      ),
      headers: ['Item', 'Details'],
      data: rows
          .map(
            (row) => [
              _pdfSafe(row[0]),
              _pdfSafe(row[1]),
            ],
          )
          .toList(),
    );
  }

  static pw.Widget _pdfRegisteredParticipantsTable(
    List<_RegistrationReportItem> participants,
  ) {
    return pw.Table.fromTextArray(
      border: pw.TableBorder.all(
        color: PdfColors.grey300,
        width: 0.6,
      ),
      cellPadding: const pw.EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 5,
      ),
      columnWidths: {
        0: const pw.FixedColumnWidth(20),
        1: const pw.FlexColumnWidth(2.5),
        2: const pw.FlexColumnWidth(3),
        3: const pw.FlexColumnWidth(1.4),
        4: const pw.FlexColumnWidth(1.8),
      },
      headerStyle: pw.TextStyle(
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(
        color: PdfColors.indigo900,
      ),
      cellStyle: const pw.TextStyle(
        fontSize: 7.4,
      ),
      headers: [
        '#',
        'Name',
        'Email',
        'Role',
        'Registered At',
      ],
      data: List.generate(participants.length, (index) {
        final participant = participants[index];

        return [
          '${index + 1}',
          _pdfSafe(participant.name),
          _pdfSafe(participant.email.isEmpty ? '-' : participant.email),
          _pdfSafe(participant.role),
          _pdfSafe(
            participant.registeredAt == null
                ? '-'
                : _formatDate(participant.registeredAt!),
          ),
        ];
      }),
    );
  }

  static pw.Widget _pdfSessionTable(List<_SessionReportItem> sessions) {
    return pw.Table.fromTextArray(
      border: pw.TableBorder.all(
        color: PdfColors.grey300,
        width: 0.6,
      ),
      cellPadding: const pw.EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 5,
      ),
      columnWidths: {
        0: const pw.FixedColumnWidth(20),
        1: const pw.FlexColumnWidth(3.4),
        2: const pw.FlexColumnWidth(1.6),
        3: const pw.FlexColumnWidth(1.1),
        4: const pw.FixedColumnWidth(42),
        5: const pw.FixedColumnWidth(42),
      },
      headerStyle: pw.TextStyle(
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(
        color: PdfColors.indigo900,
      ),
      cellStyle: const pw.TextStyle(
        fontSize: 7.4,
      ),
      headers: [
        '#',
        'Session',
        'Time',
        'Location',
        'Check-ins',
        'Messages',
      ],
      data: List.generate(sessions.length, (index) {
        final session = sessions[index];

        return [
          '${index + 1}',
          _pdfSafe(session.title),
          _pdfSafe(_formatSessionTime(session.startTime, session.endTime)),
          _pdfSafe(session.location),
          session.checkedInCount.toString(),
          session.totalMessages.toString(),
        ];
      }),
    );
  }

  static List<pw.Widget> _pdfNotes(_ReportNotes notes) {
    final widgets = <pw.Widget>[];

    void add(String title, String value) {
      if (value.trim().isEmpty) return;

      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                _pdfSafe(title),
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.indigo900,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                _pdfSafe(value),
                style: const pw.TextStyle(
                  fontSize: 9.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    add('Event Objectives', notes.eventObjectives);
    add('Key Highlights', notes.keyHighlights);
    add('Main Outcomes', notes.mainOutcomes);
    add('Challenges', notes.challenges);
    add('Recommendations', notes.recommendations);
    add('Conclusion', notes.conclusion);

    return widgets;
  }
}

class _EventReportDashboardData {
  final String eventId;
  final String eventName;
  final String description;
  final String location;
  final DateTime? startDate;
  final DateTime? endDate;
  final int totalUsers;
  final int attendees;
  final int speakers;
  final int staffAdmins;
  final int present;
  final int absent;
  final int certificates;
  final List<_SessionReportItem> sessions;
  final List<_FeedbackReportItem> feedbacks;
  final List<_EventPhotoReportItem> approvedPhotos;
  final List<_RegistrationReportItem> registeredParticipants;
  final int totalMessages;
  final int totalSessionCheckIns;
  final double averageOverallRating;
  final double averageSessionQualityRating;
  final double averageSpeakerRating;
  final double averageVenueRating;
  final double averageAppExperienceRating;
  final _ReportNotes reportNotes;

  const _EventReportDashboardData({
    required this.eventId,
    required this.eventName,
    required this.description,
    required this.location,
    required this.startDate,
    required this.endDate,
    required this.totalUsers,
    required this.attendees,
    required this.speakers,
    required this.staffAdmins,
    required this.present,
    required this.absent,
    required this.certificates,
    required this.sessions,
    required this.feedbacks,
    required this.approvedPhotos,
    required this.registeredParticipants,
    required this.totalMessages,
    required this.totalSessionCheckIns,
    required this.averageOverallRating,
    required this.averageSessionQualityRating,
    required this.averageSpeakerRating,
    required this.averageVenueRating,
    required this.averageAppExperienceRating,
    required this.reportNotes,
  });

  int get attendanceRate {
    if (attendees == 0) return 0;
    return ((present / attendees) * 100).round();
  }

  String get dateText {
    if (startDate == null && endDate == null) return '';

    if (startDate != null && endDate == null) {
      return _formatDate(startDate!);
    }

    if (startDate == null && endDate != null) {
      return _formatDate(endDate!);
    }

    final sameDay = startDate!.year == endDate!.year &&
        startDate!.month == endDate!.month &&
        startDate!.day == endDate!.day;

    if (sameDay) return _formatDate(startDate!);

    return '${_formatDate(startDate!)} - ${_formatDate(endDate!)}';
  }

  factory _EventReportDashboardData.empty({
    required String eventId,
    required String eventName,
  }) {
    return _EventReportDashboardData(
      eventId: eventId,
      eventName: eventName,
      description: '',
      location: '',
      startDate: null,
      endDate: null,
      totalUsers: 0,
      attendees: 0,
      speakers: 0,
      staffAdmins: 0,
      present: 0,
      absent: 0,
      certificates: 0,
      sessions: const [],
      feedbacks: const [],
      approvedPhotos: const [],
      registeredParticipants: const [],
      totalMessages: 0,
      totalSessionCheckIns: 0,
      averageOverallRating: 0,
      averageSessionQualityRating: 0,
      averageSpeakerRating: 0,
      averageVenueRating: 0,
      averageAppExperienceRating: 0,
      reportNotes: _ReportNotes.empty(),
    );
  }
}

class _EventPhotoGroup {
  final String userName;
  final String userEmail;
  final String sessionTitle;
  final List<_EventPhotoReportItem> photos;

  const _EventPhotoGroup({
    required this.userName,
    required this.userEmail,
    required this.sessionTitle,
    required this.photos,
  });
}

class _SessionReportItem {
  final String id;
  final String title;
  final String location;
  final DateTime? startTime;
  final DateTime? endTime;
  final int speakerCount;
  final int checkedInCount;
  final int totalMessages;
  final int activeChatUsers;
  final double averageRating;

  const _SessionReportItem({
    required this.id,
    required this.title,
    required this.location,
    required this.startTime,
    required this.endTime,
    required this.speakerCount,
    required this.checkedInCount,
    required this.totalMessages,
    required this.activeChatUsers,
    required this.averageRating,
  });

  factory _SessionReportItem.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    return _SessionReportItem(
      id: doc.id,
      title: (data['title'] ?? data['sessionTitle'] ?? 'Untitled Session')
          .toString(),
      location: (data['location'] ?? 'Unknown Location').toString(),
      startTime: _readDate(data['startTime']),
      endTime: _readDate(data['endTime']),
      speakerCount: List.from(data['speakerIds'] as List? ?? []).length,
      checkedInCount:
          List.from(data['checkedInAttendees'] as List? ?? []).length,
      totalMessages: (data['totalMessages'] as num?)?.toInt() ?? 0,
      activeChatUsers:
          List.from(data['uniqueParticipants'] as List? ?? []).length,
      averageRating: (data['averageRating'] as num?)?.toDouble() ?? 0,
    );
  }
}

class _FeedbackReportItem {
  final String id;
  final String userName;
  final String userEmail;
  final double overallRating;
  final double sessionQualityRating;
  final double speakerRating;
  final double venueRating;
  final double appExperienceRating;
  final String likedMost;
  final String improvementSuggestion;
  final String additionalComments;
  final DateTime? createdAt;

  const _FeedbackReportItem({
    required this.id,
    required this.userName,
    required this.userEmail,
    required this.overallRating,
    required this.sessionQualityRating,
    required this.speakerRating,
    required this.venueRating,
    required this.appExperienceRating,
    required this.likedMost,
    required this.improvementSuggestion,
    required this.additionalComments,
    required this.createdAt,
  });

  factory _FeedbackReportItem.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    return _FeedbackReportItem(
      id: doc.id,
      userName: (data['userName'] ??
              data['name'] ??
              data['fullName'] ??
              'Attendee')
          .toString(),
      userEmail: (data['userEmail'] ?? data['email'] ?? '').toString(),
      overallRating:
          ((data['overallRating'] ?? data['rating'] ?? 0) as num?)
                  ?.toDouble() ??
              0,
      sessionQualityRating:
          ((data['sessionQualityRating'] ?? 0) as num?)?.toDouble() ?? 0,
      speakerRating: ((data['speakerRating'] ?? 0) as num?)?.toDouble() ?? 0,
      venueRating: ((data['venueRating'] ?? 0) as num?)?.toDouble() ?? 0,
      appExperienceRating:
          ((data['appExperienceRating'] ?? 0) as num?)?.toDouble() ?? 0,
      likedMost: (data['likedMost'] ?? '').toString(),
      improvementSuggestion:
          (data['improvementSuggestion'] ?? '').toString(),
      additionalComments: (data['additionalComments'] ?? '').toString(),
      createdAt: _readDate(data['createdAt'] ?? data['submittedAt']),
    );
  }
}

class _EventPhotoReportItem {
  final String id;
  final String sessionTitle;
  final String userName;
  final String userEmail;
  final String photoUrl;
  final String caption;
  final DateTime? uploadedAt;

  const _EventPhotoReportItem({
    required this.id,
    required this.sessionTitle,
    required this.userName,
    required this.userEmail,
    required this.photoUrl,
    required this.caption,
    required this.uploadedAt,
  });

  factory _EventPhotoReportItem.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    return _EventPhotoReportItem(
      id: doc.id,
      sessionTitle: (data['sessionTitle'] ?? 'Unknown Session').toString(),
      userName: (data['userName'] ?? 'Attendee').toString(),
      userEmail: (data['userEmail'] ?? '').toString(),
      photoUrl: (data['photoUrl'] ?? data['imageUrl'] ?? '').toString(),
      caption: (data['caption'] ?? '').toString(),
      uploadedAt: _readDate(data['uploadedAt'] ?? data['createdAt']),
    );
  }
}

class _RegistrationReportItem {
  final String id;
  final String userId;
  final String name;
  final String email;
  final String role;
  final String status;
  final DateTime? registeredAt;

  const _RegistrationReportItem({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    required this.registeredAt,
  });

  factory _RegistrationReportItem.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    return _RegistrationReportItem(
      id: doc.id,
      userId: (data['userId'] ?? doc.id).toString(),
      name: (data['name'] ?? 'Unknown User').toString(),
      email: (data['email'] ?? '').toString(),
      role: (data['role'] ?? 'user').toString(),
      status: (data['status'] ?? 'registered').toString(),
      registeredAt: _readDate(data['registeredAt'] ?? data['createdAt']),
    );
  }
}

class _ReportNotes {
  final String eventObjectives;
  final String keyHighlights;
  final String mainOutcomes;
  final String challenges;
  final String recommendations;
  final String conclusion;

  const _ReportNotes({
    required this.eventObjectives,
    required this.keyHighlights,
    required this.mainOutcomes,
    required this.challenges,
    required this.recommendations,
    required this.conclusion,
  });

  bool get hasContent {
    return eventObjectives.trim().isNotEmpty ||
        keyHighlights.trim().isNotEmpty ||
        mainOutcomes.trim().isNotEmpty ||
        challenges.trim().isNotEmpty ||
        recommendations.trim().isNotEmpty ||
        conclusion.trim().isNotEmpty;
  }

  factory _ReportNotes.empty() {
    return const _ReportNotes(
      eventObjectives: '',
      keyHighlights: '',
      mainOutcomes: '',
      challenges: '',
      recommendations: '',
      conclusion: '',
    );
  }

  factory _ReportNotes.fromMap(Map<String, dynamic> data) {
    return _ReportNotes(
      eventObjectives: (data['eventObjectives'] ?? '').toString(),
      keyHighlights: (data['keyHighlights'] ?? '').toString(),
      mainOutcomes: (data['mainOutcomes'] ?? '').toString(),
      challenges: (data['challenges'] ?? '').toString(),
      recommendations: (data['recommendations'] ?? '').toString(),
      conclusion: (data['conclusion'] ?? '').toString(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
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
          Icon(icon, color: color, size: 24),
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

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.white,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.namaNavyBlue,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.namaMediumGray,
                          fontSize: 11.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.namaNavyBlue,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const _MetricRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: Colors.black.withOpacity(0.06),
                ),
              ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.namaMediumGray,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.namaNavyBlue,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteBlock extends StatelessWidget {
  final String title;
  final String value;

  const _NoteBlock({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.namaNavyBlue,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.namaDarkGray,
              fontSize: 11.8,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final _SessionReportItem session;

  const _SessionCard({
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            session.title,
            style: const TextStyle(
              color: AppColors.namaNavyBlue,
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          _SmallInfoLine(
            icon: Icons.access_time_rounded,
            text: _formatSessionTime(session.startTime, session.endTime),
          ),
          const SizedBox(height: 5),
          _SmallInfoLine(
            icon: Icons.location_on_outlined,
            text: session.location,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MiniMetric(
                  label: 'Check-ins',
                  value: session.checkedInCount.toString(),
                ),
              ),
              Expanded(
                child: _MiniMetric(
                  label: 'Messages',
                  value: session.totalMessages.toString(),
                ),
              ),
              Expanded(
                child: _MiniMetric(
                  label: 'Chat Users',
                  value: session.activeChatUsers.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final _FeedbackReportItem feedback;

  const _FeedbackCard({
    required this.feedback,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            feedback.userName,
            style: const TextStyle(
              color: AppColors.namaNavyBlue,
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (feedback.userEmail.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              feedback.userEmail,
              style: const TextStyle(
                color: AppColors.namaMediumGray,
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _SmallChip(
                text: 'Overall: ${_ratingText(feedback.overallRating)}',
              ),
              _SmallChip(
                text:
                    'Session: ${_ratingText(feedback.sessionQualityRating)}',
              ),
              _SmallChip(
                text: 'Speaker: ${_ratingText(feedback.speakerRating)}',
              ),
              _SmallChip(
                text: 'Venue: ${_ratingText(feedback.venueRating)}',
              ),
              _SmallChip(
                text: 'App: ${_ratingText(feedback.appExperienceRating)}',
              ),
            ],
          ),
          if (feedback.likedMost.isNotEmpty) ...[
            const SizedBox(height: 10),
            _TextBlock(title: 'Liked Most', text: feedback.likedMost),
          ],
          if (feedback.improvementSuggestion.isNotEmpty) ...[
            const SizedBox(height: 8),
            _TextBlock(
              title: 'Improvement Suggestion',
              text: feedback.improvementSuggestion,
            ),
          ],
          if (feedback.additionalComments.isNotEmpty) ...[
            const SizedBox(height: 8),
            _TextBlock(
              title: 'Additional Comments',
              text: feedback.additionalComments,
            ),
          ],
        ],
      ),
    );
  }
}

class _RegistrationCard extends StatelessWidget {
  final _RegistrationReportItem participant;

  const _RegistrationCard({
    required this.participant,
  });

  @override
  Widget build(BuildContext context) {
    final registeredAt = participant.registeredAt == null
        ? '-'
        : _formatDate(participant.registeredAt!);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.namaNavyBlue.withOpacity(0.10),
            child: Text(
              participant.name.trim().isNotEmpty
                  ? participant.name.trim()[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: AppColors.namaNavyBlue,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  participant.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.namaNavyBlue,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  participant.email.isEmpty ? '-' : participant.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.namaMediumGray,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${participant.role} • $registeredAt',
                  style: const TextStyle(
                    color: AppColors.namaMediumGray,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.10),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Text(
              'Registered',
              style: TextStyle(
                color: Colors.green,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoGroupCard extends StatelessWidget {
  final _EventPhotoGroup group;

  const _PhotoGroupCard({
    required this.group,
  });

  @override
  Widget build(BuildContext context) {
    final photos = group.photos;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.sessionTitle,
            style: const TextStyle(
              color: AppColors.namaNavyBlue,
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Uploaded by: ${group.userName}',
            style: const TextStyle(
              color: AppColors.namaMediumGray,
              fontSize: 11.5,
            ),
          ),
          if (group.userEmail.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              group.userEmail,
              style: const TextStyle(
                color: AppColors.namaMediumGray,
                fontSize: 10.5,
              ),
            ),
          ],
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 8.0;
              final itemWidth = (constraints.maxWidth - (spacing * 2)) / 3;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: photos.map((photo) {
                  return SizedBox(
                    width: itemWidth,
                    child: _PhotoThumb(photo: photo),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  final _EventPhotoReportItem photo;

  const _PhotoThumb({
    required this.photo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: photo.photoUrl.isEmpty
                ? Container(
                    color: const Color(0xFFF4F2FB),
                    child: const Icon(
                      Icons.image_not_supported_outlined,
                      color: AppColors.namaNavyBlue,
                      size: 24,
                    ),
                  )
                : Image.network(
                    photo.photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return Container(
                        color: const Color(0xFFF4F2FB),
                        child: const Icon(
                          Icons.broken_image_outlined,
                          color: AppColors.namaNavyBlue,
                          size: 24,
                        ),
                      );
                    },
                  ),
          ),
        ),
        if (photo.caption.trim().isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            photo.caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.namaDarkGray,
              fontSize: 10,
              height: 1.25,
            ),
          ),
        ],
      ],
    );
  }
}

class _SmallInfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SmallInfoLine({
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

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;

  const _MiniMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.namaNavyBlue,
            fontSize: 13.5,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.namaMediumGray,
            fontSize: 9.5,
          ),
        ),
      ],
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

class _TextBlock extends StatelessWidget {
  final String title;
  final String text;

  const _TextBlock({
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.namaNavyBlue,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.namaDarkGray,
            fontSize: 11.5,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _BulletText extends StatelessWidget {
  final String text;

  const _BulletText({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '• ',
          style: TextStyle(
            color: AppColors.namaGoldenYellow,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.namaDarkGray,
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.namaNavyBlue,
        fontSize: 15,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionText;
  final VoidCallback? onActionTap;

  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionText,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Icon(icon, color: AppColors.namaNavyBlue, size: 30),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.namaNavyBlue,
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.namaMediumGray,
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
          if (actionText != null && onActionTap != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 36,
              child: ElevatedButton(
                onPressed: onActionTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.namaNavyBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: Text(
                  actionText!,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
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

String _formatSessionTime(DateTime? start, DateTime? end) {
  if (start == null && end == null) return 'Time not set';

  if (start != null && end == null) {
    return '${_formatDate(start)} - ${_formatTime(start)}';
  }

  if (start == null && end != null) {
    return '${_formatDate(end)} - ${_formatTime(end)}';
  }

  final sameDay = start!.year == end!.year &&
      start.month == end.month &&
      start.day == end.day;

  if (sameDay) {
    return '${_formatDate(start)} • ${_formatTime(start)} - ${_formatTime(end)}';
  }

  return '${_formatDate(start)} - ${_formatDate(end)}';
}

String _formatTime(DateTime date) {
  final hour = date.hour;
  final minute = date.minute.toString().padLeft(2, '0');
  final suffix = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour == 0 ? 12 : hour > 12 ? hour - 12 : hour;

  return '$displayHour:$minute $suffix';
}

String _formatRating(double value) {
  if (value <= 0) return '-';
  return '${value.toStringAsFixed(1)} / 5';
}

String _ratingText(double value) {
  if (value <= 0) return '-';
  return value.toStringAsFixed(1);
}

String _pdfSafe(String value) {
  return value
      .replaceAll('\n', ' ')
      .replaceAll('\r', ' ')
      .replaceAll(' ', '')
      .trim();
}