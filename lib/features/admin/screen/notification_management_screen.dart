// lib/features/admin/screen/notification_management_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
  static const Color _gold = AppColors.namaGoldenYellow;
  static const Color _softGold = AppColors.namaWarmGold;

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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 38,
              width: 38,
              decoration: BoxDecoration(
                color: _softGold.withOpacity(0.75),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _gold.withOpacity(0.55),
                ),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: AppColors.namaNavyBlue,
                size: 21,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
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
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    height: 3,
                    width: 58,
                    decoration: BoxDecoration(
                      color: _gold,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  if (widget.isEventSpecific) ...[
                    const SizedBox(height: 6),
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
        color: Colors.white,
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
            'Filter:',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: AppColors.namaNavyBlue,
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
                color: AppColors.namaNavyBlue,
              ),
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.namaNavyBlue,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: _softGold.withOpacity(0.22),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(
                    color: _gold.withOpacity(0.55),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(
                    color: _gold,
                    width: 1.2,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(
                    color: _gold.withOpacity(0.55),
                  ),
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 58,
                      width: 58,
                      decoration: BoxDecoration(
                        color: _softGold.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _gold.withOpacity(0.5),
                        ),
                      ),
                      child: const Icon(
                        Icons.notifications_active_outlined,
                        color: AppColors.namaNavyBlue,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      widget.isEventSpecific
                          ? 'No notifications found for this event.'
                          : 'No notifications found.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
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
      side: BorderSide(
        color: _gold.withOpacity(0.28),
      ),
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: cardShape,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 4,
              color: _gold,
            ),
          ),
          Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
            child: ExpansionTile(
              tilePadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              childrenPadding: EdgeInsets.zero,
              shape: cardShape,
              collapsedShape: cardShape,
              backgroundColor: Colors.white,
              collapsedBackgroundColor: Colors.white,
              iconColor: _primaryColor,
              collapsedIconColor: _gold,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _softGold.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: _gold.withOpacity(0.35),
                  ),
                ),
                child: Icon(
                  type.icon,
                  color: _primaryColor,
                  size: 19,
                ),
              ),
              title: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  color: AppColors.namaNavyBlue,
                ),
              ),
              subtitle: subtitle != null && subtitle.trim().isNotEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        subtitle,
                        style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          color: _textMuted,
                          fontSize: 11.5,
                        ),
                      ),
                    )
                  : null,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Message',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          color: _primaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: _softGold.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _gold.withOpacity(0.35),
                          ),
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
                              backgroundColor: _softGold.withOpacity(0.45),
                              side: BorderSide(
                                color: _gold.withOpacity(0.55),
                              ),
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
                              side: BorderSide(
                                color: Colors.red.withOpacity(0.35),
                              ),
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
        ],
      ),
    );
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Edit Notification',
            style: TextStyle(
              color: AppColors.namaNavyBlue,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Title',
                    labelStyle: const TextStyle(fontSize: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _gold.withOpacity(0.45),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _gold),
                    ),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: subtitleController,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Subtitle (optional)',
                    labelStyle: const TextStyle(fontSize: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _gold.withOpacity(0.45),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _gold),
                    ),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyController,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Message',
                    labelStyle: const TextStyle(fontSize: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _gold.withOpacity(0.45),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _gold),
                    ),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.namaNavyBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                if (titleController.text.trim().isEmpty ||
                    bodyController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Title and Message cannot be empty'),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Delete Notification',
            style: TextStyle(
              color: Colors.red,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'Are you sure you want to delete this notification?\n\nThis action cannot be undone.',
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