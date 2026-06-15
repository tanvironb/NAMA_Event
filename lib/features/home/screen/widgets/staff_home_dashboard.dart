// lib/features/home/screen/widgets/staff_home_dashboard.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:card_swiper/card_swiper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/core/constants/app_constants.dart';
import 'package:events_app_trueattempt/features/home/screen/widgets/staff_quick_actions.dart';
import 'package:events_app_trueattempt/features/profile/screen/user_details_screen.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/common_widgets/message_icon_with_badge.dart';
import 'package:events_app_trueattempt/common_widgets/notification_icon_with_badge.dart';
import 'package:events_app_trueattempt/features/messaging/screen/conversations_screen.dart';
import 'package:events_app_trueattempt/features/notifications/screen/notifications_screen.dart';

class StaffHomeDashboard extends ConsumerWidget {
  final ValueChanged<int>? onTabSelected;

  const StaffHomeDashboard({
    super.key,
    this.onTabSelected,
  });

  static const Color _primaryColor = AppColors.namaNavyBlue;
  static const Color _textDark = Color(0xFF202124);
  static const Color _textMuted = Color(0xFF8A8A8A);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(activeEventFutureProvider);
    final userAsync = ref.watch(userAppProfileStreamProvider);
    final speakersAsync = ref.watch(featuredSpeakersFutureProvider);
    final venueMapsAsync = ref.watch(venueMapsStreamProvider);
    final sponsorsAsync = ref.watch(sponsorsStreamProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 92),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopIntro(context, userAsync, eventAsync),
            const SizedBox(height: 44),
            _buildSectionTitle(
              icon: Icons.bolt_rounded,
              title: 'Quick Actions',
            ),
            const SizedBox(height: 16),
            StaffQuickActions(onTabSelected: onTabSelected),
            const SizedBox(height: 42),
            _buildSectionTitle(
              icon: Icons.mic_rounded,
              title: 'Featured Speakers',
            ),
            const SizedBox(height: 16),
            _buildFeaturedSpeakers(context, speakersAsync),
            const SizedBox(height: 42),
            _buildSectionTitle(
              icon: Icons.map_outlined,
              title: 'Venue Maps',
            ),
            const SizedBox(height: 16),
            _buildVenueMaps(context, venueMapsAsync),
            const SizedBox(height: 42),
            _buildSectionTitle(
              icon: Icons.handshake_outlined,
              title: 'Our Partners',
            ),
            const SizedBox(height: 18),
            _buildPartners(context, sponsorsAsync),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTopIntro(
    BuildContext context,
    AsyncValue<dynamic> userAsync,
    AsyncValue<dynamic> eventAsync,
  ) {
    final userName = userAsync.maybeWhen(
      data: (user) {
        final name = user?.name?.toString().trim() ?? '';
        if (name.isEmpty) return 'Staff';
        return name.split(' ').first;
      },
      orElse: () => 'Staff',
    );

    final eventName = eventAsync.maybeWhen(
      data: (event) => event.name.toString(),
      orElse: () => 'Explore our events',
    );

    final eventDate = eventAsync.maybeWhen(
      data: (event) {
        final DateTime startDate = event.startDate;
        final DateTime endDate = event.endDate;

        final bool sameDay = startDate.year == endDate.year &&
            startDate.month == endDate.month &&
            startDate.day == endDate.day;

        if (sameDay) {
          return DateFormat('EEEE, MMM d, yyyy').format(startDate);
        }

        final bool sameYear = startDate.year == endDate.year;

        if (sameYear) {
          return '${DateFormat('MMM d').format(startDate)} - ${DateFormat('MMM d, yyyy').format(endDate)}';
        }

        return '${DateFormat('MMM d, yyyy').format(startDate)} - ${DateFormat('MMM d, yyyy').format(endDate)}';
      },
      orElse: () => '',
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        children: [
          Row(
            children: [
              Image.asset(
                AppConstants.logoEmblemPath,
                height: 68,
                width: 68,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) {
                  return const Icon(
                    Icons.circle,
                    color: AppColors.namaNavyBlue,
                    size: 46,
                  );
                },
              ),
              const Spacer(),
              _TopIconButton(
                child: const MessageIconWithBadge(),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ConversationsScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              _TopIconButton(
                child: const NotificationIconWithBadge(),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 26),
          Align(
            alignment: Alignment.centerLeft,
            child: RichText(
              text: TextSpan(
                children: [
                  const TextSpan(
                    text: 'Hi, ',
                    style: TextStyle(
                      color: AppColors.namaNavyBlue,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  TextSpan(
                    text: '$userName!',
                    style: const TextStyle(
                      color: AppColors.namaGoldenYellow,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              eventName,
              style: const TextStyle(
                color: _textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (eventDate.isNotEmpty) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                eventDate,
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.namaGoldenYellow,
            size: 17,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: _textDark,
              fontSize: 19.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedSpeakers(
    BuildContext context,
    AsyncValue<List<dynamic>> speakersAsync,
  ) {
    return SizedBox(
      height: 235,
      child: speakersAsync.when(
        data: (speakers) {
          if (speakers.isEmpty) {
            return const Center(
              child: Text(
                'No featured speakers yet.',
                style: TextStyle(
                  color: _textMuted,
                  fontSize: 12,
                ),
              ),
            );
          }

          return Swiper(
            itemCount: speakers.length,
            viewportFraction: 0.54,
            scale: 0.88,
            autoplay: speakers.length > 1,
            autoplayDelay: 4500,
            duration: 650,
            loop: speakers.length > 1,
            itemBuilder: (context, index) {
              final speaker = speakers[index];

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserDetailsScreen(userId: speaker.uid),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.13),
                        blurRadius: 11,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        speaker.profileImageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: speaker.profileImageUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  color: AppColors.avatarPlaceholder,
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                                errorWidget: (_, __, ___) =>
                                    _speakerFallback(),
                              )
                            : _speakerFallback(),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.32),
                                Colors.black.withOpacity(0.76),
                              ],
                              stops: const [0.45, 0.73, 1],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 15,
                          right: 15,
                          bottom: 15,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                speaker.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                speaker.title,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: LoadingIndicator()),
        error: (err, stack) => Center(
          child: Text(
            'Error loading speakers.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _speakerFallback() {
    return Container(
      color: AppColors.avatarPlaceholder,
      child: const Icon(
        Icons.person,
        size: 58,
        color: AppColors.avatarPlaceholderText,
      ),
    );
  }

  Widget _buildVenueMaps(
    BuildContext context,
    AsyncValue<List<dynamic>> venueMapsAsync,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: SizedBox(
        height: 150,
        width: double.infinity,
        child: venueMapsAsync.when(
          data: (venueMaps) {
            final allVenueImages = <Map<String, dynamic>>[];
            final seenImageUrls = <String>{};

            for (final venueMap in venueMaps) {
              final venueTitle = venueMap.title.toString().trim();
              final venueDescription = venueMap.description.toString().trim();

              for (final rawImageUrl in venueMap.imageUrls) {
                final imageUrl = rawImageUrl.toString().trim();

                if (imageUrl.isEmpty) continue;

                if (seenImageUrls.contains(imageUrl)) continue;
                seenImageUrls.add(imageUrl);

                allVenueImages.add({
                  'url': imageUrl,
                  'title': venueTitle.isEmpty ? 'Venue' : venueTitle,
                  'description': venueDescription.isEmpty
                      ? 'Venue details'
                      : venueDescription,
                });
              }
            }

            if (allVenueImages.isEmpty) {
              return const Center(
                child: Text(
                  'No venue maps available.',
                  style: TextStyle(
                    color: _textMuted,
                    fontSize: 12,
                  ),
                ),
              );
            }

            return Swiper(
              itemCount: allVenueImages.length,
              viewportFraction: 1.0,
              scale: 1.0,
              autoplay: allVenueImages.length > 1,
              autoplayDelay: 4200,
              autoplayDisableOnInteraction: false,
              duration: 650,
              loop: allVenueImages.length > 1,
              pagination: allVenueImages.length > 1
                  ? const SwiperPagination(
                      alignment: Alignment.bottomCenter,
                      margin: EdgeInsets.only(bottom: 7),
                      builder: DotSwiperPaginationBuilder(
                        activeColor: AppColors.namaGoldenYellow,
                        color: Color(0xFFD6D6D6),
                        size: 5,
                        activeSize: 6,
                        space: 3,
                      ),
                    )
                  : null,
              itemBuilder: (context, index) {
                final mapData = allVenueImages[index];

                final imageUrl = mapData['url'].toString();
                final title = mapData['title'].toString();
                final description = mapData['description'].toString();

                return GestureDetector(
                  onTap: () {
                    _openVenueImagePreview(
                      context: context,
                      imageUrl: imageUrl,
                      title: title,
                      description: description,
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    margin: EdgeInsets.zero,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.09),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            imageUrl: imageUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: const Color(0xFFF1F3F8),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: const Color(0xFFF1F3F8),
                              child: const Icon(
                                Icons.broken_image_outlined,
                                color: AppColors.namaNavyBlue,
                              ),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Colors.black.withOpacity(0.58),
                                  Colors.black.withOpacity(0.18),
                                  Colors.black.withOpacity(0.50),
                                ],
                                stops: const [0, 0.55, 1],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 18,
                            right: 88,
                            bottom: 20,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  description,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.92),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            right: 14,
                            bottom: 18,
                            child: GestureDetector(
                              onTap: () {
                                _openVenueImagePreview(
                                  context: context,
                                  imageUrl: imageUrl,
                                  title: title,
                                  description: description,
                                );
                              },
                              child: Container(
                                height: 30,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.namaGoldenYellow,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                alignment: Alignment.center,
                                child: const Text(
                                  'View',
                                  style: TextStyle(
                                    color: AppColors.namaNavyBlue,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: LoadingIndicator()),
          error: (err, stack) => Center(
            child: Text(
              'Error loading venue maps.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openVenueImagePreview({
    required BuildContext context,
    required String imageUrl,
    required String title,
    required String description,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _VenueImagePreviewScreen(
          imageUrl: imageUrl,
          title: title,
          description: description,
        ),
      ),
    );
  }

  Widget _buildPartners(
    BuildContext context,
    AsyncValue<List<dynamic>> sponsorsAsync,
  ) {
    return sponsorsAsync.when(
      data: (sponsors) {
        if (sponsors.isEmpty) {
          return const SizedBox(
            height: 110,
            child: Center(
              child: Text(
                'No partners yet.',
                style: TextStyle(
                  color: _textMuted,
                  fontSize: 12,
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const double spacing = 12;
              const double runSpacing = 18;
              final double itemWidth =
                  (constraints.maxWidth - (spacing * 2)) / 3;

              return Wrap(
                alignment: WrapAlignment.center,
                runAlignment: WrapAlignment.center,
                spacing: spacing,
                runSpacing: runSpacing,
                children: sponsors.map((sponsor) {
                  return SizedBox(
                    width: itemWidth,
                    child: _partnerItem(
                      name: sponsor.name.toString(),
                      logoUrl: sponsor.logoUrl.toString(),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        );
      },
      loading: () => const SizedBox(
        height: 110,
        child: Center(child: LoadingIndicator()),
      ),
      error: (err, stack) => SizedBox(
        height: 110,
        child: Center(
          child: Text(
            'Error loading partners.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _partnerItem({
    required String name,
    required String logoUrl,
  }) {
    final cleanLogoUrl = logoUrl.trim();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 72,
          width: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(
            child: cleanLogoUrl.isEmpty
                ? const Center(
                    child: Icon(
                      Icons.handshake_outlined,
                      color: AppColors.namaNavyBlue,
                      size: 30,
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(10),
                    child: Image.network(
                      cleanLogoUrl,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;

                        return const Center(
                          child: SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint('Staff partner logo failed to load.');
                        debugPrint('Partner name: $name');
                        debugPrint('Partner logoUrl: $cleanLogoUrl');
                        debugPrint('Partner logo error: $error');

                        return const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.namaNavyBlue,
                            size: 28,
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          name.trim().isEmpty ? 'Partner' : name.trim(),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.namaNavyBlue,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _VenueImagePreviewScreen extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String description;

  const _VenueImagePreviewScreen({
    required this.imageUrl,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          title.trim().isEmpty ? 'Venue Map' : title.trim(),
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
              maxScale: 4,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  errorWidget: (_, __, ___) => const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white,
                      size: 54,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (description.trim().isNotEmpty)
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
                description.trim(),
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
        backgroundColor: AppColors.namaGoldenYellow,
        foregroundColor: AppColors.namaNavyBlue,
        onPressed: () => Navigator.of(context).pop(),
        child: const Icon(Icons.close),
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _TopIconButton({
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 7,
      shadowColor: Colors.black.withOpacity(0.12),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          height: 40,
          width: 40,
          child: Center(child: child),
        ),
      ),
    );
  }
}