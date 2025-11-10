// lib/features/admin/screen/user_detail_admin_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/models/app_user.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/features/admin/screen/manage_user_profile_screen.dart';
import 'package:intl/intl.dart';

class UserDetailAdminScreen extends ConsumerStatefulWidget {
  final AppUser user;
  const UserDetailAdminScreen({super.key, required this.user});

  @override
  ConsumerState<UserDetailAdminScreen> createState() => _UserDetailAdminScreenState();
}

class _UserDetailAdminScreenState extends ConsumerState<UserDetailAdminScreen> {
  final TextEditingController _pointsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pointsController.text = widget.user.points.toString();
  }

  @override
  void dispose() {
    _pointsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final possibleRoles = ['attendee', 'staff', 'speaker', 'admin'];
    final possibleStatuses = ['pending', 'approved', 'rejected', 'blocked'];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.user.name),
        backgroundColor: AppColors.namaNavyBlue,
        foregroundColor: AppColors.namaWhite,
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
                      _buildInfoRow('Email', widget.user.email),
                      _buildInfoRow('Name', widget.user.name),
                      _buildInfoRow('Company', widget.user.company.isEmpty ? 'Not provided' : widget.user.company),
                      _buildInfoRow('Title', widget.user.title.isEmpty ? 'Not provided' : widget.user.title),
                      _buildInfoRow('Phone', widget.user.phone.isEmpty ? 'Not provided' : widget.user.phone),
                      _buildInfoRow('Created', widget.user.createdAt != null 
                          ? DateFormat('MMM dd, yyyy HH:mm').format(widget.user.createdAt!) 
                          : 'Unknown'),
                      _buildInfoRow('Last Seen', widget.user.lastSeen != null 
                          ? DateFormat('MMM dd, yyyy HH:mm').format(widget.user.lastSeen!) 
                          : 'Never'),
                      _buildInfoRow('Online Status', widget.user.isOnline ? 'Online' : 'Offline'),
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
                        value: widget.user.role,
                        items: possibleRoles.map((role) => 
                          DropdownMenuItem(
                            value: role, 
                            child: Text(role.toUpperCase()),
                          )
                        ).toList(),
                        onChanged: (newRole) => _handleRoleChange(newRole),
                        decoration: const InputDecoration(
                          labelText: 'Change Role',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Status Changer
                      DropdownButtonFormField<String>(
                        value: widget.user.status,
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
                        onChanged: (newStatus) => _handleStatusChange(newStatus),
                        decoration: const InputDecoration(
                          labelText: 'Change Status',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Points Editor
                      _buildPointsEditor(),

                      const SizedBox(height: 16),

                      // Manage User's Profile Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (context) => ManageUserProfileScreen(user: widget.user),
                            ));
                          },
                          icon: const Icon(Icons.edit_note),
                          label: const Text('Manage User\'s Profile'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.namaNavyBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
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

  Widget _buildPointsEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'User Points',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Minus Button
            IconButton(
              onPressed: () => _adjustPoints(-1),
              icon: const Icon(Icons.remove_circle),
              color: AppColors.errorRed,
              iconSize: 32,
            ),
            // Points Input
            Expanded(
              child: TextField(
                controller: _pointsController,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Plus Button
            IconButton(
              onPressed: () => _adjustPoints(1),
              icon: const Icon(Icons.add_circle),
              color: AppColors.successGreen,
              iconSize: 32,
            ),
            // Update Button
            ElevatedButton(
              onPressed: _updatePoints,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.namaNavyBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text('Update'),
            ),
          ],
        ),
      ],
    );
  }

  void _adjustPoints(int delta) {
    final currentPoints = int.tryParse(_pointsController.text) ?? widget.user.points;
    final newPoints = (currentPoints + delta).clamp(0, 999999);
    setState(() {
      _pointsController.text = newPoints.toString();
    });
  }

  Future<void> _updatePoints() async {
    final newPoints = int.tryParse(_pointsController.text);
    if (newPoints == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid number'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    if (newPoints == widget.user.points) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Points value hasn\'t changed'),
          backgroundColor: AppColors.warningAmber,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Update Points'),
          content: Text(
            'Change user points from ${widget.user.points} to $newPoints?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.namaNavyBlue,
              ),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        await ref.read(userProfileRepositoryProvider).updateUserProfile(
          widget.user.uid,
          {'points': newPoints},
        );

        if (mounted) {
          Navigator.of(context).pop(); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Points updated to $newPoints'),
              backgroundColor: AppColors.successGreen,
            ),
          );
          Navigator.of(context).pop(); // Go back to user list
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop(); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update points: $e'),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleRoleChange(String? newRole) async {
    if (newRole != null && newRole != widget.user.role) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Change Role'),
            content: Text('Are you sure you want to change this user\'s role to ${newRole.toUpperCase()}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.namaNavyBlue,
                ),
                child: const Text('Confirm'),
              ),
            ],
          );
        },
      );

      if (confirmed == true && mounted) {
        // Show loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );

        try {
          await ref.read(userProfileRepositoryProvider).updateUserProfile(
            widget.user.uid, 
            {'role': newRole}
          );
          
          if (mounted) {
            Navigator.of(context).pop(); // Close loading
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Role updated to ${newRole.toUpperCase()}'),
                backgroundColor: AppColors.successGreen,
              ),
            );
            Navigator.of(context).pop(); // Go back to user list
          }
        } catch (e) {
          if (mounted) {
            Navigator.of(context).pop(); // Close loading
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to update role: $e'),
                backgroundColor: AppColors.errorRed,
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _handleStatusChange(String? newStatus) async {
    if (newStatus != null && newStatus != widget.user.status) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Change Status'),
            content: Text('Are you sure you want to change this user\'s status to ${newStatus.toUpperCase()}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.namaNavyBlue,
                ),
                child: const Text('Confirm'),
              ),
            ],
          );
        },
      );

      if (confirmed == true && mounted) {
        // Show loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );

        try {
          await ref.read(userProfileRepositoryProvider).updateUserProfile(
            widget.user.uid, 
            {'status': newStatus}
          );
          
          if (mounted) {
            Navigator.of(context).pop(); // Close loading
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Status updated to ${newStatus.toUpperCase()}'),
                backgroundColor: AppColors.successGreen,
              ),
            );
            Navigator.of(context).pop(); // Go back to user list
          }
        } catch (e) {
          if (mounted) {
            Navigator.of(context).pop(); // Close loading
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to update status: $e'),
                backgroundColor: AppColors.errorRed,
              ),
            );
          }
        }
      }
    }
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
      case 'blocked':
        return Icons.block;
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
        return AppColors.errorRed;
      case 'blocked':
        return AppColors.errorRed;
      case 'pending':
      default:
        return AppColors.warningAmber;
    }
  }
}
