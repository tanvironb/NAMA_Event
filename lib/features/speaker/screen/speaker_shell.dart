import 'package:cached_network_image/cached_network_image.dart';
import 'package:card_swiper/card_swiper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/common_widgets/message_icon_with_badge.dart';
import 'package:events_app_trueattempt/common_widgets/notification_icon_with_badge.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/constants/app_constants.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/core/services/notification_services.dart';

import 'package:events_app_trueattempt/features/agenda/screen/agenda_screen.dart';
import 'package:events_app_trueattempt/features/directories/screen/directories_hub_screen.dart';
import 'package:events_app_trueattempt/features/messaging/screen/conversations_screen.dart';
import 'package:events_app_trueattempt/features/notifications/screen/notifications_screen.dart';
import 'package:events_app_trueattempt/features/profile/screen/profile_tab_screen.dart';
import 'package:events_app_trueattempt/features/profile/screen/user_details_screen.dart';
import 'package:events_app_trueattempt/features/qr_scanner/screen/qr_hub_screen.dart';

import 'package:events_app_trueattempt/features/speaker/screen/my_sessions_screen.dart';
import 'package:events_app_trueattempt/features/speaker/screen/session_feedback_screen.dart';
import 'package:events_app_trueattempt/features/speaker/screen/session_qa_screen.dart';
import 'package:events_app_trueattempt/features/speaker/screen/session_resources_screen.dart';
import 'package:events_app_trueattempt/features/speaker/screen/speaker_analytics_screen.dart';
import 'package:events_app_trueattempt/features/speaker/screen/speaker_audience_screen.dart';

class SpeakerShell extends ConsumerStatefulWidget {
  const SpeakerShell({super.key});

  @override
  ConsumerState<SpeakerShell> createState() => _SpeakerShellState();
}

class _SpeakerShellState extends ConsumerState<SpeakerShell> {
  int _selectedIndex = 0;
  NotificationService? _notificationService;

  late final List<Widget> _widgetOptions = <Widget>[
    const SpeakerHomeQuickActionsPage(),
    const AgendaScreen(),
    const DirectoriesHubScreen(),
    const QRHubScreen(),
    const ProfileTabScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    await Future.delayed(Duration.zero);

    if (!mounted) return;

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
    if (!mounted) return;

    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: const Color(0xFFF5B51B),
        unselectedItemColor: Colors.white,
        backgroundColor: const Color(0xFF1B0F72),
        selectedFontSize: 12,
        unselectedFontSize: 12,
        elevation: 0,
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
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Networking',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            activeIcon: Icon(Icons.qr_code_scanner),
            label: 'QR',
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

class SpeakerHomeQuickActionsPage extends ConsumerWidget {
  const SpeakerHomeQuickActionsPage({super.key});

  static const Color _primaryColor = Color(0xFF1B0F72);
  static const Color _textDark = Color(0xFF202124);
  static const Color _textMuted = Color(0xFF8A8A8A);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userAppProfileStreamProvider).asData?.value;
    final eventAsync = ref.watch(activeEventFutureProvider);
    final remoteConfig = ref.watch(remoteConfigServiceProvider);

    final speakersAsync = ref.watch(featuredSpeakersFutureProvider);
    final venueMapsAsync = ref.watch(venueMapsStreamProvider);
    final sponsorsAsync = ref.watch(sponsorsStreamProvider);

    final eventName = eventAsync.maybeWhen(
      data: (event) => event.name.toString(),
      orElse: () => 'Philanthropy Learning Forum',
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 92),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top logo + message/notification icons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Image.asset(
                  AppConstants.logoEmblemPath,
                  height: 38,
                  width: 38,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.auto_awesome,
                      color: AppColors.namaNavyBlue,
                      size: 34,
                    );
                  },
                ),
                Row(
                  children: [
                    _TopCircleIconButton(
                      child: const MessageIconWithBadge(),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const ConversationsScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    _TopCircleIconButton(
                      child: const NotificationIconWithBadge(),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const NotificationsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 30),

            Text(
              'Hi, ${user?.name ?? 'Speaker'}!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.namaNavyBlue,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              eventName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.namaMediumGray,
                  ),
            ),

            const SizedBox(height: 38),

            _buildSectionTitle(
              icon: Icons.bolt,
              title: 'Speaker Tools',
            ),

            const SizedBox(height: 18),

            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 3.05,
              ),
              children: [
                _QuickActionTile(
                  icon: Icons.calendar_month_outlined,
                  title: 'My Sessions',
                  iconColor: AppColors.namaNavyBlue,
                  backgroundColor: const Color(0xFFEFF3FF),
                  isEnabled: remoteConfig.isSpeakerQRGenerationEnabled,
                  disabledMessage: 'Session management is currently disabled',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const MySessionsScreen(),
                      ),
                    );
                  },
                ),
                _QuickActionTile(
                  icon: Icons.analytics_outlined,
                  title: 'Analytics',
                  iconColor: AppColors.namaGoldenYellow,
                  backgroundColor: const Color(0xFFF5EFFF),
                  isEnabled: remoteConfig.isSpeakerAnalyticsEnabled,
                  disabledMessage: 'Analytics is currently unavailable',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SpeakerAnalyticsScreen(),
                      ),
                    );
                  },
                ),
                _QuickActionTile(
                  icon: Icons.people_outline_rounded,
                  title: 'Audience',
                  iconColor: const Color(0xFF00A676),
                  backgroundColor: const Color(0xFFEFFFF8),
                  isEnabled: remoteConfig.isSpeakerAudienceInsightsEnabled,
                  disabledMessage: 'Audience insights is currently unavailable',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SpeakerAudienceScreen(),
                      ),
                    );
                  },
                ),
                _QuickActionTile(
                  icon: Icons.star_border_rounded,
                  title: 'Feedback',
                  iconColor: AppColors.namaRichGold,
                  backgroundColor: const Color(0xFFFFF7EA),
                  isEnabled: true,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SessionFeedbackScreen(),
                      ),
                    );
                  },
                ),
                _QuickActionTile(
                  icon: Icons.question_answer_outlined,
                  title: 'Q&A',
                  iconColor: AppColors.namaMediumGray,
                  backgroundColor: const Color(0xFFF3F6FA),
                  isEnabled: false,
                  disabledMessage: 'Q&A feature is under development',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SessionQAScreen(),
                      ),
                    );
                  },
                ),
                _QuickActionTile(
                  icon: Icons.folder_outlined,
                  title: 'Resources',
                  iconColor: AppColors.namaMediumGray,
                  backgroundColor: const Color(0xFFF3F6FA),
                  isEnabled: false,
                  disabledMessage: 'Resource management is under development',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SessionResourcesScreen(),
                      ),
                    );
                  },
                ),
                _QuickActionTile(
                  icon: Icons.videocam_outlined,
                  title: 'Go Live',
                  iconColor: AppColors.namaMediumGray,
                  backgroundColor: const Color(0xFFF3F6FA),
                  isEnabled: false,
                  disabledMessage: 'Live broadcast is currently disabled',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Live broadcast is currently disabled'),
                      ),
                    );
                  },
                ),
              ],
            ),

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

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: _primaryColor,
          size: 16,
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
      child: Icon(
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
    return SizedBox(
      height: 150,
      child: venueMapsAsync.when(
        data: (venueMaps) {
          final uniqueVenueImages = <Map<String, dynamic>>[];
          final seenVenueKeys = <String>{};

          for (final venueMap in venueMaps) {
            final venueTitle = venueMap.title.toString().trim();
            final venueKey = venueTitle.toLowerCase();

            if (venueKey.isEmpty || seenVenueKeys.contains(venueKey)) {
              continue;
            }

            if (venueMap.imageUrls.isEmpty) continue;

            final firstImageUrl = venueMap.imageUrls.first.toString().trim();
            if (firstImageUrl.isEmpty) continue;

            seenVenueKeys.add(venueKey);

            uniqueVenueImages.add({
              'url': firstImageUrl,
              'title': venueTitle,
              'description': venueMap.description.toString().trim(),
            });
          }

          if (uniqueVenueImages.isEmpty) {
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
            itemCount: uniqueVenueImages.length,
            viewportFraction: uniqueVenueImages.length > 1 ? 0.86 : 0.92,
            scale: uniqueVenueImages.length > 1 ? 0.92 : 1,
            autoplay: uniqueVenueImages.length > 1,
            autoplayDelay: 4200,
            duration: 650,
            loop: uniqueVenueImages.length > 1,
            pagination: uniqueVenueImages.length > 1
                ? const SwiperPagination(
                    alignment: Alignment.bottomCenter,
                    margin: EdgeInsets.only(bottom: 7),
                    builder: DotSwiperPaginationBuilder(
                      activeColor: _primaryColor,
                      color: Color(0xFFD6D6D6),
                      size: 5,
                      activeSize: 6,
                      space: 3,
                    ),
                  )
                : null,
            itemBuilder: (context, index) {
              final mapData = uniqueVenueImages[index];
              final description = mapData['description'].toString().isNotEmpty
                  ? mapData['description'].toString()
                  : 'Welcome Word';

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
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
                        imageUrl: mapData['url'],
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: const Color(0xFFF1F3F8),
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: const Color(0xFFF1F3F8),
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: _primaryColor,
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
                              mapData['title'],
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
                        child: Container(
                          height: 30,
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          decoration: BoxDecoration(
                            color: _primaryColor,
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
                    ],
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

        return LayoutBuilder(
          builder: (context, constraints) {
            const double spacing = 12;
            const double runSpacing = 18;
            final double itemWidth = (constraints.maxWidth - (spacing * 2)) / 3;

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
                      color: _primaryColor,
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
                        debugPrint('Speaker partner logo failed to load.');
                        debugPrint('Partner name: $name');
                        debugPrint('Partner logoUrl: $cleanLogoUrl');
                        debugPrint('Partner logo error: $error');

                        return const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: _primaryColor,
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
            color: _primaryColor,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _TopCircleIconButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _TopCircleIconButton({
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.08),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color iconColor;
  final Color backgroundColor;
  final bool isEnabled;
  final String? disabledMessage;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.iconColor,
    required this.backgroundColor,
    required this.isEnabled,
    required this.onTap,
    this.disabledMessage,
  });

  @override
  Widget build(BuildContext context) {
    final Color effectiveIconColor =
        isEnabled ? iconColor : AppColors.namaMediumGray.withOpacity(0.45);

    final Color effectiveTextColor = isEnabled
        ? const Color(0xFF202124)
        : AppColors.namaMediumGray.withOpacity(0.55);

    return Material(
      color: isEnabled ? backgroundColor : const Color(0xFFF5F7FB),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: isEnabled
            ? onTap
            : () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text(disabledMessage ?? 'This feature is disabled'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                color: effectiveIconColor,
                size: 21,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: effectiveTextColor,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: effectiveIconColor,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}