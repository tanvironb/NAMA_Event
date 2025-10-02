// lib/features/home/screen/widgets/venue_maps_carousel.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:card_swiper/card_swiper.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';

class VenueMapsCarousel extends ConsumerWidget {
  const VenueMapsCarousel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // For now, using dummy data. Later this can be connected to a venue maps provider
    final venueMaps = [
      {
        'title': 'Main Conference Hall',
        'description': 'Ground Floor - Keynotes & Main Sessions',
        'imageUrl': 'assets/images/venue_map_1.png', // placeholder
        'floor': 'Ground Floor',
      },
      {
        'title': 'Breakout Rooms',
        'description': 'Second Floor - Workshop Sessions',
        'imageUrl': 'assets/images/venue_map_2.png', // placeholder
        'floor': 'Second Floor',
      },
      {
        'title': 'Exhibition Area',
        'description': 'Ground Floor - Sponsor Booths',
        'imageUrl': 'assets/images/venue_map_3.png', // placeholder
        'floor': 'Ground Floor',
      },
    ];

    return SizedBox(
      height: 200, // Fixed height for the carousel
      child: venueMaps.isEmpty
          ? Center(
              child: Text(
                'No venue maps available.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            )
          : Swiper(
              itemCount: venueMaps.length,
              itemBuilder: (context, index) {
                final venueMap = venueMaps[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8.0),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).colorScheme.surface,
                          Theme.of(context).colorScheme.surface.withOpacity(0.8),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Floor indicator
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.goldenYellow,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              venueMap['floor'] as String,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.darkGray,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Title
                          Text(
                            venueMap['title'] as String,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          // Description
                          Text(
                            venueMap['description'] as String,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          // View map button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  // TODO: Navigate to detailed map view
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Opening ${venueMap['title']} map...'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.map_outlined, size: 16),
                                label: const Text('View Map'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.navyBlue,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              autoplay: true,
              autoplayDelay: 5000, // 5 seconds
              autoplayDisableOnInteraction: false,
              viewportFraction: 0.85,
              scale: 0.9,
              loop: venueMaps.length > 1,
            ),
    );
  }
}