import 'package:flutter/material.dart';
import 'package:events_app_trueattempt/features/agenda/agenda_screen.dart';
import 'package:events_app_trueattempt/features/explore/explore_screen.dart';
import 'package:events_app_trueattempt/features/profile/profile_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';

// HomeScreen acts as the main container for the bottom navigation bar
// and displays the selected screen.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0; // Current selected tab index

  // List of screens corresponding to the bottom navigation bar items
  static const List<Widget> _widgetOptions = <Widget>[
    AgendaScreen(),
    ExploreScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch the activeEventProvider to get the event name for the AppBar
    final eventAsync = ref.watch(activeEventProvider);

    return Scaffold(
      appBar: AppBar(
        title: eventAsync.when(
          data: (event) => Text((eventAsync.asData?.value.data() as Map<String, dynamic>?)?['name'] ?? 'Event'),
          loading: () => const Text('Loading Event...'),
          error: (err, stack) => const Text('Event App'), // Fallback title
        ),
        // Add a placeholder for the menu icon later for the drawer
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              // TODO: Implement opening the Drawer (Sidebar) in Phase 2/3
              // Scaffold.of(context).openDrawer();
            },
          ),
        ),
        actions: [
          // Placeholder for notification icon
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: Navigate to Notifications screen in Phase 2/3
            },
          ),
        ],
      ),
      // TODO: Implement Drawer (Sidebar) in Phase 2/3
      // drawer: const AppDrawer(), 
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // Ensures all items are visible
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'Agenda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
            label: 'Explore',
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