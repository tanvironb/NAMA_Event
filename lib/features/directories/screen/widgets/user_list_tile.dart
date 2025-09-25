// lib/features/directories/presentation/widgets/user_list_tile.dart
import 'package:flutter/material.dart';
import 'package:events_app_trueattempt/core/models/app_user.dart';

class UserListTile extends StatelessWidget {
  final AppUser user;
  const UserListTile({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: user.profileImageUrl.isNotEmpty ? NetworkImage(user.profileImageUrl) : null,
          child: user.profileImageUrl.isEmpty ? Text(user.name[0].toUpperCase()) : null,
        ),
        title: Text(user.name),
        subtitle: Text(user.title),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // TODO: Navigate to a detailed user profile screen in Phase 3
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Viewing ${user.name}\'s profile...')),
          );
        },
      ),
    );
  }
}