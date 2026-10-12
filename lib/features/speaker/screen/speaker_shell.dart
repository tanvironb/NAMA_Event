// lib/features/speaker/screen/speaker_shell.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
import 'package:events_app_trueattempt/features/chat/screen/speaker_moderator_room_screen.dart';
import 'package:events_app_trueattempt/features/directories/screen/directories_hub_screen.dart';
import 'package:events_app_trueattempt/features/messaging/screen/conversations_screen.dart';
import 'package:events_app_trueattempt/features/notifications/screen/notifications_screen.dart';
import 'package:events_app_trueattempt/features/profile/screen/profile_tab_screen.dart';
import 'package:events_app_trueattempt/features/profile/screen/user_details_screen.dart';
import 'package:events_app_trueattempt/features/qr_scanner/screen/qr_hub_screen.dart';
import 'package:events_app_trueattempt/features/speaker/screen/my_sessions_screen.dart';
import 'package:events_app_trueattempt/features/speaker/screen/session_feedback_screen.dart';
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
  List<Widget> _widgetOptions() => const <Widget>[
        SpeakerHomeQuickActionsPage(),
        AgendaScreen(),
        DirectoriesHubScreen(),
        QRHubScreen(),
        ProfileTabScreen(),
      ];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeNotifications();
    });
  }
  Future<void> _initializeNotifications() async {
    if (!mounted) return;
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user != null) {
      final notificationService = ref.read(
        notificationServiceProvider(user.uid),
      );
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
    final pages = _widgetOptions();
    if (index < 0 || index >= pages.length) return;
    setState(() {
      _selectedIndex = index;
    });
  }
  @override
  Widget build(BuildContext context) {
    final pages = _widgetOptions();
    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: AppColors.namaGoldenYellow,
        unselectedItemColor: Colors.white,
        backgroundColor: AppColors.namaNavyBlue,
        selectedFontSize: 11,
        unselectedFontSize: 11,
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
  static const Color _textDark = Color(0xFF202124);
  static const Color _textMuted = Color(0xFF8A8A8A);
    Future<void> _markSpeakerRoomNotificationsAsRead(WidgetRef ref, String eventId) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;
    final firestore = ref.read(firestoreProvider);
    final notificationsRef = firestore.collection('users').doc(user.uid).collection('notifications');
    final snapshot = await notificationsRef.where('eventId', isEqualTo: eventId).where('isRead', isEqualTo: false).get();
    if (snapshot.docs.isEmpty) return;
    final batch = firestore.batch();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final type = (data['type'] ?? '').toString().toLowerCase();
      final title = (data['title'] ?? '').toString().toLowerCase();
      final subtitle = (data['subtitle'] ?? '').toString().toLowerCase();
      final body = (data['body'] ?? data['message'] ?? '').toString().toLowerCase();
      final notificationCategory = data['data'] is Map ? ((data['data'] as Map)['notificationCategory'] ?? '').toString().toLowerCase() : '';
      final isSpeakerRoomNotification = type.contains('speakermoderatorroom') || notificationCategory.contains('speakermoderatorroom') || title.contains('speaker room') || title.contains('speaker & moderator') || subtitle.contains('speaker & moderator') || body.contains('speaker & moderator room');
      if (isSpeakerRoomNotification) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
    }
    await batch.commit();
  }
@override
Widget build(BuildContext context, WidgetRef ref) {
  final user = ref.watch(userAppProfileStreamProvider).asData?.value;
  final eventAsync = ref.watch(activeEventFutureProvider);
  final remoteConfig = ref.watch(remoteConfigServiceProvider);
  final speakersAsync = ref.watch(featuredSpeakersFutureProvider);
  final venueMapsAsync = ref.watch(venueMapsStreamProvider);
  final sponsorsAsync = ref.watch(sponsorsStreamProvider);
  final hasUnreadSpeakerRoom = ref.watch(unreadSpeakerRoomNotificationsProvider).maybeWhen(data: (value) => value, orElse: () => false);
  final eventName = eventAsync.when(data: (event) => event.name.toString(), loading: () => 'Loading event...', error: (_, __) => 'Assigned event unavailable');
  final userName = (user?.name ?? 'Speaker').toString().trim().isEmpty ? 'Speaker' : (user?.name ?? 'Speaker').toString().trim().split(' ').first;
  return SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 92),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopBar(context),
          const SizedBox(height: 30),
          _buildWelcomeText(context, userName, eventName),
          if (eventAsync.hasError) ...[
            const SizedBox(height: 10),
            _buildEventErrorBox(context),
          ],
          const SizedBox(height: 38),
          _buildSectionTitle(
            icon: Icons.bolt,
            title: 'Tools',
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
                icon: Icons.groups_2_outlined,
                title: 'Speaker Room',
                iconColor: AppColors.namaNavyBlue,
                backgroundColor: const Color(0xFFE8F1FF),
                isEnabled: true,
                showBadge: hasUnreadSpeakerRoom,
                onTap: () async {
                  final event = await ref.read(activeEventFutureProvider.future);
                  await _markSpeakerRoomNotificationsAsRead(ref, event.id);
                  if (!context.mounted) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const SpeakerModeratorRoomScreen(),
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
  Widget _buildTopBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Image.asset(
          AppConstants.logoEmblemPath,
          height: 68,
          width: 68,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.auto_awesome,
              color: AppColors.namaNavyBlue,
              size: 46,
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
    );
  }
  Widget _buildWelcomeText(
    BuildContext context,
    String userName,
    String eventName,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Hi, ',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.namaNavyBlue,
                    ),
              ),
              TextSpan(
                text: '$userName!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.namaGoldenYellow,
                    ),
              ),
            ],
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
      ],
    );
  }
  Widget _buildEventErrorBox(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFFC9C9),
        ),
      ),
      child: Text(
        'This account is not currently linked to a valid event. Please ask an admin to assign the speaker again.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF9B1C1C),
              fontWeight: FontWeight.w600,
              height: 1.35,
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
    );
  }
  Widget _buildFeaturedSpeakers(
    BuildContext context,
    AsyncValue<List<dynamic>> speakersAsync,
  ) {
    return SizedBox(
      height: 220,
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
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: speakers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final speaker = speakers[index];
              final imageUrl = speaker.profileImageUrl.toString().trim();
              final name = speaker.name.toString().trim().isNotEmpty
                  ? speaker.name.toString().trim()
                  : 'Speaker';
              final title = speaker.title.toString().trim().isNotEmpty
                  ? speaker.title.toString().trim()
                  : 'Speaker';
              return SizedBox(
                width: 150,
                child: _FeaturedSpeakerImageCard(
                  name: name,
                  title: title,
                  imageUrl: imageUrl,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserDetailsScreen(
                          userId: speaker.uid,
                        ),
                      ),
                    );
                  },
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
  Widget _buildVenueMaps(
    BuildContext context,
    AsyncValue<List<dynamic>> venueMapsAsync,
  ) {
    return SizedBox(
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
                'description':
                    venueDescription.isEmpty ? 'Venue details' : venueDescription,
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
          final mapData = allVenueImages.first;
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
                          child: CircularProgressIndicator(strokeWidth: 2),
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
                      child: Container(
                        height: 30,
                        padding: const EdgeInsets.symmetric(horizontal: 15),
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
                  ],
                ),
              ),
            ),
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
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 18,
          children: sponsors.map((sponsor) {
            return SizedBox(
              width: 94,
              child: _partnerItem(
                name: sponsor.name.toString(),
                logoUrl: sponsor.logoUrl.toString(),
              ),
            );
          }).toList(),
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
                      errorBuilder: (context, error, stackTrace) {
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
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.08),
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
class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color iconColor;
  final Color backgroundColor;
  final bool isEnabled;
  final bool showBadge;
  final String? disabledMessage;
  final VoidCallback onTap;
  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.iconColor,
    required this.backgroundColor,
    required this.isEnabled,
    required this.onTap,
    this.showBadge = false,
    this.disabledMessage,
  });
  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = isEnabled ? iconColor : AppColors.namaMediumGray.withOpacity(0.45);
    final effectiveTextColor = isEnabled ? const Color(0xFF202124) : AppColors.namaMediumGray.withOpacity(0.55);
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
                    content: Text(disabledMessage ?? 'This feature is disabled'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    icon,
                    color: effectiveIconColor,
                    size: 21,
                  ),
                  if (showBadge)
                    Positioned(
                      right: -4,
                      top: -5,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: effectiveTextColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
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
class _FeaturedSpeakerImageCard extends StatelessWidget {
  final String name;
  final String title;
  final String imageUrl;
  final VoidCallback onTap;
  const _FeaturedSpeakerImageCard({
    required this.name,
    required this.title,
    required this.imageUrl,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F3F8),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.13),
              blurRadius: 11,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                errorWidget: (_, __, ___) => const Icon(
                  Icons.person,
                  size: 52,
                  color: AppColors.namaNavyBlue,
                ),
              )
            else
              const Icon(
                Icons.person,
                size: 52,
                color: AppColors.namaNavyBlue,
              ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.70),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.86),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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
}
