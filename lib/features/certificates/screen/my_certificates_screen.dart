import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/models/certificate_model.dart';
import 'package:events_app_trueattempt/features/certificates/screen/certificate_preview_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MyCertificatesScreen extends StatefulWidget {
  const MyCertificatesScreen({super.key});

  @override
  State<MyCertificatesScreen> createState() => _MyCertificatesScreenState();
}

class _MyCertificatesScreenState extends State<MyCertificatesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late Future<_MyCertificatesData> _certificatesFuture;

  @override
  void initState() {
    super.initState();
    _certificatesFuture = _loadMyCertificates();
  }

  void _refresh() {
    setState(() {
      _certificatesFuture = _loadMyCertificates();
    });
  }

  Future<_MyCertificatesData> _loadMyCertificates() async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      return const _MyCertificatesData(
        availableCertificates: [],
        lockedCertificates: [],
      );
    }

    final userId = currentUser.uid;

    final eventsSnap = await _firestore.collection('events').get();

    final availableCertificates = <_CertificateWithEvent>[];
    final lockedCertificates = <_CertificateWithEvent>[];

    for (final eventDoc in eventsSnap.docs) {
      final eventData = eventDoc.data();

      final eventName = (eventData['name'] ??
              eventData['title'] ??
              eventData['eventName'] ??
              'Unnamed Event')
          .toString();

      final eventStartDate = _readDate(
        eventData['startDate'] ??
            eventData['startTime'] ??
            eventData['eventStartDate'] ??
            eventData['date'],
      );

      final eventEndDate = _readEventEndDate(eventData);

      final eventIsOver = _isEventOver(eventEndDate);

      final certSnap = await _firestore
          .collection('events')
          .doc(eventDoc.id)
          .collection('certificates')
          .where('userId', isEqualTo: userId)
          .get();

      for (final certDoc in certSnap.docs) {
        final certificate = CertificateModel.fromFirestore(certDoc);

        final item = _CertificateWithEvent(
          certificate: certificate,
          eventName: eventName,
          eventStartDate: eventStartDate,
          eventEndDate: eventEndDate,
          eventIsOver: eventIsOver,
        );

        if (eventIsOver) {
          availableCertificates.add(item);
        } else {
          lockedCertificates.add(item);
        }
      }
    }

    availableCertificates.sort((a, b) {
      final aDate = a.certificate.generatedAt;
      final bDate = b.certificate.generatedAt;

      if (aDate == null && bDate == null) {
        return a.eventName.compareTo(b.eventName);
      }

      if (aDate == null) return 1;
      if (bDate == null) return -1;

      return bDate.compareTo(aDate);
    });

    lockedCertificates.sort((a, b) {
      final aDate = a.eventEndDate;
      final bDate = b.eventEndDate;

      if (aDate == null && bDate == null) {
        return a.eventName.compareTo(b.eventName);
      }

      if (aDate == null) return 1;
      if (bDate == null) return -1;

      return aDate.compareTo(bDate);
    });

    return _MyCertificatesData(
      availableCertificates: availableCertificates,
      lockedCertificates: lockedCertificates,
    );
  }

  Future<void> _downloadCertificate(_CertificateWithEvent item) async {
    if (!item.eventIsOver) {
      _showLockedMessage(item);
      return;
    }

    await CertificatePreviewScreen.downloadCertificatePdf(
      context: context,
      certificate: item.certificate,
      eventName: item.eventName,
      eventDate: item.eventStartDate,
    );
  }

  void _viewCertificate(_CertificateWithEvent item) {
    if (!item.eventIsOver) {
      _showLockedMessage(item);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CertificatePreviewScreen(
          certificate: item.certificate,
          eventName: item.eventName,
          eventDate: item.eventStartDate,
        ),
      ),
    );
  }

  void _showLockedMessage(_CertificateWithEvent item) {
    final endText = item.eventEndDate == null
        ? 'after the event is completed'
        : 'after ${_formatDateTime(item.eventEndDate!)}';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Certificate will be available $endText.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
            'My Certificates',
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

  Widget _topInfoCard() {
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
            'Certificate Center',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Your certificates will appear here after the admin generates them and the event is over.',
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

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(),
      child: const Column(
        children: [
          Icon(
            Icons.workspace_premium_outlined,
            color: AppColors.namaNavyBlue,
            size: 38,
          ),
          SizedBox(height: 12),
          Text(
            'No certificates available yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.namaNavyBlue,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Your certificate will appear here after the event ends and the admin generates it.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.namaMediumGray,
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _lockedInfoCard(int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.namaGoldenYellow.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.namaGoldenYellow.withOpacity(0.35),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: AppColors.namaGoldenYellow.withOpacity(0.20),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.lock_clock_rounded,
              color: AppColors.namaGoldenYellow,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$count certificate${count == 1 ? '' : 's'} already generated, but locked until the event is over.',
              style: const TextStyle(
                color: AppColors.namaNavyBlue,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.namaLightGray,
      body: SafeArea(
        child: FutureBuilder<_MyCertificatesData>(
          future: _certificatesFuture,
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
                        'Unable to load certificates',
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final data = snapshot.data ??
                const _MyCertificatesData(
                  availableCertificates: [],
                  lockedCertificates: [],
                );

            final available = data.availableCertificates;
            final locked = data.lockedCertificates;

            return RefreshIndicator(
              color: AppColors.namaNavyBlue,
              onRefresh: () async => _refresh(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                children: [
                  _header(),
                  const SizedBox(height: 18),
                  _topInfoCard(),
                  const SizedBox(height: 18),
                  if (locked.isNotEmpty) ...[
                    _lockedInfoCard(locked.length),
                    const SizedBox(height: 16),
                  ],
                  if (available.isEmpty)
                    _emptyState()
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Available Certificates',
                          style: TextStyle(
                            color: AppColors.namaNavyBlue,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...available.map((item) {
                          return _CertificateCard(
                            item: item,
                            locked: false,
                            onView: () => _viewCertificate(item),
                            onDownload: () => _downloadCertificate(item),
                          );
                        }),
                      ],
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

class _CertificateCard extends StatelessWidget {
  final _CertificateWithEvent item;
  final bool locked;
  final VoidCallback onView;
  final VoidCallback onDownload;

  const _CertificateCard({
    required this.item,
    required this.locked,
    required this.onView,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final certificate = item.certificate;
    final isSpeaker = certificate.userRole.toLowerCase() == 'speaker';

    final certificateTitle = isSpeaker
        ? 'Certificate of Appreciation'
        : 'Certificate of Participation';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: locked
                    ? Colors.grey.withOpacity(0.12)
                    : AppColors.namaGoldenYellow.withOpacity(0.16),
                child: Icon(
                  locked
                      ? Icons.lock_outline_rounded
                      : isSpeaker
                          ? Icons.record_voice_over_rounded
                          : Icons.workspace_premium_rounded,
                  color: locked ? Colors.grey : AppColors.namaGoldenYellow,
                  size: 22,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      certificateTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.namaNavyBlue,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.eventName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.namaMediumGray,
                        fontSize: 11.5,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoLine(
            icon: Icons.confirmation_number_outlined,
            text: 'Certificate ID: ${certificate.certificateId}',
          ),
          if (item.eventStartDate != null) ...[
            const SizedBox(height: 6),
            _InfoLine(
              icon: Icons.calendar_today_rounded,
              text: 'Event date: ${_formatDate(item.eventStartDate!)}',
            ),
          ],
          if (item.eventEndDate != null) ...[
            const SizedBox(height: 6),
            _InfoLine(
              icon: Icons.event_available_rounded,
              text: 'Certificate available after: ${_formatDateTime(item.eventEndDate!)}',
            ),
          ],
          if (certificate.sessionTitle != null &&
              certificate.sessionTitle!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            _InfoLine(
              icon: Icons.event_note_outlined,
              text: 'Session: ${certificate.sessionTitle}',
            ),
          ],
          if (certificate.generatedAt != null) ...[
            const SizedBox(height: 6),
            _InfoLine(
              icon: Icons.access_time_rounded,
              text: 'Generated: ${_formatDate(certificate.generatedAt!)}',
            ),
          ],
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: _SmallActionButton(
                  label: locked ? 'Locked' : 'View',
                  icon: locked
                      ? Icons.lock_outline_rounded
                      : Icons.visibility_outlined,
                  backgroundColor:
                      locked ? Colors.grey.shade400 : AppColors.namaNavyBlue,
                  textColor: Colors.white,
                  onTap: onView,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SmallActionButton(
                  label: locked ? 'Unavailable' : 'Download',
                  icon: locked
                      ? Icons.lock_clock_rounded
                      : Icons.download_rounded,
                  backgroundColor: locked
                      ? Colors.grey.shade300
                      : AppColors.namaGoldenYellow,
                  textColor: locked
                      ? Colors.grey.shade700
                      : AppColors.namaNavyBlue,
                  onTap: onDownload,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback onTap;

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
          style: const TextStyle(
            fontSize: 11.5,
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

class _MyCertificatesData {
  final List<_CertificateWithEvent> availableCertificates;
  final List<_CertificateWithEvent> lockedCertificates;

  const _MyCertificatesData({
    required this.availableCertificates,
    required this.lockedCertificates,
  });
}

class _CertificateWithEvent {
  final CertificateModel certificate;
  final String eventName;
  final DateTime? eventStartDate;
  final DateTime? eventEndDate;
  final bool eventIsOver;

  const _CertificateWithEvent({
    required this.certificate,
    required this.eventName,
    required this.eventStartDate,
    required this.eventEndDate,
    required this.eventIsOver,
  });
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

DateTime? _readEventEndDate(Map<String, dynamic> eventData) {
  final directEndDate = _readDate(
    eventData['endDate'] ??
        eventData['endTime'] ??
        eventData['eventEndDate'] ??
        eventData['eventEndTime'],
  );

  if (directEndDate != null) {
    return directEndDate;
  }

  final fallbackStartDate = _readDate(
    eventData['startDate'] ??
        eventData['startTime'] ??
        eventData['eventStartDate'] ??
        eventData['date'],
  );

  if (fallbackStartDate == null) {
    return null;
  }

  return DateTime(
    fallbackStartDate.year,
    fallbackStartDate.month,
    fallbackStartDate.day,
    23,
    59,
    59,
  );
}

bool _isEventOver(DateTime? eventEndDate) {
  if (eventEndDate == null) return false;
  return DateTime.now().isAfter(eventEndDate);
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

String _formatDateTime(DateTime date) {
  return '${_formatDate(date)} - ${_formatTime(date)}';
}

String _formatTime(DateTime date) {
  final hour = date.hour;
  final minute = date.minute.toString().padLeft(2, '0');
  final suffix = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour == 0 ? 12 : hour > 12 ? hour - 12 : hour;

  return '$displayHour:$minute $suffix';
}