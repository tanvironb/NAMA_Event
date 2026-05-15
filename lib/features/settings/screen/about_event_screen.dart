// lib/features/settings/screen/about_event_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:flutter/material.dart';

class AboutEventScreen extends StatelessWidget {
  const AboutEventScreen({super.key});

  Future<Map<String, dynamic>?> _getActiveEvent() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('events')
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    return snapshot.docs.first.data();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.arrow_back,
                      size: 22,
                      color: AppColors.namaNavyBlue,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'About Event',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.namaNavyBlue,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: FutureBuilder<Map<String, dynamic>?>(
                  future: _getActiveEvent(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.namaNavyBlue,
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return const Center(
                        child: Text(
                          'Something went wrong while loading event details.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: Colors.black54,
                          ),
                        ),
                      );
                    }

                    final eventData = snapshot.data;

                    if (eventData == null) {
                      return const Center(
                        child: Text(
                          'No active event found.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: Colors.black54,
                          ),
                        ),
                      );
                    }

                    final eventName =
                        (eventData['name'] ?? 'Current Event').toString();
                    final aboutEvent =
                        (eventData['aboutEvent'] ?? '').toString().trim();
                    final shortDescription =
                        (eventData['description'] ?? '').toString().trim();

                    final displayText = aboutEvent.isNotEmpty
                        ? aboutEvent
                        : shortDescription.isNotEmpty
                            ? shortDescription
                            : 'No about event details have been added yet.';

                    return SingleChildScrollView(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFE8E4F8),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.035),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 42,
                              width: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF6F4FD),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.info_outline_rounded,
                                color: AppColors.namaNavyBlue,
                                size: 22,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              eventName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.namaNavyBlue,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              displayText,
                              style: const TextStyle(
                                fontSize: 13.5,
                                height: 1.55,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF333333),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}