import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';

// ProfileScreen displays the current user's profile information and actions.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the stream of the current user's profile from Firestore
    final userProfileStream = ref.watch(userProfileProvider);
    final currentUser = FirebaseAuth.instance.currentUser; // Get current Firebase Auth user

    return userProfileStream.when(
      data: (snapshot) {
        // Handle cases where profile data might not exist or snapshot is null
        if (snapshot == null || !snapshot.exists) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Could not load profile data.'),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  child: const Text('Logout'),
                ),
              ],
            ),
          );
        }
        final userData = snapshot.data() as Map<String, dynamic>;

        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const SizedBox(height: 20),
            Center(
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                backgroundImage: (userData['profileImageUrl'] != null && userData['profileImageUrl']!.isNotEmpty)
                    ? NetworkImage(userData['profileImageUrl'])
                    : null,
                child: (userData['profileImageUrl'] == null || userData['profileImageUrl']!.isEmpty)
                    ? Text(
                        (userData['name']?[0] ?? currentUser?.email?[0] ?? 'U').toUpperCase(),
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              userData['name'] ?? currentUser?.email ?? 'User',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              userData['title'] ?? (userData['role'] ?? 'Attendee').toUpperCase(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 32),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.edit_outlined, color: Theme.of(context).colorScheme.primary),
                    title: Text('Edit Profile', style: Theme.of(context).textTheme.titleMedium),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // TODO: Navigate to Edit Profile screen in Phase 2
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Edit Profile coming in Phase 2!')),
                      );
                    },
                  ),
                  const Divider(height: 0),
                  ListTile(
                    leading: Icon(Icons.notifications_outlined, color: Theme.of(context).colorScheme.primary),
                    title: Text('Notifications', style: Theme.of(context).textTheme.titleMedium),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // TODO: Navigate to Notifications screen in Phase 2
                       ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Notifications management coming in Phase 2!')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
                title: Text('Logout', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.error)),
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                },
              ),
            ),
            const SizedBox(height: 40),
          ],
        );
      },
      loading: () => const LoadingIndicator(), // Show loading spinner
      error: (err, stack) => Center(
        child: Text(
          'Error loading profile: $err',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }
}