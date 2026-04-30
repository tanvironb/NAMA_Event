// lib/features/home/screen/widgets/venue_maps_carousel.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:card_swiper/card_swiper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/providers.dart';

class VenueMapsCarousel extends ConsumerWidget {
  const VenueMapsCarousel({super.key});

  static const Color primaryBlue = Color(0xFF0D1496);
  static const Color cardGrey = Color(0xFFEFEFEF);
  static const Color gold = Color(0xFFF2C94C);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venueMapsAsync = ref.watch(venueMapsStreamProvider);

    return SizedBox(
      height: 115,
      child: venueMapsAsync.when(
        data: (venueMaps) {
          if (venueMaps.isEmpty) {
            return _emptyState(context, 'No venue maps available.');
          }

          return Swiper(
            itemCount: venueMaps.length,
            autoplay: venueMaps.length > 1,
            autoplayDelay: 5000,
            autoplayDisableOnInteraction: false,
            viewportFraction: 0.75,
            scale: 0.9,
            loop: venueMaps.length > 1,
            itemBuilder: (context, index) {
              final venueMap = venueMaps[index];
              return _venueCard(context, venueMap);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _emptyState(context, 'Failed to load venue maps'),
      ),
    );
  }

  Widget _venueCard(BuildContext context, dynamic venueMap) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardGrey,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.14),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 130,
            height: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: venueMap.imageUrls.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: CachedNetworkImage(
                      imageUrl: venueMap.imageUrls.first,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      errorWidget: (context, url, error) => const Icon(
                        Icons.map_outlined,
                        color: primaryBlue,
                        size: 34,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.map_outlined,
                    color: primaryBlue,
                    size: 34,
                  ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  venueMap.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  venueMap.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.55),
                    fontSize: 10,
                  ),
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.bottomRight,
                  child: GestureDetector(
                    onTap: () => VenueMapsCarousel._showMapGallery(context, venueMap),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        venueMap.imageUrls.length > 1
                            ? 'Maps (${venueMap.imageUrls.length})'
                            : 'Map',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context, String text) {
    return Center(
      child: Text(
        text,
        style: TextStyle(
          color: Colors.black.withOpacity(0.55),
          fontSize: 13,
        ),
      ),
    );
  }

  static void _showMapGallery(BuildContext context, venueMap) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
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
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          venueMap.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.map_outlined, size: 64, color: Colors.white54),
        const SizedBox(height: 16),
        Text(
          venueMap.title,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}