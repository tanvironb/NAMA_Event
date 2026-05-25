// lib/features/speaker/widgets/session_qr_viewer_screen.dart

import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/enums/notification_type.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/features/admin/screen/send_notification_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

class SessionQRViewerScreen extends StatefulWidget {
  final Session session;

  const SessionQRViewerScreen({
    super.key,
    required this.session,
  });

  @override
  State<SessionQRViewerScreen> createState() => _SessionQRViewerScreenState();
}

class _SessionQRViewerScreenState extends State<SessionQRViewerScreen> {
  String _sessionCode = '';
  bool _isLoadingCode = true;
  bool _isDownloading = false;

  static const Color _primaryColor = Color(0xFF1B0F72);
  static const Color _softPurple = Color(0xFFF1EEFB);
  static const Color _textMuted = Color(0xFF7A7A7A);

  @override
  void initState() {
    super.initState();
    _loadOrCreateSessionCode();
  }

  Future<void> _loadOrCreateSessionCode() async {
    try {
      final sessionRef = FirebaseFirestore.instance
          .collection('sessions')
          .doc(widget.session.id);

      final sessionDoc = await sessionRef.get();
      final data = sessionDoc.data();

      String code = (data?['checkInCode'] ?? '').toString().trim();

      if (code.isEmpty) {
        code = _generateSessionCode();

        await sessionRef.update({
          'checkInCode': code,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      setState(() {
        _sessionCode = code;
        _isLoadingCode = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _sessionCode = _generateSessionCode();
        _isLoadingCode = false;
      });
    }
  }

  String _generateSessionCode() {
    final random = Random();
    final number = 100000 + random.nextInt(900000);
    return 'SES-$number';
  }

  Future<void> _copySessionCode() async {
    if (_sessionCode.trim().isEmpty) return;

    await Clipboard.setData(
      ClipboardData(text: _sessionCode),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Session code copied.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<Uint8List> _generateQrPdfBytes() async {
    final pdf = pw.Document();

    final qrImage = await QrPainter(
      data: widget.session.qrCodePayload,
      version: QrVersions.auto,
      gapless: true,
      color: _primaryColor,
      emptyColor: Colors.white,
    ).toImageData(900);

    final qrBytes = qrImage!.buffer.asUint8List();

    final dateText = DateFormat('EEEE, MMM d, yyyy').format(
      widget.session.startTime,
    );

    final timeText =
        '${DateFormat.jm().format(widget.session.startTime)} - ${DateFormat.jm().format(widget.session.endTime)}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFF1B0F72),
                  borderRadius: pw.BorderRadius.circular(14),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      widget.session.title,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      dateText,
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 34),
              pw.Container(
                padding: const pw.EdgeInsets.all(18),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: PdfColor.fromInt(0xFFF5B51B),
                    width: 2,
                  ),
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Image(
                  pw.MemoryImage(qrBytes),
                  width: 260,
                  height: 260,
                ),
              ),
              pw.SizedBox(height: 18),
              pw.Container(
                width: 220,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFF1EEFB),
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Session Code',
                      style: const pw.TextStyle(
                        color: PdfColors.grey700,
                        fontSize: 10,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      _sessionCode.isEmpty ? 'Not available' : _sessionCode,
                      style: pw.TextStyle(
                        color: PdfColor.fromInt(0xFF1B0F72),
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFF7F7FA),
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _pdfInfoRow('Session Code', _sessionCode),
                    pw.SizedBox(height: 10),
                    _pdfInfoRow('Time', timeText),
                    pw.SizedBox(height: 10),
                    _pdfInfoRow(
                      'Location',
                      widget.session.location.isEmpty
                          ? 'Not provided'
                          : widget.session.location,
                    ),
                    pw.SizedBox(height: 10),
                    _pdfInfoRow(
                      'Attendees',
                      '${widget.session.checkedInAttendees.length} checked in',
                    ),
                  ],
                ),
              ),
              pw.Spacer(),
              pw.Text(
                'Attendees can scan this QR code or use the session code to check in.',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(
                  color: PdfColors.grey700,
                  fontSize: 11,
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _pdfInfoRow(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 95,
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromInt(0xFF1B0F72),
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value.isEmpty ? 'Not provided' : value,
            style: const pw.TextStyle(
              fontSize: 11,
              color: PdfColors.grey800,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _downloadQrCode() async {
    if (widget.session.qrCodePayload.isEmpty) {
      _showMessage('QR code is not available.');
      return;
    }

    if (_isLoadingCode) {
      _showMessage('Please wait, session code is still loading.');
      return;
    }

    setState(() => _isDownloading = true);

    try {
      final bytes = await _generateQrPdfBytes();

      await Printing.sharePdf(
        bytes: bytes,
        filename: _cleanFileName('${widget.session.title}_QR_Code.pdf'),
      );
    } catch (e) {
      _showMessage('Failed to download QR code: $e');
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  void _shareQrAsAnnouncement() {
    if (_isLoadingCode) {
      _showMessage('Please wait, session code is still loading.');
      return;
    }

    final sessionDate = DateFormat('EEEE, MMM d, yyyy').format(
      widget.session.startTime,
    );

    final sessionTime =
        '${DateFormat.jm().format(widget.session.startTime)} - ${DateFormat.jm().format(widget.session.endTime)}';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SendNotificationScreen(
          eventId: widget.session.eventId,
          eventName: widget.session.title,
          initialTitle: 'Session QR Code Available',
          initialSubtitle: widget.session.title,
          initialAudience: 'attendee',
          initialType: AppNotificationType.announcement,
          initialQrPayload: widget.session.qrCodePayload,
          initialSessionCode: _sessionCode,
          initialSessionTitle: widget.session.title,
          initialSessionDate: widget.session.startTime,
          initialBody:
              'The QR code and session code are now available for check-in.\n\n'
              'Session: ${widget.session.title}\n'
              'Date: $sessionDate\n'
              'Time: $sessionTime\n'
              'Location: ${widget.session.location.isEmpty ? 'Not provided' : widget.session.location}\n'
              'Session Code: $_sessionCode\n\n'
              'Please scan the QR code or use the session code to check in.',
        ),
      ),
    );
  }

  String _cleanFileName(String fileName) {
    return fileName
        .replaceAll(RegExp(r'[^\w\s.-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 12.5),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final qrData = widget.session.qrCodePayload;

    if (qrData.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F8F8),
        body: SafeArea(
          child: Column(
            children: [
              _Header(
                title: 'Session QR Code',
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.qr_code_2_outlined,
                          size: 58,
                          color: AppColors.namaMediumGray,
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'QR Code Not Generated',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: AppColors.namaDarkGray,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please generate the QR code first.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.namaMediumGray,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _Header(
                  title: 'Session QR Code',
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.namaNavyBlue,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              Text(
                                widget.session.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontSize: 19,
                                      height: 1.2,
                                      fontWeight: FontWeight.w800,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                DateFormat('EEEE, MMM d, y')
                                    .format(widget.session.startTime),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.namaGoldenYellow
                                    .withOpacity(0.20),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                            border: Border.all(
                              color: AppColors.namaGoldenYellow,
                              width: 2,
                            ),
                          ),
                          child: QrImageView(
                            data: qrData,
                            version: QrVersions.auto,
                            size: 220,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: AppColors.namaNavyBlue,
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: AppColors.navyBlue,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: _copySessionCode,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 250,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 13,
                            ),
                            decoration: BoxDecoration(
                              color: _softPurple,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Session Code',
                                  style: TextStyle(
                                    color: _textMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                _isLoadingCode
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: _primaryColor,
                                        ),
                                      )
                                    : Text(
                                        _sessionCode,
                                        style: const TextStyle(
                                          color: _primaryColor,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        _buildInfoCard(
                          icon: Icons.schedule_outlined,
                          label: 'Time',
                          value:
                              '${DateFormat.jm().format(widget.session.startTime)} - ${DateFormat.jm().format(widget.session.endTime)}',
                        ),
                        const SizedBox(height: 10),
                        _buildInfoCard(
                          icon: Icons.location_on_outlined,
                          label: 'Location',
                          value: widget.session.location,
                        ),
                        const SizedBox(height: 10),
                        _buildInfoCard(
                          icon: Icons.people_outline,
                          label: 'Attendees',
                          value:
                              '${widget.session.checkedInAttendees.length} checked in',
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton.icon(
                            onPressed: _isDownloading ? null : _downloadQrCode,
                            icon: const Icon(
                              Icons.download_outlined,
                              size: 18,
                            ),
                            label: Text(
                              _isDownloading
                                  ? 'Downloading...'
                                  : 'Download QR Code',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.namaGoldenYellow,
                              foregroundColor: AppColors.navyBlue,
                              disabledBackgroundColor:
                                  AppColors.namaGoldenYellow.withOpacity(0.55),
                              disabledForegroundColor:
                                  AppColors.navyBlue.withOpacity(0.5),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed: _shareQrAsAnnouncement,
                            icon: const Icon(
                              Icons.campaign_outlined,
                              size: 18,
                            ),
                            label: const Text(
                              'Share QR',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _primaryColor,
                              side: const BorderSide(
                                color: _primaryColor,
                                width: 1.4,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Attendees can scan this QR code or use the session code to check in.',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.namaMediumGray,
                                    fontSize: 12.5,
                                    height: 1.4,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_isDownloading)
              Container(
                color: Colors.white.withOpacity(0.55),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: _primaryColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF1EEFB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: AppColors.namaNavyBlue,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.namaMediumGray,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value.isEmpty ? 'Not provided' : value,
                  style: const TextStyle(
                    color: AppColors.namaDarkGray,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _Header({
    required this.title,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 18, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back,
              color: AppColors.namaNavyBlue,
              size: 22,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minHeight: 36,
              minWidth: 36,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.namaNavyBlue,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}