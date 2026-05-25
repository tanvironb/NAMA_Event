import 'dart:typed_data';

import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/models/certificate_model.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class CertificatePreviewScreen extends StatelessWidget {
  final CertificateModel certificate;
  final String eventName;
  final DateTime? eventDate;

  const CertificatePreviewScreen({
    super.key,
    required this.certificate,
    required this.eventName,
    this.eventDate,
  });

  static Future<void> downloadCertificatePdf({
    required BuildContext context,
    required CertificateModel certificate,
    required String eventName,
    DateTime? eventDate,
  }) async {
    final bytes = await _buildCertificatePdf(
      certificate: certificate,
      eventName: eventName,
      eventDate: eventDate,
    );

    final safeName = certificate.userName
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');

    await Printing.sharePdf(
      bytes: bytes,
      filename: '${certificate.certificateId}_$safeName.pdf',
    );
  }

  Future<void> _download(BuildContext context) async {
    await downloadCertificatePdf(
      context: context,
      certificate: certificate,
      eventName: eventName,
      eventDate: eventDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSpeaker = certificate.userRole.toLowerCase() == 'speaker';
    final title = isSpeaker
        ? 'Certificate of Appreciation'
        : 'Certificate of Participation';

    final bodyText = isSpeaker
        ? 'This certificate is proudly presented to ${certificate.userName} in appreciation of their valuable contribution as a speaker${certificate.sessionTitle == null || certificate.sessionTitle!.trim().isEmpty ? '' : ' for the session “${certificate.sessionTitle}”'} during $eventName.'
        : 'This certificate is proudly presented to ${certificate.userName} for participating in $eventName.';

    return Scaffold(
      backgroundColor: AppColors.namaLightGray,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          children: [
            Row(
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
                    'Certificate Preview',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.namaNavyBlue,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.045),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 22,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.namaGoldenYellow,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    const Text(
                      'NAMA FOUNDATION',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.namaNavyBlue,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.namaGoldenYellow,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'This certificate is proudly presented to',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.namaMediumGray,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      certificate.userName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.namaNavyBlue,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      bodyText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.namaDarkGray,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _InfoRow(
                      label: 'Event',
                      value: eventName,
                    ),
                    if (eventDate != null)
                      _InfoRow(
                        label: 'Event Date',
                        value: _formatDate(eventDate!),
                      ),
                    if (certificate.sessionTitle != null &&
                        certificate.sessionTitle!.trim().isNotEmpty)
                      _InfoRow(
                        label: 'Session',
                        value: certificate.sessionTitle!,
                      ),
                    _InfoRow(
                      label: 'Certificate ID',
                      value: certificate.certificateId,
                    ),
                    _InfoRow(
                      label: 'Generated Date',
                      value: certificate.generatedAt == null
                          ? _formatDate(DateTime.now())
                          : _formatDate(certificate.generatedAt!),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 44,
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _download(context),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text(
                  'Download Certificate PDF',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.namaNavyBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<Uint8List> _buildCertificatePdf({
    required CertificateModel certificate,
    required String eventName,
    DateTime? eventDate,
  }) async {
    final pdf = pw.Document();
    final isSpeaker = certificate.userRole.toLowerCase() == 'speaker';
    final title = isSpeaker
        ? 'Certificate of Appreciation'
        : 'Certificate of Participation';

    final bodyText = isSpeaker
        ? 'This certificate is proudly presented to ${certificate.userName} in appreciation of their valuable contribution as a speaker${certificate.sessionTitle == null || certificate.sessionTitle!.trim().isEmpty ? '' : ' for the session "${certificate.sessionTitle}"'} during $eventName.'
        : 'This certificate is proudly presented to ${certificate.userName} for participating in $eventName.';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          return pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(24),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(
                color: PdfColor.fromInt(0xFFD6A329),
                width: 3,
              ),
            ),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'NAMA FOUNDATION',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    color: PdfColor.fromInt(0xFF0D1496),
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                pw.SizedBox(height: 26),
                pw.Text(
                  title,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    color: PdfColor.fromInt(0xFFD6A329),
                    fontSize: 34,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 22),
                pw.Text(
                  'This certificate is proudly presented to',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(
                    color: PdfColors.grey700,
                    fontSize: 13,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Text(
                  certificate.userName,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    color: PdfColor.fromInt(0xFF0D1496),
                    fontSize: 36,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 70),
                  child: pw.Text(
                    bodyText,
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(
                      color: PdfColors.grey800,
                      fontSize: 14,
                      lineSpacing: 4,
                    ),
                  ),
                ),
                pw.SizedBox(height: 28),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _pdfInfoBlock(
                      label: 'Certificate ID',
                      value: certificate.certificateId,
                    ),
                    if (eventDate != null)
                      _pdfInfoBlock(
                        label: 'Event Date',
                        value: _formatDate(eventDate),
                      )
                    else
                      _pdfInfoBlock(
                        label: 'Event',
                        value: eventName,
                      ),
                    _pdfInfoBlock(
                      label: 'Generated Date',
                      value: certificate.generatedAt == null
                          ? _formatDate(DateTime.now())
                          : _formatDate(certificate.generatedAt!),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _pdfInfoBlock({
    required String label,
    required String value,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            color: PdfColors.grey700,
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            color: PdfColor.fromInt(0xFF0D1496),
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.namaMediumGray,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.namaNavyBlue,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
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