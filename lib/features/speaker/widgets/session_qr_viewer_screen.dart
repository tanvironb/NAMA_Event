import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/features/speaker/widgets/session_qr_download_page.dart';
import 'package:intl/intl.dart';

/// QR code viewer screen with styled display and download functionality.
class SessionQRViewerScreen extends StatelessWidget {
  final Session session;

  const SessionQRViewerScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final qrData = session.qrCodePayload;

    if (qrData.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Session QR Code'),
          backgroundColor: AppColors.namaNavyBlue,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.qr_code_2_outlined,
                size: 80,
                color: AppColors.namaMediumGray,
              ),
              const SizedBox(height: 24),
              Text(
                'QR Code Not Generated',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.namaDarkGray,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Please generate the QR code first',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.namaMediumGray),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session QR Code'),
        backgroundColor: AppColors.namaNavyBlue,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Colored Header Section
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.namaNavyBlue,
                    AppColors.namaNavyBlue.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    session.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat('EEEE, MMM d, y').format(session.startTime),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // QR Code Display Section
            Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.namaGoldenYellow.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(
                  color: AppColors.namaGoldenYellow,
                  width: 3,
                ),
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 280,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: AppColors.namaNavyBlue,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: AppColors.navyBlue,
                ),
                embeddedImageStyle: const QrEmbeddedImageStyle(
                  size: Size(40, 40),
                ),
              ),
            ),

            // Session Info Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _buildInfoCard(
                    icon: Icons.schedule_outlined,
                    label: 'Time',
                    value:
                        '${DateFormat.jm().format(session.startTime)} - ${DateFormat.jm().format(session.endTime)}',
                    context: context,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    icon: Icons.location_on_outlined,
                    label: 'Location',
                    value: session.location,
                    context: context,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    icon: Icons.people_outline,
                    label: 'Attendees',
                    value: '${session.checkedInAttendees.length} checked in',
                    context: context,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Download Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () => _downloadQR(context),
                  icon: const Icon(Icons.download_outlined, size: 24),
                  label: const Text(
                    'Download QR Code',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.namaGoldenYellow,
                    foregroundColor: AppColors.navyBlue,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Instructions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Attendees can scan this QR code to check in to your session',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.namaMediumGray,
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required BuildContext context,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.lightGray,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.namaNavyBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.namaNavyBlue, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.namaMediumGray,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.namaDarkGray,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _downloadQR(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SessionQRDownloadPage(session: session),
      ),
    );
  }
}
