import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/features/home/screen/widgets/speaker_carousel.dart';
import 'package:events_app_trueattempt/features/home/screen/widgets/partner_carousel.dart';
import 'package:events_app_trueattempt/features/home/screen/widgets/quick_action_grid.dart';
import 'package:events_app_trueattempt/features/home/screen/widgets/live_stream_card.dart';
import 'package:events_app_trueattempt/features/home/screen/widgets/venue_maps_carousel.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';

/// Staff Home Dashboard - Identical to HomeDashboardScreen but separate for testing
/// This allows you to test UI changes on staff users without affecting attendees
class StaffHomeDashboard extends ConsumerWidget {
  const StaffHomeDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(activeEventFutureProvider);
    final activeLiveSessionAsync = ref.watch(activeLiveSessionProvider);
    
    // Smart announcement card that adapts based on current state
    final announcementCard = activeLiveSessionAsync.when(
      data: (liveSession) {
        if (liveSession != null) {
          // Show live session announcement
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.red.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.live_tv, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '🔴 ${liveSession.title} is LIVE now!',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 16, color: Colors.red.withOpacity(0.6)),
                ],
              ),
            ),
          );
        } else {
          // Show default announcement
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.campaign_outlined, color: Theme.of(context).colorScheme.secondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Welcome to the event! Check out the agenda for upcoming sessions.',
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
        }
      },
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.campaign_outlined, color: Theme.of(context).colorScheme.secondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Welcome to the event! Check out the agenda for upcoming sessions.',
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
              loading: () => const LoadingIndicator(),
              error: (err, stack) => Text('Failed to load event data.', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          ),
          
          // Live Stream Card - Auto-detects and shows active live sessions
          const LiveStreamCard(),
          
          const SizedBox(height: 24),

          // Featured Speakers Carousel
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('Featured Speakers', style: Theme.of(context).textTheme.headlineSmall),
          ),
          const SizedBox(height: 12),
          const SpeakerCarousel(),
          const SizedBox(height: 24),

          // Venue Maps Carousel
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('Venue Maps', style: Theme.of(context).textTheme.headlineSmall),
          ),
          const SizedBox(height: 12),
          const VenueMapsCarousel(),
          const SizedBox(height: 24),

          // Event Partners/Sponsors Carousel
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('Our Partners', style: Theme.of(context).textTheme.headlineSmall),
          ),
          const SizedBox(height: 12),
          const PartnerCarousel(),
          const SizedBox(height: 24),

          // Quick Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('Quick Actions', style: Theme.of(context).textTheme.headlineSmall),
          ),
          const SizedBox(height: 12),
          const QuickActionGrid(),
          const SizedBox(height: 24),

          // Announcement / Highlight Card
          announcementCard,
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
