// lib/features/notifications/screen/notification_detail_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/models/notification_model.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/features/chat/screen/speaker_moderator_room_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

class NotificationDetailScreen extends ConsumerStatefulWidget {
  final AppNotification notification;
  const NotificationDetailScreen({
    super.key,
    required this.notification,
  });
  @override
  ConsumerState<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState
    extends ConsumerState<NotificationDetailScreen> {
  late TextEditingController _titleController;
  late TextEditingController _subtitleController;
  late TextEditingController _bodyController;
  bool _isEditing = false;
  bool _isLoading = false;
  String? _localMeetingStatus;
  static const Color _primaryColor = Color(0xFF1B0F72);
  static const Color _textMuted = Color(0xFF6B7280);
  static const Color _softPurple = Color(0xFFF1EEFB);
  static const Color _borderColor = Color(0xFFE1DDF0);

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.notification.title);
    _subtitleController =
        TextEditingController(text: widget.notification.subtitle ?? '');
    _bodyController = TextEditingController(text: widget.notification.body);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  String get _qrPayload {
    final fromModel = widget.notification.qrPayload.trim();
    if (fromModel.isNotEmpty) return fromModel;
    return (widget.notification.data['qrPayload'] ?? '').toString().trim();
  }

  String get _sessionCode {
    final fromModel = widget.notification.sessionCode.trim();
    if (fromModel.isNotEmpty) return fromModel;
    return (widget.notification.data['sessionCode'] ?? '').toString().trim();
  }

  String get _sessionTitle {
    final fromModel = widget.notification.sessionTitle.trim();
    if (fromModel.isNotEmpty) return fromModel;
    final fromData =
        (widget.notification.data['sessionTitle'] ?? '').toString().trim();
    if (fromData.isNotEmpty) return fromData;
    if ((widget.notification.subtitle ?? '').trim().isNotEmpty) {
      return widget.notification.subtitle!.trim();
    }
    return widget.notification.eventName.trim();
  }

  String get _meetingId {
    return (widget.notification.data['meetingId'] ?? '').toString().trim();
  }

  String get _meetingStatus {
    if (_localMeetingStatus != null &&
        _localMeetingStatus!.trim().isNotEmpty) {
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

  bool get _hasQrPayload => _qrPayload.isNotEmpty;
  bool get _hasSessionCode => _sessionCode.isNotEmpty;
  bool get _hasQrAnnouncement => _hasQrPayload || _hasSessionCode;

  Color _getNotificationColor() {
    final title = widget.notification.title.toLowerCase();
    final body = widget.notification.body.toLowerCase();
    final type = widget.notification.type.name.toLowerCase();
    if (title.contains('accepted') || type.contains('accepted')) {
      return AppColors.successGreen;
    }
    if (title.contains('declined') ||
        title.contains('cancelled') ||
        type.contains('declined') ||
        type.contains('cancelled')) {
      return Colors.red;
    }
    if (type.contains('meeting') ||
        title.contains('meeting') ||
        body.contains('meeting')) {
      return AppColors.namaNavyBlue;
    }
    if (type.contains('speaker') ||
        title.contains('speaker room') ||
        title.contains('speaker & moderator') ||
        body.contains('speaker & moderator')) {
      return AppColors.namaNavyBlue;
    }
    return AppColors.namaNavyBlue;
  }

  IconData _getNotificationIcon() {
    final title = widget.notification.title.toLowerCase();
    final body = widget.notification.body.toLowerCase();
    final type = widget.notification.type.name.toLowerCase();
    if (title.contains('accepted') || type.contains('accepted')) {
      return Icons.check_circle_outline_rounded;
    }
    if (title.contains('declined') ||
        title.contains('cancelled') ||
        type.contains('declined') ||
        type.contains('cancelled')) {
      return Icons.cancel_outlined;
    }
    if (type.contains('meeting') ||
        title.contains('meeting') ||
        body.contains('meeting')) {
      return Icons.handshake_outlined;
    }
    if (type.contains('speaker') ||
        title.contains('speaker room') ||
        title.contains('speaker & moderator') ||
        body.contains('speaker & moderator')) {
      return Icons.groups_2_outlined;
    }
    if (title.contains('qr') || body.contains('qr')) {
      return Icons.qr_code_2_rounded;
    }
    if (title.contains('session') || body.contains('session')) {
      return Icons.event_note_outlined;
    }
    return Icons.notifications_none_rounded;
  }

  String _getNotificationTypeLabel() {
    final type = widget.notification.type.name.trim();
    if (type.isEmpty) return 'Notification';
    if (type.toLowerCase() == 'meetingrequest') return 'Meeting Request';
    if (type.toLowerCase() == 'meetingaccepted') return 'Meeting Accepted';
    if (type.toLowerCase() == 'meetingdeclined') return 'Meeting Declined';
    if (type.toLowerCase() == 'speakermoderatorroom') return 'Speaker Room';
    return type;
  }

  bool _isSpeakerRoomNotification() {
    final title = widget.notification.title.toLowerCase();
    final subtitle = (widget.notification.subtitle ?? '').toLowerCase();
    final body = widget.notification.body.toLowerCase();
    final type = widget.notification.type.name.toLowerCase();
    final notificationCategory =
        (widget.notification.data['notificationCategory'] ?? '')
            .toString()
            .toLowerCase();
    final allText = '$title $subtitle $body $type $notificationCategory';
    return allText.contains('speaker room') ||
        allText.contains('speaker & moderator') ||
        allText.contains('speaker moderator') ||
        allText.contains('speaker and moderator') ||
        allText.contains('speakermoderatorroom');
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

  Future<void> _markSpeakerRoomNotificationsAsRead() async {
    final userId = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (userId == null) return;
    final eventId =
        (widget.notification.data['eventId'] ?? '').toString().trim();
    final notificationsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications');
    Query<Map<String, dynamic>> query =
        notificationsRef.where('isRead', isEqualTo: false);
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
      final body =
          (data['body'] ?? data['message'] ?? '').toString().toLowerCase();
      final notificationCategory = data['data'] is Map
          ? (data['data']['notificationCategory'] ?? '')
              .toString()
              .toLowerCase()
          : '';
      final isSpeakerRoomNotification =
          type.contains('speakermoderatorroom') ||
              notificationCategory.contains('speakermoderatorroom') ||
              title.contains('speaker room') ||
              title.contains('speaker & moderator') ||
              subtitle.contains('speaker & moderator') ||
              body.contains('speaker & moderator room');
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
    setState(() => _isLoading = true);
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
        _isLoading = false;
      });
      _showSnackBar(
        cleanStatus == 'accepted'
            ? 'Meeting accepted.'
            : 'Meeting declined.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('Failed to update meeting request: $e');
    }
  }

  Future<void> _updateCurrentMeetingNotification(String status) async {
    final userId = ref.read(firebaseAuthProvider).currentUser?.uid;
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

  Future<void> _copySessionCode() async {
    if (_sessionCode.isEmpty) return;
    await Clipboard.setData(
      ClipboardData(text: _sessionCode),
    );
    if (!mounted) return;
    _showSnackBar('Session code copied.');
  }

  Future<void> _saveChanges() async {
    if (_titleController.text.trim().isEmpty) {
      _showSnackBar('Title cannot be empty');
      return;
    }
    if (_bodyController.text.trim().isEmpty) {
      _showSnackBar('Message cannot be empty');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final sharedNotificationId =
          widget.notification.data['notificationId'] as String?;
      if (sharedNotificationId == null) {
        throw Exception(
          'Notification ID not found. This notification may not support editing.',
        );
      }
      final targetRole = widget.notification.targetRole;
      final usersQuery = targetRole == 'all'
          ? FirebaseFirestore.instance
              .collection('users')
              .where('status', isEqualTo: 'approved')
          : FirebaseFirestore.instance
              .collection('users')
              .where('status', isEqualTo: 'approved')
              .where('role', isEqualTo: targetRole);
      final usersSnapshot = await usersQuery.get();
      final batch = FirebaseFirestore.instance.batch();
      int updatedCount = 0;
      for (final userDoc in usersSnapshot.docs) {
        final notificationsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userDoc.id)
            .collection('notifications')
            .where('data.notificationId', isEqualTo: sharedNotificationId)
            .limit(1)
            .get();
        if (notificationsSnapshot.docs.isNotEmpty) {
          final notificationRef = notificationsSnapshot.docs.first.reference;
          batch.update(notificationRef, {
            'title': _titleController.text.trim(),
            'subtitle': _subtitleController.text.trim().isEmpty
                ? FieldValue.delete()
                : _subtitleController.text.trim(),
            'body': _bodyController.text.trim(),
            'data.editedAt': Timestamp.now(),
          });
          updatedCount++;
        }
      }
      await batch.commit();
      if (!mounted) return;
      setState(() {
        _isEditing = false;
        _isLoading = false;
      });
      _showSnackBar('Notification updated for $updatedCount user(s)');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('Failed to update notification: $e');
    }
  }

  Future<void> _deleteNotification() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Delete Notification',
            style: TextStyle(fontSize: 16),
          ),
          content: const Text(
            'Are you sure you want to delete this notification? This action cannot be undone.',
            style: TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 12),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text(
                'Delete',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isLoading = true);
    try {
      final sharedNotificationId =
          widget.notification.data['notificationId'] as String?;
      if (sharedNotificationId == null) {
        throw Exception(
          'Notification ID not found. This notification may not support deletion.',
        );
      }
      final targetRole = widget.notification.targetRole;
      final usersQuery = targetRole == 'all'
          ? FirebaseFirestore.instance
              .collection('users')
              .where('status', isEqualTo: 'approved')
          : FirebaseFirestore.instance
              .collection('users')
              .where('status', isEqualTo: 'approved')
              .where('role', isEqualTo: targetRole);
      final usersSnapshot = await usersQuery.get();
      final batch = FirebaseFirestore.instance.batch();
      int deletedCount = 0;
      for (final userDoc in usersSnapshot.docs) {
        final notificationsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userDoc.id)
            .collection('notifications')
            .where('data.notificationId', isEqualTo: sharedNotificationId)
            .limit(1)
            .get();
        if (notificationsSnapshot.docs.isNotEmpty) {
          batch.delete(notificationsSnapshot.docs.first.reference);
          deletedCount++;
        }
      }
      await batch.commit();
      if (!mounted) return;
      Navigator.pop(context, true);
      _showSnackBar('Notification deleted for $deletedCount user(s)');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('Failed to delete notification: $e');
    }
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _titleController.text = widget.notification.title;
      _subtitleController.text = widget.notification.subtitle ?? '';
      _bodyController.text = widget.notification.body;
    });
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

  @override
  Widget build(BuildContext context) {
    final currentUserAsync = ref.watch(userAppProfileStreamProvider);
    final isAdmin = currentUserAsync.when(
      data: (user) => user?.role.toLowerCase() == 'admin',
      loading: () => false,
      error: (_, __) => false,
    );
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.namaNavyBlue,
                ),
              )
            : Column(
                children: [
                  _buildHeader(isAdmin),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTopSummary(),
                          const SizedBox(height: 22),
                          if (_isEditing) ...[
                            _buildEditableFields(),
                          ] else ...[
                            if (_hasQrAnnouncement) ...[
                              _buildQrPreviewCard(),
                              const SizedBox(height: 20),
                            ],
                            _buildMessageSection(),
                            _buildActionButtons(),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader(bool isAdmin) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 12, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back,
              color: AppColors.namaNavyBlue,
              size: 22,
            ),
          ),
          const SizedBox(width: 2),
          const Expanded(
            child: Text(
              'Notification',
              style: TextStyle(
                color: AppColors.namaNavyBlue,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (isAdmin && !_isEditing) ...[
            IconButton(
              icon: const Icon(
                Icons.edit_outlined,
                color: AppColors.namaNavyBlue,
                size: 21,
              ),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.red,
                size: 21,
              ),
              onPressed: _deleteNotification,
              tooltip: 'Delete',
            ),
          ],
          if (_isEditing) ...[
            IconButton(
              icon: const Icon(
                Icons.close,
                color: Colors.red,
                size: 21,
              ),
              onPressed: _cancelEditing,
              tooltip: 'Cancel',
            ),
            IconButton(
              icon: const Icon(
                Icons.check,
                color: AppColors.successGreen,
                size: 21,
              ),
              onPressed: _isLoading ? null : _saveChanges,
              tooltip: 'Save',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTopSummary() {
    final color = _getNotificationColor();
    final icon = _getNotificationIcon();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        border: Border(
          bottom: BorderSide(
            color: color.withOpacity(0.25),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.08),
              border: Border.all(
                color: color,
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 25,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getNotificationTypeLabel().toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: 11.5,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  widget.notification.title,
                  style: const TextStyle(
                    color: AppColors.namaNavyBlue,
                    fontSize: 20,
                    height: 1.18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if ((widget.notification.subtitle ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.notification.subtitle!,
                    style: const TextStyle(
                      color: _textMuted,
                      fontSize: 13,
                      height: 1.25,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrPreviewCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _borderColor,
        ),
      ),
      child: Column(
        children: [
          const Text(
            'Session QR Code',
            style: TextStyle(
              color: _primaryColor,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (_sessionTitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _sessionTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 13,
                height: 1.25,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (_hasQrPayload)
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.namaGoldenYellow,
                  width: 1.5,
                ),
              ),
              child: QrImageView(
                data: _qrPayload,
                version: QrVersions.auto,
                size: 170,
                backgroundColor: Colors.white,
                foregroundColor: AppColors.namaNavyBlue,
              ),
            ),
          if (_hasSessionCode) ...[
            const SizedBox(height: 14),
            InkWell(
              onTap: _copySessionCode,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 230,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _softPurple,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Session Code / PIN',
                      style: TextStyle(
                        color: _textMuted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _sessionCode,
                      style: const TextStyle(
                        color: _primaryColor,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 180,
              height: 36,
              child: OutlinedButton.icon(
                onPressed: _copySessionCode,
                icon: const Icon(
                  Icons.copy_rounded,
                  size: 15,
                ),
                label: const Text(
                  'Copy PIN',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primaryColor,
                  side: const BorderSide(
                    color: _primaryColor,
                    width: 1.2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            'Scan the QR code or copy the PIN to check in.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textMuted,
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Message',
          style: TextStyle(
            color: AppColors.namaNavyBlue,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.shade300,
            ),
          ),
          child: Text(
            widget.notification.body,
            style: const TextStyle(
              color: AppColors.namaNavyBlue,
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
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
                    onPressed: () => _respondToMeetingRequest('declined'),
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
                    onPressed: () => _respondToMeetingRequest('accepted'),
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
                      backgroundColor: AppColors.successGreen,
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: accepted
                  ? AppColors.successGreen.withOpacity(0.10)
                  : Colors.red.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: accepted
                    ? AppColors.successGreen.withOpacity(0.35)
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
                  color: accepted ? AppColors.successGreen : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  accepted ? 'Meeting accepted' : 'Meeting declined',
                  style: TextStyle(
                    color: accepted ? AppColors.successGreen : Colors.red,
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

  Widget _buildActionButtons() {
    return Column(
      children: [
        _buildMeetingResponseButtons(),
        if (_isSpeakerRoomNotification()) ...[
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
        const SizedBox(height: 12),
        Center(
          child: SizedBox(
            width: 260,
            height: 36,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.namaNavyBlue,
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
    );
  }

  Widget _buildEditableFields() {
    return Column(
      children: [
        _buildEditField(
          label: 'Title',
          controller: _titleController,
          maxLines: 2,
        ),
        const SizedBox(height: 14),
        _buildEditField(
          label: 'Subtitle',
          controller: _subtitleController,
          maxLines: 2,
        ),
        const SizedBox(height: 14),
        _buildEditField(
          label: 'Message',
          controller: _bodyController,
          maxLines: 7,
        ),
      ],
    );
  }

  Widget _buildEditField({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(
        fontSize: 13,
        color: Color(0xFF111827),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: _textMuted,
          fontSize: 12,
        ),
        contentPadding: const EdgeInsets.all(12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: _borderColor,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: _primaryColor,
            width: 1.2,
          ),
        ),
      ),
    );
  }
}
