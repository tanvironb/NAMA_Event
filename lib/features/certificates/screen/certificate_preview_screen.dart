import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
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
    final template = await _loadTemplate(certificate.eventId);

    final bytes = await _buildCertificatePdf(
      certificate: certificate,
      eventName: eventName,
      eventDate: eventDate,
      template: template,
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

  static Future<_CertificateTemplate?> _loadTemplate(String eventId) async {
    final doc = await FirebaseFirestore.instance
        .collection('events')
        .doc(eventId)
        .collection('certificateTemplate')
        .doc('main')
        .get();

    if (!doc.exists) return null;

    final data = doc.data() ?? {};
    final templateUrl = (data['templateUrl'] ?? '').toString().trim();

    if (templateUrl.isEmpty) return null;

    return _CertificateTemplate.fromMap(data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.namaLightGray,
      body: SafeArea(
        child: FutureBuilder<_CertificateTemplate?>(
          future: _loadTemplate(certificate.eventId),
          builder: (context, snapshot) {
            final template = snapshot.data;

            return ListView(
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
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(30),
                      child: CircularProgressIndicator(
                        color: AppColors.namaNavyBlue,
                      ),
                    ),
                  )
                else if (template != null)
                  _TemplateCertificatePreview(
                    certificate: certificate,
                    eventName: eventName,
                    eventDate: eventDate,
                    template: template,
                  )
                else
                  _FallbackCertificatePreview(
                    certificate: certificate,
                    eventName: eventName,
                    eventDate: eventDate,
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
            );
          },
        ),
      ),
    );
  }

  static Future<Uint8List> _buildCertificatePdf({
    required CertificateModel certificate,
    required String eventName,
    DateTime? eventDate,
    _CertificateTemplate? template,
  }) async {
    final pdf = pw.Document();

    final nameFont = await PdfGoogleFonts.sacramentoRegular();

    if (template != null) {
      final background = await networkImage(template.templateUrl);
      final pageFormat = template.orientation == 'portrait'
          ? PdfPageFormat.a4
          : PdfPageFormat.a4.landscape;

      final pageWidth = pageFormat.width;
      final pageHeight = pageFormat.height;
      final textColor = _pdfColorFromHex(template.textColor);
      final dateText = eventDate == null ? '' : _formatDate(eventDate);

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.zero,
          build: (context) {
            return pw.Stack(
              children: [
                pw.Positioned.fill(
                  child: pw.Image(background, fit: pw.BoxFit.cover),
                ),
                _pdfText(
                  pageWidth: pageWidth,
                  pageHeight: pageHeight,
                  x: template.nameX,
                  y: template.nameY,
                  text: certificate.userName,
                  fontSize: template.nameFontSize + 10,
                  color: textColor,
                  bold: false,
                  font: nameFont,
                ),
                _pdfText(
                  pageWidth: pageWidth,
                  pageHeight: pageHeight,
                  x: template.eventX,
                  y: template.eventY,
                  text: eventName,
                  fontSize: template.normalFontSize,
                  color: textColor,
                  bold: true,
                ),
                if (dateText.isNotEmpty)
                  _pdfText(
                    pageWidth: pageWidth,
                    pageHeight: pageHeight,
                    x: template.dateX,
                    y: template.dateY,
                    text: dateText,
                    fontSize: template.normalFontSize,
                    color: textColor,
                    bold: false,
                  ),
                _pdfText(
                  pageWidth: pageWidth,
                  pageHeight: pageHeight,
                  x: template.certificateIdX,
                  y: template.certificateIdY,
                  text: certificate.certificateId,
                  fontSize: template.normalFontSize * 0.80,
                  color: textColor,
                  bold: false,
                ),
              ],
            );
          },
        ),
      );

      return pdf.save();
    }

    final isSpeaker = certificate.userRole.toLowerCase() == 'speaker';
    final title = isSpeaker
        ? 'Certificate of Appreciation'
        : 'Certificate of Participation';

    final bodyText = isSpeaker
        ? 'This certificate is proudly presented to ${certificate.userName} in appreciation of their valuable contribution during $eventName.'
        : 'This certificate is proudly presented to ${certificate.userName} for attending $eventName.';

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
                    font: nameFont,
                    color: PdfColor.fromInt(0xFF0D1496),
                    fontSize: 52,
                    fontWeight: pw.FontWeight.normal,
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

  static pw.Widget _pdfText({
    required double pageWidth,
    required double pageHeight,
    required double x,
    required double y,
    required String text,
    required double fontSize,
    required PdfColor color,
    required bool bold,
    pw.Font? font,
  }) {
    final textBoxWidth = pageWidth * 0.82;

    return pw.Positioned(
      left: (pageWidth * x) - (textBoxWidth / 2),
      top: (pageHeight * y) - (fontSize / 2),
      child: pw.SizedBox(
        width: textBoxWidth,
        child: pw.Text(
          text,
          maxLines: 1,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            font: font,
            color: color,
            fontSize: fontSize,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ),
    );
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

class _TemplateCertificatePreview extends StatelessWidget {
  final CertificateModel certificate;
  final String eventName;
  final DateTime? eventDate;
  final _CertificateTemplate template;

  const _TemplateCertificatePreview({
    required this.certificate,
    required this.eventName,
    required this.eventDate,
    required this.template,
  });

  Color _parseColor(String hex) {
    var value = hex.replaceAll('#', '').trim();
    if (value.length == 6) value = 'FF$value';
    return Color(int.tryParse(value, radix: 16) ?? 0xFF111827);
  }

  @override
  Widget build(BuildContext context) {
    final aspectRatio = template.orientation == 'portrait' ? 0.707 : 1.414;
    final textColor = _parseColor(template.textColor);
    final dateText = eventDate == null ? '' : _formatDate(eventDate!);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
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
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    template.templateUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return const Center(
                        child: Text('Template image could not load'),
                      );
                    },
                  ),
                  _PositionedPreviewText(
                    x: template.nameX,
                    y: template.nameY,
                    width: constraints.maxWidth,
                    text: certificate.userName,
                    color: textColor,
                    fontSize: template.nameFontSize * 0.42,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'cursive',
                    italic: true,
                  ),
                  _PositionedPreviewText(
                    x: template.eventX,
                    y: template.eventY,
                    width: constraints.maxWidth,
                    text: eventName,
                    color: textColor,
                    fontSize: template.normalFontSize * 0.28,
                    fontWeight: FontWeight.w800,
                  ),
                  if (dateText.isNotEmpty)
                    _PositionedPreviewText(
                      x: template.dateX,
                      y: template.dateY,
                      width: constraints.maxWidth,
                      text: dateText,
                      color: textColor,
                      fontSize: template.normalFontSize * 0.26,
                      fontWeight: FontWeight.w700,
                    ),
                  _PositionedPreviewText(
                    x: template.certificateIdX,
                    y: template.certificateIdY,
                    width: constraints.maxWidth,
                    text: certificate.certificateId,
                    color: textColor,
                    fontSize: template.normalFontSize * 0.24,
                    fontWeight: FontWeight.w700,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FallbackCertificatePreview extends StatelessWidget {
  final CertificateModel certificate;
  final String eventName;
  final DateTime? eventDate;

  const _FallbackCertificatePreview({
    required this.certificate,
    required this.eventName,
    required this.eventDate,
  });

  @override
  Widget build(BuildContext context) {
    final isSpeaker = certificate.userRole.toLowerCase() == 'speaker';
    final title = isSpeaker
        ? 'Certificate of Appreciation'
        : 'Certificate of Participation';

    final bodyText = isSpeaker
        ? 'This certificate is proudly presented to ${certificate.userName} in appreciation of their valuable contribution during $eventName.'
        : 'This certificate is proudly presented to ${certificate.userName} for attending $eventName.';

    return Container(
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.namaGoldenYellow, width: 2),
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
              style: TextStyle(color: AppColors.namaMediumGray, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Text(
              certificate.userName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.namaNavyBlue,
                fontSize: 32,
                fontWeight: FontWeight.w400,
                fontStyle: FontStyle.italic,
                fontFamily: 'cursive',
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
            _InfoRow(label: 'Event', value: eventName),
            if (eventDate != null)
              _InfoRow(label: 'Event Date', value: _formatDate(eventDate!)),
            _InfoRow(label: 'Certificate ID', value: certificate.certificateId),
            _InfoRow(
              label: 'Generated Date',
              value: certificate.generatedAt == null
                  ? _formatDate(DateTime.now())
                  : _formatDate(certificate.generatedAt!),
            ),
          ],
        ),
      ),
    );
  }
}

class _PositionedPreviewText extends StatelessWidget {
  final double x;
  final double y;
  final double width;
  final String text;
  final Color color;
  final double fontSize;
  final FontWeight fontWeight;
  final String? fontFamily;
  final bool italic;

  const _PositionedPreviewText({
    required this.x,
    required this.y,
    required this.width,
    required this.text,
    required this.color,
    required this.fontSize,
    required this.fontWeight,
    this.fontFamily,
    this.italic = false,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: FractionalTranslation(
        translation: Offset(x - 0.5, y - 0.5),
        child: Center(
          child: SizedBox(
            width: width * 0.82,
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: fontSize,
                fontWeight: fontWeight,
                fontFamily: fontFamily,
                fontStyle: italic ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

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

class _CertificateTemplate {
  final String templateUrl;
  final String orientation;
  final double nameX;
  final double nameY;
  final double eventX;
  final double eventY;
  final double dateX;
  final double dateY;
  final double certificateIdX;
  final double certificateIdY;
  final double nameFontSize;
  final double normalFontSize;
  final String textColor;

  const _CertificateTemplate({
    required this.templateUrl,
    required this.orientation,
    required this.nameX,
    required this.nameY,
    required this.eventX,
    required this.eventY,
    required this.dateX,
    required this.dateY,
    required this.certificateIdX,
    required this.certificateIdY,
    required this.nameFontSize,
    required this.normalFontSize,
    required this.textColor,
  });

  factory _CertificateTemplate.fromMap(Map<String, dynamic> data) {
    return _CertificateTemplate(
      templateUrl: (data['templateUrl'] ?? '').toString(),
      orientation: (data['orientation'] ?? 'landscape').toString(),
      nameX: _readDouble(data['nameX'], 0.50),
      nameY: _readDouble(data['nameY'], 0.48),
      eventX: _readDouble(data['eventX'], 0.50),
      eventY: _readDouble(data['eventY'], 0.60),
      dateX: _readDouble(data['dateX'], 0.50),
      dateY: _readDouble(data['dateY'], 0.68),
      certificateIdX: _readDouble(data['certificateIdX'], 0.50),
      certificateIdY: _readDouble(data['certificateIdY'], 0.88),
      nameFontSize: _readDouble(data['nameFontSize'], 34),
      normalFontSize: _readDouble(data['normalFontSize'], 16),
      textColor: (data['textColor'] ?? '#111827').toString(),
    );
  }
}

double _readDouble(dynamic value, double fallback) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

PdfColor _pdfColorFromHex(String hex) {
  var value = hex.replaceAll('#', '').trim();
  if (value.length == 6) value = 'FF$value';
  return PdfColor.fromInt(int.tryParse(value, radix: 16) ?? 0xFF111827);
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