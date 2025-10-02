// lib/features/qr_scanner/screen/qr_hub_screen.dart
import 'package:flutter/material.dart';
import 'package:events_app_trueattempt/features/qr_scanner/screen/my_qr_code_screen.dart';
import 'package:events_app_trueattempt/features/qr_scanner/screen/qr_scanner_screen.dart';

class QRHubScreen extends StatelessWidget {
  const QRHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: TabBar(
          tabs: const [
            Tab(icon: Icon(Icons.qr_code_2), text: 'My Code'),
            Tab(icon: Icon(Icons.camera_alt_outlined), text: 'Scanner'),
          ],
        ),
        body: const TabBarView(
          children: [
            MyQRCodeScreen(),
            QRScannerScreen(),
          ],
        ),
      ),
    );
  }
}