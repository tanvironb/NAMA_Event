// lib/features/home/screen/widgets/venue_maps_carousel.dart

import 'package:card_swiper/card_swiper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:flutter/material.dart';

class VenueMapsCarousel extends StatelessWidget {
  const VenueMapsCarousel({super.key});

  static const Color primaryBlue = Color(0xFF0D1496);
  static const Color cardGrey = Color(0xFFEFEFEF);

  Stream<List<_VenueSessionItem>> _venueSessionsStream() {
    return FirebaseFirestore.instance
        .collection('sessions')
        .orderBy('startTime')
        .snapshots()
        .map((snapshot) {
      final venues = <_VenueSessionItem>[];
      final usedImages = <String>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final title = (data['title'] ?? '').toString().trim();
        final location = (data['location'] ?? '').toString().trim();
        final description = (data['description'] ?? '').toString().trim();
        final venueImageUrl = (data['venueImageUrl'] ?? '').toString().trim();

        if (venueImageUrl.isEmpty) continue;

        if (usedImages.contains(venueImageUrl)) continue;
        usedImages.add(venueImageUrl);

        venues.add(
          _VenueSessionItem(
            id: doc.id,
            title: location.isEmpty ? 'Venue' : location,
            description: title.isEmpty
                ? description.isEmpty
                    ? 'Event venue location'
                    : description
                : title,
            imageUrls: [venueImageUrl],
          ),
        );
      }

      return venues;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 135,
      child: StreamBuilder<List<_VenueSessionItem>>(
        stream: _venueSessionsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }

          if (snapshot.hasError) {
            return _emptyState(context, 'Failed to load venue maps');
          }

          final venueMaps = snapshot.data ?? [];

          if (venueMaps.isEmpty) {
            return _emptyState(context, 'No venue maps available.');
          }

          return Swiper(
            itemCount: venueMaps.length,
            autoplay: venueMaps.length > 1,
            autoplayDelay: 5000,
            autoplayDisableOnInteraction: false,
            viewportFraction: 0.82,
            scale: 0.9,
            loop: venueMaps.length > 1,
            pagination: venueMaps.length > 1
                ? const SwiperPagination(
                    margin: EdgeInsets.only(bottom: 2),
                    builder: DotSwiperPaginationBuilder(
                      color: Color(0xFFD7D7D7),
                      activeColor: primaryBlue,
                      size: 6,
                      activeSize: 7,
                    ),
                  )
                : null,
            itemBuilder: (context, index) {
              final venueMap = venueMaps[index];
              return _venueCard(context, venueMap);
            },
          );
        },
      ),
    );
  }

  Widget _venueCard(BuildContext context, _VenueSessionItem venueMap) {
    return GestureDetector(
      onTap: () => VenueMapsCarousel._showMapGallery(context, venueMap),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: cardGrey,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: venueMap.imageUrls.first,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(
                    Icons.map_outlined,
                    color: primaryBlue,
                    size: 34,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.72),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          venueMap.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          venueMap.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: primaryBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'View',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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

  static void _showMapGallery(
    BuildContext context,
    _VenueSessionItem venueMap,
  ) {
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
                          ? const SwiperControl(
                              color: AppColors.goldenYellow,
                            )
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
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                        ),
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

  static Widget _buildPlaceholder(
    BuildContext context,
    _VenueSessionItem venueMap,
  ) {
    return Column(
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
            color: Colors.white,
            fontSize: 18,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _VenueSessionItem {
  final String id;
  final String title;
  final String description;
  final List<String> imageUrls;

  const _VenueSessionItem({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrls,
  });
}