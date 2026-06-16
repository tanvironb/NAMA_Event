// lib/features/notifications/screen/notification_detail_screen.dart
import 'package:events_app_trueattempt/core/enums/notification_type.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/models/notification_model.dart';
import 'package:events_app_trueattempt/core/providers.dart';
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

  bool get _hasQrPayload => _qrPayload.isNotEmpty;

  bool get _hasSessionCode => _sessionCode.isNotEmpty;

  bool get _hasQrAnnouncement => _hasQrPayload || _hasSessionCode;

  Future<void> _copySessionCode() async {
    if (_sessionCode.isEmpty) return;

    await Clipboard.setData(
      ClipboardData(text: _sessionCode),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Session code copied.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveChanges() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title cannot be empty')),
      );
      return;
    }

    if (_bodyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message cannot be empty')),
      );
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notification updated for $updatedCount user(s)'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update notification: $e'),
          backgroundColor: Colors.red,
        ),
      );
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notification deleted for $deletedCount user(s)'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete notification: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
    final type = widget.notification.type;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: type.color.withOpacity(0.08),
        border: Border(
          bottom: BorderSide(
            color: type.color.withOpacity(0.25),
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
              color: type.color.withOpacity(0.08),
              border: Border.all(
                color: type.color,
                width: 1.5,
              ),
            ),
            child: Icon(
              type.icon,
              color: type.color,
              size: 25,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type.displayName.toUpperCase(),
                  style: TextStyle(
                    color: type.color,
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