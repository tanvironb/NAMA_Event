import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';

class StaffSessionQRViewerScreen extends StatelessWidget {
  final Session session;
  final String checkInCode;
  final String qrPayload;

  const StaffSessionQRViewerScreen({
    super.key,
    required this.session,
    required this.checkInCode,
    required this.qrPayload,
  });

  String get _safePayload {
    if (qrPayload.trim().isNotEmpty) return qrPayload.trim();

    return jsonEncode({
      'type': 'session_checkin',
      'code': checkInCode,
    });
  }

  Future<void> _shareSessionCode() async {
    await Share.share(
      'Join session: ${session.title}\n\nSession Code: $checkInCode',
      subject: 'Session Check-in Code',
    );
  }

  @override
  Widget build(BuildContext context) {
    final payload = _safePayload;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(context),

              const SizedBox(height: 26),

              Center(
                child: Text(
                  session.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.namaNavyBlue,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              Center(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: payload,
                    version: QrVersions.auto,
                    size: 230,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              const Center(
                child: Text(
                  'Session Code',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F0FA),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.namaNavyBlue.withOpacity(0.18),
                    ),
                  ),
                  child: SelectableText(
                    checkInCode,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.namaNavyBlue,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _shareSessionCode,
                  icon: const Icon(Icons.share_outlined, size: 19),
                  label: const Text(
                    'Share QR Code / Session Code',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.namaNavyBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF6DD),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFE2BF3C),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Color(0xFFE2BF3C),
                      size: 19,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Attendees can scan this QR or enter the session code manually from Join Sessions.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.namaNavyBlue,
                          height: 1.35,
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

  Widget _header(BuildContext context) {
    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.pop(context),
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(
              Icons.arrow_back,
              color: AppColors.namaNavyBlue,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Session QR Code',
            style: TextStyle(
              color: AppColors.namaNavyBlue,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}