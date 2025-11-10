import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/enums/notification_type.dart';

/// Admin screen to manage all sent notifications
/// Allows viewing, editing, and deleting notifications
class NotificationManagementScreen extends ConsumerStatefulWidget {
  const NotificationManagementScreen({super.key});

  @override
  ConsumerState<NotificationManagementScreen> createState() =>
      _NotificationManagementScreenState();
}

class _NotificationManagementScreenState
    extends ConsumerState<NotificationManagementScreen> {
  String _selectedFilter = 'All';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.namaNavyBlue,
        foregroundColor: AppColors.namaWhite,
        title: const Text('Notification Management'),
      ),
      body: Column(
        children: [
          // Filter Section
          _buildFilterSection(),
          
          // Notifications List
          Expanded(
            child: _buildNotificationsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text(
            'Target Audience:',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedFilter,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: ['All', 'all', 'attendee', 'speaker', 'staff', 'admin']
                  .map((filter) => DropdownMenuItem(
                        value: filter,
                        child: Text(filter == 'All' 
                            ? 'All Notifications' 
                            : filter[0].toUpperCase() + filter.substring(1)),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() => _selectedFilter = value!);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getNotificationsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final notifications = snapshot.data?.docs ?? [];

        if (notifications.isEmpty) {
          return const Center(
            child: Text('No notifications found'),
          );
        }

        return ListView.builder(
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notificationDoc = notifications[index];
            final data = notificationDoc.data() as Map<String, dynamic>;
            
            return _buildNotificationCard(
              notificationDoc.id,
              data,
            );
          },
        );
      },
    );
  }

  Stream<QuerySnapshot> _getNotificationsStream() {
    var query = FirebaseFirestore.instance
        .collection('adminNotifications')
        .orderBy('timestamp', descending: true);

    if (_selectedFilter != 'All') {
      query = query.where('targetRole', isEqualTo: _selectedFilter);
    }

    return query.snapshots();
  }

  Widget _buildNotificationCard(String notificationId, Map<String, dynamic> data) {
    final title = data['title'] as String? ?? 'Untitled';
    final subtitle = data['subtitle'] as String?;
    final body = data['body'] as String? ?? '';
    final targetRole = data['targetRole'] as String? ?? 'all';
    final typeStr = data['type'] as String? ?? 'generic';
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    final editedAt = (data['editedAt'] as Timestamp?)?.toDate();

    // Parse type
    AppNotificationType type;
    try {
      type = AppNotificationType.values.firstWhere(
        (e) => e.toString().split('.').last == typeStr,
        orElse: () => AppNotificationType.generic,
      );
    } catch (e) {
      type = AppNotificationType.generic;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: type.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(type.icon, color: type.color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[600],
                ),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.people, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Target: ${targetRole == 'all' ? 'All Users' : targetRole[0].toUpperCase() + targetRole.substring(1)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(width: 12),
                Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  DateFormat('MMM dd, yyyy').format(timestamp),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            if (editedAt != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.edit, size: 14, color: Colors.orange[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Edited: ${DateFormat('MMM dd, yyyy hh:mm a').format(editedAt)}',
                    style: TextStyle(fontSize: 12, color: Colors.orange[600]),
                  ),
                ],
              ),
            ],
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Body
                const Text(
                  'Description:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(body),
                ),
                const SizedBox(height: 16),
                
                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () => _editNotification(notificationId, data),
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.namaNavyBlue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () => _deleteNotification(notificationId, targetRole),
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editNotification(
    String notificationId,
    Map<String, dynamic> currentData,
  ) async {
    final titleController = TextEditingController(text: currentData['title']);
    final subtitleController = TextEditingController(text: currentData['subtitle'] ?? '');
    final bodyController = TextEditingController(text: currentData['body']);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Notification'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: subtitleController,
                decoration: const InputDecoration(
                  labelText: 'Subtitle (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bodyController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.trim().isEmpty ||
                  bodyController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Title and Description cannot be empty'),
                  ),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      setState(() => _isLoading = true);

      try {
        // Call cloud function to edit notification
        final functions = FirebaseFunctions.instanceFor(region: 'asia-southeast1');
        final callable = functions.httpsCallable('editNotification');
        
        final response = await callable.call({
          'notificationId': notificationId,
          'title': titleController.text.trim(),
          'subtitle': subtitleController.text.trim().isEmpty 
              ? null 
              : subtitleController.text.trim(),
          'body': bodyController.text.trim(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Notification updated for ${response.data['updatedCount']} user(s)',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          // Shorten error message for rate limit
          String errorMessage = 'Failed to update notification';
          if (e.toString().contains('resource-exhausted') || 
              e.toString().contains('Rate limit')) {
            errorMessage = 'Rate limit exceeded. Please wait a minute.';
          } else if (e.toString().contains('permission-denied')) {
            errorMessage = 'Permission denied';
          } else if (e.toString().contains('not-found')) {
            errorMessage = 'Notification not found';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }

    titleController.dispose();
    subtitleController.dispose();
    bodyController.dispose();
  }

  Future<void> _deleteNotification(String notificationId, String targetRole) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notification'),
        content: Text(
          'Are you sure you want to delete this notification for ALL ${targetRole == 'all' ? 'users' : targetRole + 's'}?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);

      try {
        // Call cloud function to delete notification
        final functions = FirebaseFunctions.instanceFor(region: 'asia-southeast1');
        final callable = functions.httpsCallable('deleteNotification');
        
        final response = await callable.call({
          'notificationId': notificationId,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Notification deleted for ${response.data['deletedCount']} user(s)',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          // Shorten error message for rate limit
          String errorMessage = 'Failed to delete notification';
          if (e.toString().contains('resource-exhausted') || 
              e.toString().contains('Rate limit')) {
            errorMessage = 'Rate limit exceeded. Please wait a minute.';
          } else if (e.toString().contains('permission-denied')) {
            errorMessage = 'Permission denied';
          } else if (e.toString().contains('not-found')) {
            errorMessage = 'Notification not found';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }
}
