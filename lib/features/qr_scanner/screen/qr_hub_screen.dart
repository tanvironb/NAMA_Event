import 'package:flutter/material.dart';
import 'package:events_app_trueattempt/features/qr_scanner/screen/my_qr_code_screen.dart';

class QRHubScreen extends StatelessWidget {
  const QRHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: MyQRCodeScreen(),
    );
  }
}