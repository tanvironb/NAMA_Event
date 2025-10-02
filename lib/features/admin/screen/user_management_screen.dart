import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/features/directories/screen/widgets/user_list_tile.dart'; // Reusing this tile
import 'package:events_app_trueattempt/features/admin/screen/user_detail_admin_screen.dart';

class UserManagementScreen extends ConsumerWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allUsersAsync = ref.watch(allUsersStreamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Users')),
      body: allUsersAsync.when(
        data: (users) {
          if (users.isEmpty) return const Center(child: Text('No users found.'));
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return UserListTile(
                user: user,
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => UserDetailAdminScreen(user: user),
                  ));
                },
              );
            },
          );
        },
        loading: () => const LoadingIndicator(),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}