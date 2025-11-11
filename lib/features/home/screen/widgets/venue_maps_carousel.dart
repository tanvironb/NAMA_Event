// lib/features/home/screen/widgets/venue_maps_carousel.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:card_swiper/card_swiper.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:cached_network_image/cached_network_image.dart';

class VenueMapsCarousel extends ConsumerWidget {
  const VenueMapsCarousel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venueMapsAsync = ref.watch(venueMapsStreamProvider);

    return venueMapsAsync.when(
      data: (venueMaps) {
        if (venueMaps.isEmpty) {
          return SizedBox(
            height: 200,
            child: Center(
              child: Text(
                'No venue maps available.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
          );
        }

        return SizedBox(
          height: 200,
          child: Swiper(
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
                              venueMap.floor,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.darkGray,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Title
                          Text(
                            venueMap.title,
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
                            venueMap.description,
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
                                  VenueMapsCarousel._showMapGallery(context, venueMap);
                                },
                                icon: Icon(
                                  venueMap.imageUrls.length > 1
                                      ? Icons.photo_library_outlined
                                      : Icons.map_outlined,
                                  size: 16,
                                ),
                                label: Text(
                                  venueMap.imageUrls.length > 1
                                      ? 'View Maps (${venueMap.imageUrls.length})'
                                      : 'View Map',
                                ),
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
      },
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'Failed to load venue maps',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ),
    );
  }

  // Show image gallery with swipeable, zoomable maps
  static void _showMapGallery(BuildContext context, venueMap) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            // Image gallery with swiper
            Center(
              child: venueMap.imageUrls.isEmpty
                  ? _buildPlaceholder(context, venueMap)
                  : Swiper(
                      itemCount: venueMap.imageUrls.length,
                      pagination: venueMap.imageUrls.length > 1
                          ? const SwiperPagination(
                              builder: DotSwiperPaginationBuilder(
                                color: Colors.white30,
                                activeColor: AppColors.goldenYellow,
                              ),
                            )
                          : null,
                      control: venueMap.imageUrls.length > 1
                          ? const SwiperControl(color: AppColors.goldenYellow)
                          : null,
                      itemBuilder: (context, index) {
                        return InteractiveViewer(
                          minScale: 0.5,
                          maxScale: 4.0,
                          child: Center(
                            child: CachedNetworkImage(
                              imageUrl: venueMap.imageUrls[index],
                              fit: BoxFit.contain,
                              placeholder: (context, url) => const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.goldenYellow,
                                ),
                              ),
                              errorWidget: (context, url, error) =>
                                  _buildPlaceholder(context, venueMap),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            // Header with title and close button
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black87,
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              venueMap.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              venueMap.floor,
                              style: const TextStyle(
                                color: AppColors.goldenYellow,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Material(
                        color: Colors.white24,
                        shape: const CircleBorder(),
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildPlaceholder(BuildContext context, venueMap) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.map_outlined,
            size: 64,
            color: Colors.white54,
          ),
          const SizedBox(height: 16),
          Text(
            venueMap.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            venueMap.description,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'Map images coming soon',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white54,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}