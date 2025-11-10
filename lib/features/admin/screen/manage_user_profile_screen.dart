import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/models/app_user.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';

class ManageUserProfileScreen extends ConsumerStatefulWidget {
  final AppUser user;

  const ManageUserProfileScreen({super.key, required this.user});

  @override
  ConsumerState<ManageUserProfileScreen> createState() => _ManageUserProfileScreenState();
}

class _ManageUserProfileScreenState extends ConsumerState<ManageUserProfileScreen> {
  // Track which fields are marked for removal
  final Set<String> _fieldsToRemove = {};

  // Define removable fields (excluding email, uid, password-related fields)
  final Map<String, String> _removableFields = {
    'name': 'Name',
    'company': 'Company',
    'title': 'Job Title',
    'bio': 'Bio',
    'phone': 'Phone Number',
    'linkedin': 'LinkedIn',
    'twitter': 'Twitter',
    'website': 'Website',
    'github': 'GitHub',
    'medium': 'Medium',
    'instagram': 'Instagram',
    'profileImageUrl': 'Profile Image',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage User Profile'),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: Column(
        children: [
          // User Info Header
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Theme.of(context).colorScheme.surface,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.namaNavyBlue.withOpacity(0.1),
                  backgroundImage: widget.user.profileImageUrl.isNotEmpty
                      ? NetworkImage(widget.user.profileImageUrl)
                      : null,
                  child: widget.user.profileImageUrl.isEmpty
                      ? Text(
                          widget.user.name.isNotEmpty ? widget.user.name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.namaNavyBlue,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.user.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.user.email,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Warning Banner
          Container(
            padding: const EdgeInsets.all(12.0),
            margin: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: AppColors.warningAmber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.warningAmber),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, color: AppColors.warningAmber),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'You can only remove fields, not edit them. Removed fields will be cleared from the user\'s profile.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Field List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              children: _removableFields.entries.map((entry) {
                final fieldKey = entry.key;
                final fieldLabel = entry.value;
                final fieldValue = _getFieldValue(fieldKey);
                final hasValue = fieldValue.isNotEmpty;

                return _ProfileFieldCard(
                  fieldKey: fieldKey,
                  fieldLabel: fieldLabel,
                  fieldValue: fieldValue,
                  hasValue: hasValue,
                  isMarkedForRemoval: _fieldsToRemove.contains(fieldKey),
                  onToggleRemoval: (marked) {
                    setState(() {
                      if (marked) {
                        _fieldsToRemove.add(fieldKey);
                      } else {
                        _fieldsToRemove.remove(fieldKey);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),

          // Action Buttons
          if (_fieldsToRemove.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    '${_fieldsToRemove.length} field${_fieldsToRemove.length != 1 ? 's' : ''} marked for removal',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _showConfirmationDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.errorRed,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Update User\'s Profile',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _getFieldValue(String fieldKey) {
    switch (fieldKey) {
      case 'name':
        return widget.user.name;
      case 'company':
        return widget.user.company;
      case 'title':
        return widget.user.title;
      case 'bio':
        return widget.user.bio;
      case 'phone':
        return widget.user.phone;
      case 'linkedin':
        return widget.user.linkedin;
      case 'twitter':
        return widget.user.twitter;
      case 'website':
        return widget.user.website;
      case 'github':
        return widget.user.github;
      case 'medium':
        return widget.user.medium;
      case 'instagram':
        return widget.user.instagram;
      case 'profileImageUrl':
        return widget.user.profileImageUrl;
      default:
        return '';
    }
  }

  void _showConfirmationDialog() {
    final fieldNames = _fieldsToRemove.map((key) => _removableFields[key]).join(', ');

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: AppColors.errorRed),
              SizedBox(width: 8),
              Text('Confirm Profile Update'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you SURE you want to remove the following fields from the user\'s profile?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  fieldNames,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'This action cannot be undone.',
                style: TextStyle(
                  color: AppColors.errorRed,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _performUpdate();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorRed,
              ),
              child: const Text(
                'Confirm',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performUpdate() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Build update map with empty strings for fields to remove
      final Map<String, dynamic> updates = {};
      for (final fieldKey in _fieldsToRemove) {
        if (fieldKey == 'name') {
          updates[fieldKey] = 'User'; // Don't allow completely empty name
        } else {
          updates[fieldKey] = ''; // Clear the field
        }
      }

      await ref.read(userProfileRepositoryProvider).updateUserProfile(
        widget.user.uid,
        updates,
      );

      if (mounted) {
        Navigator.of(context).pop(); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User profile updated successfully'),
            backgroundColor: AppColors.successGreen,
          ),
        );
        Navigator.of(context).pop(); // Go back to previous screen
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }
}

class _ProfileFieldCard extends StatelessWidget {
  final String fieldKey;
  final String fieldLabel;
  final String fieldValue;
  final bool hasValue;
  final bool isMarkedForRemoval;
  final Function(bool) onToggleRemoval;

  const _ProfileFieldCard({
    required this.fieldKey,
    required this.fieldLabel,
    required this.fieldValue,
    required this.hasValue,
    required this.isMarkedForRemoval,
    required this.onToggleRemoval,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isMarkedForRemoval
            ? AppColors.errorRed.withOpacity(0.05)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isMarkedForRemoval
              ? AppColors.errorRed
              : hasValue
                  ? Colors.grey[300]!
                  : Colors.grey[200]!,
          width: isMarkedForRemoval ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fieldLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasValue ? fieldValue : 'Not provided',
                      style: TextStyle(
                        fontSize: 13,
                        color: hasValue ? Colors.grey[700] : Colors.grey[400],
                        fontStyle: hasValue ? FontStyle.normal : FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (hasValue)
                IconButton(
                  icon: Icon(
                    isMarkedForRemoval ? Icons.undo : Icons.delete,
                    color: isMarkedForRemoval ? AppColors.warningAmber : AppColors.errorRed,
                  ),
                  onPressed: () => onToggleRemoval(!isMarkedForRemoval),
                  tooltip: isMarkedForRemoval ? 'Undo' : 'Remove',
                ),
            ],
          ),
        ],
      ),
    );
  }
}
