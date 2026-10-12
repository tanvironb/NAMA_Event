import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'session_monitoring_repository.dart' as monitoring;
import 'widgets/monitoring_ui.dart' show monitorInk, monitorMuted;
import 'widgets/session_overview_tab.dart' show SessionOverviewTab;
import 'widgets/session_attendance_tab.dart' show SessionAttendanceTab;
import 'widgets/session_feedback_tab.dart' show SessionFeedbackTab;
import 'widgets/session_chat_tab.dart' show SessionChatTab;
import 'widgets/session_photos_tab.dart' show SessionPhotosTab;

class SessionMonitoringPage extends StatefulWidget {
  final String eventId;
  final String sessionId;
  final String eventName;

  final VoidCallback? onOpenSession;
  final VoidCallback? onEdit;

  final monitoring.SessionMonitoringRepository? repository;
  final String? sessionLink;

  const SessionMonitoringPage({
    super.key,
    required this.eventId,
    required this.sessionId,
    this.eventName = '',
    this.onOpenSession,
    this.onEdit,
    this.repository,
    this.sessionLink,
  });

  @override
  State<SessionMonitoringPage> createState() =>
      _SessionMonitoringPageState();
}

class _SessionMonitoringPageState
    extends State<SessionMonitoringPage> {
  static const Color _primary = Color(0xFF0B0B83);

  late monitoring.SessionMonitoringRepository _repository;
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _sessionStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _photosStream;

  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _configureRepository();
  }

  @override
  void didUpdateWidget(covariant SessionMonitoringPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.eventId != widget.eventId ||
        oldWidget.sessionId != widget.sessionId ||
        oldWidget.repository != widget.repository) {
      _selectedTab = 0;
      _configureRepository();
    }
  }

  void _configureRepository() {
    _repository = widget.repository ??
        monitoring.SessionMonitoringRepository(
          eventId: widget.eventId,
          sessionId: widget.sessionId,
        );

    _sessionStream = _repository.watchSession();
    _photosStream = _repository.watch(_repository.photosPath);
  }

  void _showQr(Map<String, dynamic> data) {
    final payload = (data['qrCodePayload'] ?? '').toString().trim();
    final code = (
      data['checkInCode'] ??
      data['sessionCode'] ??
      ''
    ).toString().trim();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Session QR Code',
          style: TextStyle(
            color: monitorInk,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: SizedBox(
          width: 260,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (payload.isNotEmpty)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final size = constraints.maxWidth < 220
                          ? constraints.maxWidth
                          : 220.0;

                      return Center(
                        child: QrImageView(
                          data: payload,
                          size: size,
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: _primary,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: _primary,
                          ),
                        ),
                      );
                    },
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Open Session to generate the QR code.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: monitorMuted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                if (code.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'SESSION CODE',
                    style: TextStyle(
                      color: monitorMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    code,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _primary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _copyLink() async {
    final link = widget.sessionLink?.trim();

    if (link == null || link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No public session link configured. '
            'Use Open Session to share the session code.',
          ),
        ),
      );
      return;
    }

    try {
      await Clipboard.setData(ClipboardData(text: link));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session link copied.')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not copy the link: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.apply(
          bodyColor: monitorInk,
          displayColor: monitorInk,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: _primary,
          onPrimary: Colors.white,
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FD),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF8F8FF),
                Color(0xFFF3F6FF),
                Color(0xFFF8F6FF),
              ],
            ),
          ),
          child: SafeArea(
            child: StreamBuilder<
                DocumentSnapshot<Map<String, dynamic>>>(
              stream: _sessionStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _message(
                    'Unable to load session: ${snapshot.error}',
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: _primary,
                      strokeWidth: 3,
                    ),
                  );
                }

                final document = snapshot.data!;
                final data = document.data();

                if (!document.exists || data == null) {
                  return _message('Session no longer exists.');
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final mobile = constraints.maxWidth < 600;

                    return SingleChildScrollView(
                      padding: EdgeInsets.all(mobile ? 12 : 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _header(data),
                          const SizedBox(height: 20),
                          _tabs(),
                          const SizedBox(height: 18),
                          _content(data),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _message(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: monitorMuted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back, size: 17),
              label: const Text('Back to Sessions'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(Map<String, dynamic> data) {
    switch (_selectedTab) {
      case 0:
        return SessionOverviewTab(
          repository: _repository,
          data: data,
          onEdit: widget.onEdit,
          onQr: () => _showQr(data),
          onCopy: _copyLink,
          onNotification: widget.onOpenSession,
        );

      case 1:
        return SessionAttendanceTab(
          repository: _repository,
          data: data,
        );

      case 2:
        return SessionFeedbackTab(repository: _repository);

      case 3:
        return SessionChatTab(
          repository: _repository,
          data: data,
        );

      default:
        return SessionPhotosTab(repository: _repository);
    }
  }

  Widget _header(Map<String, dynamic> data) {
    final rawTitle = (data['title'] ?? '').toString().trim();
    final title = rawTitle.isEmpty ? 'Session' : rawTitle;

    final rawLocation = (data['location'] ?? '').toString().trim();
    final location = rawLocation.isEmpty ? '—' : rawLocation;

    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 600;

        final information = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFE8EAFE),
                ),
              ),
              child: IconButton(
                tooltip: 'Back to Sessions',
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(
                  Icons.arrow_back,
                  color: _primary,
                  size: 19,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (mobile) ...[
                    const Text(
                      'Session Monitoring',
                      style: TextStyle(
                        color: monitorInk,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      title,
                      style: const TextStyle(
                        color: monitorMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ] else
                    Wrap(
                      spacing: 14,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'Session Monitoring',
                          style: TextStyle(
                            color: monitorInk,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                        const Text(
                          '|',
                          style: TextStyle(
                            color: Color(0xFFD0D4EA),
                            fontSize: 20,
                          ),
                        ),
                        Text(
                          title,
                          style: const TextStyle(
                            color: monitorInk,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 12,
                    runSpacing: 7,
                    children: [
                      _meta(
                        Icons.calendar_month_outlined,
                        monitoring.monitorDay(data['startTime']),
                      ),
                      _meta(
                        Icons.schedule,
                        '${monitoring.monitorTime(data['startTime'])} – '
                        '${monitoring.monitorTime(data['endTime'])}',
                      ),
                      _meta(
                        Icons.location_on_outlined,
                        location,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );

        final actions = Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFE7F7F0),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.circle,
                    size: 9,
                    color: Color(0xFF00AA66),
                  ),
                  SizedBox(width: 7),
                  Text(
                    'Live Monitoring',
                    style: TextStyle(
                      color: Color(0xFF00AA66),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: widget.onOpenSession,
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text(
                'Open Session',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        );

        if (constraints.maxWidth < 1050) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              information,
              const SizedBox(height: 14),
              Align(
                alignment: mobile
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: actions,
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: information),
            const SizedBox(width: 18),
            actions,
          ],
        );
      },
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: monitorMuted),
        const SizedBox(width: 6),
        Flexible(
          fit: FlexFit.loose,
          child: Text(
            text,
            softWrap: true,
            style: const TextStyle(
              color: monitorMuted,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _tabs() {
    const names = [
      'Overview',
      'Attendance',
      'Feedback',
      'Live Chat',
      'Photos',
    ];

    const icons = [
      Icons.grid_view_rounded,
      Icons.people_outline,
      Icons.star_border_rounded,
      Icons.chat_bubble_outline,
      Icons.photo_library_outlined,
    ];

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scrollable = constraints.maxWidth < 680;

          final items = List<Widget>.generate(
            names.length,
            (index) {
              final selected = _selectedTab == index;
              final color = selected ? _primary : monitorMuted;

              return Material(
                color: selected
                    ? _primary.withOpacity(0.07)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () {
                    if (_selectedTab != index) {
                      setState(() => _selectedTab = index);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: scrollable ? 132 : null,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: selected
                              ? _primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (index == 4)
                          _photoIcon(icons[index], color)
                        else
                          Icon(
                            icons[index],
                            color: color,
                            size: 20,
                          ),
                        const SizedBox(width: 9),
                        Text(
                          names[index],
                          style: TextStyle(
                            color: color,
                            fontSize: 12.5,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );

          if (scrollable) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: items),
            );
          }

          return Row(
            children: items
                .map((item) => Expanded(child: item))
                .toList(),
          );
        },
      ),
    );
  }

  Widget _photoIcon(IconData icon, Color color) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _photosStream,
      builder: (context, snapshot) {
        var pending = 0;

        if (!snapshot.hasError && snapshot.hasData) {
          pending = snapshot.data!.docs.where((document) {
            final status = (
              document.data()['status'] ?? 'pending'
            ).toString().toLowerCase();

            return status == 'pending';
          }).length;
        }

        return Badge(
          isLabelVisible: pending > 0,
          backgroundColor: const Color(0xFFFF1856),
          label: Text(
            pending > 99 ? '99+' : '$pending',
            style: const TextStyle(fontSize: 9),
          ),
          child: Icon(icon, color: color, size: 20),
        );
      },
    );
  }
}