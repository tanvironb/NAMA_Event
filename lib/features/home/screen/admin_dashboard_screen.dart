// lib/features/admin/screen/admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';

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
              // TODO: Implement notification sending UI
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notification sending UI coming soon!')),
              );
            },
          ),
          // Example Admin Action: View Users
          _AdminActionCard(
            icon: Icons.people,
            title: 'Manage Users',
            subtitle: 'View all registered users and their roles.',
            onTap: () {
              // TODO: Navigate to a user management screen
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