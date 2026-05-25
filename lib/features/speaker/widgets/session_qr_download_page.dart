// lib/features/speaker/widgets/session_qr_download_page.dart

import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

class SessionQRDownloadPage extends StatefulWidget {
  final Session session;

  const SessionQRDownloadPage({
    super.key,
    required this.session,
  });

  @override
  State<SessionQRDownloadPage> createState() => _SessionQRDownloadPageState();
}

class _SessionQRDownloadPageState extends State<SessionQRDownloadPage> {
  bool _isGenerating = false;
  bool _isLoadingCode = true;
  String _sessionCode = '';

  static const Color _primaryColor = Color(0xFF1B0F72);
  static const Color _goldColor = Color(0xFFF5B51B);
  static const Color _textMuted = Color(0xFF6B7280);
  static const Color _softPurple = Color(0xFFEFF2FF);

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

  Future<Uint8List> _generatePdfBytes() async {
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

  Future<void> _downloadPdf() async {
    if (widget.session.qrCodePayload.isEmpty) {
      _showMessage('QR code is not available.');
      return;
    }

    if (_isLoadingCode) {
      _showMessage('Please wait, session code is still loading.');
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final bytes = await _generatePdfBytes();

      await Printing.sharePdf(
        bytes: bytes,
        filename: _cleanFileName('${widget.session.title}_QR_Code.pdf'),
      );
    } catch (e) {
      _showMessage('Failed to export QR code: $e');
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _printPreview() async {
    if (widget.session.qrCodePayload.isEmpty) {
      _showMessage('QR code is not available.');
      return;
    }

    if (_isLoadingCode) {
      _showMessage('Please wait, session code is still loading.');
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final bytes = await _generatePdfBytes();

      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: _cleanFileName('${widget.session.title}_QR_Code.pdf'),
      );
    } catch (e) {
      _showMessage('Failed to open print preview: $e');
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
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
    final sessionTitle = widget.session.title;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 70, 24, 26),
                    child: Column(
                      children: [
                        Container(
                          height: 100,
                          width: 100,
                          decoration: BoxDecoration(
                            color: _softPurple,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: const Icon(
                            Icons.qr_code_2_rounded,
                            color: _primaryColor,
                            size: 50,
                          ),
                        ),
                        const SizedBox(height: 28),
                        const Text(
                          'Export QR Code',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _primaryColor,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'Generate an A4 PDF with the QR code and session code for $sessionTitle',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _textMuted,
                              fontSize: 13,
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                        const SizedBox(height: 22),

                        Container(
                          width: 230,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1EEFB),
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
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 34),

                        SizedBox(
                          width: double.infinity,
                          height: 42,
                          child: ElevatedButton.icon(
                            onPressed: _isGenerating ? null : _downloadPdf,
                            icon: const Icon(
                              Icons.download_rounded,
                              size: 17,
                            ),
                            label: Text(
                              _isGenerating ? 'Generating...' : 'Download PDF',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor: _goldColor,
                              foregroundColor: _primaryColor,
                              disabledBackgroundColor:
                                  _goldColor.withOpacity(0.55),
                              disabledForegroundColor:
                                  _primaryColor.withOpacity(0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 42,
                          child: OutlinedButton.icon(
                            onPressed: _isGenerating ? null : _printPreview,
                            icon: const Icon(
                              Icons.print_rounded,
                              size: 17,
                            ),
                            label: const Text(
                              'Print Preview',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _primaryColor,
                              side: const BorderSide(
                                color: _primaryColor,
                                width: 1.4,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F6F3),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: _primaryColor,
                                size: 19,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'The PDF will include the QR code and session code in A4 format.',
                                  style: TextStyle(
                                    color: _textMuted,
                                    fontSize: 12.5,
                                    height: 1.35,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_isGenerating)
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

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 18, 10),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(
                Icons.arrow_back,
                color: _primaryColor,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Export QR Code',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _primaryColor,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}