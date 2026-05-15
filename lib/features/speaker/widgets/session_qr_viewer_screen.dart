import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/features/speaker/widgets/session_qr_download_page.dart';
import 'package:intl/intl.dart';

/// QR code viewer screen with styled display and download functionality.
class SessionQRViewerScreen extends StatelessWidget {
  final Session session;

  const SessionQRViewerScreen({
    super.key,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    final qrData = session.qrCodePayload;

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
                          'Please generate the QR code first',
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
        child: Column(
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
                    // Session title card
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
                            session.title,
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
                                .format(session.startTime),
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

                    // QR Code Display Section
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppColors.namaGoldenYellow.withOpacity(0.20),
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
                        embeddedImageStyle: const QrEmbeddedImageStyle(
                          size: Size(32, 32),
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Session Info Section
                    _buildInfoCard(
                      icon: Icons.schedule_outlined,
                      label: 'Time',
                      value:
                          '${DateFormat.jm().format(session.startTime)} - ${DateFormat.jm().format(session.endTime)}',
                      context: context,
                    ),
                    const SizedBox(height: 10),
                    _buildInfoCard(
                      icon: Icons.location_on_outlined,
                      label: 'Location',
                      value: session.location,
                      context: context,
                    ),
                    const SizedBox(height: 10),
                    _buildInfoCard(
                      icon: Icons.people_outline,
                      label: 'Attendees',
                      value: '${session.checkedInAttendees.length} checked in',
                      context: context,
                    ),

                    const SizedBox(height: 22),

                    // Download Button
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: () => _downloadQR(context),
                        icon: const Icon(
                          Icons.download_outlined,
                          size: 18,
                        ),
                        label: const Text(
                          'Download QR Code',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.namaGoldenYellow,
                          foregroundColor: AppColors.navyBlue,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    Text(
                      'Attendees can scan this QR code to check in to your session',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.namaNavyBlue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: AppColors.namaNavyBlue,
              size: 20,
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
                    fontSize: 11.5,
                    color: AppColors.namaMediumGray,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.namaDarkGray,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
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
      padding: const EdgeInsets.fromLTRB(8, 8, 18, 6),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: AppColors.namaNavyBlue,
              size: 22,
            ),
            onPressed: onBack,
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.namaNavyBlue,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}