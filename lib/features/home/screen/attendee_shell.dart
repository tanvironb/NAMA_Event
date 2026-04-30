import 'package:events_app_trueattempt/features/qr_scanner/screen/qr_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:events_app_trueattempt/features/agenda/screen/agenda_screen.dart';
import 'package:events_app_trueattempt/features/profile/screen/profile_tab_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/core/constants/app_constants.dart';
import 'package:events_app_trueattempt/features/home/screen/widgets/home_dashboard_screen.dart';
import 'package:events_app_trueattempt/features/home/screen/widgets/youtube_live_player.dart';
import 'package:events_app_trueattempt/features/directories/screen/directories_hub_screen.dart';
import 'package:events_app_trueattempt/features/meetings/screen/my_meetings_screen.dart';
import 'package:events_app_trueattempt/features/privacy/screens/privacy_screen.dart';
import 'package:events_app_trueattempt/features/connections/screen/connections_screen.dart';
import 'package:events_app_trueattempt/core/services/notification_services.dart';

class AttendeeShell extends ConsumerStatefulWidget {
  const AttendeeShell({super.key});

  @override
  ConsumerState<AttendeeShell> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<AttendeeShell> {
  int _selectedIndex = 0;
  NotificationService? _notificationService;

  static List<Widget> _widgetOptions(String currentUserId) => <Widget>[
        const HomeDashboardScreen(),
        const AgendaScreen(),
        const DirectoriesHubScreen(),
        const QRHubScreen(),
        const ProfileTabScreen(),
      ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeNotifications();
    });
  }

  Future<void> _initializeNotifications() async {
    if (!mounted) return;

    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user != null) {
      debugPrint('AttendeeShell: Initializing notifications for user ${user.uid}');
      final notificationService = ref.read(notificationServiceProvider(user.uid));

      if (notificationService != null) {
        _notificationService = notificationService;
        await notificationService.initialize();
        debugPrint('AttendeeShell: Notification service initialized successfully');
      } else {
        debugPrint('AttendeeShell: Notification service is null');
      }
    } else {
      debugPrint('AttendeeShell: No authenticated user found');
    }
  }

  @override
  void dispose() {
    _notificationService?.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(activeEventFutureProvider);

    return Scaffold(
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
                    AppConstants.logoCombinationPath,
                    height: 50,
                    color: Colors.white,
                    errorBuilder: (context, error, stackTrace) => Text(
                      AppConstants.appName,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 8),
                  eventAsync.when(
                    data: (event) => Text(
                      event.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: Colors.white70),
                    ),
                    loading: () => Text(
                      'Loading Event...',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: Colors.white70),
                    ),
                    error: (err, stack) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              title: Text(
                'About Event',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('About Event details will be here!'),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(
                Icons.calendar_today_outlined,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              title: Text(
                'My Meetings',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const MyMeetingsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(
                Icons.handshake_outlined,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              title: Text(
                'Connections',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ConnectionsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(
                Icons.privacy_tip_outlined,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              title: Text(
                'Privacy & Settings',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const PrivacyScreen(),
                  ),
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
              final currentUserId =
                  ref.watch(firebaseAuthProvider).currentUser?.uid ?? '';

              return IndexedStack(
                index: _selectedIndex,
                children: _widgetOptions(currentUserId),
              );
            },
          ),
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: YoutubeLivePlayer(),
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
            icon: Icon(Icons.qr_code_scanner),
            activeIcon: Icon(Icons.qr_code_scanner),
            label: 'Scan',
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