import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Generates and exports session QR code as A4 PDF.
/// Provides options to download or share the PDF.
class SessionQRDownloadPage extends StatefulWidget {
  final Session session;

  const SessionQRDownloadPage({super.key, required this.session});

  @override
  State<SessionQRDownloadPage> createState() => _SessionQRDownloadPageState();
}

class _SessionQRDownloadPageState extends State<SessionQRDownloadPage> {
  bool _isGenerating = false;

  Future<pw.Document> _generatePDF() async {
    final pdf = pw.Document();

    // Load logo image
    final ByteData? logoData = await rootBundle.load('assets/logo.png').catchError((_) => 
      rootBundle.load('assets/images/logo.png')
    );
    final Uint8List? logoBytes = logoData?.buffer.asUint8List();

    // Load font for better text rendering
    final font = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Header with logo and NAMA Foundation
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  if (logoBytes != null)
                    pw.Image(
                      pw.MemoryImage(logoBytes),
                      width: 50,
                      height: 50,
                    ),
                  if (logoBytes != null)
                    pw.SizedBox(width: 16),
                  pw.Text(
                    'NAMA Foundation',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 28,
                      color: PdfColor.fromHex('#1B1464'),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 10),

              // Session Check-in subtitle
              pw.Text(
                'Session Check-in',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 16,
                  color: PdfColor.fromHex('#6B6B6B'),
                ),
              ),

              pw.SizedBox(height: 40),

              // QR Code - Large and centered
              pw.Center(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                      color: PdfColor.fromHex('#E4B544'),
                      width: 4,
                    ),
                    borderRadius: pw.BorderRadius.circular(16),
                  ),
                  child: pw.BarcodeWidget(
                    data: widget.session.qrCodePayload,
                    barcode: pw.Barcode.qrCode(),
                    width: 400,
                    height: 400,
                    drawText: false,
                  ),
                ),
              ),

              pw.SizedBox(height: 40),

              // Session Title
              pw.Text(
                widget.session.title,
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 24,
                  color: PdfColor.fromHex('#1B1464'),
                ),
                textAlign: pw.TextAlign.center,
              ),

              pw.SizedBox(height: 20),

              // Time Range
              pw.Text(
                '${DateFormat('h:mm a').format(widget.session.startTime)} - ${DateFormat('h:mm a').format(widget.session.endTime)}',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 18,
                  color: PdfColor.fromHex('#4A4A4A'),
                ),
                textAlign: pw.TextAlign.center,
              ),

              pw.SizedBox(height: 8),

              // Date
              pw.Text(
                DateFormat('EEEE, MMMM d, y').format(widget.session.startTime),
                style: pw.TextStyle(
                  font: font,
                  fontSize: 16,
                  color: PdfColor.fromHex('#6B6B6B'),
                ),
                textAlign: pw.TextAlign.center,
              ),

              pw.SizedBox(height: 20),

              // Location
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#E8EEFF'),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(
                  widget.session.location,
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 16,
                    color: PdfColor.fromHex('#1B1464'),
                  ),
                ),
              ),

              pw.Spacer(),

              // Scan to Check In box
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F5E6B8').flatten(),
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(
                    color: PdfColor.fromHex('#E4B544'),
                    width: 1,
                  ),
                ),
                child: pw.Text(
                  'Scan to Check In',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 18,
                    color: PdfColor.fromHex('#1B1464'),
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  Future<void> _downloadPDF() async {
    setState(() {
      _isGenerating = true;
    });

    try {
      final pdf = await _generatePDF();
      final bytes = await pdf.save();

      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final fileName = 'QR_${widget.session.title.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = '${directory.path}/$fileName';

      // Save file
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      // Share the file
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'QR Code for ${widget.session.title}',
        subject: 'Session Check-in QR Code',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR code PDF exported successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export QR code: $e'),
          backgroundColor: AppColors.errorRed,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _printPDF() async {
    setState(() {
      _isGenerating = true;
    });

    try {
      final pdf = await _generatePDF();
      
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Print preview opened!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open print preview: $e'),
          backgroundColor: AppColors.errorRed,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.namaWhite,
      appBar: AppBar(
        title: const Text('Export QR Code'),
        backgroundColor: AppColors.namaNavyBlue,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // QR Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.namaLightBlue,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.qr_code_2,
                  size: 80,
                  color: AppColors.namaNavyBlue,
                ),
              ),

              const SizedBox(height: 32),

              // Title
              Text(
                'Export QR Code',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.namaNavyBlue,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Description
              Text(
                'Generate an A4 PDF with the QR code for ${widget.session.title}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.namaMediumGray,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              // Download button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _downloadPDF,
                  icon: _isGenerating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.download),
                  label: Text(_isGenerating ? 'Generating...' : 'Download PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.namaGoldenYellow,
                    foregroundColor: AppColors.namaNavyBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Print/Preview button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isGenerating ? null : _printPDF,
                  icon: const Icon(Icons.print),
                  label: const Text('Print Preview'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.namaNavyBlue,
                    side: BorderSide(color: AppColors.namaNavyBlue, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Info text
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.namaLightGray,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.namaNavyBlue,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'The PDF will be in A4 format, perfect for printing',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.namaDarkGray,
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
    );
  }
}

