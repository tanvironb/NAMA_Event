// lib/features/directories/presentation/widgets/user_list_tile.dart
import 'package:flutter/material.dart';
import 'package:events_app_trueattempt/core/models/app_user.dart';
import 'package:events_app_trueattempt/features/profile/screen/user_details_screen.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';

class UserListTile extends StatelessWidget {
  final AppUser user;
  final VoidCallback? onTap;
  final Widget? trailing;
  final String? displayName; // NEW: Optional override for display name
  final String? displaySubtitle; // NEW: Optional override for subtitle

  const UserListTile({
    super.key, 
    required this.user, 
    this.onTap,
    this.trailing,
    this.displayName,
    this.displaySubtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: user.profileImageUrl.isNotEmpty ? NetworkImage(user.profileImageUrl) : null,
          backgroundColor: AppColors.avatarPlaceholder,
          child: user.profileImageUrl.isEmpty 
            ? Text(
                (displayName ?? user.name)[0].toUpperCase(),
                style: const TextStyle(
                  color: AppColors.avatarPlaceholderText,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
        ),
        title: Text(displayName ?? user.name),
        subtitle: Text(displaySubtitle ?? user.title),
        trailing: trailing ?? const Icon(Icons.chevron_right),
        onTap: onTap ?? () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => UserDetailsScreen(userId: user.uid),
          ));
        },
      ),
    );
  }
}