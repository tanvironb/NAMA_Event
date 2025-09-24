import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileStream = ref.watch(userProfileProvider);

    return Scaffold(
      body: userProfileStream.when(
        data: (snapshot) {
          if (snapshot == null || !snapshot.exists) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Could not load profile.'),
                  const SizedBox(height: 20),
                   ElevatedButton(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    child: const Text('Logout'),
                  )
                ],
              )
            );
          }
          final userData = snapshot.data() as Map<String, dynamic>;
          final user = FirebaseAuth.instance.currentUser;
          
          return ListView(
            children: [
              const SizedBox(height: 20),
              CircleAvatar(
                radius: 50,
                backgroundImage: (userData['profileImageUrl'] != null && userData['profileImageUrl']!.isNotEmpty)
                    ? NetworkImage(userData['profileImageUrl'])
                    : null,
                child: (userData['profileImageUrl'] == null || userData['profileImageUrl']!.isEmpty)
                    ? Text(
                        userData['name']?[0] ?? user?.email?[0] ?? 'U',
                        style: Theme.of(context).textTheme.headlineLarge,
                      )
                    : null,
              ),
              const SizedBox(height: 12),
              Text(
                userData['name'] ?? user?.email ?? 'User',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                userData['title'] ?? '',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit Profile'),
                onTap: () {
                  // TODO: Navigate to Edit Profile screen
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('Notifications'),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () => FirebaseAuth.instance.signOut(),
              ),
            ],
          );
        },
        loading: () => const LoadingIndicator(),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}