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
import 'package:events_app_trueattempt/common_widgets/message_icon_with_badge.dart';
import 'package:events_app_trueattempt/common_widgets/notification_icon_with_badge.dart';
import 'package:events_app_trueattempt/features/qr_scanner/screen/qr_hub_screen.dart';
import 'package:events_app_trueattempt/features/admin/screen/admin_dashboard_screen.dart';
import 'package:events_app_trueattempt/features/admin/screen/admin_session_management_screen.dart';
import 'package:events_app_trueattempt/features/privacy/screens/privacy_screen.dart';
import 'package:events_app_trueattempt/features/connections/screen/connections_screen.dart';
import 'package:events_app_trueattempt/core/services/notification_services.dart';

class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});
  
  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  int _selectedIndex = 0;
  NotificationService? _notificationService;

  static List<Widget> _widgetOptions(String currentUserId) => <Widget>[
    const AdminDashboardScreen(), // Admin Dashboard with quick actions
    const AgendaScreen(), // Can still view the agenda
    const DirectoriesHubScreen(), // Can still network
    const QRHubScreen(), // QR Scanner and My QR
    const ProfileTabScreen(), // Profile
  ];

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to ensure providers are ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeNotifications();
    });
  }

  Future<void> _initializeNotifications() async {
    if (!mounted) return;
    
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user != null) {
      debugPrint('AdminShell: Initializing notifications for user ${user.uid}');
      final notificationService = ref.read(notificationServiceProvider(user.uid));
      if (notificationService != null) {
        _notificationService = notificationService;
        await notificationService.initialize();
        debugPrint('AdminShell: Notification service initialized successfully');
      } else {
        debugPrint('AdminShell: Notification service is null');
      }
    } else {
      debugPrint('AdminShell: No authenticated user found');
    }
  }

  @override
  void dispose() {
    _notificationService?.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    // Watch the activeEventProvider to get the event name for the AppBar
    final eventAsync = ref.watch(activeEventFutureProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              AppConstants.logoEmblemPath,
              height: 30,
              errorBuilder: (context, error, stackTrace) => Text(
                AppConstants.appName,
                style: Theme.of(context).appBarTheme.titleTextStyle,
              ),
            ),
          ],
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
            icon: const MessageIconWithBadge(),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const ConversationsScreen(),
              ));
            },
          ),
          IconButton(
            icon: const NotificationIconWithBadge(),
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
              leading: Icon(Icons.event_note_outlined, color: Theme.of(context).colorScheme.onSurface),
              title: Text('Manage Sessions', style: Theme.of(context).textTheme.titleMedium),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const AdminSessionManagementScreen(),
                ));
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
              leading: Icon(Icons.handshake_outlined, color: Theme.of(context).colorScheme.onSurface),
              title: Text('Connections', style: Theme.of(context).textTheme.titleMedium),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const ConnectionsScreen(),
                ));
              },
            ),
            ListTile(
              leading: Icon(Icons.privacy_tip_outlined, color: Theme.of(context).colorScheme.onSurface),
              title: Text('Privacy & Settings', style: Theme.of(context).textTheme.titleMedium),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const PrivacyScreen(),
                ));
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
            label: 'Admin',
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
            icon: Icon(Icons.qr_code_scanner),
            activeIcon: Icon(Icons.qr_code_scanner),
            label: 'QR',
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
