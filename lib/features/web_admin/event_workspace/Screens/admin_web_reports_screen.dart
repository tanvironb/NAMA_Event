// lib/features/web_admin/event_workspace/Screens/admin_web_reports_screen.dart
import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../admin_web_theme.dart';

class AdminWebReportsScreen extends StatefulWidget {
  final String eventId;
  final String eventName;

  const AdminWebReportsScreen({
    super.key,
    required this.eventId,
    required this.eventName,
  });

  @override
  State<AdminWebReportsScreen> createState() =>
      _AdminWebReportsScreenState();
}

class _AdminWebReportsScreenState extends State<AdminWebReportsScreen> {
  static const int _maxReportPhotos = 10;

  late Future<_ReportData> _future;
  bool _isGeneratingPdf = false;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _feedbackSubscription;

  @override
  void initState() {
    super.initState();
    _future = _loadData();

    // Refresh the report automatically whenever any feedback document changes.
    // The data loader below still filters the feedback to this event's sessions.
    _feedbackSubscription = FirebaseFirestore.instance
        .collectionGroup('feedback')
        .snapshots()
        .listen(
      (_) {
        if (!mounted) return;

        setState(() {
          _future = _loadData();
        });
      },
      onError: (_) {
        // The manual Refresh button remains available if a live listener
        // is not permitted by the current Firestore rules.
      },
    );
  }

  @override
  void dispose() {
    _feedbackSubscription?.cancel();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _future = _loadData();
    });
  }

  Future<_ReportData> _loadData() async {
    final firestore = FirebaseFirestore.instance;

    final results = await Future.wait([
      firestore.collection('events').doc(widget.eventId).get(),
      firestore
          .collection('users')
          .where('eventIds', arrayContains: widget.eventId)
          .get(),
      firestore
          .collection('events')
          .doc(widget.eventId)
          .collection('attendance')
          .get(),
      firestore
          .collection('events')
          .doc(widget.eventId)
          .collection('certificates')
          .get(),
      firestore
          .collection('sessions')
          .where('eventId', isEqualTo: widget.eventId)
          .get(),
      firestore
          .collection('events')
          .doc(widget.eventId)
          .collection('sessions')
          .get(),
      firestore
          .collection('events')
          .doc(widget.eventId)
          .collection('feedback')
          .get(),
      firestore
          .collection('feedback')
          .where('eventId', isEqualTo: widget.eventId)
          .get(),
      firestore
          .collection('events')
          .doc(widget.eventId)
          .collection('eventPhotos')
          .where('status', isEqualTo: 'approved')
          .get(),
      firestore
          .collection('eventPhotos')
          .where('eventId', isEqualTo: widget.eventId)
          .where('status', isEqualTo: 'approved')
          .get(),
      firestore
          .collection('events')
          .doc(widget.eventId)
          .collection('registrations')
          .where('includedInReport', isEqualTo: true)
          .get(),
      firestore
          .collection('events')
          .doc(widget.eventId)
          .collection('reportNotes')
          .doc('main')
          .get(),
    ]);

    final eventDoc =
        results[0] as DocumentSnapshot<Map<String, dynamic>>;
    final usersSnap =
        results[1] as QuerySnapshot<Map<String, dynamic>>;
    final attendanceSnap =
        results[2] as QuerySnapshot<Map<String, dynamic>>;
    final certificatesSnap =
        results[3] as QuerySnapshot<Map<String, dynamic>>;
    final topSessionsSnap =
        results[4] as QuerySnapshot<Map<String, dynamic>>;
    final subSessionsSnap =
        results[5] as QuerySnapshot<Map<String, dynamic>>;
    final feedbackSnap =
        results[6] as QuerySnapshot<Map<String, dynamic>>;
    final topFeedbackSnap =
        results[7] as QuerySnapshot<Map<String, dynamic>>;
    final approvedPhotosSnap =
        results[8] as QuerySnapshot<Map<String, dynamic>>;
    final topPhotosSnap =
        results[9] as QuerySnapshot<Map<String, dynamic>>;
    final registrationsSnap =
        results[10] as QuerySnapshot<Map<String, dynamic>>;
    final reportNotesDoc =
        results[11] as DocumentSnapshot<Map<String, dynamic>>;

    final eventData = eventDoc.data() ?? <String, dynamic>{};

    int attendeeCount = 0;
    int speakerCount = 0;
    int moderatorCount = 0;
    int staffCount = 0;
    int adminCount = 0;

    for (final doc in usersSnap.docs) {
      final role =
          (doc.data()['role'] ?? '').toString().trim().toLowerCase();

      switch (role) {
        case 'attendee':
          attendeeCount++;
          break;
        case 'speaker':
          speakerCount++;
          break;
        case 'moderator':
          moderatorCount++;
          break;
        case 'staff':
          staffCount++;
          break;
        case 'admin':
          adminCount++;
          break;
        default:
          staffCount++;
      }
    }

    final sessionsMap = <String, _SessionReportItem>{};

    for (final doc in topSessionsSnap.docs) {
      sessionsMap[doc.reference.path] =
          _SessionReportItem.fromDoc(doc);
    }

    for (final doc in subSessionsSnap.docs) {
      sessionsMap[doc.reference.path] =
          _SessionReportItem.fromDoc(doc);
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

    // Session feedback is stored below each session document:
    // sessions/{sessionId}/feedback/{feedbackId}
    // and, for legacy event-subcollection sessions:
    // events/{eventId}/sessions/{sessionId}/feedback/{feedbackId}
    //
    // Read both locations directly. This avoids depending on an eventId field
    // inside every feedback document and prevents a collection-group index
    // requirement.
    final sessionFeedbackFutures =
        <Future<QuerySnapshot<Map<String, dynamic>>>>[];

    for (final sessionDocument in topSessionsSnap.docs) {
      sessionFeedbackFutures.add(
        sessionDocument.reference.collection('feedback').get(),
      );
    }

    for (final sessionDocument in subSessionsSnap.docs) {
      sessionFeedbackFutures.add(
        sessionDocument.reference.collection('feedback').get(),
      );
    }

    final sessionFeedbackSnapshots = sessionFeedbackFutures.isEmpty
        ? <QuerySnapshot<Map<String, dynamic>>>[]
        : await Future.wait(sessionFeedbackFutures);

    final feedbackMap = <String, _FeedbackReportItem>{};

    for (final doc in feedbackSnap.docs) {
      feedbackMap[doc.reference.path] =
          _FeedbackReportItem.fromDoc(doc);
    }

    for (final doc in topFeedbackSnap.docs) {
      feedbackMap[doc.reference.path] =
          _FeedbackReportItem.fromDoc(doc);
    }

    for (final snapshot in sessionFeedbackSnapshots) {
      for (final doc in snapshot.docs) {
        feedbackMap[doc.reference.path] =
            _FeedbackReportItem.fromDoc(doc);
      }
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

    final photosMap = <String, _PhotoReportItem>{};

    for (final doc in approvedPhotosSnap.docs) {
      photosMap[doc.reference.path] =
          _PhotoReportItem.fromDoc(doc);
    }

    for (final doc in topPhotosSnap.docs) {
      photosMap[doc.reference.path] =
          _PhotoReportItem.fromDoc(doc);
    }

    final photos = photosMap.values.toList()
      ..sort((a, b) {
        if (a.uploadedAt == null && b.uploadedAt == null) {
          return a.sessionTitle.compareTo(b.sessionTitle);
        }
        if (a.uploadedAt == null) return 1;
        if (b.uploadedAt == null) return -1;
        return b.uploadedAt!.compareTo(a.uploadedAt!);
      });

    final registrations = registrationsSnap.docs
        .map(_RegistrationReportItem.fromDoc)
        .toList()
      ..sort((a, b) {
        if (a.registeredAt == null && b.registeredAt == null) {
          return a.name.compareTo(b.name);
        }
        if (a.registeredAt == null) return 1;
        if (b.registeredAt == null) return -1;
        return a.registeredAt!.compareTo(b.registeredAt!);
      });

    final startDate = _readDate(
      eventData['startDate'] ??
          eventData['startTime'] ??
          eventData['eventStartDate'] ??
          eventData['date'],
    );

    final endDate = _readDate(
      eventData['endDate'] ??
          eventData['endTime'] ??
          eventData['eventEndDate'] ??
          eventData['eventEndTime'],
    );

    double overallTotal = 0;
    double sessionTotal = 0;
    double speakerTotal = 0;
    double venueTotal = 0;
    double appTotal = 0;

    int overallRatingCount = 0;
    int sessionRatingCount = 0;
    int speakerRatingCount = 0;
    int venueRatingCount = 0;
    int appRatingCount = 0;

    for (final feedback in feedbacks) {
      if (feedback.overallRating > 0) {
        overallTotal += feedback.overallRating;
        overallRatingCount++;
      }

      if (feedback.sessionQualityRating > 0) {
        sessionTotal += feedback.sessionQualityRating;
        sessionRatingCount++;
      }

      if (feedback.speakerRating > 0) {
        speakerTotal += feedback.speakerRating;
        speakerRatingCount++;
      }

      if (feedback.venueRating > 0) {
        venueTotal += feedback.venueRating;
        venueRatingCount++;
      }

      if (feedback.appExperienceRating > 0) {
        appTotal += feedback.appExperienceRating;
        appRatingCount++;
      }
    }

    return _ReportData(
      eventId: widget.eventId,
      eventName: (eventData['name'] ??
              eventData['title'] ??
              eventData['eventName'] ??
              widget.eventName)
          .toString(),
      description: (eventData['description'] ?? '').toString(),
      location: (eventData['location'] ?? '').toString(),
      startDate: startDate,
      endDate: endDate,
      totalUsers: usersSnap.docs.length,
      attendees: attendeeCount,
      speakers: speakerCount,
      moderators: moderatorCount,
      staff: staffCount,
      admins: adminCount,
      present: attendanceSnap.docs.length,
      certificates: certificatesSnap.docs.length,
      sessions: sessions,
      feedbacks: feedbacks,
      photos: photos,
      registrations: registrations,
      totalMessages: sessions.fold(
        0,
        (sum, item) => sum + item.totalMessages,
      ),
      totalCheckIns: sessions.fold(
        0,
        (sum, item) => sum + item.checkedInCount,
      ),
      averageOverall: overallRatingCount == 0
          ? 0
          : overallTotal / overallRatingCount,
      averageSession: sessionRatingCount == 0
          ? 0
          : sessionTotal / sessionRatingCount,
      averageSpeaker: speakerRatingCount == 0
          ? 0
          : speakerTotal / speakerRatingCount,
      averageVenue: venueRatingCount == 0
          ? 0
          : venueTotal / venueRatingCount,
      averageApp:
          appRatingCount == 0 ? 0 : appTotal / appRatingCount,
      notes: _ReportNotes.fromMap(
        reportNotesDoc.data() ?? <String, dynamic>{},
      ),
    );
  }

  Future<void> _openNotesEditor(_ReportData data) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ReportNotesDialog(
        eventId: widget.eventId,
        eventName: data.eventName,
        initialNotes: data.notes,
      ),
    );

    if (changed == true) {
      _refresh();
    }
  }

  Future<void> _generatePdf(_ReportData data) async {
    if (_isGeneratingPdf) return;

    setState(() => _isGeneratingPdf = true);

    try {
      final bytes = await _ReportPdfGenerator.build(data);
      final safeName = data.eventName
          .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
          .replaceAll(RegExp(r'_+'), '_');

      await Printing.sharePdf(
        bytes: bytes,
        filename: '${safeName}_event_report.pdf',
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate PDF: $error'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ReportData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: AdminWebTheme.primary,
            ),
          );
        }

        if (snapshot.hasError) {
          return _ReportErrorState(
            message: snapshot.error.toString(),
            onRetry: _refresh,
          );
        }

        final data = snapshot.data ??
            _ReportData.empty(
              eventId: widget.eventId,
              eventName: widget.eventName,
            );

        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          color: AdminWebTheme.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PageHeader(
                  eventName: data.eventName,
                  onRefresh: _refresh,
                  onEditNotes: () => _openNotesEditor(data),
                  onGeneratePdf: _isGeneratingPdf
                      ? null
                      : () => _generatePdf(data),
                  isGeneratingPdf: _isGeneratingPdf,
                ),
                const SizedBox(height: 20),
                _OverviewBanner(data: data),
                const SizedBox(height: 18),
                _SummaryGrid(data: data),
                const SizedBox(height: 18),
                _SectionCard(
                  title: 'Report details',
                  subtitle:
                      'Key data included in the final event report.',
                  icon: Icons.analytics_outlined,
                  child: _ReportMetricsGrid(data: data),
                ),
                const SizedBox(height: 18),
                _SectionCard(
                  title: 'Management report notes',
                  subtitle:
                      'Objectives, highlights, outcomes, challenges and recommendations.',
                  icon: Icons.edit_note_rounded,
                  action: TextButton.icon(
                    onPressed: () => _openNotesEditor(data),
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 17,
                    ),
                    label: Text(
                      data.notes.hasContent ? 'Edit notes' : 'Add notes',
                    ),
                  ),
                  child: data.notes.hasContent
                      ? _NotesView(notes: data.notes)
                      : const _EmptyState(
                          icon: Icons.notes_outlined,
                          title: 'No report notes yet',
                          message:
                              'Add management notes so they appear in the dashboard and generated PDF.',
                        ),
                ),
                const SizedBox(height: 18),
                _SectionCard(
                  title: 'Session performance',
                  subtitle:
                      'Schedule, participation, messages and ratings by session.',
                  icon: Icons.event_note_outlined,
                  child: data.sessions.isEmpty
                      ? const _EmptyState(
                          icon: Icons.event_busy_outlined,
                          title: 'No sessions found',
                          message:
                              'Sessions created for this event will appear here.',
                        )
                      : _SessionsTable(sessions: data.sessions),
                ),
                const SizedBox(height: 18),
                _SectionCard(
                  title: 'Engagement and feedback',
                  subtitle:
                      'Overall engagement totals and attendee rating averages.',
                  icon: Icons.insights_outlined,
                  child: _EngagementGrid(data: data),
                ),
                const SizedBox(height: 18),
                _SectionCard(
                  title: 'Attendee feedback',
                  subtitle:
                      'Individual responses submitted through the event feedback form.',
                  icon: Icons.rate_review_outlined,
                  child: data.feedbacks.isEmpty
                      ? const _EmptyState(
                          icon: Icons.rate_review_outlined,
                          title: 'No feedback submitted yet',
                          message:
                              'Attendee feedback will appear here after submission.',
                        )
                      : _FeedbackList(feedbacks: data.feedbacks),
                ),
                const SizedBox(height: 18),
                _SectionCard(
                  title: 'Event photo gallery',
                  subtitle:
                      'Approved photos included in the report. Maximum $_maxReportPhotos photos.',
                  icon: Icons.photo_library_outlined,
                  child: data.photos.isEmpty
                      ? const _EmptyState(
                          icon: Icons.photo_library_outlined,
                          title: 'No approved photos yet',
                          message:
                              'Approved event photos will appear here and in the PDF.',
                        )
                      : _PhotoGallery(
                          photos: data.photos
                              .take(_maxReportPhotos)
                              .toList(),
                        ),
                ),
                const SizedBox(height: 18),
                _SectionCard(
                  title: 'Registered participants',
                  subtitle:
                      'Participants explicitly added to the report.',
                  icon: Icons.fact_check_outlined,
                  child: data.registrations.isEmpty
                      ? const _EmptyState(
                          icon: Icons.fact_check_outlined,
                          title: 'No participants added',
                          message:
                              'Participants marked for inclusion will appear here.',
                        )
                      : _RegistrationsTable(
                          registrations: data.registrations,
                        ),
                ),
                const SizedBox(height: 18),
                _SystemNotesCard(),
                const SizedBox(height: 22),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PageHeader extends StatelessWidget {
  final String eventName;
  final VoidCallback onRefresh;
  final VoidCallback onEditNotes;
  final VoidCallback? onGeneratePdf;
  final bool isGeneratingPdf;

  const _PageHeader({
    required this.eventName,
    required this.onRefresh,
    required this.onEditNotes,
    required this.onGeneratePdf,
    required this.isGeneratingPdf,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eventName.toUpperCase(),
              style: const TextStyle(
                color: AdminWebTheme.primary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Event Report',
              style: TextStyle(
                color: AdminWebTheme.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Review event performance, manage report notes, and generate the final PDF.',
              style: TextStyle(
                color: AdminWebTheme.textSecondary,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        );

        final actions = Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Refresh'),
            ),
            OutlinedButton.icon(
              onPressed: onEditNotes,
              icon: const Icon(Icons.edit_note_rounded, size: 17),
              label: const Text('Report Notes'),
            ),
            FilledButton.icon(
              onPressed: onGeneratePdf,
              icon: isGeneratingPdf
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.picture_as_pdf_rounded,
                      size: 17,
                    ),
              label: Text(
                isGeneratingPdf
                    ? 'Generating...'
                    : 'Generate PDF',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AdminWebTheme.primary,
              ),
            ),
          ],
        );

        if (constraints.maxWidth < 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              const SizedBox(height: 16),
              actions,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: heading),
            const SizedBox(width: 20),
            actions,
          ],
        );
      },
    );
  }
}

class _OverviewBanner extends StatelessWidget {
  final _ReportData data;

  const _OverviewBanner({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // Positioned(
              //   right: -40,
              //   top: -70,
              //   child: Container(
              //     width: 230,
              //     height: 230,
              //     decoration: BoxDecoration(
              //       color: AdminWebTheme.gold.withOpacity(0.10),
              //       shape: BoxShape.circle,
              //     ),
              //   ),
              // ),
              Positioned(
  right: 30,
  top: 20,
  bottom: 20,
  child: IgnorePointer(
    child: Image.asset(
      'assets/images/logo.png',
      width: 120,
      fit: BoxFit.contain,
    ),
  ),
),
              Padding(
                padding: EdgeInsets.only(
                  right: constraints.maxWidth < 700 ? 145 : 215,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'REPORT OVERVIEW',
                      style: TextStyle(
                        color: AdminWebTheme.gold,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data.eventName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      [
                        if (data.dateText.isNotEmpty) data.dateText,
                        if (data.location.trim().isNotEmpty) data.location,
                      ].join('  •  '),
                      style: const TextStyle(
                        color: Color(0xFFD7D9EE),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      data.description.trim().isEmpty
                          ? 'A complete overview of attendance, sessions, engagement, feedback, photos, registrations and management notes.'
                          : data.description,
                      style: const TextStyle(
                        color: Color(0xFFC5C8E1),
                        fontSize: 12,
                        height: 1.55,
                      ),
                    ),
                  ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final _ReportData data;

  const _SummaryGrid({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _SummaryItem(
        title: 'Total Users',
        value: '${data.totalUsers}',
        subtitle: 'Linked to this event',
        icon: Icons.people_alt_outlined,
        color: const Color(0xFF246BFD),
      ),
      _SummaryItem(
        title: 'Attendance',
        value: '${data.present}',
        subtitle: '${data.attendanceRate}% attendance rate',
        icon: Icons.how_to_reg_outlined,
        color: const Color(0xFF17A673),
      ),
      _SummaryItem(
        title: 'Sessions',
        value: '${data.sessions.length}',
        subtitle: '${data.totalCheckIns} session check-ins',
        icon: Icons.event_note_outlined,
        color: const Color(0xFF7B4DFF),
      ),
      _SummaryItem(
        title: 'Speakers',
        value: '${data.speakers}',
        subtitle: '${data.moderators} moderators',
        icon: Icons.record_voice_over_outlined,
        color: const Color(0xFFF59E0B),
      ),
      _SummaryItem(
        title: 'Feedback',
        value: '${data.feedbacks.length}',
        subtitle: _ratingText(data.averageOverall),
        icon: Icons.star_outline_rounded,
        color: const Color(0xFFEF476F),
      ),
      _SummaryItem(
        title: 'Certificates',
        value: '${data.certificates}',
        subtitle: 'Generated certificates',
        icon: Icons.workspace_premium_outlined,
        color: const Color(0xFF0EA5E9),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 1180
            ? 6
            : constraints.maxWidth >= 760
                ? 3
                : constraints.maxWidth >= 480
                    ? 2
                    : 1;

        final spacing = 12.0;
        final width =
            (constraints.maxWidth - (spacing * (count - 1))) / count;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: _SummaryCard(item: item),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _SummaryItem {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _SummaryItem({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

class _SummaryCard extends StatelessWidget {
  final _SummaryItem item;

  const _SummaryCard({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 126,
      padding: const EdgeInsets.all(16),
      decoration: _webCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(11),
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
                  color: AdminWebTheme.textPrimary,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            item.title,
            style: const TextStyle(
              color: AdminWebTheme.textPrimary,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            item.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AdminWebTheme.textSecondary,
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final Widget? action;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: _webCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
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
                const SizedBox(width: 11),
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
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                if (action != null) action!,
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(18),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _ReportMetricsGrid extends StatelessWidget {
  final _ReportData data;

  const _ReportMetricsGrid({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Attendees', '${data.attendees}'),
      ('Speakers', '${data.speakers}'),
      ('Moderators', '${data.moderators}'),
      ('Staff', '${data.staff}'),
      ('Admins', '${data.admins}'),
      ('Present', '${data.present}'),
      ('Absent', '${data.absent}'),
      ('Attendance Rate', '${data.attendanceRate}%'),
      ('Approved Photos', '${data.photos.length}'),
      ('Registered Participants', '${data.registrations.length}'),
      ('Chat Messages', '${data.totalMessages}'),
      ('Session Check-ins', '${data.totalCheckIns}'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 1000
            ? 4
            : constraints.maxWidth >= 640
                ? 3
                : 2;

        final spacing = 10.0;
        final width =
            (constraints.maxWidth - (spacing * (count - 1))) / count;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map(
                (item) => Container(
                  width: width,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFBFD),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AdminWebTheme.border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$1,
                        style: const TextStyle(
                          color: AdminWebTheme.textSecondary,
                          fontSize: 9.5,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item.$2,
                        style: const TextStyle(
                          color: AdminWebTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _NotesView extends StatelessWidget {
  final _ReportNotes notes;

  const _NotesView({
    required this.notes,
  });

  @override
  Widget build(BuildContext context) {
    final items = <(String, String)>[
      ('Event Objectives', notes.eventObjectives),
      ('Key Highlights', notes.keyHighlights),
      ('Main Outcomes', notes.mainOutcomes),
      ('Challenges', notes.challenges),
      ('Recommendations', notes.recommendations),
      ('Conclusion', notes.conclusion),
    ].where((item) => item.$2.trim().isNotEmpty).toList();

    return Column(
      children: items
          .map(
            (item) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFBFD),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AdminWebTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.$1,
                    style: const TextStyle(
                      color: AdminWebTheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.$2,
                    style: const TextStyle(
                      color: AdminWebTheme.textPrimary,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _SessionsTable extends StatelessWidget {
  final List<_SessionReportItem> sessions;

  const _SessionsTable({
    required this.sessions,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(
            children: sessions
                .map(
                  (session) => Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFBFD),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AdminWebTheme.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.title,
                          style: const TextStyle(
                            color: AdminWebTheme.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          _formatSessionTime(
                            session.startTime,
                            session.endTime,
                          ),
                          style: const TextStyle(
                            color: AdminWebTheme.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          session.location,
                          style: const TextStyle(
                            color: AdminWebTheme.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _MiniBadge(
                              text:
                                  '${session.checkedInCount} check-ins',
                            ),
                            _MiniBadge(
                              text:
                                  '${session.totalMessages} messages',
                            ),
                            _MiniBadge(
                              text:
                                  '${session.activeChatUsers} chat users',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: constraints.maxWidth,
            ),
            child: DataTable(
              headingRowHeight: 44,
              dataRowMinHeight: 52,
              dataRowMaxHeight: 60,
              headingRowColor: WidgetStateProperty.all(
                const Color(0xFFFAFBFD),
              ),
              horizontalMargin: 14,
              columnSpacing: 24,
              headingTextStyle: const TextStyle(
                color: AdminWebTheme.textSecondary,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
              dataTextStyle: const TextStyle(
                color: AdminWebTheme.textPrimary,
                fontSize: 10,
              ),
              columns: const [
                DataColumn(label: Text('SESSION')),
                DataColumn(label: Text('SCHEDULE')),
                DataColumn(label: Text('LOCATION')),
                DataColumn(label: Text('SPEAKERS')),
                DataColumn(label: Text('CHECK-INS')),
                DataColumn(label: Text('MESSAGES')),
                DataColumn(label: Text('RATING')),
              ],
              rows: sessions.map((session) {
                return DataRow(
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 210,
                        child: Text(
                          session.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        _formatSessionTime(
                          session.startTime,
                          session.endTime,
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 150,
                        child: Text(
                          session.location,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(Text('${session.speakerCount}')),
                    DataCell(Text('${session.checkedInCount}')),
                    DataCell(Text('${session.totalMessages}')),
                    DataCell(
                      Text(_ratingText(session.averageRating)),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String text;

  const _MiniBadge({
    required this.text,
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
        text,
        style: const TextStyle(
          color: AdminWebTheme.primary,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EngagementGrid extends StatelessWidget {
  final _ReportData data;

  const _EngagementGrid({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Session Check-ins', '${data.totalCheckIns}'),
      ('Chat Messages', '${data.totalMessages}'),
      ('Feedback Responses', '${data.feedbacks.length}'),
      ('Overall Rating', _ratingText(data.averageOverall)),
      ('Session Quality', _ratingText(data.averageSession)),
      ('Speaker Rating', _ratingText(data.averageSpeaker)),
      ('Venue Rating', _ratingText(data.averageVenue)),
      ('App Experience', _ratingText(data.averageApp)),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 560
                ? 2
                : 1;

        final spacing = 10.0;
        final width =
            (constraints.maxWidth - (spacing * (count - 1))) / count;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map(
                (item) => Container(
                  width: width,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFBFD),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AdminWebTheme.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.$1,
                          style: const TextStyle(
                            color: AdminWebTheme.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      Text(
                        item.$2,
                        style: const TextStyle(
                          color: AdminWebTheme.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _FeedbackList extends StatelessWidget {
  final List<_FeedbackReportItem> feedbacks;

  const _FeedbackList({
    required this.feedbacks,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: feedbacks.map((feedback) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFBFD),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AdminWebTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        AdminWebTheme.primary.withOpacity(0.08),
                    child: Text(
                      feedback.userName.trim().isEmpty
                          ? '?'
                          : feedback.userName
                              .trim()
                              .substring(0, 1)
                              .toUpperCase(),
                      style: const TextStyle(
                        color: AdminWebTheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          feedback.userName,
                          style: const TextStyle(
                            color: AdminWebTheme.textPrimary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (feedback.userEmail.isNotEmpty)
                          Text(
                            feedback.userEmail,
                            style: const TextStyle(
                              color: AdminWebTheme.textSecondary,
                              fontSize: 9.5,
                            ),
                          ),
                      ],
                    ),
                  ),
                  _RatingBadge(
                    value: feedback.overallRating,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _MiniBadge(
                    text:
                        'Session ${_ratingText(feedback.sessionQualityRating)}',
                  ),
                  _MiniBadge(
                    text:
                        'Speaker ${_ratingText(feedback.speakerRating)}',
                  ),
                  _MiniBadge(
                    text:
                        'Venue ${_ratingText(feedback.venueRating)}',
                  ),
                  _MiniBadge(
                    text:
                        'App ${_ratingText(feedback.appExperienceRating)}',
                  ),
                ],
              ),
              if (feedback.likedMost.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                _FeedbackText(
                  title: 'Liked most',
                  value: feedback.likedMost,
                ),
              ],
              if (feedback.improvementSuggestion.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                _FeedbackText(
                  title: 'Improvement suggestion',
                  value: feedback.improvementSuggestion,
                ),
              ],
              if (feedback.additionalComments.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                _FeedbackText(
                  title: 'Additional comments',
                  value: feedback.additionalComments,
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  final double value;

  const _RatingBadge({
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AdminWebTheme.gold.withOpacity(0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.star_rounded,
            size: 14,
            color: AdminWebTheme.gold,
          ),
          const SizedBox(width: 4),
          Text(
            _ratingText(value),
            style: const TextStyle(
              color: AdminWebTheme.textPrimary,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackText extends StatelessWidget {
  final String title;
  final String value;

  const _FeedbackText({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AdminWebTheme.primary,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AdminWebTheme.textPrimary,
            fontSize: 10.5,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _PhotoGallery extends StatelessWidget {
  final List<_PhotoReportItem> photos;

  const _PhotoGallery({
    required this.photos,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 1100
            ? 5
            : constraints.maxWidth >= 760
                ? 4
                : constraints.maxWidth >= 500
                    ? 3
                    : 2;

        final spacing = 10.0;
        final width =
            (constraints.maxWidth - (spacing * (count - 1))) / count;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: photos.map((photo) {
            return SizedBox(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 1.2,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: photo.photoUrl.trim().isEmpty
                          ? Container(
                              color: const Color(0xFFFAFBFD),
                              child: const Icon(
                                Icons.image_not_supported_outlined,
                                color: AdminWebTheme.textSecondary,
                              ),
                            )
                          : Image.network(
                              photo.photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) {
                                return Container(
                                  color: const Color(0xFFFAFBFD),
                                  child: const Icon(
                                    Icons.broken_image_outlined,
                                    color:
                                        AdminWebTheme.textSecondary,
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    photo.sessionTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AdminWebTheme.textPrimary,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    photo.userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AdminWebTheme.textSecondary,
                      fontSize: 8.5,
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

class _RegistrationsTable extends StatelessWidget {
  final List<_RegistrationReportItem> registrations;

  const _RegistrationsTable({
    required this.registrations,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 680) {
          return Column(
            children: registrations.map((item) {
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFBFD),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AdminWebTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        color: AdminWebTheme.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.email.isEmpty ? '-' : item.email,
                      style: const TextStyle(
                        color: AdminWebTheme.textSecondary,
                        fontSize: 9.5,
                      ),
                    ),
                    const SizedBox(height: 7),
                    _MiniBadge(text: item.role),
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
              headingRowHeight: 44,
              dataRowMinHeight: 48,
              dataRowMaxHeight: 56,
              headingRowColor: WidgetStateProperty.all(
                const Color(0xFFFAFBFD),
              ),
              horizontalMargin: 14,
              columnSpacing: 26,
              headingTextStyle: const TextStyle(
                color: AdminWebTheme.textSecondary,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
              dataTextStyle: const TextStyle(
                color: AdminWebTheme.textPrimary,
                fontSize: 10,
              ),
              columns: const [
                DataColumn(label: Text('NAME')),
                DataColumn(label: Text('EMAIL')),
                DataColumn(label: Text('ROLE')),
                DataColumn(label: Text('STATUS')),
                DataColumn(label: Text('REGISTERED')),
              ],
              rows: registrations.map((item) {
                return DataRow(
                  cells: [
                    DataCell(Text(item.name)),
                    DataCell(Text(item.email.isEmpty ? '-' : item.email)),
                    DataCell(Text(item.role)),
                    DataCell(Text(item.status)),
                    DataCell(
                      Text(
                        item.registeredAt == null
                            ? '-'
                            : _formatDate(item.registeredAt!),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

class _SystemNotesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final notes = [
      'Attendance rate is calculated from event attendance records compared with registered attendees.',
      'Only admin-approved event photos are included in the dashboard and generated PDF.',
      'The generated PDF includes a maximum of 10 approved event photos.',
      'Feedback ratings are calculated directly from attendee feedback submissions.',
      'Speaker and moderator counts are based on user roles linked to the selected event.',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AdminWebTheme.primary.withOpacity(0.045),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AdminWebTheme.primary.withOpacity(0.10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: AdminWebTheme.primary,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'System notes',
                style: TextStyle(
                  color: AdminWebTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...notes.map(
            (note) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '•',
                    style: TextStyle(
                      color: AdminWebTheme.gold,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      note,
                      style: const TextStyle(
                        color: AdminWebTheme.textSecondary,
                        fontSize: 10,
                        height: 1.45,
                      ),
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
        vertical: 36,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminWebTheme.border),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: AdminWebTheme.primary,
            size: 34,
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

class _ReportErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ReportErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: _webCardDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 44,
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load event report',
              style: TextStyle(
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
                fontSize: 10.5,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportNotesDialog extends StatefulWidget {
  final String eventId;
  final String eventName;
  final _ReportNotes initialNotes;

  const _ReportNotesDialog({
    required this.eventId,
    required this.eventName,
    required this.initialNotes,
  });

  @override
  State<_ReportNotesDialog> createState() =>
      _ReportNotesDialogState();
}

class _ReportNotesDialogState extends State<_ReportNotesDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _objectives;
  late final TextEditingController _highlights;
  late final TextEditingController _outcomes;
  late final TextEditingController _challenges;
  late final TextEditingController _recommendations;
  late final TextEditingController _conclusion;

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _objectives = TextEditingController(
      text: widget.initialNotes.eventObjectives,
    );
    _highlights = TextEditingController(
      text: widget.initialNotes.keyHighlights,
    );
    _outcomes = TextEditingController(
      text: widget.initialNotes.mainOutcomes,
    );
    _challenges = TextEditingController(
      text: widget.initialNotes.challenges,
    );
    _recommendations = TextEditingController(
      text: widget.initialNotes.recommendations,
    );
    _conclusion = TextEditingController(
      text: widget.initialNotes.conclusion,
    );
  }

  @override
  void dispose() {
    _objectives.dispose();
    _highlights.dispose();
    _outcomes.dispose();
    _challenges.dispose();
    _recommendations.dispose();
    _conclusion.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;

    setState(() => _saving = true);

    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('reportNotes')
          .doc('main')
          .set({
        'eventObjectives': _objectives.text.trim(),
        'keyHighlights': _highlights.text.trim(),
        'mainOutcomes': _outcomes.text.trim(),
        'challenges': _challenges.text.trim(),
        'recommendations': _recommendations.text.trim(),
        'conclusion': _conclusion.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save report notes: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 860,
          maxHeight: 760,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: AdminWebTheme.border,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.edit_note_rounded,
                    color: AdminWebTheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Report Notes',
                          style: TextStyle(
                            color: AdminWebTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          widget.eventName,
                          style: const TextStyle(
                            color: AdminWebTheme.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _NotesField(
                        label: 'Event Objectives',
                        controller: _objectives,
                      ),
                      const SizedBox(height: 14),
                      _NotesField(
                        label: 'Key Highlights',
                        controller: _highlights,
                      ),
                      const SizedBox(height: 14),
                      _NotesField(
                        label: 'Main Outcomes',
                        controller: _outcomes,
                      ),
                      const SizedBox(height: 14),
                      _NotesField(
                        label: 'Challenges',
                        controller: _challenges,
                      ),
                      const SizedBox(height: 14),
                      _NotesField(
                        label: 'Recommendations',
                        controller: _recommendations,
                      ),
                      const SizedBox(height: 14),
                      _NotesField(
                        label: 'Conclusion',
                        controller: _conclusion,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AdminWebTheme.border),
                ),
              ),
              child: Row(
                children: [
                  const Spacer(),
                  OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.save_outlined,
                            size: 17,
                          ),
                    label: Text(
                      _saving ? 'Saving...' : 'Save Notes',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AdminWebTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotesField extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _NotesField({
    required this.label,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      minLines: 3,
      maxLines: 6,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: true,
        filled: true,
        fillColor: const Color(0xFFFAFBFD),
      ),
    );
  }
}

class _ReportPdfGenerator {
  static const int maxPhotos = 10;

  static Future<Uint8List> build(_ReportData data) async {
    final pdf = pw.Document();
    final regular = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();

    pw.MemoryImage? logoImage;

    try {
      final logoData = await rootBundle.load('assets/images/logo.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {
      logoImage = null;
    }

    final photos = data.photos.take(maxPhotos).toList();
    final images = <String, pw.ImageProvider?>{};

    for (final photo in photos) {
      if (photo.photoUrl.trim().isEmpty) continue;

      try {
        images[photo.id] = await networkImage(photo.photoUrl);
      } catch (_) {
        images[photo.id] = null;
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        theme: pw.ThemeData.withFont(
          base: regular,
          bold: bold,
        ),
        build: (_) => [
          _header(data, logoImage),
          pw.SizedBox(height: 18),
          _title('Report Summary'),
          pw.SizedBox(height: 8),
          _infoTable([
            ['Event Name', data.eventName],
            ['Date', data.dateText.isEmpty ? '-' : data.dateText],
            ['Location', data.location.isEmpty ? '-' : data.location],
            ['Total Users', '${data.totalUsers}'],
            ['Attendees', '${data.attendees}'],
            ['Present', '${data.present}'],
            ['Absent', '${data.absent}'],
            ['Attendance Rate', '${data.attendanceRate}%'],
            ['Speakers', '${data.speakers}'],
            ['Moderators', '${data.moderators}'],
            ['Staff', '${data.staff}'],
            ['Certificates', '${data.certificates}'],
          ]),
          pw.SizedBox(height: 18),
          _title('Engagement Summary'),
          pw.SizedBox(height: 8),
          _infoTable([
            ['Sessions', '${data.sessions.length}'],
            ['Session Check-ins', '${data.totalCheckIns}'],
            ['Chat Messages', '${data.totalMessages}'],
            ['Feedback Responses', '${data.feedbacks.length}'],
            ['Average Overall Rating', _ratingText(data.averageOverall)],
            ['Average Session Quality', _ratingText(data.averageSession)],
            ['Average Speaker Rating', _ratingText(data.averageSpeaker)],
            ['Average Venue Rating', _ratingText(data.averageVenue)],
            ['Average App Experience', _ratingText(data.averageApp)],
          ]),
          if (data.notes.hasContent) ...[
            pw.SizedBox(height: 18),
            _title('Management Report Notes'),
            pw.SizedBox(height: 8),
            ..._notes(data.notes),
          ],
          pw.SizedBox(height: 18),
          _title('Session Performance'),
          pw.SizedBox(height: 8),
          data.sessions.isEmpty
              ? pw.Text('No sessions found.')
              : _sessionTable(data.sessions),
          pw.SizedBox(height: 18),
          _title('Attendee Feedback'),
          pw.SizedBox(height: 8),
          if (data.feedbacks.isEmpty)
            pw.Text('No attendee feedback submitted.')
          else
            ...data.feedbacks.map(_feedbackCard),
          pw.SizedBox(height: 18),
          _title('Photo Gallery'),
          pw.SizedBox(height: 8),
          if (photos.isEmpty)
            pw.Text('No approved photos available.')
          else
            _photoGrid(photos, images),
          pw.SizedBox(height: 18),
          _title('Registered Participants'),
          pw.SizedBox(height: 8),
          data.registrations.isEmpty
              ? pw.Text('No registered participants included.')
              : _registrationTable(data.registrations),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _header(
    _ReportData data,
    pw.MemoryImage? logoImage,
  ) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.indigo900,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(
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
                if (data.dateText.isNotEmpty ||
                    data.location.trim().isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    _pdfSafe(
                      [
                        if (data.dateText.isNotEmpty) data.dateText,
                        if (data.location.trim().isNotEmpty)
                          data.location,
                      ].join('  •  '),
                    ),
                    style: const pw.TextStyle(
                      color: PdfColors.grey300,
                      fontSize: 8.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          pw.SizedBox(width: 16),
          pw.Container(
            width: 86,
            height: 86,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: logoImage == null
                ? pw.Center(
                    child: pw.Text(
                      'NAMA',
                      style: pw.TextStyle(
                        color: PdfColors.indigo900,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  )
                : pw.Image(
                    logoImage,
                    fit: pw.BoxFit.contain,
                  ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _title(String text) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 13,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.indigo900,
      ),
    );
  }

  static pw.Widget _infoTable(List<List<String>> rows) {
    return pw.Table.fromTextArray(
      border: pw.TableBorder.all(
        color: PdfColors.grey300,
        width: 0.6,
      ),
      cellPadding: const pw.EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 6,
      ),
      headers: ['Item', 'Details'],
      headerStyle: pw.TextStyle(
        color: PdfColors.white,
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
      ),
      headerDecoration: const pw.BoxDecoration(
        color: PdfColors.indigo900,
      ),
      cellStyle: const pw.TextStyle(fontSize: 8.5),
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

  static pw.Widget _sessionTable(
    List<_SessionReportItem> sessions,
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
      headers: [
        '#',
        'Session',
        'Time',
        'Location',
        'Check-ins',
        'Messages',
      ],
      headerStyle: pw.TextStyle(
        color: PdfColors.white,
        fontSize: 7.5,
        fontWeight: pw.FontWeight.bold,
      ),
      headerDecoration: const pw.BoxDecoration(
        color: PdfColors.indigo900,
      ),
      cellStyle: const pw.TextStyle(fontSize: 7),
      data: List.generate(sessions.length, (index) {
        final item = sessions[index];

        return [
          '${index + 1}',
          _pdfSafe(item.title),
          _pdfSafe(
            _formatSessionTime(
              item.startTime,
              item.endTime,
            ),
          ),
          _pdfSafe(item.location),
          '${item.checkedInCount}',
          '${item.totalMessages}',
        ];
      }),
    );
  }

  static pw.Widget _registrationTable(
    List<_RegistrationReportItem> registrations,
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
      headers: ['#', 'Name', 'Email', 'Role', 'Registered'],
      headerStyle: pw.TextStyle(
        color: PdfColors.white,
        fontSize: 7.5,
        fontWeight: pw.FontWeight.bold,
      ),
      headerDecoration: const pw.BoxDecoration(
        color: PdfColors.indigo900,
      ),
      cellStyle: const pw.TextStyle(fontSize: 7),
      data: List.generate(registrations.length, (index) {
        final item = registrations[index];

        return [
          '${index + 1}',
          _pdfSafe(item.name),
          _pdfSafe(item.email.isEmpty ? '-' : item.email),
          _pdfSafe(item.role),
          item.registeredAt == null
              ? '-'
              : _formatDate(item.registeredAt!),
        ];
      }),
    );
  }

  static pw.Widget _feedbackCard(
    _FeedbackReportItem feedback,
  ) {
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
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            'Overall: ${_ratingText(feedback.overallRating)} | '
            'Session: ${_ratingText(feedback.sessionQualityRating)} | '
            'Speaker: ${_ratingText(feedback.speakerRating)} | '
            'Venue: ${_ratingText(feedback.venueRating)} | '
            'App: ${_ratingText(feedback.appExperienceRating)}',
            style: const pw.TextStyle(fontSize: 7.5),
          ),
          if (feedback.additionalComments.trim().isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              _pdfSafe(feedback.additionalComments),
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
        ],
      ),
    );
  }

  static List<pw.Widget> _notes(_ReportNotes notes) {
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
                title,
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.indigo900,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                _pdfSafe(value),
                style: const pw.TextStyle(
                  fontSize: 8.5,
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

  static pw.Widget _photoGrid(
    List<_PhotoReportItem> photos,
    Map<String, pw.ImageProvider?> images,
  ) {
    final rows = <pw.Widget>[];

    for (int i = 0; i < photos.length; i += 3) {
      final rowPhotos = photos.skip(i).take(3).toList();

      rows.add(
        pw.Row(
          children: List.generate(3, (index) {
            if (index >= rowPhotos.length) {
              return pw.Expanded(child: pw.SizedBox());
            }

            final photo = rowPhotos[index];
            final image = images[photo.id];

            return pw.Expanded(
              child: pw.Container(
                height: 78,
                margin: pw.EdgeInsets.only(
                  right: index == 2 ? 0 : 5,
                  bottom: 5,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  border: pw.Border.all(
                    color: PdfColors.grey400,
                  ),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: image == null
                    ? pw.Center(
                        child: pw.Text(
                          'Photo unavailable',
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
}

class _ReportData {
  final String eventId;
  final String eventName;
  final String description;
  final String location;
  final DateTime? startDate;
  final DateTime? endDate;
  final int totalUsers;
  final int attendees;
  final int speakers;
  final int moderators;
  final int staff;
  final int admins;
  final int present;
  final int certificates;
  final List<_SessionReportItem> sessions;
  final List<_FeedbackReportItem> feedbacks;
  final List<_PhotoReportItem> photos;
  final List<_RegistrationReportItem> registrations;
  final int totalMessages;
  final int totalCheckIns;
  final double averageOverall;
  final double averageSession;
  final double averageSpeaker;
  final double averageVenue;
  final double averageApp;
  final _ReportNotes notes;

  const _ReportData({
    required this.eventId,
    required this.eventName,
    required this.description,
    required this.location,
    required this.startDate,
    required this.endDate,
    required this.totalUsers,
    required this.attendees,
    required this.speakers,
    required this.moderators,
    required this.staff,
    required this.admins,
    required this.present,
    required this.certificates,
    required this.sessions,
    required this.feedbacks,
    required this.photos,
    required this.registrations,
    required this.totalMessages,
    required this.totalCheckIns,
    required this.averageOverall,
    required this.averageSession,
    required this.averageSpeaker,
    required this.averageVenue,
    required this.averageApp,
    required this.notes,
  });

  int get absent {
    final result = attendees - present;
    return result < 0 ? 0 : result;
  }

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

  factory _ReportData.empty({
    required String eventId,
    required String eventName,
  }) {
    return _ReportData(
      eventId: eventId,
      eventName: eventName,
      description: '',
      location: '',
      startDate: null,
      endDate: null,
      totalUsers: 0,
      attendees: 0,
      speakers: 0,
      moderators: 0,
      staff: 0,
      admins: 0,
      present: 0,
      certificates: 0,
      sessions: const [],
      feedbacks: const [],
      photos: const [],
      registrations: const [],
      totalMessages: 0,
      totalCheckIns: 0,
      averageOverall: 0,
      averageSession: 0,
      averageSpeaker: 0,
      averageVenue: 0,
      averageApp: 0,
      notes: _ReportNotes.empty(),
    );
  }
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
      title: (data['title'] ??
              data['sessionTitle'] ??
              'Untitled Session')
          .toString(),
      location: (data['location'] ?? 'Unknown Location').toString(),
      startTime: _readDate(data['startTime']),
      endTime: _readDate(data['endTime']),
      speakerCount:
          List.from(data['speakerIds'] as List? ?? []).length,
      checkedInCount:
          List.from(data['checkedInAttendees'] as List? ?? []).length,
      totalMessages:
          (data['totalMessages'] as num?)?.toInt() ?? 0,
      activeChatUsers:
          List.from(data['uniqueParticipants'] as List? ?? []).length,
      averageRating:
          (data['averageRating'] as num?)?.toDouble() ?? 0,
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
      userEmail:
          (data['userEmail'] ?? data['email'] ?? '').toString(),
      overallRating:
          ((data['overallRating'] ?? data['rating'] ?? 0) as num?)
                  ?.toDouble() ??
              0,
      sessionQualityRating:
          ((data['sessionQualityRating'] ?? 0) as num?)
                  ?.toDouble() ??
              0,
      speakerRating:
          ((data['speakerRating'] ?? 0) as num?)?.toDouble() ?? 0,
      venueRating:
          ((data['venueRating'] ?? 0) as num?)?.toDouble() ?? 0,
      appExperienceRating:
          ((data['appExperienceRating'] ?? 0) as num?)
                  ?.toDouble() ??
              0,
      likedMost: (data['likedMost'] ?? '').toString(),
      improvementSuggestion:
          (data['improvementSuggestion'] ?? '').toString(),
      additionalComments:
          (data['additionalComments'] ??
                  data['comment'] ??
                  data['feedback'] ??
                  '')
              .toString(),
      createdAt: _readDate(
        data['createdAt'] ??
            data['submittedAt'] ??
            data['updatedAt'],
      ),
    );
  }
}

class _PhotoReportItem {
  final String id;
  final String sessionTitle;
  final String userName;
  final String userEmail;
  final String photoUrl;
  final String caption;
  final DateTime? uploadedAt;

  const _PhotoReportItem({
    required this.id,
    required this.sessionTitle,
    required this.userName,
    required this.userEmail,
    required this.photoUrl,
    required this.caption,
    required this.uploadedAt,
  });

  factory _PhotoReportItem.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    return _PhotoReportItem(
      id: doc.id,
      sessionTitle:
          (data['sessionTitle'] ?? 'Unknown Session').toString(),
      userName: (data['userName'] ?? 'Attendee').toString(),
      userEmail: (data['userEmail'] ?? '').toString(),
      photoUrl:
          (data['photoUrl'] ?? data['imageUrl'] ?? '').toString(),
      caption: (data['caption'] ?? '').toString(),
      uploadedAt:
          _readDate(data['uploadedAt'] ?? data['createdAt']),
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
      registeredAt:
          _readDate(data['registeredAt'] ?? data['createdAt']),
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
      eventObjectives:
          (data['eventObjectives'] ?? '').toString(),
      keyHighlights: (data['keyHighlights'] ?? '').toString(),
      mainOutcomes: (data['mainOutcomes'] ?? '').toString(),
      challenges: (data['challenges'] ?? '').toString(),
      recommendations:
          (data['recommendations'] ?? '').toString(),
      conclusion: (data['conclusion'] ?? '').toString(),
    );
  }
}

BoxDecoration _webCardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: AdminWebTheme.border),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.025),
        blurRadius: 14,
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

String _formatTime(DateTime date) {
  final hour = date.hour;
  final minute = date.minute.toString().padLeft(2, '0');
  final suffix = hour >= 12 ? 'PM' : 'AM';
  final displayHour =
      hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);

  return '$displayHour:$minute $suffix';
}

String _formatSessionTime(DateTime? start, DateTime? end) {
  if (start == null && end == null) return 'Time not set';

  if (start != null && end == null) {
    return '${_formatDate(start)} • ${_formatTime(start)}';
  }

  if (start == null && end != null) {
    return '${_formatDate(end)} • ${_formatTime(end)}';
  }

  final sameDay = start!.year == end!.year &&
      start.month == end.month &&
      start.day == end.day;

  if (sameDay) {
    return '${_formatDate(start)} • '
        '${_formatTime(start)} - ${_formatTime(end)}';
  }

  return '${_formatDate(start)} - ${_formatDate(end)}';
}

String _ratingText(double value) {
  if (value <= 0) return '-';
  return '${value.toStringAsFixed(1)} / 5';
}

String _pdfSafe(String value) {
  return value
      .replaceAll('\n', ' ')
      .replaceAll('\r', ' ')
      .trim();
}
