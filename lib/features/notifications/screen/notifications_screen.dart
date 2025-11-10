import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/features/notifications/screen/widgets/notification_list_tile.dart';
import 'package:events_app_trueattempt/core/enums/notification_type.dart';
import 'package:events_app_trueattempt/core/models/notification_model.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String? _selectedPriority; // 'high', 'medium', 'low', or null for all
  AppNotificationType? _selectedType;
  DateTime? _selectedDate;

  /// Helper method to get notification priority for sorting
  /// Lower number = higher priority
  int _getNotificationPriority(AppNotificationType type) {
    return type.priorityValue;
  }

  /// Apply filters to notifications
  List<AppNotification> _applyFilters(List<AppNotification> notifications) {
    // Exclude chat messages (they have their own flow)
    notifications = notifications.where((n) => n.type != AppNotificationType.chat).toList();
    
    return notifications.where((notification) {
      // Filter by priority
      if (_selectedPriority != null && notification.priority != _selectedPriority) {
        return false;
      }
      
      // Filter by type
      if (_selectedType != null && notification.type != _selectedType) {
        return false;
      }
      
      // Filter by date (same day)
      if (_selectedDate != null) {
        final notificationDate = notification.timestamp.toDate();
        if (notificationDate.year != _selectedDate!.year ||
            notificationDate.month != _selectedDate!.month ||
            notificationDate.day != _selectedDate!.day) {
          return false;
        }
      }
      
      return true;
    }).toList();
  }

  /// Mark all unread notifications as read
  Future<void> _markAllAsRead(List<AppNotification> unreadNotifications) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark All as Read'),
        content: Text(
          'Are you sure you want to mark all ${unreadNotifications.length} '
          'notification${unreadNotifications.length != 1 ? 's' : ''} as read?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.namaNavyBlue,
            ),
            child: const Text('Mark All as Read'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // Batch update all unread notifications
      final batch = FirebaseFirestore.instance.batch();
      
      for (final notification in unreadNotifications) {
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .doc(notification.id);
        batch.update(docRef, {'isRead': true});
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Marked ${unreadNotifications.length} notification${unreadNotifications.length != 1 ? 's' : ''} as read',
            ),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark notifications as read: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);
    
    return notificationsAsync.when(
      data: (notifications) {
        // Calculate unread count for AppBar
        final filteredNotifications = _applyFilters(notifications);
        final unreadNotifications = filteredNotifications.where((n) => !n.isRead).toList();
        final hasUnread = unreadNotifications.isNotEmpty;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Notifications'),
            actions: [
              // Mark all as read button (only show when there are unread notifications)
              if (hasUnread)
                IconButton(
                  icon: const Icon(Icons.done_all),
                  onPressed: () => _markAllAsRead(unreadNotifications),
                  tooltip: 'Mark All as Read',
                ),
              // Clear filters button
              if (_selectedPriority != null || _selectedType != null || _selectedDate != null)
                IconButton(
                  icon: const Icon(Icons.filter_alt_off),
                  onPressed: () {
                    setState(() {
                      _selectedPriority = null;
                      _selectedType = null;
                      _selectedDate = null;
                    });
                  },
                  tooltip: 'Clear Filters',
                ),
            ],
          ),
          body: _buildBody(notifications),
        );
      },
      loading: () => const LoadingIndicator(),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildBody(List<AppNotification> notifications) {
    if (notifications.isEmpty) {
      return const Center(child: Text('You have no notifications.'));
    }

    // Apply filters
    final filteredNotifications = _applyFilters(notifications);

    if (filteredNotifications.isEmpty) {
      return Column(
        children: [
          _buildFilterChips(),
          const Expanded(
            child: Center(child: Text('No notifications match the selected filters.')),
          ),
        ],
      );
    }

    // Separate into unread and read
    final unreadNotifications = filteredNotifications.where((n) => !n.isRead).toList();
    final readNotifications = filteredNotifications.where((n) => n.isRead).toList();

    // Sort each group by priority then timestamp
    unreadNotifications.sort((a, b) {
      final aPriority = _getNotificationPriority(a.type);
      final bPriority = _getNotificationPriority(b.type);
      if (aPriority != bPriority) {
        return aPriority.compareTo(bPriority);
      }
      return b.timestamp.compareTo(a.timestamp);
    });

    readNotifications.sort((a, b) {
      final aPriority = _getNotificationPriority(a.type);
      final bPriority = _getNotificationPriority(b.type);
      if (aPriority != bPriority) {
        return aPriority.compareTo(bPriority);
      }
      return b.timestamp.compareTo(a.timestamp);
    });

    return Column(
      children: [
        _buildFilterChips(),
        Expanded(
          child: ListView(
            children: [
              // UNREAD section
              if (unreadNotifications.isNotEmpty) ...[
                _buildSectionHeader('UNREAD NOTIFICATIONS', unreadNotifications.length),
                ...unreadNotifications.map((n) => NotificationListTile(
                  notification: n,
                  key: ValueKey(n.id),
                )),
                const SizedBox(height: 16),
              ],
              // READ section
              if (readNotifications.isNotEmpty) ...[
                _buildSectionHeader('READ NOTIFICATIONS', readNotifications.length),
                ...readNotifications.map((n) => NotificationListTile(
                  notification: n,
                  key: ValueKey(n.id),
                )),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Build filter chips - compact horizontal layout
  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          // Priority filter dropdown
          Expanded(
            child: _buildFilterDropdown<String?>(
              value: _selectedPriority,
              hint: 'Priority',
              icon: Icons.priority_high,
              items: [
                DropdownMenuItem(value: null, child: Text('All Priorities')),
                DropdownMenuItem(
                  value: 'high',
                  child: Row(
                    children: [
                      Icon(Icons.priority_high, size: 16, color: AppColors.errorRed),
                      SizedBox(width: 8),
                      Text('High'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'medium',
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 16, color: AppColors.warningAmber),
                      SizedBox(width: 8),
                      Text('Medium'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'low',
                  child: Row(
                    children: [
                      Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.infoBlue),
                      SizedBox(width: 8),
                      Text('Low'),
                    ],
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedPriority = value;
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          // Type filter dropdown
          Expanded(
            child: _buildFilterDropdown<AppNotificationType?>(
              value: _selectedType,
              hint: 'Type',
              icon: Icons.category,
              items: [
                DropdownMenuItem(value: null, child: Text('All Types')),
                ...AppNotificationType.values
                    .where((type) =>
                        type != AppNotificationType.warning &&
                        type != AppNotificationType.important &&
                        type != AppNotificationType.reminder &&
                        type != AppNotificationType.chat) // Exclude chat and deprecated
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Row(
                            children: [
                              Icon(type.icon, size: 16),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  type.displayName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        )),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedType = value;
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          // Date filter button
          IconButton(
            icon: Icon(
              _selectedDate != null ? Icons.event_available : Icons.event,
              color: _selectedDate != null ? AppColors.namaGoldenYellow : Colors.grey[600],
            ),
            tooltip: _selectedDate != null
                ? 'Date: ${_selectedDate!.month}/${_selectedDate!.day}'
                : 'Filter by Date',
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) {
                setState(() {
                  _selectedDate = date;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  /// Build a compact filter dropdown
  Widget _buildFilterDropdown<T>({
    required T value,
    required String hint,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: value != null ? AppColors.namaGoldenYellow.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: value != null ? AppColors.namaGoldenYellow : Colors.grey[300]!,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(hint, style: TextStyle(fontSize: 13)),
            ],
          ),
          isExpanded: true,
          items: items,
          onChanged: onChanged,
          icon: const Icon(Icons.arrow_drop_down, size: 20),
          iconSize: 20,
          style: const TextStyle(fontSize: 13, color: AppColors.namaDeepNavy),
          dropdownColor: Colors.white,
        ),
      ),
    );
  }

  /// Build section header
  Widget _buildSectionHeader(String title, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.namaDeepNavy.withOpacity(0.05),
        border: Border(
          bottom: BorderSide(color: AppColors.namaDeepNavy.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.namaDeepNavy,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.namaDeepNavy.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.namaDeepNavy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}