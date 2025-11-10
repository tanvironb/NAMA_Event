// lib/features/admin/screen/admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/features/admin/screen/user_management_screen.dart';
import 'package:events_app_trueattempt/features/admin/screen/admin_session_management_screen.dart';
import 'package:events_app_trueattempt/features/admin/screen/send_notification_screen.dart';
import 'package:events_app_trueattempt/features/admin/screen/notification_management_screen.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text('Admin Panel', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          // Example Admin Action: Send Notification
          _AdminActionCard(
            icon: Icons.send,
            title: 'Send Push Notification',
            subtitle: 'Broadcast a message to all attendees.',
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const SendNotificationScreen(),
              ));
            },
          ),
          // Notification Management
          _AdminActionCard(
            icon: Icons.notifications_active,
            title: 'Manage Notifications',
            subtitle: 'View, edit, and delete sent notifications.',
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const NotificationManagementScreen(),
              ));
            },
          ),
          // Example Admin Action: View Users
          _AdminActionCard(
            icon: Icons.people,
            title: 'Manage Users',
            subtitle: 'View all registered users and their roles.',
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const UserManagementScreen(),
              ));
            },
          ),
          // Example Admin Action: Manage Sessions
          _AdminActionCard(
            icon: Icons.event_note,
            title: 'Manage Sessions',
            subtitle: 'View and manage all event sessions.',
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const AdminSessionManagementScreen(),
              ));
            },
          ),
          // Example Admin Action: View Event Stats
          _AdminActionCard(
            icon: Icons.bar_chart,
            title: 'Event Statistics',
            subtitle: 'See check-ins, bookmarks, and engagement.',
            onTap: () {
              // TODO: Navigate to an event statistics screen
            },
          ),
        ],
      ),
    );
  }
}

class _AdminActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AdminActionCard({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}