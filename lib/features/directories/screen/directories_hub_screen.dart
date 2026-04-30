// lib/features/directories/presentation/directories_hub_screen.dart
import 'package:flutter/material.dart';
import 'package:events_app_trueattempt/features/directories/screen/attendee_directory_screen.dart';
import 'package:events_app_trueattempt/features/directories/screen/speaker_directory_screen.dart';

class DirectoriesHubScreen extends StatelessWidget {
  const DirectoriesHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Static page title
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Networking',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0B0B83),
                      ),
                ),
              ),

              const SizedBox(height: 10),

              // Scan-style tab buttons
              Center(
                child: Container(
                  width: 200,
                  height: 38,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7E4F5),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: TabBar(
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorPadding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical:2,
                    ),
                    indicator: BoxDecoration(
                      color: const Color(0xFF4A3B95),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: const Color(0xFF4A3B95),
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: const [
                      Tab(text: 'Attendees'),
                      Tab(text: 'Speakers'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              const Expanded(
                child: TabBarView(
                  children: [
                    AttendeeDirectoryScreen(),
                    SpeakerDirectoryScreen(),
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