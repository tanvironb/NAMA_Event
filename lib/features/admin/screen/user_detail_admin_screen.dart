// lib/features/admin/screen/user_detail_admin_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/models/app_user.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:intl/intl.dart';

class UserDetailAdminScreen extends ConsumerWidget {
  final AppUser user;
  const UserDetailAdminScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final possibleRoles = ['attendee', 'staff', 'speaker', 'admin'];
    final possibleStatuses = ['pending', 'approved', 'rejected'];

    return Scaffold(
      appBar: AppBar(
        title: Text(user.name),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Details Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'User Information',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow('Email', user.email),
                      _buildInfoRow('Name', user.name),
                      _buildInfoRow('Company', user.company.isEmpty ? 'Not provided' : user.company),
                      _buildInfoRow('Title', user.title.isEmpty ? 'Not provided' : user.title),
                      _buildInfoRow('Phone', user.phone.isEmpty ? 'Not provided' : user.phone),
                      _buildInfoRow('Points', user.points.toString()),
                      _buildInfoRow('Created', user.createdAt != null 
                          ? DateFormat('MMM dd, yyyy HH:mm').format(user.createdAt!) 
                          : 'Unknown'),
                      _buildInfoRow('Last Seen', user.lastSeen != null 
                          ? DateFormat('MMM dd, yyyy HH:mm').format(user.lastSeen!) 
                          : 'Never'),
                      _buildInfoRow('Online Status', user.isOnline ? 'Online' : 'Offline'),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Admin Controls Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin Controls',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Role Changer
                      DropdownButtonFormField<String>(
                        value: user.role,
                        items: possibleRoles.map((role) => 
                          DropdownMenuItem(
                            value: role, 
                            child: Text(role.toUpperCase()),
                          )
                        ).toList(),
                        onChanged: (newRole) {
                          if (newRole != null && newRole != user.role) {
                            _showConfirmationDialog(
                              context,
                              'Change Role',
                              'Are you sure you want to change this user\'s role to ${newRole.toUpperCase()}?',
                              () {
                                ref.read(userProfileRepositoryProvider).updateUserProfile(
                                  user.uid, 
                                  {'role': newRole, 'updatedAt': DateTime.now()}
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Role updated to ${newRole.toUpperCase()}')),
                                );
                              },
                            );
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Change Role',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Status Changer
                      DropdownButtonFormField<String>(
                        value: user.status,
                        items: possibleStatuses.map((status) => 
                          DropdownMenuItem(
                            value: status, 
                            child: Row(
                              children: [
                                Icon(
                                  _getStatusIcon(status),
                                  color: _getStatusColor(status),
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(status.toUpperCase()),
                              ],
                            ),
                          )
                        ).toList(),
                        onChanged: (newStatus) {
                          if (newStatus != null && newStatus != user.status) {
                            _showConfirmationDialog(
                              context,
                              'Change Status',
                              'Are you sure you want to change this user\'s status to ${newStatus.toUpperCase()}?',
                              () {
                                ref.read(userProfileRepositoryProvider).updateUserProfile(
                                  user.uid, 
                                  {'status': newStatus, 'updatedAt': DateTime.now()}
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Status updated to ${newStatus.toUpperCase()}')),
                                );
                              },
                            );
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Change Status',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'pending':
      default:
        return Icons.schedule;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return AppColors.successGreen;
      case 'rejected':
        return AppColors.dangerRed;
      case 'pending':
      default:
        return AppColors.warningOrange;
    }
  }

  void _showConfirmationDialog(
    BuildContext context,
    String title,
    String message,
    VoidCallback onConfirm,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm();
              },
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }
}
