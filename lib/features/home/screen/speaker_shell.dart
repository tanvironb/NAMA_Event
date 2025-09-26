import 'package:flutter/material.dart';
import 'package:events_app_trueattempt/features/agenda/screen/agenda_screen.dart';
import 'package:events_app_trueattempt/features/explore/screen/explore_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/core/constants/app_constants.dart';
import 'package:events_app_trueattempt/features/home/screen/widgets/home_dashboard_screen.dart';
import 'package:events_app_trueattempt/features/home/screen/widgets/youtube_live_player.dart';
import 'package:events_app_trueattempt/features/directories/screen/directories_hub_screen.dart';
import 'package:events_app_trueattempt/core/services/notification_services.dart';
import 'package:events_app_trueattempt/features/notifications/screen/notifications_screen.dart';
// import 'package:events_app_trueattempt/features/profile/screen/speaker_dashboard_screen.dart'; // New speaker dashboard - TODO: Uncomment when created

class SpeakerShell extends ConsumerStatefulWidget {
  const SpeakerShell({super.key});
  
  @override
  ConsumerState<SpeakerShell> createState() => _SpeakerShellState();
}

class _SpeakerShellState extends ConsumerState<SpeakerShell> {
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    const HomeDashboardScreen(),
    const AgendaScreen(),
    const DirectoriesHubScreen(),
    const ExploreScreen(),
    // TODO: Replace with SpeakerDashboardScreen() when created
    const Center(child: Text('Speaker Dashboard Coming Soon')), // Temporary placeholder
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
    final userRepo = ref.read(userProfileRepositoryProvider);
    if (user != null) {
      final notificationService = NotificationService(userRepo, user.uid);
      await notificationService.initialize();
    }
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    // Watch the activeEventProvider to get the event name for the AppBar
    final eventAsync = ref.watch(activeEventFutureProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // Using the combination logo for the AppBar title
            Image.asset(
              AppConstants.logoEmblemPath, // Just the emblem
              height: 30,
              errorBuilder: (context, error, stackTrace) => Text(
                AppConstants.appName,
                style: Theme.of(context).appBarTheme.titleTextStyle,
              ),
            ),
            const SizedBox(width: 8),
            eventAsync.when(
              data: (event) => Text(event.name, style: Theme.of(context).appBarTheme.titleTextStyle),
              loading: () => Text('Loading Event...', style: Theme.of(context).appBarTheme.titleTextStyle),
              error: (err, stack) => Text('Event App', style: Theme.of(context).appBarTheme.titleTextStyle), // Fallback title
            ),
          ],
        ),
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
            // Speaker-specific drawer items could be added here
          ],
        ),
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: _widgetOptions,
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
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'Agenda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Networking',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
