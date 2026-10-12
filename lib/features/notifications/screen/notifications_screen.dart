import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/config/app_colors.dart' show AppColors;
import 'package:events_app_trueattempt/core/enums/notification_type.dart';
import 'package:events_app_trueattempt/core/models/notification_model.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/features/chat/screen/speaker_moderator_room_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}
class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _localOpenedNotificationIds = {};
  static const Color titleColor = Color(0xFF0D1496);
  static const Color goldColor = Color(0xFFE2BF3C);
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return DateTime.now();
  }
  Stream<Set<String>> _openedNotificationIdsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value(_localOpenedNotificationIds);
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('readNotifications')
        .snapshots()
        .map((snapshot) {
      final ids = snapshot.docs.map((doc) => doc.id).toSet();
      ids.addAll(_localOpenedNotificationIds);
      return ids;
    });
  }
  Future<void> _markNotificationAsOpened(AppNotification notification) async {
    final id = notification.id.trim();
    if (id.isEmpty) return;
    setState(() {
      _localOpenedNotificationIds.add(id);
    });
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('readNotifications')
          .doc(id)
          .set({
        'notificationId': id,
        'openedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to mark notification as opened: $e');
    }
  }
  bool _isNotificationOpened(
    AppNotification notification,
    Set<String> openedIds,
  ) {
    final id = notification.id.trim();
    if (id.isEmpty) return false;
    return openedIds.contains(id) || _localOpenedNotificationIds.contains(id);
  }
  List<AppNotification> _applyFilters(List<AppNotification> notifications) {
    final query = _searchQuery.trim().toLowerCase();
    var filtered = notifications
        .where((notification) => notification.type != AppNotificationType.chat)
        .toList();
    if (query.isNotEmpty) {
      filtered = filtered.where((notification) {
        final title = notification.title.toLowerCase();
        final subtitle = (notification.subtitle ?? '').toLowerCase();
        final body = notification.body.toLowerCase();
        return title.contains(query) ||
            subtitle.contains(query) ||
            body.contains(query);
      }).toList();
    }
    filtered.sort((a, b) {
      final aTime = _toDateTime(a.timestamp);
      final bTime = _toDateTime(b.timestamp);
      return bTime.compareTo(aTime);
    });
    return filtered;
  }
  Future<void> _openNotificationDetails(AppNotification notification) async {
    await _markNotificationAsOpened(notification);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationDetailsScreen(
          notification: notification,
        ),
      ),
    );
  }
  String _formatTime(dynamic value) {
    final dateTime = _toDateTime(value);
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inMinutes < 1) {
      return 'Just now';
    }
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    }
    if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    }
    return DateFormat('dd MMM yyyy').format(dateTime);
  }
  IconData _iconForNotification(AppNotification notification) {
    switch (notification.type) {
      case AppNotificationType.chat:
        return Icons.chat_bubble_outline;
      default:
        final title = notification.title.toLowerCase();
        final body = notification.body.toLowerCase();
        if (title.contains('qr') ||
            body.contains('qr') ||
            title.contains('code') ||
            body.contains('code')) {
          return Icons.qr_code_2;
        }
        if (title.contains('session') || body.contains('session')) {
          return Icons.event_note_outlined;
        }
        return Icons.notifications_none_rounded;
    }
  }
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.arrow_back,
                size: 22,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Notifications',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: titleColor,
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: SizedBox(
        height: 40,
        child: TextField(
          controller: _searchController,
          style: const TextStyle(fontSize: 12.5),
          decoration: InputDecoration(
            hintText: 'Search notifications...',
            hintStyle: const TextStyle(
              fontSize: 12.5,
              color: Colors.grey,
            ),
            prefixIcon: const Icon(
              Icons.search,
              size: 18,
              color: Colors.grey,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.clear,
                      size: 16,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        _searchQuery = '';
                      });
                    },
                  )
                : null,
            filled: true,
            fillColor: const Color(0xFFF7F7F7),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(
                color: Color(0xFFD9D9D9),
                width: 0.8,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(
                color: titleColor,
                width: 1,
              ),
            ),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
        ),
      ),
    );
  }
  Widget _buildEmptyState(String message) {
    return Expanded(
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12.5,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
  Widget _buildNotificationList(
    List<AppNotification> notifications,
    Set<String> openedIds,
  ) {
    final filteredNotifications = _applyFilters(notifications);
    if (notifications.isEmpty) {
      return _buildEmptyState('No notifications');
    }
    if (filteredNotifications.isEmpty) {
      return _buildEmptyState('No notifications match your search.');
    }
    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        itemCount: filteredNotifications.length,
        itemBuilder: (context, index) {
          final notification = filteredNotifications[index];
          final isOpened = _isNotificationOpened(notification, openedIds);
          return _notificationCard(
            notification: notification,
            isOpened: isOpened,
          );
        },
      ),
    );
  }
  Widget _notificationCard({
    required AppNotification notification,
    required bool isOpened,
  }) {
    final subtitle = notification.subtitle?.trim() ?? '';
    final body = notification.body.trim();
    final cardColor = isOpened ? const Color(0xFFF4F5F8) : Colors.white;
    final borderColor =
        isOpened ? const Color(0xFFE8E8E8) : titleColor.withOpacity(0.10);
    final titleTextColor = isOpened ? const Color(0xFF3F4858) : titleColor;
    final bodyTextColor =
        isOpened ? Colors.black.withOpacity(0.45) : Colors.black.withOpacity(0.62);
    final subtitleTextColor =
        isOpened ? Colors.black.withOpacity(0.50) : Colors.black87;
    final timeTextColor =
        isOpened ? Colors.black.withOpacity(0.35) : Colors.black.withOpacity(0.45);
    return InkWell(
      onTap: () => _openNotificationDetails(notification),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: borderColor,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isOpened
                  ? Colors.black.withOpacity(0.025)
                  : Colors.black.withOpacity(0.075),
              blurRadius: isOpened ? 8 : 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: isOpened
                    ? titleColor.withOpacity(0.06)
                    : titleColor.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _iconForNotification(notification),
                color: isOpened ? titleColor.withOpacity(0.55) : titleColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: titleTextColor,
                      fontSize: 14,
                      height: 1.25,
                      fontWeight: isOpened ? FontWeight.w600 : FontWeight.w800,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: subtitleTextColor,
                        fontSize: 12.5,
                        fontWeight: isOpened ? FontWeight.w400 : FontWeight.w600,
                      ),
                    ),
                  ],
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: bodyTextColor,
                        fontSize: 12,
                        height: 1.3,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    _formatTime(notification.timestamp),
                    style: TextStyle(
                      color: timeTextColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isOpened)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: goldColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: goldColor.withOpacity(0.28),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Text(
                      'NEW',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                SizedBox(height: isOpened ? 2 : 12),
                Icon(
                  Icons.chevron_right,
                  color: isOpened ? Colors.grey.shade400 : Colors.grey,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildSearchBar(),
            StreamBuilder<Set<String>>(
              stream: _openedNotificationIdsStream(),
              builder: (context, readSnapshot) {
                final openedIds =
                    readSnapshot.data ?? _localOpenedNotificationIds;
                return notificationsAsync.when(
                  data: (notifications) {
                    return _buildNotificationList(
                      notifications,
                      openedIds,
                    );
                  },
                  loading: () => const Expanded(
                    child: Center(
                      child: LoadingIndicator(),
                    ),
                  ),
                  error: (err, _) => Expanded(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          'Error: $err',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
class NotificationDetailsScreen extends ConsumerStatefulWidget {
  final AppNotification notification;
  const NotificationDetailsScreen({
    super.key,
    required this.notification,
  });
  @override
  ConsumerState<NotificationDetailsScreen> createState() =>
      _NotificationDetailsScreenState();
}
class _NotificationDetailsScreenState
    extends ConsumerState<NotificationDetailsScreen> {
  static const Color titleColor = Color(0xFF0D1496);
  static const Color goldColor = Color(0xFFE2BF3C);
  String? _watchedSessionCode;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _sessionCategoryStream;
  bool _isBreakoutCategory(dynamic value) {
    final category = (value ?? '').toString().toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    return category == 'breakout' || category == 'breakoutsession';
  }
  Stream<QuerySnapshot<Map<String, dynamic>>> _watchSessionCategory(String code) {
    final normalized = code.trim().toUpperCase();
    if (_sessionCategoryStream == null || _watchedSessionCode != normalized) {
      _watchedSessionCode = normalized;
      _sessionCategoryStream = FirebaseFirestore.instance.collection('sessions')
          .where('checkInCode', isEqualTo: normalized).limit(1).snapshots();
    }
    return _sessionCategoryStream!;
  }
  bool _isJoining = false;
  bool _isMeetingActionLoading = false;
  String? _localMeetingStatus;
  DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return DateTime.now();
  }
  String _formatFullDate(dynamic value) {
    final dateTime = _toDateTime(value);
    return DateFormat('dd MMM yyyy, h:mm a').format(dateTime);
  }
  IconData _iconForNotification(AppNotification notification) {
    switch (notification.type) {
      case AppNotificationType.chat:
        return Icons.chat_bubble_outline;
      default:
        final title = notification.title.toLowerCase();
        final body = notification.body.toLowerCase();
        if (title.contains('qr') ||
            body.contains('qr') ||
            title.contains('code') ||
            body.contains('code')) {
          return Icons.qr_code_2;
        }
        if (title.contains('session') || body.contains('session')) {
          return Icons.event_note_outlined;
        }
        return Icons.notifications_none_rounded;
    }
  }
  String _notificationTypeName(AppNotification notification) {
    final raw = notification.type.name;
    if (raw.isEmpty) return 'Notification';
    return raw[0].toUpperCase() + raw.substring(1);
  }
  String _extractSessionCode(AppNotification notification) {
    final allText =
        '${notification.title} ${notification.subtitle ?? ''} ${notification.body}';
    final regex = RegExp(
      r'SES[-\s]?\d+',
      caseSensitive: false,
    );
    final match = regex.firstMatch(allText);
    if (match == null) return '';
    return match.group(0)!.replaceAll(' ', '-').toUpperCase();
  }
  Future<DocumentSnapshot<Map<String, dynamic>>?> _findSessionByCode(
    String sessionCode,
  ) async {
    final cleanCode = sessionCode.trim().toUpperCase();
    if (cleanCode.isEmpty) return null;
    final snapshot = await FirebaseFirestore.instance
        .collection('sessions')
        .where('checkInCode', isEqualTo: cleanCode)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first;
  }
  bool _isSessionActive(Map<String, dynamic> sessionData) {
    final startValue = sessionData['startTime'];
    final endValue = sessionData['endTime'];
    if (startValue == null || endValue == null) {
      return true;
    }
    final startTime = _toDateTime(startValue);
    final endTime = _toDateTime(endValue);
    final now = DateTime.now();
    return now.isAfter(startTime) && now.isBefore(endTime);
  }
  Future<bool> _alreadyJoined(String sessionId, String userId) async {
    final checkinDoc = await FirebaseFirestore.instance
        .collection('sessions')
        .doc(sessionId)
        .collection('checkins')
        .doc(userId)
        .get();
    if (checkinDoc.exists) return true;
    final sessionDoc = await FirebaseFirestore.instance
        .collection('sessions')
        .doc(sessionId)
        .get();
    final data = sessionDoc.data();
    final checkedInAttendees = data?['checkedInAttendees'];
    if (checkedInAttendees is List && checkedInAttendees.contains(userId)) {
      return true;
    }
    return false;
  }
  Future<void> _copySessionCode(String sessionCode) async {
    if (sessionCode.isEmpty) {
      _showSnackBar('No session code found.');
      return;
    }
    await Clipboard.setData(
      ClipboardData(text: sessionCode),
    );
    if (!mounted) return;
    _showSnackBar('Session code copied.');
  }
  Future<void> _joinEventFromNotification(String sessionCode) async {
    if (sessionCode.isEmpty) {
      _showAlertDialog(
        title: 'No Session Code',
        message: 'No session code was found in this notification.',
      );
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showAlertDialog(
        title: 'Login Required',
        message: 'Please login first to join this session.',
      );
      return;
    }
    if (_isJoining) return;
    setState(() {
      _isJoining = true;
    });
    try {
      final sessionDoc = await _findSessionByCode(sessionCode);
      if (sessionDoc == null || !sessionDoc.exists) {
        if (!mounted) return;
        setState(() {
          _isJoining = false;
        });
        _showAlertDialog(
          title: 'Invalid Session Code',
          message: 'No session found for this code.',
        );
        return;
      }
      final sessionData = sessionDoc.data() ?? {};
      if (_isBreakoutCategory(sessionData['category'])) {
        if (!mounted) return;
        setState(() => _isJoining = false);
        _showAlertDialog(
          title: 'Staff Admission Required',
          message: 'Please ask staff to join this breakout session.',
        );
        return;
      }
      if (!_isSessionActive(sessionData)) {
        if (!mounted) return;
        setState(() {
          _isJoining = false;
        });
        _showAlertDialog(
          title: 'Session Not Active',
          message: 'The session is not active yet.',
        );
        return;
      }
      final hasJoined = await _alreadyJoined(sessionDoc.id, user.uid);
      if (hasJoined) {
        if (!mounted) return;
        setState(() {
          _isJoining = false;
        });
        _showSnackBar('You have already joined this session.');
        return;
      }
      final functions = ref.read(firebaseFunctionsProvider);
      final callable = functions.httpsCallable('logSessionCheckIn');
      await callable.call<Map<String, dynamic>>({
        'sessionId': sessionDoc.id,
      });
      if (!mounted) return;
      setState(() {
        _isJoining = false;
      });
      final sessionTitle =
          (sessionData['title'] ?? sessionData['name'] ?? 'session')
              .toString();
      _showSnackBar('Joined "$sessionTitle" successfully!');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isJoining = false;
      });
String message = 'Failed to join session. Please try again.';
if (e.toString().contains('resource-exhausted')) {
  message = 'This session is full, please join another session.';
} else if (e.toString().contains('failed-precondition')) {
  message = 'The session is not active yet.';
} else if (e.toString().contains('already')) {
  message = 'You have already joined this session.';
} else if (e.toString().contains('not-found')) {
  message = 'Session not found.';
}
_showAlertDialog(
  title: 'Unable to Join',
  message: message,
);
    }
  }
  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  void _showAlertDialog({
    required String title,
    required String message,
  }) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: titleColor,
            ),
          ),
          content: Text(
            message,
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'OK',
                style: TextStyle(color: titleColor),
              ),
            ),
          ],
        );
      },
    );
  }
  Widget _sessionQrSection(String sessionCode) {
    if (sessionCode.isEmpty) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _watchSessionCategory(sessionCode),
      builder: (context, snapshot) {
        final sessions = snapshot.data?.docs;
        final canSelfJoin = !snapshot.hasError && sessions != null && sessions.isNotEmpty &&
            !_isBreakoutCategory(sessions.first.data()['category']);
        return Column(
      children: [
        const SizedBox(height: 22),
        Center(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: const Color(0xFFE2E2E2),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: QrImageView(
              data: sessionCode,
              version: QrVersions.auto,
              size: 170,
              backgroundColor: Colors.white,
              foregroundColor: titleColor,
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Session Code',
          style: TextStyle(
            color: Colors.black54,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: titleColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            sessionCode,
            style: const TextStyle(
              color: titleColor,
              fontSize: 18,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _copySessionCode(sessionCode),
                icon: const Icon(Icons.copy, size: 17),
                label: const Text(
                  'Copy Code',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: titleColor,
                  side: const BorderSide(color: titleColor),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            if (canSelfJoin) ...[
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isJoining
                    ? null
                    : () => _joinEventFromNotification(sessionCode),
                icon: _isJoining
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.login, size: 17),
                label: Text(
                  _isJoining ? 'Joining...' : 'Join Event',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: titleColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            ],
          ],
        ),
      ],
        );
      },
    );
  }
  String get _meetingId {
    return (widget.notification.data['meetingId'] ?? '').toString().trim();
  }
  String get _meetingStatus {
    if (_localMeetingStatus != null && _localMeetingStatus!.trim().isNotEmpty) {
      return _localMeetingStatus!.trim().toLowerCase();
    }
    final status = (widget.notification.data['status'] ??
            widget.notification.data['meetingStatus'] ??
            widget.notification.data['meeting_status'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();
    if (status.isNotEmpty) return status;
    return 'pending';
  }
  bool _isMeetingRequestNotification() {
    final title = widget.notification.title.toLowerCase();
    final subtitle = (widget.notification.subtitle ?? '').toLowerCase();
    final body = widget.notification.body.toLowerCase();
    final type = widget.notification.type.name.toLowerCase();
    final notificationCategory =
        (widget.notification.data['notificationCategory'] ?? '')
            .toString()
            .toLowerCase();
    final allText = '$title $subtitle $body $type $notificationCategory';
    return _meetingId.isNotEmpty &&
        (allText.contains('meeting request') ||
            allText.contains('meetingrequest') ||
            allText.contains('meeting'));
  }
  bool _canRespondToMeetingRequest() {
    return _isMeetingRequestNotification() && _meetingStatus == 'pending';
  }
  Future<void> _respondToMeetingRequest(String status) async {
    final meetingId = _meetingId;
    if (meetingId.isEmpty) {
      _showSnackBar('Meeting ID not found.');
      return;
    }
    final cleanStatus = status.trim().toLowerCase();
    if (cleanStatus != 'accepted' && cleanStatus != 'declined') {
      _showSnackBar('Invalid meeting response.');
      return;
    }
    if (_isMeetingActionLoading) return;
    setState(() {
      _isMeetingActionLoading = true;
    });
    try {
      final meetingRef =
          FirebaseFirestore.instance.collection('meetings').doc(meetingId);
      final meetingDoc = await meetingRef.get();
      if (!meetingDoc.exists) {
        throw Exception('Meeting request not found.');
      }
      final meetingData = meetingDoc.data() ?? {};
      final eventId =
          (meetingData['eventId'] ?? widget.notification.data['eventId'] ?? '')
              .toString();
      final requesterId = (meetingData['requesterId'] ??
              widget.notification.data['requesterId'] ??
              '')
          .toString();
      final recipientId = (meetingData['recipientId'] ??
              widget.notification.data['recipientId'] ??
              '')
          .toString();
      final requesterInfo =
          Map<String, dynamic>.from(meetingData['requesterInfo'] ?? {});
      final recipientInfo =
          Map<String, dynamic>.from(meetingData['recipientInfo'] ?? {});
      await meetingRef.update({
        'status': cleanStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'respondedAt': FieldValue.serverTimestamp(),
        'lastActionStatus': cleanStatus,
      });
      await _updateCurrentMeetingNotification(cleanStatus);
      if (requesterId.isNotEmpty) {
        final responderName =
            (recipientInfo['name'] ?? 'Someone').toString().trim();
        final requesterName =
            (requesterInfo['name'] ?? 'User').toString().trim();
        final isAccepted = cleanStatus == 'accepted';
        await FirebaseFirestore.instance
            .collection('users')
            .doc(requesterId)
            .collection('notifications')
            .add({
          'eventId': eventId,
          'title': isAccepted ? 'Meeting Accepted' : 'Meeting Declined',
          'subtitle': responderName.isEmpty ? 'Meeting Update' : responderName,
          'body': isAccepted
              ? '${responderName.isEmpty ? 'Someone' : responderName} accepted your meeting request.'
              : '${responderName.isEmpty ? 'Someone' : responderName} declined your meeting request.',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'type': isAccepted ? 'meetingAccepted' : 'meetingDeclined',
          'targetRole': 'all',
          'priority': isAccepted ? 'normal' : 'medium',
          'data': {
            'meetingId': meetingId,
            'requesterId': requesterId,
            'recipientId': recipientId,
            'requesterName': requesterName,
            'responderName': responderName,
            'status': cleanStatus,
            'notificationCategory':
                isAccepted ? 'meetingAccepted' : 'meetingDeclined',
          },
        });
      }
      if (!mounted) return;
      setState(() {
        _localMeetingStatus = cleanStatus;
        _isMeetingActionLoading = false;
      });
      _showSnackBar(
        cleanStatus == 'accepted'
            ? 'Meeting accepted.'
            : 'Meeting declined.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isMeetingActionLoading = false;
      });
      _showSnackBar('Failed to update meeting request: $e');
    }
  }
  Future<void> _updateCurrentMeetingNotification(String status) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    final notificationId = widget.notification.id.trim();
    if (notificationId.isNotEmpty) {
      final notificationRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId);
      final doc = await notificationRef.get();
      if (doc.exists) {
        await notificationRef.set({
          'isRead': true,
          'meetingStatus': status,
          'updatedAt': FieldValue.serverTimestamp(),
          'data': {
            'status': status,
          },
        }, SetOptions(merge: true));
        return;
      }
    }
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('data.meetingId', isEqualTo: _meetingId)
        .get();
    if (snapshot.docs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snapshot.docs) {
      batch.set(doc.reference, {
        'isRead': true,
        'meetingStatus': status,
        'updatedAt': FieldValue.serverTimestamp(),
        'data': {
          'status': status,
        },
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }
  Widget _buildMeetingResponseButtons() {
    if (_canRespondToMeetingRequest()) {
      return Column(
        children: [
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: OutlinedButton.icon(
                    onPressed: _isMeetingActionLoading
                        ? null
                        : () => _respondToMeetingRequest('declined'),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 16,
                    ),
                    label: const Text(
                      'Decline',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(
                        color: Colors.red,
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: ElevatedButton.icon(
                    onPressed: _isMeetingActionLoading
                        ? null
                        : () => _respondToMeetingRequest('accepted'),
                    icon: const Icon(
                      Icons.check_rounded,
                      size: 16,
                    ),
                    label: const Text(
                      'Accept',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }
    if (_isMeetingRequestNotification() && _meetingStatus != 'pending') {
      final accepted = _meetingStatus == 'accepted';
      return Column(
        children: [
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 11,
            ),
            decoration: BoxDecoration(
              color: accepted
                  ? Colors.green.withOpacity(0.10)
                  : Colors.red.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: accepted
                    ? Colors.green.withOpacity(0.35)
                    : Colors.red.withOpacity(0.35),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  accepted
                      ? Icons.check_circle_outline
                      : Icons.cancel_outlined,
                  size: 18,
                  color: accepted ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  accepted ? 'Meeting accepted' : 'Meeting declined',
                  style: TextStyle(
                    color: accepted ? Colors.green : Colors.red,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
  bool _isSpeakerRoomNotification(AppNotification notification) {
    final title = notification.title.toLowerCase();
    final subtitle = (notification.subtitle ?? '').toLowerCase();
    final body = notification.body.toLowerCase();
    final type = notification.type.name.toLowerCase();
    final dataCategory = (notification.data['notificationCategory'] ?? '').toString().toLowerCase();
    final allText = '$title $subtitle $body $type $dataCategory';
    return allText.contains('speaker room') ||
        allText.contains('speaker & moderator') ||
        allText.contains('speaker moderator') ||
        allText.contains('speaker and moderator') ||
        allText.contains('speakermoderatorroom');
  }
  Future<void> _markSpeakerRoomNotificationsAsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final eventId = (widget.notification.data['eventId'] ?? '').toString().trim();
    final notificationsRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('notifications');
    Query<Map<String, dynamic>> query = notificationsRef.where('isRead', isEqualTo: false);
    if (eventId.isNotEmpty) {
      query = query.where('eventId', isEqualTo: eventId);
    }
    final snapshot = await query.get();
    if (snapshot.docs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final type = (data['type'] ?? '').toString().toLowerCase();
      final title = (data['title'] ?? '').toString().toLowerCase();
      final subtitle = (data['subtitle'] ?? '').toString().toLowerCase();
      final body = (data['body'] ?? data['message'] ?? '').toString().toLowerCase();
      final notificationCategory = data['data'] is Map ? (data['data']['notificationCategory'] ?? '').toString().toLowerCase() : '';
      final allText = '$type $title $subtitle $body $notificationCategory';
      final isSpeakerRoomNotification = allText.contains('speaker room') ||
          allText.contains('speaker & moderator') ||
          allText.contains('speaker moderator') ||
          allText.contains('speaker and moderator') ||
          allText.contains('speakermoderatorroom');
      if (isSpeakerRoomNotification) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
    }
    await batch.commit();
  }
  Future<void> _openSpeakerRoom() async {
    await _markSpeakerRoomNotificationsAsRead();
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SpeakerModeratorRoomScreen(),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final notification = widget.notification;
    final subtitle = notification.subtitle?.trim() ?? '';
    final body = notification.body.trim();
    final sessionCode = _extractSessionCode(notification);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.arrow_back,
                        size: 22,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Notification Details',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        height: 72,
                        width: 72,
                        decoration: BoxDecoration(
                          color: titleColor.withOpacity(0.10),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _iconForNotification(notification),
                          color: titleColor,
                          size: 34,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Center(
                      child: Text(
                        notification.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: titleColor,
                          fontSize: 21,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        _formatFullDate(notification.timestamp),
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.50),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    _sessionQrSection(sessionCode),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F7),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFE2E2E2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _notificationTypeName(notification),
                            style: const TextStyle(
                              color: goldColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 14,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (body.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              body,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 14,
                                height: 1.45,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                          if (subtitle.isEmpty && body.isEmpty) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'No additional details available.',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
_buildMeetingResponseButtons(),
                        if (_isSpeakerRoomNotification(widget.notification)) ...[
  const SizedBox(height: 22),
  Center(
    child: SizedBox(
      width: 260,
      height: 36,
      child: ElevatedButton.icon(
        onPressed: _openSpeakerRoom,
        icon: const Icon(
          Icons.groups_2_outlined,
          size: 16,
        ),
        label: const Text(
          'Open Speaker Room',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.namaGoldenYellow,
          foregroundColor: AppColors.namaNavyBlue,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    ),
  ),
],
const SizedBox(height: 10),
Center(
  child: SizedBox(
    width: 260,
    height: 36,
    child: ElevatedButton(
      onPressed: () => Navigator.pop(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: titleColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      child: const Text(
        'Back to Notifications',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  ),
),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
