import 'package:events_app_trueattempt/features/qr_scanner/screen/qr_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:events_app_trueattempt/features/agenda/screen/agenda_screen.dart';
import 'package:events_app_trueattempt/features/profile/screen/profile_tab_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/features/home/screen/widgets/home_dashboard_screen.dart';
import 'package:events_app_trueattempt/features/home/screen/widgets/youtube_live_player.dart';
import 'package:events_app_trueattempt/features/directories/screen/directories_hub_screen.dart';
import 'package:events_app_trueattempt/core/services/notification_services.dart';

class AttendeeShell extends ConsumerStatefulWidget {
  const AttendeeShell({super.key});

  @override
  ConsumerState<AttendeeShell> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<AttendeeShell> {
  int _selectedIndex = 0;
  NotificationService? _notificationService;

  List<Widget> _pages(String currentUserId) => <Widget>[
        HomeDashboardScreen(
          onSeeAllUpcomingSessions: () {
            _onItemTapped(1); // 🔥 switch to Agenda tab
          },
        ),
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
    final user = ref.read(firebaseAuthProvider).currentUser;

    if (user != null) {
      final notificationService =
          ref.read(notificationServiceProvider(user.uid));

      if (notificationService != null) {
        _notificationService = notificationService;
        await notificationService.initialize();
      }
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
    final currentUserId =
        ref.watch(firebaseAuthProvider).currentUser?.uid ?? '';

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: _pages(currentUserId),
          ),
          // const Positioned(
          //   bottom: 0,
          //   left: 0,
          //   right: 0,
          //   child: YoutubeLivePlayer(),
          // ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
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
            label: 'Scan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}