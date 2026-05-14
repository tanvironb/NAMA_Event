// lib/features/admin/screen/notification_management_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/enums/notification_type.dart';

class NotificationManagementScreen extends ConsumerStatefulWidget {
  final String? eventId;
  final String? eventName;

  const NotificationManagementScreen({
    super.key,
    this.eventId,
    this.eventName,
  });

  bool get isEventSpecific => eventId != null && eventId!.isNotEmpty;

  @override
  ConsumerState<NotificationManagementScreen> createState() =>
      _NotificationManagementScreenState();
}

class _NotificationManagementScreenState
    extends ConsumerState<NotificationManagementScreen> {
  String _selectedFilter = 'All';
  bool _isLoading = false;

  static const Color _primaryColor = Color(0xFF1B0F72);
  static const Color _textMuted = Color(0xFF6B7280);
  static const Color _borderColor = Color(0xFFE8E4F8);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildFilterSection(),
            Expanded(
              child: _buildNotificationsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 14, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back,
              color: AppColors.namaNavyBlue,
              size: 22,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 36,
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Notification Management',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.namaNavyBlue,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (widget.isEventSpecific) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.eventName ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: _textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text(
            'Target Audience:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedFilter,
              isDense: true,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: _textMuted,
              ),
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF333333),
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: _borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(
                    color: _primaryColor,
                    width: 1.2,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: _borderColor),
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'All',
                  child: Text('All Notifications'),
                ),
                DropdownMenuItem(
                  value: 'all',
                  child: Text('All Users'),
                ),
                DropdownMenuItem(
                  value: 'attendee',
                  child: Text('Attendee'),
                ),
                DropdownMenuItem(
                  value: 'speaker',
                  child: Text('Speaker'),
                ),
                DropdownMenuItem(
                  value: 'staff',
                  child: Text('Staff'),
                ),
                DropdownMenuItem(
                  value: 'admin',
                  child: Text('Admin'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedFilter = value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList() {
    return Stack(
      children: [
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _getNotificationsStream(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    'Error: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppColors.namaNavyBlue,
                ),
              );
            }

            var notifications = snapshot.data?.docs ?? [];

            notifications.sort((a, b) {
              final aTime = a.data()['timestamp'];
              final bTime = b.data()['timestamp'];

              if (aTime is Timestamp && bTime is Timestamp) {
                return bTime.compareTo(aTime);
              }

              return 0;
            });

            if (_selectedFilter != 'All') {
              notifications = notifications.where((doc) {
                final data = doc.data();
                return (data['targetRole'] ?? '').toString() ==
                    _selectedFilter;
              }).toList();
            }

            if (notifications.isEmpty) {
              return Center(
                child: Text(
                  widget.isEventSpecific
                      ? 'No notifications found for this event.'
                      : 'No notifications found.',
                  style: const TextStyle(
                    color: _textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.only(top: 10, bottom: 16),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notificationDoc = notifications[index];
                final data = notificationDoc.data();

                return _buildNotificationCard(
                  notificationDoc.id,
                  data,
                );
              },
            );
          },
        ),
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.15),
            child: const Center(
              child: CircularProgressIndicator(
                color: AppColors.namaNavyBlue,
              ),
            ),
          ),
      ],
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _getNotificationsStream() {
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection('adminNotifications');

    if (widget.isEventSpecific) {
      query = query.where('eventId', isEqualTo: widget.eventId);
    }

    return query.snapshots();
  }

  Widget _buildNotificationCard(
    String notificationId,
    Map<String, dynamic> data,
  ) {
    final title = data['title'] as String? ?? 'Untitled';
    final subtitle = data['subtitle'] as String?;
    final body = data['body'] as String? ?? '';
    final targetRole = data['targetRole'] as String? ?? 'all';
    final typeStr = data['type'] as String? ?? 'generic';
    final timestamp =
        (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    final editedAt = (data['editedAt'] as Timestamp?)?.toDate();

    AppNotificationType type;
    try {
      type = AppNotificationType.values.firstWhere(
        (e) => e.toString().split('.').last == typeStr,
        orElse: () => AppNotificationType.generic,
      );
    } catch (_) {
      type = AppNotificationType.generic;
    }

    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFF0EDF8)),
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: cardShape,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          childrenPadding: EdgeInsets.zero,
          shape: cardShape,
          collapsedShape: cardShape,
          backgroundColor: Colors.white,
          collapsedBackgroundColor: Colors.white,
          iconColor: _primaryColor,
          collapsedIconColor: const Color(0xFF333333),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: type.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              type.icon,
              color: type.color,
              size: 19,
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: Color(0xFF333333),
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[600],
                    fontSize: 11.5,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                runSpacing: 4,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people, size: 12.5, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        'Target: ${_targetRoleText(targetRole)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12.5,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMM dd, yyyy').format(timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (editedAt != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.edit, size: 12.5, color: Colors.orange[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Edited: ${DateFormat('MMM dd, yyyy hh:mm a').format(editedAt)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Description:',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: _primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F7FA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      body,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF333333),
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () => _editNotification(notificationId, data),
                        icon: const Icon(Icons.edit, size: 15),
                        label: const Text(
                          'Edit',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.namaNavyBlue,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          minimumSize: const Size(0, 34),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () => _deleteNotification(
                                  notificationId,
                                  targetRole,
                                ),
                        icon: const Icon(Icons.delete, size: 15),
                        label: const Text(
                          'Delete',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          minimumSize: const Size(0, 34),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _targetRoleText(String targetRole) {
    if (targetRole == 'all') return 'All Users';
    if (targetRole.isEmpty) return 'Unknown';

    return targetRole[0].toUpperCase() + targetRole.substring(1);
  }

  Future<void> _editNotification(
    String notificationId,
    Map<String, dynamic> currentData,
  ) async {
    final titleController = TextEditingController(
      text: currentData['title']?.toString() ?? '',
    );
    final subtitleController = TextEditingController(
      text: currentData['subtitle']?.toString() ?? '',
    );
    final bodyController = TextEditingController(
      text: currentData['body']?.toString() ?? '',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Edit Notification',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    labelStyle: TextStyle(fontSize: 12),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: subtitleController,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Subtitle (optional)',
                    labelStyle: TextStyle(fontSize: 12),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyController,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    labelStyle: TextStyle(fontSize: 12),
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
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 12),
              ),
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
              child: const Text(
                'Save',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        );
      },
    );

    if (result == true && mounted) {
      setState(() => _isLoading = true);

      try {
        final functions =
            FirebaseFunctions.instanceFor(region: 'asia-southeast1');
        final callable = functions.httpsCallable('editNotification');

        final response = await callable.call({
          'notificationId': notificationId,
          'title': titleController.text.trim(),
          'subtitle': subtitleController.text.trim().isEmpty
              ? null
              : subtitleController.text.trim(),
          'body': bodyController.text.trim(),
          'eventId': widget.eventId,
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

  Future<void> _deleteNotification(
    String notificationId,
    String targetRole,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Delete Notification',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Are you sure you want to delete this notification for ALL ${targetRole == 'all' ? 'users' : '${targetRole}s'}?\n\nThis action cannot be undone.',
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 12),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text(
                'Delete',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);

      try {
        final functions =
            FirebaseFunctions.instanceFor(region: 'asia-southeast1');
        final callable = functions.httpsCallable('deleteNotification');

        final response = await callable.call({
          'notificationId': notificationId,
          'eventId': widget.eventId,
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