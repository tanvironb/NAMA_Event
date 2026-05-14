import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/features/notifications/screen/widgets/notification_list_tile.dart';
import 'package:events_app_trueattempt/core/enums/notification_type.dart';
import 'package:events_app_trueattempt/core/models/notification_model.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  static const Color titleColor = Color(0xFF0D1496);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AppNotification> _applyFilters(List<AppNotification> notifications) {
    final query = _searchQuery.trim().toLowerCase();

    var filtered = notifications
        .where((notification) => notification.type != AppNotificationType.chat)
        .toList();

    if (query.isNotEmpty) {
      filtered = filtered.where((notification) {
        final title = notification.title.toLowerCase();
        final subtitle = (notification.subtitle ?? '').toLowerCase();
        final body = notification.body.toLowerCase();

        return title.contains(query) ||
            subtitle.contains(query) ||
            body.contains(query);
      }).toList();
    }

    filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return filtered;
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.arrow_back,
                size: 22,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Notifications',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: titleColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: SizedBox(
        height: 40,
        child: TextField(
          controller: _searchController,
          style: const TextStyle(fontSize: 12.5),
          decoration: InputDecoration(
            hintText: 'Search notifications...',
            hintStyle: const TextStyle(
              fontSize: 12.5,
              color: Colors.grey,
            ),
            prefixIcon: const Icon(
              Icons.search,
              size: 18,
              color: Colors.grey,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.clear,
                      size: 16,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        _searchQuery = '';
                      });
                    },
                  )
                : null,
            filled: true,
            fillColor: const Color(0xFFF7F7F7),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(
                color: Color(0xFFD9D9D9),
                width: 0.8,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(
                color: titleColor,
                width: 1,
              ),
            ),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Expanded(
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12.5,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationList(List<AppNotification> notifications) {
    final filteredNotifications = _applyFilters(notifications);

    if (notifications.isEmpty) {
      return _buildEmptyState('No notifications');
    }

    if (filteredNotifications.isEmpty) {
      return _buildEmptyState('No notifications match your search.');
    }

    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 10, bottom: 20),
        itemCount: filteredNotifications.length,
        itemBuilder: (context, index) {
          final notification = filteredNotifications[index];

          return NotificationListTile(
            notification: notification,
            key: ValueKey(notification.id),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildSearchBar(),
            notificationsAsync.when(
              data: (notifications) => _buildNotificationList(notifications),
              loading: () => const Expanded(
                child: Center(
                  child: LoadingIndicator(),
                ),
              ),
              error: (err, _) => Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Error: $err',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}