import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/features/auth/screen/auth_view_model.dart'; // To sign out
import 'package:events_app_trueattempt/features/agenda/screen/my_bookmarks_screen.dart'; // New screen
import 'package:events_app_trueattempt/features/profile/screen/edit_profile_screen.dart';
import 'package:events_app_trueattempt/features/qrcode_checkin/screen/qr_generator_screen.dart';

// ProfileScreen displays the current user's profile information and actions.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the stream of the current user's profile from Firestore
    final userProfileAsync = ref.watch(userAppProfileStreamProvider);
    final authViewModel = ref.read(authViewModelProvider.notifier); // For signing out

    return userProfileAsync.when(
      data: (appUser) {
        // Handle cases where profile data might not exist or snapshot is null
        if (appUser == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Could not load profile data.'),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await authViewModel.signOut();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Logout failed: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Logout'),
                ),
              ],
            ),
          );
        }
        
        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const SizedBox(height: 20),
            Center(
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                backgroundImage: (appUser.profileImageUrl.isNotEmpty)
                    ? NetworkImage(appUser.profileImageUrl)
                    : null,
                child: (appUser.profileImageUrl.isEmpty)
                    ? Text(
                        appUser.name[0].toUpperCase(),
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
              appUser.name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              appUser.title.isNotEmpty ? appUser.title : appUser.role.toUpperCase(),
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
                  // My Bookmarks Button
                  ListTile(
                    leading: Icon(Icons.bookmarks_outlined, color: Theme.of(context).colorScheme.primary),
                    title: Text('My Bookmarks', style: Theme.of(context).textTheme.titleMedium),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => const MyBookmarksScreen(),
                      ));
                    },
                  ),
                  const Divider(height: 0),
                  ListTile(
                    leading: Icon(Icons.edit_outlined, color: Theme.of(context).colorScheme.primary),
                    title: Text('Edit Profile', style: Theme.of(context).textTheme.titleMedium),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => EditProfileScreen(user: appUser),
                      ));
                    },
                  ),
                  const Divider(height: 0),
                  ListTile(
                    leading: Icon(Icons.notifications_outlined, color: Theme.of(context).colorScheme.primary),
                    title: Text('Notifications', style: Theme.of(context).textTheme.titleMedium),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Notifications management coming in Phase 2!')),
                      );
                      // TODO: Navigate to Notifications screen in Phase 2
                    },
                  ),
                ],
              ),
            ),
            
            // Speaker Tools Section
            if (appUser.role == 'speaker')
              Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text('Speaker Tools', style: Theme.of(context).textTheme.titleLarge),
                      ),
                      const Divider(height: 0),
                      ListTile(
                        leading: Icon(Icons.qr_code_2, color: Theme.of(context).colorScheme.primary),
                        title: Text('Generate Session QR', style: Theme.of(context).textTheme.titleMedium),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => const QRGeneratorScreen(),
                          ));
                        },
                      ),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
                title: Text('Logout', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.error)),
                onTap: () async {
                  try {
                    await authViewModel.signOut();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Logout failed: $e')),
                      );
                    }
                  }
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