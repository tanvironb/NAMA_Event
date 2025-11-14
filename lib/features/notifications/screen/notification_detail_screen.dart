import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/models/notification_model.dart';
import 'package:events_app_trueattempt/core/enums/notification_type.dart';
import 'package:events_app_trueattempt/core/providers.dart';

class NotificationDetailScreen extends ConsumerStatefulWidget {
  final AppNotification notification;

  const NotificationDetailScreen({
    super.key,
    required this.notification,
  });

  @override
  ConsumerState<NotificationDetailScreen> createState() => _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends ConsumerState<NotificationDetailScreen> {
  late TextEditingController _titleController;
  late TextEditingController _subtitleController;
  late TextEditingController _bodyController;
  late DateTime? _editedAt;
  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.notification.title);
    _subtitleController = TextEditingController(text: widget.notification.subtitle ?? '');
    _bodyController = TextEditingController(text: widget.notification.body);
    // Check if editedAt exists in data map
    _editedAt = widget.notification.data['editedAt'] != null 
        ? (widget.notification.data['editedAt'] as Timestamp).toDate()
        : null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_titleController.text.trim().isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title cannot be empty')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Get the shared notification ID from data field
      final sharedNotificationId = widget.notification.data['notificationId'] as String?;
      
      if (sharedNotificationId == null) {
        throw Exception('Notification ID not found. This notification may not support editing.');
      }

      // Get the target role to query the right users
      final targetRole = widget.notification.targetRole;

      // Query all users based on target role
      final usersQuery = targetRole == 'all'
          ? FirebaseFirestore.instance.collection('users').where('status', isEqualTo: 'approved')
          : FirebaseFirestore.instance.collection('users')
              .where('status', isEqualTo: 'approved')
              .where('role', isEqualTo: targetRole);

      final usersSnapshot = await usersQuery.get();

      // Update notification for all users using batch
      final batch = FirebaseFirestore.instance.batch();
      int updatedCount = 0;

      for (final userDoc in usersSnapshot.docs) {
        // Query this user's notifications to find the one with matching notificationId
        final notificationsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userDoc.id)
            .collection('notifications')
            .where('data.notificationId', isEqualTo: sharedNotificationId)
            .limit(1)
            .get();

        if (notificationsSnapshot.docs.isNotEmpty) {
          final notificationRef = notificationsSnapshot.docs.first.reference;
          
          batch.update(notificationRef, {
            'title': _titleController.text.trim(),
            'subtitle': _subtitleController.text.trim().isEmpty 
                ? FieldValue.delete() 
                : _subtitleController.text.trim(),
            'body': _bodyController.text.trim(),
            'data.editedAt': Timestamp.now(),
          });
          updatedCount++;
        }
      }

      await batch.commit();

      if (mounted) {
        setState(() {
          _isEditing = false;
          _isLoading = false;
          _editedAt = DateTime.now();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notification updated for $updatedCount user(s)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update notification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteNotification() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notification'),
        content: const Text(
          'Are you sure you want to delete this notification for ALL users? This action cannot be undone.',
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

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);

    try {
      // Get the shared notification ID from data field
      final sharedNotificationId = widget.notification.data['notificationId'] as String?;
      
      if (sharedNotificationId == null) {
        throw Exception('Notification ID not found. This notification may not support deletion.');
      }

      // Get the target role to query the right users
      final targetRole = widget.notification.targetRole;

      // Query all users based on target role
      final usersQuery = targetRole == 'all'
          ? FirebaseFirestore.instance.collection('users').where('status', isEqualTo: 'approved')
          : FirebaseFirestore.instance.collection('users')
              .where('status', isEqualTo: 'approved')
              .where('role', isEqualTo: targetRole);

      final usersSnapshot = await usersQuery.get();

      // Delete notification for all users using batch
      final batch = FirebaseFirestore.instance.batch();
      int deletedCount = 0;

      for (final userDoc in usersSnapshot.docs) {
        // Query this user's notifications to find the one with matching notificationId
        final notificationsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userDoc.id)
            .collection('notifications')
            .where('data.notificationId', isEqualTo: sharedNotificationId)
            .limit(1)
            .get();

        if (notificationsSnapshot.docs.isNotEmpty) {
          batch.delete(notificationsSnapshot.docs.first.reference);
          deletedCount++;
        }
      }

      await batch.commit();

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate deletion
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notification deleted for $deletedCount user(s)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete notification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _titleController.text = widget.notification.title;
      _subtitleController.text = widget.notification.subtitle ?? '';
      _bodyController.text = widget.notification.body;
    });
  }

  String _formatEventTimestamp() {
    if (widget.notification.eventTimestamp == null) return '';
    
    final eventTime = widget.notification.eventTimestamp!;
    if (widget.notification.includeDate) {
      final format = DateFormat('EEEE, MMMM d, yyyy • h:mm a');
      return format.format(eventTime);
    } else {
      final format = DateFormat('h:mm a');
      return format.format(eventTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get current user from stream provider
    final currentUserAsync = ref.watch(userAppProfileStreamProvider);
    
    final isAdmin = currentUserAsync.when(
      data: (user) => user?.role.toLowerCase() == 'admin',
      loading: () => false,
      error: (_, __) => false,
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.namaNavyBlue,
        foregroundColor: AppColors.namaWhite,
        title: const Text('Notification Details'),
        actions: [
          if (isAdmin && !_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: 'Edit',
            ),
          if (isAdmin && !_isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteNotification,
              tooltip: 'Delete',
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _cancelEditing,
              tooltip: 'Cancel',
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _isLoading ? null : _saveChanges,
              tooltip: 'Save',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type Badge
                  _buildTypeBadge(),
                  const SizedBox(height: 16),

                  // Title
                  _buildField(
                    label: 'Title',
                    controller: _titleController,
                    isEditing: _isEditing,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),

                  // Subtitle
                  if (widget.notification.subtitle != null || _isEditing)
                    _buildField(
                      label: 'Subtitle',
                      controller: _subtitleController,
                      isEditing: _isEditing,
                      maxLines: 2,
                    ),
                  if (widget.notification.subtitle != null || _isEditing)
                    const SizedBox(height: 16),

                  // Body
                  _buildField(
                    label: 'Description',
                    controller: _bodyController,
                    isEditing: _isEditing,
                    maxLines: 5,
                  ),
                  const SizedBox(height: 16),

                  // Target Role
                  _buildInfoCard(
                    'Target Audience',
                    widget.notification.targetRole == 'all' 
                        ? 'All Users' 
                        : widget.notification.targetRole[0].toUpperCase() + widget.notification.targetRole.substring(1),
                    Icons.people,
                  ),
                  const SizedBox(height: 12),

                  // Event Timestamp (if specified)
                  if (widget.notification.eventTimestamp != null)
                    _buildInfoCard(
                      widget.notification.includeDate ? 'Event Time' : 'Time',
                      _formatEventTimestamp(),
                      Icons.event,
                    ),
                  if (widget.notification.eventTimestamp != null)
                    const SizedBox(height: 12),

                  // Timestamps
                  const Divider(height: 32),
                  _buildTimestampInfo(),
                ],
              ),
            ),
    );
  }

  Widget _buildTypeBadge() {
    final type = widget.notification.type;
    final badgeColor = type.color;
    final icon = type.icon;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        border: Border.all(color: badgeColor),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: badgeColor),
          const SizedBox(width: 8),
          Text(
            type.displayName.toUpperCase(),
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required bool isEditing,
    int maxLines = 1,
  }) {
    if (isEditing) {
      return TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.all(12),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          controller.text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.namaNavyBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimestampInfo() {
    final dateFormat = DateFormat('MMM dd, yyyy hh:mm a');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Timestamps',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildTimestampRow('Created', dateFormat.format(widget.notification.timestamp.toDate())),
        if (_editedAt != null) ...[
          const SizedBox(height: 8),
          _buildTimestampRow(
            'Edited',
            dateFormat.format(_editedAt!),
            color: Colors.orange,
          ),
        ],
        const SizedBox(height: 8),
        _buildTimestampRow(
          'Read Status',
          widget.notification.isRead ? 'Read' : 'Unread',
          color: widget.notification.isRead ? Colors.green : Colors.grey,
        ),
      ],
    );
  }

  Widget _buildTimestampRow(String label, String value, {Color? color}) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
