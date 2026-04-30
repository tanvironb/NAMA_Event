import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/features/notifications/screen/widgets/notification_list_tile.dart';
import 'package:events_app_trueattempt/core/enums/notification_type.dart';
import 'package:events_app_trueattempt/core/models/notification_model.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String? _selectedPriority;
  AppNotificationType? _selectedType;

  int _getNotificationPriority(AppNotificationType type) {
    return type.priorityValue;
  }

  List<AppNotification> _applyFilters(List<AppNotification> notifications) {
    notifications =
        notifications.where((n) => n.type != AppNotificationType.chat).toList();

    return notifications.where((notification) {
      if (_selectedPriority != null &&
          notification.priority != _selectedPriority) {
        return false;
      }

      if (_selectedType != null && notification.type != _selectedType) {
        return false;
      }

      return true;
    }).toList();
  }

  void _clearFilters() {
    setState(() {
      _selectedPriority = null;
      _selectedType = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);

    return Scaffold(
      body: SafeArea(
        child: notificationsAsync.when(
          data: (notifications) => _buildBody(context, notifications),
          loading: () => const LoadingIndicator(),
          error: (err, _) => Center(child: Text('Error: $err')),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<AppNotification> notifications) {
    if (notifications.isEmpty) {
      return const Center(
        child: Text(
          'No notifications',
          style: TextStyle(fontSize: 12),
        ),
      );
    }

    final filtered = _applyFilters(notifications);

    final unread = filtered.where((n) => !n.isRead).toList();
    final read = filtered.where((n) => n.isRead).toList();

    unread.sort((a, b) {
      final aPriority = _getNotificationPriority(a.type);
      final bPriority = _getNotificationPriority(b.type);
      if (aPriority != bPriority) return aPriority.compareTo(bPriority);
      return b.timestamp.compareTo(a.timestamp);
    });

    read.sort((a, b) {
      final aPriority = _getNotificationPriority(a.type);
      final bPriority = _getNotificationPriority(b.type);
      if (aPriority != bPriority) return aPriority.compareTo(bPriority);
      return b.timestamp.compareTo(a.timestamp);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Color(0xFF20135C),
                  size: 22,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 4),
              const Text(
                "Notifications",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF20135C),
                ),
              ),
            ],
          ),
        ),

        _buildFilterChips(),

        if (filtered.isEmpty)
          const Expanded(
            child: Center(
              child: Text(
                'No notifications match the selected filters.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          )
        else
          Expanded(
            child: ListView(
              children: [
                if (unread.isNotEmpty) ...[
                  _buildSectionHeader("UNREAD NOTIFICATIONS", unread.length),
                  ...unread.map(
                    (n) => NotificationListTile(
                      notification: n,
                      key: ValueKey(n.id),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (read.isNotEmpty) ...[
                  _buildSectionHeader("READ NOTIFICATIONS", read.length),
                  ...read.map(
                    (n) => NotificationListTile(
                      notification: n,
                      key: ValueKey(n.id),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildFilterChips() {
    final hasFilter = _selectedPriority != null || _selectedType != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterDropdown<String?>(
              value: _selectedPriority,
              hint: 'All',
              items: const [
                DropdownMenuItem(value: null, child: Text('All')),
                DropdownMenuItem(value: 'high', child: Text('High')),
                DropdownMenuItem(value: 'medium', child: Text('Medium')),
                DropdownMenuItem(value: 'low', child: Text('Low')),
              ],
              onChanged: (v) => setState(() => _selectedPriority = v),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildFilterDropdown<AppNotificationType?>(
              value: _selectedType,
              hint: 'All Types',
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('All Types'),
                ),
                ...AppNotificationType.values
                    .where((type) =>
                        type != AppNotificationType.chat &&
                        type != AppNotificationType.warning &&
                        type != AppNotificationType.important &&
                        type != AppNotificationType.reminder)
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Row(
                          children: [
                            Icon(type.icon, size: 14),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                type.displayName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
              onChanged: (v) => setState(() => _selectedType = v),
            ),
          ),
          if (hasFilter) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.filter_alt_off, size: 19),
              onPressed: _clearFilters,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterDropdown<T>({
    required T value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(
            hint,
            style: const TextStyle(fontSize: 11),
          ),
          isExpanded: true,
          items: items,
          onChanged: onChanged,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.black87,
          ),
          iconSize: 18,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 5),
      color: AppColors.namaDeepNavy.withOpacity(0.04),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.namaDeepNavy,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.namaDeepNavy.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              "$count",
              style: const TextStyle(
                fontSize: 9,
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