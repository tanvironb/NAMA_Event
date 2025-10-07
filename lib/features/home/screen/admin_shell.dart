import 'package:flutter/material.dart';
import 'package:events_app_trueattempt/features/agenda/screen/agenda_screen.dart';
import 'package:events_app_trueattempt/features/profile/screen/profile_tab_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/core/constants/app_constants.dart';
import 'package:events_app_trueattempt/features/home/screen/widgets/youtube_live_player.dart';
import 'package:events_app_trueattempt/features/directories/screen/directories_hub_screen.dart';
import 'package:events_app_trueattempt/features/notifications/screen/notifications_screen.dart';
import 'package:events_app_trueattempt/features/messaging/screen/conversations_screen.dart';
// import 'package:events_app_trueattempt/features/admin/screen/admin_dashboard_screen.dart'; // New admin dashboard - TODO: Uncomment when created

class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});
  
  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  int _selectedIndex = 0;

  static List<Widget> _widgetOptions(String currentUserId) => <Widget>[
    // TODO: Replace with AdminDashboardScreen() when created
    const Center(child: Text('Admin Dashboard Coming Soon')), // Temporary placeholder
    const AgendaScreen(), // Can still view the agenda
    const DirectoriesHubScreen(), // Can still network
    const ProfileTabScreen(), // Updated to use ProfileTabScreen
  ];

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    // Wait for the widget to be built before accessing providers
    await Future.delayed(Duration.zero);
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user != null) {
      final notificationService = ref.read(notificationServiceProvider(user.uid));
      if (notificationService != null) {
        await notificationService.initialize();
      }
    }
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    // Watch the activeEventProvider to get the event name for the AppBar
    final eventAsync = ref.watch(activeEventFutureProvider);

    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Image.asset(
            AppConstants.logoEmblemPath, // Just the emblem
            height: 30,
            errorBuilder: (context, error, stackTrace) => Text(
              AppConstants.appName,
              style: Theme.of(context).appBarTheme.titleTextStyle,
            ),
          ),
        ),
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              Scaffold.of(context).openDrawer(); // Open the drawer
            },
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.message_outlined),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const ConversationsScreen(),
              ));
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const NotificationsScreen(),
              ));
            },
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: Theme.of(context).colorScheme.surface,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    AppConstants.logoCombinationPath, // Combination logo for the drawer header
                    height: 50,
                    color: Colors.white, // Assuming the logo itself might need recoloring if it's not white
                    errorBuilder: (context, error, stackTrace) => Text(
                      AppConstants.appName,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 8),
                  eventAsync.when(
                    data: (event) => Text(
                      event.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70),
                    ),
                    loading: () => Text(
                      'Loading Event...',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70),
                    ),
                    error: (err, stack) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.admin_panel_settings, color: Theme.of(context).colorScheme.onSurface),
              title: Text('Admin Settings', style: Theme.of(context).textTheme.titleMedium),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Admin Settings coming soon!')),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.analytics_outlined, color: Theme.of(context).colorScheme.onSurface),
              title: Text('Analytics', style: Theme.of(context).textTheme.titleMedium),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Analytics coming soon!')),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.info_outline, color: Theme.of(context).colorScheme.onSurface),
              title: Text('About Event', style: Theme.of(context).textTheme.titleMedium),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('About Event details will be here!')),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.settings_outlined, color: Theme.of(context).colorScheme.onSurface),
              title: Text('Settings', style: Theme.of(context).textTheme.titleMedium),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings page is coming soon!')),
                );
              },
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Consumer(
            builder: (context, ref, child) {
              final currentUserId = ref.watch(firebaseAuthProvider).currentUser?.uid ?? '';
              return IndexedStack(
                index: _selectedIndex,
                children: _widgetOptions(currentUserId),
              );
            },
          ),
          // YouTube Live Player positioned at the bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: const YoutubeLivePlayer(),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.admin_panel_settings_outlined),
            activeIcon: Icon(Icons.admin_panel_settings),
            label: 'Admin Panel',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'Agenda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Network',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
