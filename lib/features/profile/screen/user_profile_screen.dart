// lib/features/profile/screen/user_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/core/models/app_user.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/features/auth/screen/auth_view_model.dart';
import 'package:events_app_trueattempt/features/agenda/screen/my_bookmarks_screen.dart';
import 'package:events_app_trueattempt/features/profile/screen/edit_profile_screen.dart';
import 'package:events_app_trueattempt/features/qrcode_checkin/screen/qr_generator_screen.dart';
import 'package:events_app_trueattempt/features/messaging/screen/direct_message_screen.dart';

// NEW: A provider to fetch a specific user's profile
final userProfileFutureProvider = FutureProvider.autoDispose.family<AppUser?, String>((ref, userId) {
  return ref.watch(userProfileRepositoryProvider).getUserProfile(userId);
});

class UserProfileScreen extends ConsumerWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileFutureProvider(userId));
    final currentUserId = ref.watch(firebaseAuthProvider).currentUser?.uid;
    final bool isCurrentUser = userId == currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: Text(isCurrentUser ? 'My Profile' : 'User Profile'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: userProfileAsync.when(
        data: (appUser) {
          if (appUser == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_off,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'User not found',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            );
          }
          
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              const SizedBox(height: 20),
              // Profile Avatar and Info
              Center(
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  backgroundImage: (appUser.profileImageUrl.isNotEmpty)
                      ? NetworkImage(appUser.profileImageUrl)
                      : null,
                  child: (appUser.profileImageUrl.isEmpty)
                      ? Text(
                          appUser.name.isNotEmpty ? appUser.name[0].toUpperCase() : 'U',
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
                appUser.name.isNotEmpty ? appUser.name : 'Unknown User',
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
              if (appUser.company.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  appUser.company,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
              if (appUser.bio.isNotEmpty) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'About',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          appUser.bio,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 32),
              
              // --- Conditional Buttons Based on User Type ---
              if (isCurrentUser) ...[
                // Show current user's own tools
                Card(
                  child: Column(
                    children: [
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
                            const SnackBar(content: Text('Notifications management coming soon!')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                
                // Speaker Tools Section (only for current user who is a speaker)
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
              ] else ...[
                // Show action buttons for viewing another user
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.message_outlined),
                      label: const Text('Send Message'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        if (currentUserId == null) return;
                        
                        try {
                          // Show loading
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const Center(child: CircularProgressIndicator()),
                          );

                          final repo = ref.read(messagingRepositoryProvider);
                          final conversationId = await repo.createOrGetConversation(
                            currentUserId,
                            appUser.uid,
                          );

                          // Close loading dialog
                          if (context.mounted) Navigator.pop(context);

                          // Navigate to DirectMessageScreen
                          if (context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DirectMessageScreen(
                                  conversationId: conversationId,
                                  otherUserName: appUser.name,
                                  otherUserProfileImage: appUser.profileImageUrl,
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          // Close loading dialog
                          if (context.mounted) Navigator.pop(context);
                          
                          // Show error
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to start conversation: $e'),
                                backgroundColor: Theme.of(context).colorScheme.error,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ),
              ],
              
              // Logout button (only for current user)
              if (isCurrentUser) ...[
                const SizedBox(height: 20),
                Card(
                  child: ListTile(
                    leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
                    title: Text(
                      'Logout',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    onTap: () async {
                      final authViewModel = ref.read(authViewModelProvider.notifier);
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
              ],
              
              const SizedBox(height: 40),
            ],
          );
        },
        loading: () => const LoadingIndicator(),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading profile',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                err.toString(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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