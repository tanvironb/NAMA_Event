// lib/features/admin/screen/user_detail_admin_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/models/app_user.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/features/admin/screen/manage_user_profile_screen.dart';
import 'package:intl/intl.dart';

class UserDetailAdminScreen extends ConsumerStatefulWidget {
  final AppUser user;

  const UserDetailAdminScreen({
    super.key,
    required this.user,
  });

  @override
  ConsumerState<UserDetailAdminScreen> createState() =>
      _UserDetailAdminScreenState();
}

class _UserDetailAdminScreenState extends ConsumerState<UserDetailAdminScreen> {
  @override
  Widget build(BuildContext context) {
    final possibleRoles = <String>[
      'attendee',
      'staff',
      'speaker',
      'moderator',
      'admin',
    ];
    final possibleStatuses = <String>[
      'pending',
      'approved',
      'rejected',
      'blocked',
    ];

    final currentRole = widget.user.role.trim().toLowerCase();
    final currentStatus = widget.user.status.trim().toLowerCase();

    final safeRole = possibleRoles.contains(currentRole) ? currentRole : null;
    final safeStatus =
        possibleStatuses.contains(currentStatus) ? currentStatus : null;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCustomHeader(context),

              const SizedBox(height: 18),

              // User Details Card
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'User Information',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildInfoRow('Email', widget.user.email),
                    _buildInfoRow('Name', widget.user.name),
                    _buildInfoRow(
                      'Company',
                      widget.user.company.isEmpty
                          ? 'Not provided'
                          : widget.user.company,
                    ),
                    _buildInfoRow(
                      'Title',
                      widget.user.title.isEmpty
                          ? 'Not provided'
                          : widget.user.title,
                    ),
                    _buildInfoRow(
                      'Phone',
                      widget.user.phone.isEmpty
                          ? 'Not provided'
                          : widget.user.phone,
                    ),
                    _buildInfoRow(
                      'Created',
                      widget.user.createdAt != null
                          ? DateFormat('MMM dd, yyyy HH:mm')
                              .format(widget.user.createdAt!)
                          : 'Unknown',
                    ),
                    _buildInfoRow(
                      'Last Seen',
                      widget.user.lastSeen != null
                          ? DateFormat('MMM dd, yyyy HH:mm')
                              .format(widget.user.lastSeen!)
                          : 'Never',
                    ),
                    _buildInfoRow(
                      'Online Status',
                      widget.user.isOnline ? 'Online' : 'Offline',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Admin Controls Card
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Admin Controls',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Role Changer
                    DropdownButtonFormField<String>(
                      value: safeRole,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      items: possibleRoles
                          .map(
                            (role) => DropdownMenuItem(
                              value: role,
                              child: Text(
                                role.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (newRole) => _handleRoleChange(newRole),
                      decoration: _inputDecoration('Change Role'),
                    ),

                    const SizedBox(height: 14),

                    // Status Changer
                    DropdownButtonFormField<String>(
                      value: safeStatus,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      items: possibleStatuses
                          .map(
                            (status) => DropdownMenuItem(
                              value: status,
                              child: Row(
                                children: [
                                  Icon(
                                    _getStatusIcon(status),
                                    color: _getStatusColor(status),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    status.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (newStatus) => _handleStatusChange(newStatus),
                      decoration: _inputDecoration('Change Status'),
                    ),

                    const SizedBox(height: 18),

                    // Manage User's Profile Button
                    Align(
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: 230,
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    ManageUserProfileScreen(user: widget.user),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.edit_note_rounded,
                            size: 18,
                          ),
                          label: const Text(
                            'Manage Profile',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.namaNavyBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomHeader(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.of(context).pop(),
          borderRadius: BorderRadius.circular(50),
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(
              Icons.arrow_back,
              size: 24,
              color: AppColors.namaNavyBlue,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            widget.user.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.namaNavyBlue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        fontSize: 13,
        color: Colors.black54,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 13,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(
          color: Colors.grey.shade400,
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(
          color: AppColors.namaNavyBlue,
          width: 1.2,
        ),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  Future<void> _handleRoleChange(String? newRole) async {
    final currentRole = widget.user.role.trim().toLowerCase();

    if (newRole != null && newRole != currentRole) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Change Role',
              style: TextStyle(fontSize: 18),
            ),
            content: Text(
              'Are you sure you want to change this user\'s role to ${newRole.toUpperCase()}?',
              style: const TextStyle(fontSize: 14),
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
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        try {
          await ref.read(userProfileRepositoryProvider).updateUserProfile(
            widget.user.uid,
            {'role': newRole},
          );

          if (mounted) {
            Navigator.of(context).pop();

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Role updated to ${newRole.toUpperCase()}'),
                backgroundColor: AppColors.successGreen,
              ),
            );

            Navigator.of(context).pop();
          }
        } catch (e) {
          if (mounted) {
            Navigator.of(context).pop();

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
    final currentStatus = widget.user.status.trim().toLowerCase();

    if (newStatus != null && newStatus != currentStatus) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Change Status',
              style: TextStyle(fontSize: 18),
            ),
            content: Text(
              'Are you sure you want to change this user\'s status to ${newStatus.toUpperCase()}?',
              style: const TextStyle(fontSize: 14),
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
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        try {
          await ref.read(userProfileRepositoryProvider).updateUserProfile(
            widget.user.uid,
            {'status': newStatus},
          );

          if (mounted) {
            Navigator.of(context).pop();

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Status updated to ${newStatus.toUpperCase()}'),
                backgroundColor: AppColors.successGreen,
              ),
            );

            Navigator.of(context).pop();
          }
        } catch (e) {
          if (mounted) {
            Navigator.of(context).pop();

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
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13.5,
                color: Colors.black87,
                height: 1.25,
              ),
            ),
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