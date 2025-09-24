import 'package:flutter/material.dart';
import 'package:events_app_trueattempt/features/agenda/screen/agenda_screen.dart';
import 'package:events_app_trueattempt/features/explore/screen/explore_screen.dart';
import 'package:events_app_trueattempt/features/profile/screen/profile_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/core/constants/app_constants.dart';
import 'package:events_app_trueattempt/features/home/screen/widgets/speaker_carousel.dart';
import 'package:events_app_trueattempt/features/home/screen/widgets/partner_carousel.dart';
import 'package:events_app_trueattempt/features/home/screen/widgets/quick_action_grid.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart'; // Ensure this path is correct

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    _HomeDashboardScreen(), // Our new dynamic home dashboard
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifications are coming in Phase 2!')),
              );
              // TODO: Navigate to Notifications screen in Phase 2/3
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
            // TODO: Add more drawer items for other features in later phases (e.g., Leaderboard, Support)
          ],
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
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

// This is the actual dynamic Home Dashboard content screen.
class _HomeDashboardScreen extends ConsumerWidget {
  const _HomeDashboardScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(activeEventFutureProvider); // Assuming you want event details on dashboard
    
    // Placeholder for Announcement/Highlight Card (Phase 2)
    final announcementCard = Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Theme.of(context).colorScheme.primary.withOpacity(0.05), // Light background
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.campaign_outlined, color: Theme.of(context).colorScheme.secondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Session A starts in 10 minutes! Join now.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
          ],
        ),
      ),
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event Header Section
          Container(
            padding: const EdgeInsets.all(24.0),
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primary.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              // Optional: Add some wave/abstract shape like in the website screenshot
            ),
            child: eventAsync.when(
              data: (event) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.name,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppColors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${DateFormat('MMM dd').format(event.startDate)} - ${DateFormat('MMM dd, yyyy').format(event.endDate)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.white.withOpacity(0.8)),
                  ),
                  Text(
                    event.location,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.white.withOpacity(0.8)),
                  ),
                ],
              ),
              loading: () => const LoadingIndicator(), // White spinner on dark background
              error: (err, stack) => Text('Failed to load event data.', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          ),
          const SizedBox(height: 24),

          // Featured Speakers Carousel (Phase 2)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('Featured Speakers', style: Theme.of(context).textTheme.headlineSmall),
          ),
          const SizedBox(height: 12),
          const SpeakerCarousel(), // Custom widget for speakers (Phase 2)
          const SizedBox(height: 24),

          // Event Partners/Sponsors Carousel
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('Our Partners', style: Theme.of(context).textTheme.headlineSmall),
          ),
          const SizedBox(height: 12),
          const PartnerCarousel(), // Custom widget for partners
          const SizedBox(height: 24),

          // Quick Action Buttons (Phase 2)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('Quick Actions', style: Theme.of(context).textTheme.headlineSmall),
          ),
          const SizedBox(height: 12),
          const QuickActionGrid(), // Custom widget for action buttons
          const SizedBox(height: 24),

          // Announcement / Highlight Card (Phase 2)
          announcementCard,
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}