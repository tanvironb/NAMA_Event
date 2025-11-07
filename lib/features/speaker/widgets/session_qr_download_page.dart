import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:intl/intl.dart';

/// Download page for session QR code with formatted layout.
/// Displays: Logo (top left), Big QR code, Session name, Time, Location
class SessionQRDownloadPage extends StatelessWidget {
  final Session session;

  const SessionQRDownloadPage({super.key, required this.session});

  String _formatDuration() {
    final duration = session.endTime.difference(session.startTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    return '$hours hour${hours != 1 ? 's' : ''}, $minutes minute${minutes != 1 ? 's' : ''}, $seconds second${seconds != 1 ? 's' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.namaWhite,
      appBar: AppBar(
        title: const Text('Download QR Code'),
        backgroundColor: AppColors.namaNavyBlue,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Take a screenshot to save this QR code'),
                  duration: Duration(seconds: 3),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo at top left
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.namaNavyBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Image.asset(
                      'assets/icons/app_icon.png',
                      width: 60,
                      height: 60,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback if logo doesn't exist
                        return Icon(
                          Icons.event,
                          size: 60,
                          color: AppColors.namaGoldenYellow,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NAMA Foundation',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.namaNavyBlue,
                          ),
                        ),
                        Text(
                          'Session Check-in',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.namaMediumGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 48),

              // Big QR Code - Center Stage
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.namaGoldenYellow,
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.namaNavyBlue.withOpacity(0.1),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: session.qrCodePayload,
                  version: QrVersions.auto,
                  size: 350,
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

              const SizedBox(height: 40),

              // Session Name (Title - Centered)
              Text(
                session.title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.namaNavyBlue,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // Time (Duration - hours/minutes/seconds)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.namaLightGray,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time_outlined,
                      color: AppColors.namaNavyBlue,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Duration',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.namaMediumGray,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDuration(),
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.namaDarkGray,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Time Range
              Text(
                '${DateFormat('h:mm a').format(session.startTime)} - ${DateFormat('h:mm a').format(session.endTime)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.namaDarkGray,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // Date
              Text(
                DateFormat('EEEE, MMMM d, y').format(session.startTime),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.namaMediumGray,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // Location
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.namaLightBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      color: AppColors.namaNavyBlue,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      session.location,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.namaNavyBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Instructions
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.namaWarmGold.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.namaGoldenYellow,
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.qr_code_scanner_outlined,
                      color: AppColors.namaNavyBlue,
                      size: 32,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Scan to Check In',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.namaNavyBlue,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Attendees can scan this QR code to check in to the session',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.namaDarkGray,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Screenshot hint
              Text(
                'Take a screenshot to save or print this page',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.namaMediumGray,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
