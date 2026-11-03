import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/models/notification_model.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/features/chat/screen/speaker_moderator_room_screen.dart';

class NotificationDetailScreen extends ConsumerStatefulWidget {
  final AppNotification notification;

  const NotificationDetailScreen({
    super.key,
    required this.notification,
  });

  /// Both the details page and list actions use the same response operation.
  ///
  /// The existing onMeetingWrite backend function creates and pushes
  /// the response notification.
  static Future<void> respondToMeeting({
    required String meetingId,
    required String status,
    String? notificationId,
  }) async {
    final auth = FirebaseAuth.instance;
    final userId = auth.currentUser?.uid;

    if (userId == null) {
      throw StateError('Please sign in again.');
    }

    if (meetingId.isEmpty || meetingId.contains('/')) {
      throw StateError('Meeting information is missing.');
    }

    if (status != 'accepted' && status != 'declined') {
      throw StateError('Invalid meeting response.');
    }

    final db = FirebaseFirestore.instance;
    final meetingRef = db.collection('meetings').doc(meetingId);

    await db.runTransaction<void>((transaction) async {
      final document = await transaction.get(meetingRef);

      if (auth.currentUser?.uid != userId) {
        throw StateError('Your signed-in account changed.');
      }

      if (!document.exists) {
        throw StateError('This meeting request no longer exists.');
      }

      final data = document.data()!;

      if (data['recipientId'] != userId) {
        throw StateError(
          'Only the recipient can respond to this request.',
        );
      }

      final currentStatus =
          (data['status'] ?? 'pending').toString().toLowerCase();

      if (currentStatus != 'pending') {
        throw StateError(
          'This meeting request has already been updated.',
        );
      }

      transaction.update(meetingRef, {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        'respondedAt': FieldValue.serverTimestamp(),
        'lastActionStatus': status,
        'lastActionBy': userId,
      });
    });

    // The meeting update has succeeded. A read-status update failure
    // must not make the app report that the response failed.
    if (notificationId != null &&
        notificationId.isNotEmpty &&
        !notificationId.contains('/') &&
        auth.currentUser?.uid == userId) {
      try {
        await db
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .doc(notificationId)
            .update({
          'isRead': true,
          'meetingStatus': status,
          'data.status': status,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (error) {
        debugPrint(
          'Meeting response saved; notification read update failed: '
          '$error',
        );
      }
    }
  }

  @override
  ConsumerState<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState
    extends ConsumerState<NotificationDetailScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _subtitleController;
  late final TextEditingController _bodyController;

  Stream<DocumentSnapshot<Map<String, dynamic>>>? _meetingStream;

  late final String? _viewerUid;

  bool _isEditing = false;
  bool _isLoading = false;
  bool _isResponding = false;

  static const Color _primaryColor = Color(0xFF1B0F72);
  static const Color _textMuted = Color(0xFF6B7280);
  static const Color _softPurple = Color(0xFFF1EEFB);
  static const Color _borderColor = Color(0xFFE1DDF0);

  String _text(dynamic value) => value?.toString().trim() ?? '';

  String get _meetingId =>
      _text(widget.notification.data['meetingId']);

  bool get _isMeeting => _meetingId.isNotEmpty;

  @override
  void initState() {
    super.initState();

    _viewerUid = FirebaseAuth.instance.currentUser?.uid;

    _titleController = TextEditingController(
      text: widget.notification.title,
    );

    _subtitleController = TextEditingController(
      text: widget.notification.subtitle ?? '',
    );

    _bodyController = TextEditingController(
      text: widget.notification.body,
    );

    _connectMeeting();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _markAsRead();
      }
    });
  }

  void _connectMeeting() {
    if (_meetingId.isEmpty || _meetingId.contains('/')) {
      _meetingStream = null;
      return;
    }

    _meetingStream = FirebaseFirestore.instance
        .collection('meetings')
        .doc(_meetingId)
        .snapshots();
  }

  Future<void> _markAsRead() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null ||
        userId != _viewerUid ||
        widget.notification.id.isEmpty) {
      return;
    }

    try {
      await ref
          .read(notificationRepositoryProvider)
          .markAsRead(userId, widget.notification.id);
    } catch (error) {
      debugPrint('Unable to mark notification as read: $error');
    }
  }

  String get _qrPayload {
    final value = widget.notification.qrPayload.trim();

    return value.isNotEmpty
        ? value
        : _text(widget.notification.data['qrPayload']);
  }

  String get _sessionCode {
    final value = widget.notification.sessionCode.trim();

    return value.isNotEmpty
        ? value
        : _text(widget.notification.data['sessionCode']);
  }

  String get _sessionTitle {
    for (final value in [
      widget.notification.sessionTitle,
      widget.notification.data['sessionTitle'],
      widget.notification.subtitle,
      widget.notification.eventName,
    ]) {
      final text = _text(value);

      if (text.isNotEmpty) return text;
    }

    return '';
  }

  bool get _hasQrAnnouncement =>
      _qrPayload.isNotEmpty || _sessionCode.isNotEmpty;

  bool get _isSpeakerRoom {
    final text = [
      widget.notification.type.name,
      _titleController.text,
      _subtitleController.text,
      _bodyController.text,
      widget.notification.data['notificationCategory'],
    ].join(' ').toLowerCase();

    return text.contains('speaker room') ||
        text.contains('speaker & moderator') ||
        text.contains('speaker moderator') ||
        text.contains('speaker and moderator') ||
        text.contains('speakermoderatorroom');
  }

  Color get _notificationColor {
    final text =
        '${widget.notification.type.name} ${_titleController.text}'
            .toLowerCase();

    if (text.contains('accepted')) {
      return AppColors.successGreen;
    }

    if (text.contains('declined') ||
        text.contains('rejected') ||
        text.contains('cancelled')) {
      return Colors.red;
    }

    return AppColors.namaNavyBlue;
  }

  IconData get _notificationIcon {
    final text = [
      widget.notification.type.name,
      _titleController.text,
      _bodyController.text,
    ].join(' ').toLowerCase();

    if (text.contains('accepted')) {
      return Icons.check_circle_outline_rounded;
    }

    if (text.contains('declined') ||
        text.contains('rejected') ||
        text.contains('cancelled')) {
      return Icons.cancel_outlined;
    }

    if (_isMeeting || text.contains('meeting')) {
      return Icons.handshake_outlined;
    }

    if (_isSpeakerRoom) return Icons.groups_2_outlined;
    if (_hasQrAnnouncement) return Icons.qr_code_2_rounded;
    if (text.contains('session')) return Icons.event_note_outlined;

    return Icons.notifications_none_rounded;
  }

  String get _typeLabel {
    final type = widget.notification.type.name;

    switch (type.toLowerCase()) {
      case 'meetingrequest':
        return 'Meeting Request';
      case 'meetingaccepted':
        return 'Meeting Accepted';
      case 'meetingdeclined':
        return 'Meeting Declined';
      case 'speakermoderatorroom':
        return 'Speaker Room';
      default:
        return type.isEmpty ? 'Notification' : type;
    }
  }

  Future<void> _respondToMeeting(String status) async {
    if (_isResponding) return;

    setState(() {
      _isResponding = true;
    });

    try {
      await NotificationDetailScreen.respondToMeeting(
        meetingId: _meetingId,
        status: status,
        notificationId: widget.notification.id,
      );

      if (!mounted) return;

      _showSnackBar(
        status == 'accepted'
            ? 'Meeting request approved.'
            : 'Meeting request rejected.',
      );
    } catch (error) {
      if (mounted) {
        _showSnackBar('Unable to respond: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResponding = false;
        });
      }
    }
  }

  Future<void> _openSpeakerRoom() async {
    if (_isLoading) return;

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null || userId != _viewerUid) return;

      final notifications = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications');

      Query<Map<String, dynamic>> query =
          notifications.where('isRead', isEqualTo: false);

      final eventId = _text(widget.notification.data['eventId']);

      if (eventId.isNotEmpty) {
        query = query.where('eventId', isEqualTo: eventId);
      }

      final snapshot = await query.get();

      var batch = FirebaseFirestore.instance.batch();
      var count = 0;

      for (final document in snapshot.docs) {
        final data = document.data();
        final nested = data['data'];

        final text = [
          data['type'],
          data['title'],
          data['subtitle'],
          data['body'],
          data['message'],
          if (nested is Map) nested['notificationCategory'],
        ].join(' ').toLowerCase();

        if (!text.contains('speakermoderatorroom') &&
            !text.contains('speaker room') &&
            !text.contains('speaker & moderator')) {
          continue;
        }

        batch.update(document.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });

        count++;

        if (count == 450) {
          await batch.commit();
          batch = FirebaseFirestore.instance.batch();
          count = 0;
        }
      }

      if (count > 0) {
        await batch.commit();
      }

      if (!mounted ||
          FirebaseAuth.instance.currentUser?.uid != _viewerUid) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const SpeakerModeratorRoomScreen(),
        ),
      );
    } catch (error) {
      if (mounted) {
        _showSnackBar('Unable to open Speaker Room: $error');
      }
    }
  }

  Future<void> _copySessionCode() async {
    if (_sessionCode.isEmpty) return;

    await Clipboard.setData(
      ClipboardData(text: _sessionCode),
    );

    if (mounted) {
      _showSnackBar('Session code copied.');
    }
  }

  Future<void> _saveChanges() async {
    if (_titleController.text.trim().isEmpty) {
      _showSnackBar('Title cannot be empty.');
      return;
    }

    if (_bodyController.text.trim().isEmpty) {
      _showSnackBar('Message cannot be empty.');
      return;
    }

    await _updateBroadcast(delete: false);
  }

  Future<void> _deleteNotification() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Notification'),
        content: const Text(
          'Are you sure you want to delete this notification? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _updateBroadcast(delete: true);
    }
  }

  Future<void> _updateBroadcast({
    required bool delete,
  }) async {
    if (_isLoading) return;

    final sharedId =
        _text(widget.notification.data['notificationId']);

    if (sharedId.isEmpty) {
      _showSnackBar(
        'This notification does not have a shared ID '
        'for editing or deletion.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final db = FirebaseFirestore.instance;
      final role = widget.notification.targetRole;

      Query<Map<String, dynamic>> usersQuery =
          db.collection('users').where(
                'status',
                isEqualTo: 'approved',
              );

      if (role != 'all') {
        usersQuery = usersQuery.where('role', isEqualTo: role);
      }

      final users = await usersQuery.get();

      var batch = db.batch();
      var pending = 0;
      var total = 0;

      for (final user in users.docs) {
        final notifications = await user.reference
            .collection('notifications')
            .where('data.notificationId', isEqualTo: sharedId)
            .limit(1)
            .get();

        if (notifications.docs.isEmpty) continue;

        final reference = notifications.docs.first.reference;

        if (delete) {
          batch.delete(reference);
        } else {
          batch.update(reference, {
            'title': _titleController.text.trim(),
            'subtitle': _subtitleController.text.trim().isEmpty
                ? FieldValue.delete()
                : _subtitleController.text.trim(),
            'body': _bodyController.text.trim(),
            'data.editedAt': Timestamp.now(),
          });
        }

        pending++;
        total++;

        if (pending == 450) {
          await batch.commit();
          batch = db.batch();
          pending = 0;
        }
      }

      if (pending > 0) {
        await batch.commit();
      }

      if (!mounted) return;

      if (delete) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _isEditing = false;
        });

        _showSnackBar(
          'Notification updated for $total user(s).',
        );
      }
    } catch (error) {
      if (mounted) {
        _showSnackBar(
          'Unable to ${delete ? 'delete' : 'update'} '
          'notification: $error',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _titleController.text = widget.notification.title;
      _subtitleController.text =
          widget.notification.subtitle ?? '';
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
    final currentUser = ref.watch(userAppProfileStreamProvider);

    final isAdmin = currentUser.when(
      data: (user) => user?.role.toLowerCase() == 'admin',
      loading: () => false,
      error: (_, __) => false,
    );

    if (_viewerUid == null ||
        FirebaseAuth.instance.currentUser?.uid != _viewerUid) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notification')),
        body: const Center(
          child: Text(
            'Sign in to the account that received this notification.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

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
                      padding: const EdgeInsets.fromLTRB(
                        18,
                        8,
                        18,
                        28,
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          _buildTopSummary(),
                          const SizedBox(height: 22),
                          if (_isEditing)
                            _buildEditableFields()
                          else ...[
                            if (_hasQrAnnouncement) ...[
                              _buildQrPreviewCard(),
                              const SizedBox(height: 20),
                            ],
                            _buildMessageSection(),
                            if (_isMeeting) ...[
                              const SizedBox(height: 20),
                              _buildMeetingSection(),
                            ],
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
              tooltip: 'Edit',
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
              icon: const Icon(
                Icons.edit_outlined,
                color: AppColors.namaNavyBlue,
                size: 21,
              ),
            ),
            IconButton(
              tooltip: 'Delete',
              onPressed: _deleteNotification,
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.red,
                size: 21,
              ),
            ),
          ],
          if (_isEditing) ...[
            IconButton(
              tooltip: 'Cancel',
              onPressed: _cancelEditing,
              icon: const Icon(
                Icons.close,
                color: Colors.red,
                size: 21,
              ),
            ),
            IconButton(
              tooltip: 'Save',
              onPressed: _isLoading ? null : _saveChanges,
              icon: const Icon(
                Icons.check,
                color: AppColors.successGreen,
                size: 21,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTopSummary() {
    final color = _notificationColor;

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
              _notificationIcon,
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
                  _typeLabel.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: 11.5,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  _titleController.text,
                  style: const TextStyle(
                    color: AppColors.namaNavyBlue,
                    fontSize: 20,
                    height: 1.18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (_subtitleController.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _subtitleController.text,
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
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            _bodyController.text,
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

  Widget _buildMeetingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Meeting Details',
          style: TextStyle(
            color: AppColors.namaNavyBlue,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        if (_meetingStream == null)
          const Text('Meeting information is unavailable.')
        else
          StreamBuilder<
              DocumentSnapshot<Map<String, dynamic>>>(
            stream: _meetingStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Unable to load meeting details.',
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(_connectMeeting);
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                );
              }

              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.namaNavyBlue,
                    ),
                  ),
                );
              }

              if (!snapshot.data!.exists) {
                return const Text(
                  'This meeting request is no longer available.',
                );
              }

              final meeting = snapshot.data!.data()!;
              final requesterId = _text(meeting['requesterId']);
              final recipientId = _text(meeting['recipientId']);

              if (_viewerUid != requesterId &&
                  _viewerUid != recipientId) {
                return const Text(
                  'This meeting belongs to another account.',
                );
              }

              final requesterInfo = meeting['requesterInfo'];
              final recipientInfo = meeting['recipientInfo'];

              final requesterName = requesterInfo is Map
                  ? _text(requesterInfo['name'])
                  : '';

              final recipientName = recipientInfo is Map
                  ? _text(recipientInfo['name'])
                  : '';

              final rawTime = meeting['proposedTime'];

              final DateTime? time = rawTime is Timestamp
                  ? rawTime.toDate().toLocal()
                  : rawTime is DateTime
                      ? rawTime.toLocal()
                      : DateTime.tryParse(_text(rawTime))
                          ?.toLocal();

              final status = _text(
                meeting['status'] ?? 'pending',
              ).toLowerCase();

              final location = _text(meeting['location']);

              final canRespond =
                  recipientId == _viewerUid &&
                  status == 'pending';

              final String statusLabel;

              switch (status) {
                case 'accepted':
                case 'approved':
                  statusLabel = 'Approved';
                  break;
                case 'declined':
                case 'rejected':
                  statusLabel = 'Rejected';
                  break;
                case 'cancelled':
                case 'canceled':
                  statusLabel = 'Cancelled';
                  break;
                case 'pending':
                  statusLabel = 'Pending';
                  break;
                default:
                  statusLabel = status;
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _softPurple,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Column(
                      children: [
                        _meetingRow(
                          Icons.person_outline,
                          'Requested by',
                          requesterName.isEmpty
                              ? 'Participant'
                              : requesterName,
                        ),
                        _meetingRow(
                          Icons.people_outline,
                          'Meeting with',
                          recipientName.isEmpty
                              ? 'Participant'
                              : recipientName,
                        ),
                        _meetingRow(
                          Icons.calendar_today_outlined,
                          'Date',
                          time == null
                              ? 'Unavailable'
                              : DateFormat(
                                  'EEEE, d MMM yyyy',
                                ).format(time),
                        ),
                        _meetingRow(
                          Icons.access_time,
                          'Time',
                          time == null
                              ? 'Unavailable'
                              : DateFormat('h:mm a').format(time),
                        ),
                        _meetingRow(
                          Icons.location_on_outlined,
                          'Location',
                          location.isEmpty
                              ? 'Not specified'
                              : location,
                        ),
                        _meetingRow(
                          Icons.info_outline,
                          'Status',
                          statusLabel,
                        ),
                      ],
                    ),
                  ),
                  if (canRespond) ...[
                    const SizedBox(height: 16),
                    if (_isResponding)
                      const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.namaNavyBlue,
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                _respondToMeeting('declined');
                              },
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 16,
                              ),
                              label: const Text('Reject'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(
                                  color: Colors.red,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(18),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                _respondToMeeting('accepted');
                              },
                              icon: const Icon(
                                Icons.check_rounded,
                                size: 16,
                              ),
                              label: const Text('Approve'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    AppColors.successGreen,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(18),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ],
              );
            },
          ),
        const SizedBox(height: 14),
        const Text(
          'For more details, check My Meetings from your profile.',
          style: TextStyle(
            color: _textMuted,
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _meetingRow(
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: AppColors.namaNavyBlue,
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                color: _textMuted,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.namaNavyBlue,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
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
        border: Border.all(color: _borderColor),
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
          if (_qrPayload.isNotEmpty)
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
          if (_sessionCode.isNotEmpty) ...[
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
                label: const Text('Copy PIN'),
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

  Widget _buildActionButtons() {
    return Column(
      children: [
        if (_isSpeakerRoom) ...[
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
          borderSide: const BorderSide(color: _borderColor),
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

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }
}