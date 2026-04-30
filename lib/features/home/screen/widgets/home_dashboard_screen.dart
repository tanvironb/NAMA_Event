import 'dart:async';
import 'package:events_app_trueattempt/features/agenda/screen/session_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/core/constants/app_constants.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/common_widgets/message_icon_with_badge.dart';
import 'package:events_app_trueattempt/common_widgets/notification_icon_with_badge.dart';
import 'package:events_app_trueattempt/features/agenda/screen/agenda_screen.dart';
import 'package:events_app_trueattempt/features/home/screen/widgets/speaker_carousel.dart';
import 'package:events_app_trueattempt/features/home/screen/widgets/partner_carousel.dart';
import 'package:events_app_trueattempt/features/home/screen/widgets/venue_maps_carousel.dart';
import 'package:events_app_trueattempt/features/messaging/screen/conversations_screen.dart';
import 'package:events_app_trueattempt/features/notifications/screen/notifications_screen.dart';

class HomeDashboardScreen extends ConsumerStatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  ConsumerState<HomeDashboardScreen> createState() =>
      _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen> {
  String selectedFilter = 'All';

  final PageController _eventPageController = PageController();
  Timer? _eventSliderTimer;
  int _currentEventPage = 0;

  static const Color primaryBlue = Color(0xFF0D1496);
  static const Color cardGrey = Color(0xFFEFEFEF);

  @override
  void dispose() {
    _eventSliderTimer?.cancel();
    _eventPageController.dispose();
    super.dispose();
  }

  void _startEventAutoSlide(int itemCount) {
    _eventSliderTimer?.cancel();

    if (itemCount <= 1) return;

    _eventSliderTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_eventPageController.hasClients) return;

      _currentEventPage++;

      if (_currentEventPage >= itemCount) {
        _currentEventPage = 0;
      }

      _eventPageController.animateToPage(
        _currentEventPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(sessionsStreamProvider);
    final activeLiveSessionAsync = ref.watch(activeLiveSessionProvider);
    final user = ref.watch(firebaseAuthProvider).currentUser;

    final name = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.split(' ').first
        : 'Tanvir';

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _topHeader(context),
            const SizedBox(height: 22),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Hi, $name!',
                style: const TextStyle(
                  color: primaryBlue,
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 2),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Explore our events',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),

            const SizedBox(height: 18),

            sessionsAsync.when(
              data: (sessions) => _categoryChips(sessions),
              loading: () => _categoryChips([]),
              error: (_, __) => _categoryChips([]),
            ),

            const SizedBox(height: 34),

            _sectionTitle(
              context,
              title: 'Upcoming Sessions',
              showSeeAll: true,
              onSeeAll: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AgendaScreen()),
                );
              },
            ),

            const SizedBox(height: 14),

            _upcomingEventsSlider(
              context,
              sessionsAsync,
              activeLiveSessionAsync,
            ),

            const SizedBox(height: 34),

            _sectionTitle(context, title: 'Speakers'),
            const SizedBox(height: 12),
            const SpeakerCarousel(),

            const SizedBox(height: 30),

            _sectionTitle(context, title: 'Venues'),
            const SizedBox(height: 12),
            const VenueMapsCarousel(),

            const SizedBox(height: 30),

            _sectionTitle(context, title: 'Partners'),
            const SizedBox(height: 12),
            const PartnerCarousel(),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _topHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 22, 32, 0),
      child: Row(
        children: [
          Image.asset(
            AppConstants.logoEmblemPath,
            height: 40,
            width: 40,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.event, color: primaryBlue, size: 38);
            },
          ),
          const Spacer(),
          _roundIconButton(
            child: const MessageIconWithBadge(),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ConversationsScreen()),
              );
            },
          ),
          const SizedBox(width: 14),
          _roundIconButton(
            child: const NotificationIconWithBadge(),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _roundIconButton({
    required Widget child,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 42,
      width: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.14),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: child,
        onPressed: onTap,
      ),
    );
  }

  Widget _categoryChips(List<dynamic> sessions) {
    final filters = _getFiltersFromSessions(sessions);

    if (!filters.contains(selectedFilter)) {
      selectedFilter = 'All';
    }

    return SizedBox(
      height: 30,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 18),
        itemBuilder: (context, index) {
          final item = filters[index];
          final isSelected = selectedFilter == item;

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedFilter = item;
                _currentEventPage = 0;
              });

              if (_eventPageController.hasClients) {
                _eventPageController.jumpToPage(0);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? primaryBlue
                    : primaryBlue.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                item,
                style: TextStyle(
                  color: isSelected ? Colors.white : primaryBlue,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<String> _getFiltersFromSessions(List<dynamic> sessions) {
    final Set<String> filters = {'All'};

    for (final session in sessions) {
      final category = _getSessionCategory(session);

      if (category.trim().isNotEmpty) {
        filters.add(category.trim());
      }
    }

    if (filters.length == 1) {
      filters.addAll(['Education', 'Ai', 'Social', 'Scholarship']);
    }

    return filters.toList();
  }

  String _getSessionCategory(dynamic session) {
    try {
      final value = session.category;

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    } catch (_) {}

    return '';
  }

  Widget _sectionTitle(
    BuildContext context, {
    required String title,
    bool showSeeAll = false,
    VoidCallback? onSeeAll,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: primaryBlue,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          if (showSeeAll)
            GestureDetector(
              onTap: onSeeAll,
              child: const Text(
                'See All',
                style: TextStyle(
                  color: primaryBlue,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _upcomingEventsSlider(
    BuildContext context,
    AsyncValue<dynamic> sessionsAsync,
    AsyncValue<dynamic> activeLiveSessionAsync,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: SizedBox(
        height: 215,
        child: sessionsAsync.when(
          data: (sessions) {
            final now = DateTime.now();

            final sortedSessions = List<dynamic>.from(sessions)
              ..sort((a, b) => a.startTime.compareTo(b.startTime));

            final filteredSessions = sortedSessions.where((session) {
              final startTime = session.startTime as DateTime;
              final endTime = session.endTime as DateTime;

              final isUpcoming = startTime.isAfter(now) || endTime.isAfter(now);

              if (!isUpcoming) return false;

              if (selectedFilter == 'All') return true;

              final category = _getSessionCategory(session).toLowerCase();
              final selected = selectedFilter.trim().toLowerCase();

              return category == selected;
            }).toList();

            WidgetsBinding.instance.addPostFrameCallback((_) {
              _startEventAutoSlide(filteredSessions.length);
            });

            if (filteredSessions.isEmpty) {
              return Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cardGrey,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    selectedFilter == 'All'
                        ? 'No upcoming events available.'
                        : 'No upcoming event for $selectedFilter.',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            return PageView.builder(
              controller: _eventPageController,
              itemCount: filteredSessions.length,
              onPageChanged: (index) {
                _currentEventPage = index;
              },
              itemBuilder: (context, index) {
                final session = filteredSessions[index];

                return _upcomingEventCard(
                  context,
                  session,
                  activeLiveSessionAsync,
                );
              },
            );
          },
          loading: () => const Center(child: LoadingIndicator()),
          error: (err, stack) {
            return Center(
              child: Text(
                'Failed to load sessions.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _upcomingEventCard(
    BuildContext context,
    dynamic session,
    AsyncValue<dynamic> activeLiveSessionAsync,
  ) {
    final startDate = session.startTime as DateTime;

    final day = DateFormat('dd').format(startDate);
    final month = DateFormat('MMM').format(startDate);
    final time = DateFormat('h:mm a').format(startDate);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SessionDetailScreen(session: session),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: cardGrey,
          borderRadius: BorderRadius.circular(20),
          // boxShadow: [
          //   BoxShadow(
          //     color: Colors.black.withOpacity(0.88),
          //     blurRadius: 16,
          //     spreadRadius: 4,
          //     offset: const Offset(0, 6),
          //   ),
          // ],
        ),
        child: Column(
          children: [
            Container(
              height: 88,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 13,
                              height: 1.05,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const Spacer(),

                          Text(
                            'By: ${_getSessionHost(session)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.black.withOpacity(0.75),
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            day,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 28,
                              height: 0.9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            month,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 3),

                      Text(
                        time,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),

                      const Spacer(),

                      activeLiveSessionAsync.when(
                        data: (liveSession) {
                          final isThisSessionLive =
                              liveSession != null && liveSession.id == session.id;

                          return _statusBadge(
                            isThisSessionLive ? 'Live' : 'Online',
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => _statusBadge('Online'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getSessionHost(dynamic session) {
    try {
      final value = session.hostName;

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    } catch (_) {}

    try {
      final value = session.speakerName;

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    } catch (_) {}

    try {
      final value = session.speakerIds;

      if (value is List && value.isNotEmpty) {
        return value.first.toString();
      }
    } catch (_) {}

    return 'Host not available';
  }

  Widget _statusBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: primaryBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// class _SessionDetailsPreviewPage extends StatelessWidget {
//   final dynamic session;

//   const _SessionDetailsPreviewPage({
//     required this.session,
//   });

//   static const Color primaryBlue = Color(0xFF0D1496);

//   @override
//   Widget build(BuildContext context) {
//     final startDate = session.startTime as DateTime;
//     final endDate = session.endTime as DateTime;

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Session Details'),
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(24),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Container(
//               height: 180,
//               width: double.infinity,
//               decoration: BoxDecoration(
//                 color: const Color(0xFFEFEFEF),
//                 borderRadius: BorderRadius.circular(20),
//               ),
//               child: const Icon(
//                 Icons.event,
//                 color: primaryBlue,
//                 size: 60,
//               ),
//             ),

//             const SizedBox(height: 24),

//             Text(
//               session.title,
//               style: const TextStyle(
//                 color: primaryBlue,
//                 fontSize: 24,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),

//             const SizedBox(height: 12),

//             Text(
//               session.description.toString().isNotEmpty
//                   ? session.description
//                   : 'No description available.',
//               style: const TextStyle(
//                 fontSize: 14,
//                 height: 1.5,
//                 color: Colors.black87,
//               ),
//             ),

//             const SizedBox(height: 24),

//             _infoRow(
//               Icons.calendar_today,
//               DateFormat('dd MMM yyyy').format(startDate),
//             ),
//             _infoRow(
//               Icons.access_time,
//               '${DateFormat('h:mm a').format(startDate)} - ${DateFormat('h:mm a').format(endDate)}',
//             ),
//             _infoRow(
//               Icons.location_on_outlined,
//               session.location.toString(),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _infoRow(IconData icon, String text) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 14),
//       child: Row(
//         children: [
//           Icon(icon, color: primaryBlue, size: 20),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Text(
//               text,
//               style: const TextStyle(
//                 fontSize: 14,
//                 color: Colors.black87,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }


//taahmmed123@gmail.com