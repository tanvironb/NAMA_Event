import 'package:flutter/material.dart';
import 'package:events_app_trueattempt/features/directories/screen/attendee_directory_screen.dart';
import 'package:events_app_trueattempt/features/directories/screen/speaker_directory_screen.dart';

class DirectoriesHubScreen extends StatelessWidget {
  const DirectoriesHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: _DirectoriesHubContent(),
    );
  }
}

class _DirectoriesHubContent extends StatelessWidget {
  const _DirectoriesHubContent();

  static const Color _primaryColor = Color(0xFF0B0B83);
  static const Color _tabBackgroundColor = Color(0xFFE7E4F5);
  static const Color _tabSelectedColor = Color(0xFF4A3B95);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Networking',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: _primaryColor,
                    ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 200,
                height: 38,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _tabBackgroundColor,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: TabBar(
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  indicator: BoxDecoration(
                    color: _tabSelectedColor,
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
                  unselectedLabelColor: _tabSelectedColor,
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: const [
                    Tab(text: 'Delegates'),
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
    );
  }
}