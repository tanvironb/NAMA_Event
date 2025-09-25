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
        appBar: TabBar(
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).colorScheme.secondary,
          tabs: const [
            Tab(text: 'Attendees'),
            Tab(text: 'Speakers'),
          ],
        ),
        body: const TabBarView(
          children: [
            AttendeeDirectoryScreen(),
            SpeakerDirectoryScreen(),
          ],
        ),
      ),
    );
  }
}