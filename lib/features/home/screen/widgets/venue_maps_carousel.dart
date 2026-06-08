// lib/features/home/screen/widgets/venue_maps_carousel.dart

import 'package:card_swiper/card_swiper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class VenueMapsCarousel extends StatelessWidget {
  const VenueMapsCarousel({super.key});

  static const Color primaryBlue = Color(0xFF0D1496);
  static const Color cardGrey = Color(0xFFEFEFEF);

  DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Stream<List<_VenueSessionItem>> _venueMapsStream() {
    return FirebaseFirestore.instance
        .collection('events')
        .where('isActive', isEqualTo: true)
        .limit(1)
        .snapshots()
        .asyncMap((eventSnapshot) async {
      if (eventSnapshot.docs.isEmpty) return <_VenueSessionItem>[];

      final eventDoc = eventSnapshot.docs.first;
      final eventData = eventDoc.data();
      final activeEventId = eventDoc.id;

      final endDate = _toDateTime(eventData['endDate']);

      if (endDate != null && DateTime.now().isAfter(endDate)) {
        return <_VenueSessionItem>[];
      }

      final sessionSnapshot = await FirebaseFirestore.instance
          .collection('sessions')
          .where('eventId', isEqualTo: activeEventId)
          .orderBy('startTime')
          .get();

      final venues = <_VenueSessionItem>[];
      final usedImages = <String>{};

      for (final doc in sessionSnapshot.docs) {
        final data = doc.data();

        final sessionTitle = (data['title'] ?? '').toString().trim();
        final location = (data['location'] ?? '').toString().trim();
        final description = (data['description'] ?? '').toString().trim();

        final imageUrls = <String>[];

        final venueImageUrl =
            (data['venueImageUrl'] ?? '').toString().trim();

        if (venueImageUrl.isNotEmpty) {
          imageUrls.add(venueImageUrl);
        }

        final rawVenueImageUrls = data['venueImageUrls'];
        final rawLocationImages = data['locationImages'];
        final rawImageUrls = data['imageUrls'];

        if (rawVenueImageUrls is List) {
          for (final item in rawVenueImageUrls) {
            final url = item.toString().trim();
            if (url.isNotEmpty) imageUrls.add(url);
          }
        }

        if (rawLocationImages is List) {
          for (final item in rawLocationImages) {
            final url = item.toString().trim();
            if (url.isNotEmpty) imageUrls.add(url);
          }
        }

        if (rawImageUrls is List) {
          for (final item in rawImageUrls) {
            final url = item.toString().trim();
            if (url.isNotEmpty) imageUrls.add(url);
          }
        }

        for (final imageUrl in imageUrls) {
          if (usedImages.contains(imageUrl)) continue;
          usedImages.add(imageUrl);

          venues.add(
            _VenueSessionItem(
              id: '${doc.id}_${venues.length}',
              title: location.isEmpty ? 'Venue' : location,
              description: sessionTitle.isNotEmpty
                  ? sessionTitle
                  : description.isNotEmpty
                      ? description
                      : 'Event venue location',
              imageUrls: [imageUrl],
            ),
          );
        }
      }

      return venues;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      width: double.infinity,
      child: StreamBuilder<List<_VenueSessionItem>>(
        stream: _venueMapsStream(),
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
            autoplayDelay: 4200,
            autoplayDisableOnInteraction: false,
            duration: 650,
            viewportFraction: 1.0,
            scale: 1.0,
            loop: venueMaps.length > 1,
            pagination: venueMaps.length > 1
                ? const SwiperPagination(
                    alignment: Alignment.bottomCenter,
                    margin: EdgeInsets.only(bottom: 7),
                    builder: DotSwiperPaginationBuilder(
                      color: Color(0xFFD7D7D7),
                      activeColor: primaryBlue,
                      size: 5,
                      activeSize: 6,
                      space: 3,
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
      onTap: () => VenueMapsCarousel._openMapPreview(context, venueMap),
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.zero,
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
                placeholder: (context, url) => Container(
                  color: const Color(0xFFF1F3F8),
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: const Color(0xFFF1F3F8),
                  child: const Center(
                    child: Icon(
                      Icons.map_outlined,
                      color: primaryBlue,
                      size: 34,
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withOpacity(0.62),
                      Colors.black.withOpacity(0.18),
                      Colors.black.withOpacity(0.52),
                    ],
                    stops: const [0, 0.56, 1],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 90,
              bottom: 20,
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
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    venueMap.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.92),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 14,
              bottom: 18,
              child: GestureDetector(
                onTap: () => VenueMapsCarousel._openMapPreview(
                  context,
                  venueMap,
                ),
                child: Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  decoration: BoxDecoration(
                    color: primaryBlue,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'View',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context, String text) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardGrey,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: Colors.black.withOpacity(0.55),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  static void _openMapPreview(
    BuildContext context,
    _VenueSessionItem venueMap,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _VenueMapPreviewScreen(
          venueMap: venueMap,
        ),
      ),
    );
  }
}

class _VenueMapPreviewScreen extends StatelessWidget {
  final _VenueSessionItem venueMap;

  const _VenueMapPreviewScreen({
    required this.venueMap,
  });

  static const Color primaryBlue = Color(0xFF0D1496);

  @override
  Widget build(BuildContext context) {
    final imageUrl =
        venueMap.imageUrls.isNotEmpty ? venueMap.imageUrls.first : '';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          venueMap.title.trim().isEmpty ? 'Venue Map' : venueMap.title.trim(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              minScale: 0.7,
              maxScale: 4.0,
              child: Center(
                child: imageUrl.isEmpty
                    ? _buildPlaceholder(context, venueMap)
                    : CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        errorWidget: (context, url, error) =>
                            _buildPlaceholder(context, venueMap),
                      ),
              ),
            ),
          ),
          if (venueMap.description.trim().isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withOpacity(0.12),
                    width: 1,
                  ),
                ),
              ),
              child: Text(
                venueMap.description.trim(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.of(context).pop(),
        child: const Icon(Icons.close),
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