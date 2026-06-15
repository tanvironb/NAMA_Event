import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/features/agenda/screen/session_detail_screen.dart';
import 'package:events_app_trueattempt/features/qr_scanner/screen/qr_scanner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/core/constants/app_constants.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';

import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/common_widgets/message_icon_with_badge.dart';
import 'package:events_app_trueattempt/common_widgets/notification_icon_with_badge.dart';

import 'package:events_app_trueattempt/features/home/screen/widgets/speaker_carousel.dart';
import 'package:events_app_trueattempt/features/home/screen/widgets/venue_maps_carousel.dart';

import 'package:events_app_trueattempt/features/messaging/screen/conversations_screen.dart';
import 'package:events_app_trueattempt/features/notifications/screen/notifications_screen.dart';

class HomeDashboardScreen extends ConsumerStatefulWidget {
  final VoidCallback? onSeeAllUpcomingSessions;

  const HomeDashboardScreen({
    super.key,
    this.onSeeAllUpcomingSessions,
  });

  @override
  ConsumerState<HomeDashboardScreen> createState() =>
      _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen> {
  String selectedFilter = 'All';

  final PageController _eventPageController = PageController();
  Timer? _eventSliderTimer;

  int _currentEventPage = 0;
  String _lastSignature = '';

  static const Color primaryBlue = Color(0xFF0D1496);
  static const Color cardGrey = Color(0xFFEFEFEF);
  static const Color namaGoldenYellow = Color(0xFFD6A329);

  @override
  void dispose() {
    _eventSliderTimer?.cancel();
    _eventPageController.dispose();
    super.dispose();
  }

  void _setupAutoSlide(int count, String signature) {
    if (count <= 1) {
      _eventSliderTimer?.cancel();
      _eventSliderTimer = null;
      _lastSignature = signature;
      return;
    }

    if (_eventSliderTimer != null && _lastSignature == signature) return;

    _eventSliderTimer?.cancel();
    _lastSignature = signature;
    _currentEventPage = 0;

    _eventSliderTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!_eventPageController.hasClients) return;

      _currentEventPage = (_currentEventPage + 1) % count;

      _eventPageController.animateToPage(
        _currentEventPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<String> _getCurrentUserName(String uid, String? displayName) async {
    if (displayName != null && displayName.trim().isNotEmpty) {
      return displayName.trim().split(' ').first;
    }

    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final name = (data['name'] ??
                data['fullName'] ??
                data['displayName'] ??
                data['firstName'] ??
                '')
            .toString()
            .trim();

        if (name.isNotEmpty) {
          return name.split(' ').first;
        }
      }
    } catch (_) {}

    return 'User';
  }

  Future<String> _getSpeakerName(Session session) async {
    if (session.speakerIds.isEmpty) return 'Host';

    final firestore = FirebaseFirestore.instance;
    final names = <String>[];

    for (final id in session.speakerIds) {
      var doc = await firestore.collection('speakers').doc(id).get();

      if (!doc.exists) {
        doc = await firestore.collection('users').doc(id).get();
      }

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final name = (data['name'] ??
                data['fullName'] ??
                data['displayName'] ??
                data['username'] ??
                '')
            .toString()
            .trim();

        if (name.isNotEmpty) names.add(name);
      }
    }

    if (names.isEmpty) return 'Host';

    if (names.length == 1) return names.first;

    return names.map((e) => e.split(' ').first).join(', ');
  }

  DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  String _formatEventDate(Map<String, dynamic> data) {
    final startDate = _toDateTime(
      data['startDate'] ??
          data['startTime'] ??
          data['eventStartDate'] ??
          data['date'],
    );

    final endDate = _toDateTime(
      data['endDate'] ??
          data['endTime'] ??
          data['eventEndDate'],
    );

    if (startDate == null && endDate == null) {
      return '';
    }

    if (startDate != null && endDate == null) {
      return DateFormat('MMM d, yyyy').format(startDate);
    }

    if (startDate == null && endDate != null) {
      return DateFormat('MMM d, yyyy').format(endDate);
    }

    final sameDay = startDate!.year == endDate!.year &&
        startDate.month == endDate.month &&
        startDate.day == endDate.day;

    if (sameDay) {
      return DateFormat('MMM d, yyyy').format(startDate);
    }

    return '${DateFormat('MMM d, yyyy').format(startDate)} - ${DateFormat('MMM d, yyyy').format(endDate)}';
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(sessionsStreamProvider);
    final user = ref.watch(firebaseAuthProvider).currentUser;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 82),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FutureBuilder<String>(
                future: user == null
                    ? Future.value('User')
                    : _getCurrentUserName(user.uid, user.displayName),
                builder: (context, snapshot) {
                  final name = snapshot.data ?? 'User';

                  return RichText(
                    text: TextSpan(
                      children: [
                        const TextSpan(
                          text: 'Hi, ',
                          style: TextStyle(
                            fontSize: 22,
                            color: primaryBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text: '$name!',
                          style: const TextStyle(
                            fontSize: 22,
                            color: namaGoldenYellow,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            _activeEventInfo(),
            const SizedBox(height: 18),
            _joinSessionsCard(context),
            const SizedBox(height: 18),
            sessionsAsync.when(
              data: (s) => _filters(s),
              loading: () => _filters([]),
              error: (_, __) => _filters([]),
            ),
            const SizedBox(height: 30),
            _sectionTitle(
              context,
              'Upcoming Sessions',
              showSeeAll: true,
              onSeeAll: widget.onSeeAllUpcomingSessions,
            ),
            const SizedBox(height: 14),
            _slider(sessionsAsync),
            const SizedBox(height: 30),
            _sectionTitle(context, 'Speakers'),
            const SizedBox(height: 12),
            const SpeakerCarousel(),
            const SizedBox(height: 26),
            _sectionTitle(context, 'Venues'),
            const SizedBox(height: 12),

            // FIXED: Added left/right padding only for attendee Venue section.
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: VenueMapsCarousel(),
            ),

            const SizedBox(height: 26),
            _sectionTitle(context, 'Partners'),
            const SizedBox(height: 10),
            _partnersSection(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _activeEventInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('events')
            .where('isActive', isEqualTo: true)
            .limit(1)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Text(
              'Loading event...',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Text(
              'No active event',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            );
          }

          final data = snapshot.data!.docs.first.data();

          final eventName = (data['name'] ??
                  data['title'] ??
                  data['eventName'] ??
                  'Current Event')
              .toString()
              .trim();

          final eventDate = _formatEventDate(data);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eventName.isEmpty ? 'Current Event' : eventName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: primaryBlue,
                  fontSize: 18,
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (eventDate.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  eventDate,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
      child: Row(
        children: [
          Image.asset(
            AppConstants.logoEmblemPath,
            height: 68,
            width: 68,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.event, color: primaryBlue, size: 46);
            },
          ),
          const Spacer(),
          _icon(const MessageIconWithBadge(), () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ConversationsScreen()),
            );
          }),
          const SizedBox(width: 12),
          _icon(const NotificationIconWithBadge(), () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            );
          }),
        ],
      ),
    );
  }

  Widget _joinSessionsCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const QRScannerScreen(),
            ),
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: primaryBlue,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: primaryBlue.withOpacity(0.18),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: const BoxDecoration(
                  color: namaGoldenYellow,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.qr_code_scanner,
                  color: primaryBlue,
                  size: 23,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Join Session',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Scan session QR to mark your attendance',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white,
                size: 15,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _icon(Widget child, VoidCallback onTap) {
    return Container(
      height: 42,
      width: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        icon: child,
      ),
    );
  }

  Widget _filters(List sessions) {
    final filters = _getFiltersFromSessions(sessions);

    if (!filters.contains(selectedFilter)) {
      selectedFilter = 'All';
    }

    return SizedBox(
      height: 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final f = filters[index];
          final selected = selectedFilter == f;

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedFilter = f;
                _lastSignature = '';
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
              decoration: BoxDecoration(
                color: selected ? primaryBlue : primaryBlue.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                f,
                style: TextStyle(
                  color: selected ? Colors.white : primaryBlue,
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

  List<String> _getFiltersFromSessions(List sessions) {
    final filters = <String>{'All'};

    for (final session in sessions) {
      final category = (session.category ?? '').toString().trim();

      if (category.isNotEmpty) {
        filters.add(category);
      }
    }

    if (filters.length == 1) {
      filters.addAll(['Education', 'Ai', 'Social', 'Scholarship']);
    }

    return filters.toList();
  }

  Widget _sectionTitle(
    BuildContext context,
    String title, {
    bool showSeeAll = false,
    VoidCallback? onSeeAll,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              color: primaryBlue,
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
                  fontSize: 9,
                  color: primaryBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _slider(AsyncValue<List<Session>> sessionsAsync) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        height: 255,
        child: sessionsAsync.when(
          data: (sessions) {
            final now = DateTime.now();

            final list = sessions.where((s) {
              final upcoming =
                  s.startTime.isAfter(now) || s.endTime.isAfter(now);

              if (!upcoming) return false;

              if (selectedFilter == 'All') return true;

              final category = s.category.trim().toLowerCase();
              final selected = selectedFilter.trim().toLowerCase();

              return category == selected;
            }).toList()
              ..sort((a, b) => a.startTime.compareTo(b.startTime));

            final signature =
                '$selectedFilter-${list.map((e) => e.id).join('|')}';

            WidgetsBinding.instance.addPostFrameCallback((_) {
              _setupAutoSlide(list.length, signature);
            });

            if (list.isEmpty) {
              return Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cardGrey,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    selectedFilter == 'All'
                        ? 'No upcoming sessions available.'
                        : 'No upcoming session for $selectedFilter.',
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
              itemCount: list.length,
              onPageChanged: (index) {
                _currentEventPage = index;
              },
              itemBuilder: (_, i) {
                final s = list[i];

                return FutureBuilder<String>(
                  future: _getSpeakerName(s),
                  builder: (_, snap) {
                    final speaker = snap.data ?? 'Loading speaker...';
                    return _card(s, speaker);
                  },
                );
              },
            );
          },
          loading: () => const Center(child: LoadingIndicator()),
          error: (_, __) => const Center(child: Text('Error')),
        ),
      ),
    );
  }

  Widget _card(Session s, String speaker) {
    final date = s.startTime;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SessionDetailScreen(session: s),
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
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 125,
                width: double.infinity,
                color: Colors.white,
                child: s.imageUrl.isNotEmpty
                    ? Image.network(
                        s.imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;

                          return const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.image_not_supported_outlined,
                            color: primaryBlue,
                            size: 32,
                          );
                        },
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 13),
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
                            s.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                              height: 1.08,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'By: $speaker',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.black.withOpacity(0.65),
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
                            DateFormat('dd').format(date),
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 31,
                              height: 0.9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            DateFormat('MMM').format(date),
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        DateFormat('h:mm a').format(date),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const Spacer(),
                      _badge(s.location),
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

  Widget _badge(String text) {
    final safeText = text.trim().isNotEmpty ? text.trim() : 'Location';

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 105),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: namaGoldenYellow,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Text(
          safeText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: primaryBlue,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _partnersSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('events')
            .where('isActive', isEqualTo: true)
            .limit(1)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 105,
              child: Center(child: LoadingIndicator()),
            );
          }

          if (snapshot.hasError) {
            return const SizedBox(
              height: 70,
              child: Center(
                child: Text(
                  'Failed to load partners',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _emptyPartners();
          }

          final eventData = snapshot.data!.docs.first.data();
          final partnersRaw = eventData['partners'];

          final partners = partnersRaw is List
              ? partnersRaw
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .where((item) {
                  final name = (item['name'] ?? '').toString().trim();
                  final logoUrl = (item['logoUrl'] ?? '').toString().trim();
                  return name.isNotEmpty || logoUrl.isNotEmpty;
                }).toList()
              : <Map<String, dynamic>>[];

          if (partners.isEmpty) {
            return _emptyPartners();
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              const double spacing = 10;
              const double runSpacing = 8;
              final double itemWidth =
                  (constraints.maxWidth - (spacing * 2)) / 3;

              return Wrap(
                alignment: WrapAlignment.center,
                runAlignment: WrapAlignment.center,
                spacing: spacing,
                runSpacing: runSpacing,
                children: partners.map((partner) {
                  final name = (partner['name'] ?? '').toString().trim();
                  final logoUrl = (partner['logoUrl'] ?? '').toString().trim();

                  return SizedBox(
                    width: itemWidth,
                    child: _partnerItem(
                      name: name,
                      logoUrl: logoUrl,
                    ),
                  );
                }).toList(),
              );
            },
          );
        },
      ),
    );
  }

  Widget _emptyPartners() {
    return const SizedBox(
      height: 45,
      child: Center(
        child: Text(
          'No partners yet',
          style: TextStyle(
            color: Colors.black54,
            fontSize: 13,
            fontWeight: FontWeight.w400,
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
          height: 66,
          width: 66,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.055),
                blurRadius: 9,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(
            child: cleanLogoUrl.isEmpty
                ? const Center(
                    child: Icon(
                      Icons.handshake_outlined,
                      color: primaryBlue,
                      size: 28,
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(9),
                    child: Image.network(
                      cleanLogoUrl,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;

                        return const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint('Attendee partner logo failed to load.');
                        debugPrint('Partner name: $name');
                        debugPrint('Partner logoUrl: $cleanLogoUrl');
                        debugPrint('Partner logo error: $error');

                        return const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: primaryBlue,
                            size: 26,
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          name.isEmpty ? 'Partner' : name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: primaryBlue,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            height: 1.15,
          ),
        ),
      ],
    );
  }
}