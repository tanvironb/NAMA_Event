// lib/features/web_admin/event_workspace/Screens/admin_web_notifications_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../admin_web_theme.dart';

class AdminWebNotificationsScreen extends StatefulWidget {
  final String eventId;
  final String eventName;

  const AdminWebNotificationsScreen({
    super.key,
    required this.eventId,
    required this.eventName,
  });

  @override
  State<AdminWebNotificationsScreen> createState() =>
      _AdminWebNotificationsScreenState();
}

class _AdminWebNotificationsScreenState
    extends State<AdminWebNotificationsScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _bodyController = TextEditingController();

  String _selectedType = 'announcement';
  String _selectedAudience = 'all';
  bool _sending = false;

  static const Map<String, String> _notificationTypes = {
    'announcement': 'Announcement',
    'information': 'Information',
    'alert': 'Alert',
    'maintenance': 'Maintenance',
  };

  static const Map<String, String> _audiences = {
    'all': 'All Event Users',
    'attendee': 'Attendees',
    'staff': 'Staff',
    'speaker': 'Speakers',
    'moderator': 'Moderators',
  };

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Query<Map<String, dynamic>> _recipientQuery() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('users')
        .where('eventIds', arrayContains: widget.eventId);

    if (_selectedAudience != 'all') {
      query = query.where(
        'role',
        isEqualTo: _selectedAudience,
      );
    }

    return query;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _historyStream() {
    return FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .collection('admin_notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  Future<int> _recipientCount() async {
    final snapshot = await _recipientQuery().get();
    return snapshot.docs.length;
  }

  Future<void> _confirmAndSend() async {
    FocusScope.of(context).unfocus();

    if (_sending || !_formKey.currentState!.validate()) {
      return;
    }

    int count;

    try {
      count = await _recipientCount();
    } catch (error) {
      _showMessage(
        'Failed to count recipients: $error',
        error: true,
      );
      return;
    }

    if (count == 0) {
      _showMessage(
        'No users match the selected audience for this event.',
        error: true,
      );
      return;
    }

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Send Notification?',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'This notification will be sent to $count '
            '${count == 1 ? 'user' : 'users'} in ${widget.eventName}.\n\n'
            'Audience: ${_audiences[_selectedAudience]}\n'
            'Type: ${_notificationTypes[_selectedType]}',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(true),
              icon: const Icon(
                Icons.send_rounded,
                size: 18,
              ),
              label: const Text('Send Now'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _sendNotification();
    }
  }

  Future<void> _sendNotification() async {
    setState(() => _sending = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final recipientsSnapshot = await _recipientQuery().get();

      if (recipientsSnapshot.docs.isEmpty) {
        throw Exception(
          'No users match the selected audience.',
        );
      }

      final adminUser = FirebaseAuth.instance.currentUser;
      final historyReference = firestore
          .collection('events')
          .doc(widget.eventId)
          .collection('admin_notifications')
          .doc();

      final title = _titleController.text.trim();
      final subtitle = _subtitleController.text.trim();
      final body = _bodyController.text.trim();

      final commonNotificationData = <String, dynamic>{
        'title': title,
        'subtitle': subtitle.isEmpty ? null : subtitle,
        'body': body,
        'timestamp': FieldValue.serverTimestamp(),
        'timeFrom': null,
        'timeTo': null,
        'isRead': false,
        'type': _selectedType,
        'targetRole': _selectedAudience,
        'eventId': widget.eventId,
        'eventName': widget.eventName,
        'createdBy': adminUser?.uid ?? '',
        'createdByEmail': adminUser?.email ?? '',
        'source': 'admin_web',
        'data': <String, dynamic>{
          'type': _selectedType,
          'eventId': widget.eventId,
          'eventName': widget.eventName,
          'notificationId': historyReference.id,
          'targetRole': _selectedAudience,
        },
      };

      // Firestore batches allow up to 500 writes.
      // Keep room for safety and write recipients in chunks.
      const chunkSize = 450;
      final recipients = recipientsSnapshot.docs;

      for (int start = 0;
          start < recipients.length;
          start += chunkSize) {
        final end = (start + chunkSize < recipients.length)
            ? start + chunkSize
            : recipients.length;

        final batch = firestore.batch();

        for (final recipient in recipients.sublist(start, end)) {
          final notificationReference = firestore
              .collection('users')
              .doc(recipient.id)
              .collection('notifications')
              .doc();

          batch.set(
            notificationReference,
            {
              ...commonNotificationData,
              'recipientId': recipient.id,
              'notificationId': notificationReference.id,
            },
          );
        }

        await batch.commit();
      }

      await historyReference.set({
        'id': historyReference.id,
        'eventId': widget.eventId,
        'eventName': widget.eventName,
        'title': title,
        'subtitle': subtitle,
        'body': body,
        'type': _selectedType,
        'targetRole': _selectedAudience,
        'recipientCount': recipients.length,
        'status': 'sent',
        'createdBy': adminUser?.uid ?? '',
        'createdByEmail': adminUser?.email ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      _titleController.clear();
      _subtitleController.clear();
      _bodyController.clear();

      setState(() {
        _selectedType = 'announcement';
        _selectedAudience = 'all';
      });

      _showMessage(
        'Notification sent to ${recipients.length} '
        '${recipients.length == 1 ? 'user' : 'users'}.',
      );
    } catch (error) {
      _showMessage(
        'Failed to send notification: $error',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _deleteHistory(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete History Record?',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const Text(
            'This removes the notification from the admin history only. '
            'It does not remove notifications already delivered to users.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () =>
                  Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await document.reference.delete();

      _showMessage('Notification history record deleted.');
    } catch (error) {
      _showMessage(
        'Failed to delete history record: $error',
        error: true,
      );
    }
  }

  void _showMessage(
    String message, {
    bool error = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? Colors.redAccent : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PageHeader(
            eventName: widget.eventName,
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 1000) {
                return Column(
                  children: [
                    _buildComposer(),
                    const SizedBox(height: 18),
                    _buildPreview(),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: _buildComposer(),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    flex: 4,
                    child: _buildPreview(),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          _buildHistory(),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    return _SectionCard(
      icon: Icons.edit_notifications_outlined,
      title: 'Compose Notification',
      subtitle:
          'Create an in-app and push notification for users in this event.',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _ResponsiveFields(
              children: [
                _DropdownField(
                  label: 'Audience',
                  value: _selectedAudience,
                  icon: Icons.groups_outlined,
                  items: _audiences,
                  onChanged: _sending
                      ? null
                      : (value) {
                          if (value == null) return;

                          setState(() {
                            _selectedAudience = value;
                          });
                        },
                ),
                _DropdownField(
                  label: 'Notification Type',
                  value: _selectedType,
                  icon: Icons.category_outlined,
                  items: _notificationTypes,
                  onChanged: _sending
                      ? null
                      : (value) {
                          if (value == null) return;

                          setState(() {
                            _selectedType = value;
                          });
                        },
                ),
              ],
            ),
            const SizedBox(height: 15),
            _TextField(
              label: 'Title',
              hint: 'Enter notification title',
              controller: _titleController,
              icon: Icons.title_rounded,
              enabled: !_sending,
              maxLength: 80,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Notification title is required';
                }

                return null;
              },
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 15),
            _TextField(
              label: 'Subtitle',
              hint: 'Optional short subtitle',
              controller: _subtitleController,
              icon: Icons.short_text_rounded,
              enabled: !_sending,
              maxLength: 120,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 15),
            _TextField(
              label: 'Message',
              hint:
                  'Write the notification message users should receive',
              controller: _bodyController,
              icon: Icons.message_outlined,
              enabled: !_sending,
              maxLength: 500,
              maxLines: 6,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Notification message is required';
                }

                return null;
              },
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: AdminWebTheme.textSecondary,
                  size: 17,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'A notification document is created for every matching event user. '
                    'Your existing Firebase trigger then sends the push notification.',
                    style: TextStyle(
                      color: AdminWebTheme.textSecondary,
                      fontSize: 9.5,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed:
                      _sending ? null : _confirmAndSend,
                  icon: _sending
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          size: 18,
                        ),
                  label: Text(
                    _sending
                        ? 'Sending...'
                        : 'Send Notification',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AdminWebTheme.primary,
                    minimumSize: const Size(170, 43),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final title = _titleController.text.trim();
    final subtitle = _subtitleController.text.trim();
    final body = _bodyController.text.trim();

    return _SectionCard(
      icon: Icons.phone_iphone_rounded,
      title: 'Live Preview',
      subtitle:
          'Preview how the notification content will appear.',
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFBFD),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: AdminWebTheme.border,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TypeIcon(type: _selectedType),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'NAMA Events',
                              style: TextStyle(
                                color:
                                    AdminWebTheme.textPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            _notificationTypes[
                                    _selectedType] ??
                                '',
                            style: const TextStyle(
                              color:
                                  AdminWebTheme.textSecondary,
                              fontSize: 8.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title.isEmpty
                            ? 'Notification title'
                            : title,
                        style: TextStyle(
                          color: title.isEmpty
                              ? AdminWebTheme.textSecondary
                              : AdminWebTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color:
                                AdminWebTheme.textSecondary,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        body.isEmpty
                            ? 'Your notification message will appear here.'
                            : body,
                        style: TextStyle(
                          color: body.isEmpty
                              ? AdminWebTheme.textSecondary
                              : AdminWebTheme.textPrimary,
                          fontSize: 10,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _PreviewInfoRow(
            label: 'Event',
            value: widget.eventName,
          ),
          _PreviewInfoRow(
            label: 'Audience',
            value: _audiences[_selectedAudience] ?? '',
          ),
          _PreviewInfoRow(
            label: 'Type',
            value: _notificationTypes[_selectedType] ?? '',
          ),
        ],
      ),
    );
  }

  Widget _buildHistory() {
    return _SectionCard(
      icon: Icons.history_rounded,
      title: 'Notification History',
      subtitle:
          'Recently sent notifications for this event.',
      child: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: _historyStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const SizedBox(
              height: 150,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (snapshot.hasError) {
            return _InlineMessage(
              icon: Icons.error_outline_rounded,
              title: 'Could not load notification history',
              message: snapshot.error.toString(),
            );
          }

          final documents = snapshot.data?.docs ?? [];

          if (documents.isEmpty) {
            return const _InlineMessage(
              icon: Icons.notifications_none_rounded,
              title: 'No notifications sent yet',
              message:
                  'Notifications sent from this page will appear here.',
            );
          }

          return Column(
            children: documents.map((document) {
              return _HistoryRow(
                document: document,
                onDelete: () => _deleteHistory(document),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  final String eventName;

  const _PageHeader({
    required this.eventName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eventName.toUpperCase(),
          style: const TextStyle(
            color: AdminWebTheme.primary,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Notifications',
          style: TextStyle(
            color: AdminWebTheme.textPrimary,
            fontSize: 27,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Send announcements, information, alerts, and maintenance updates to event users.',
          style: TextStyle(
            color: AdminWebTheme.textSecondary,
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: AdminWebTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                  color:
                      AdminWebTheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: AdminWebTheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color:
                            AdminWebTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color:
                            AdminWebTheme.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _ResponsiveFields extends StatelessWidget {
  final List<Widget> children;

  const _ResponsiveFields({
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 650) {
          return Column(
            children: [
              for (int index = 0;
                  index < children.length;
                  index++) ...[
                children[index],
                if (index < children.length - 1)
                  const SizedBox(height: 14),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            for (int index = 0;
                index < children.length;
                index++) ...[
              Expanded(child: children[index]),
              if (index < children.length - 1)
                const SizedBox(width: 14),
            ],
          ],
        );
      },
    );
  }
}

class _TextField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData icon;
  final bool enabled;
  final int maxLength;
  final int maxLines;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  const _TextField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.icon,
    required this.enabled,
    required this.maxLength,
    this.maxLines = 1,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          enabled: enabled,
          maxLength: maxLength,
          maxLines: maxLines,
          validator: validator,
          onChanged: onChanged,
          decoration: _inputDecoration(
            hint: hint,
            icon: icon,
          ).copyWith(
            counterText:
                '${controller.text.length}/$maxLength',
          ),
        ),
      ],
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Map<String, String> items;
  final ValueChanged<String?>? onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.icon,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 7),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          onChanged: onChanged,
          items: items.entries.map((entry) {
            return DropdownMenuItem(
              value: entry.key,
              child: Text(entry.value),
            );
          }).toList(),
          decoration: _inputDecoration(
            hint: '',
            icon: icon,
          ),
        ),
      ],
    );
  }
}

InputDecoration _inputDecoration({
  required String hint,
  required IconData icon,
}) {
  return InputDecoration(
    hintText: hint,
    prefixIcon: Icon(
      icon,
      size: 19,
      color: AdminWebTheme.primary,
    ),
    filled: true,
    fillColor: const Color(0xFFFAFBFD),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 14,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(
        color: AdminWebTheme.border,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(
        color: AdminWebTheme.primary,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(
        color: Colors.redAccent,
      ),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(
        color: Colors.redAccent,
      ),
    ),
  );
}

class _TypeIcon extends StatelessWidget {
  final String type;

  const _TypeIcon({
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (type) {
      case 'alert':
        icon = Icons.warning_amber_rounded;
        color = Colors.redAccent;
        break;
      case 'information':
        icon = Icons.info_outline_rounded;
        color = Colors.blue;
        break;
      case 'maintenance':
        icon = Icons.build_outlined;
        color = Colors.orange;
        break;
      default:
        icon = Icons.campaign_outlined;
        color = AdminWebTheme.primary;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        color: color,
        size: 20,
      ),
    );
  }
}

class _PreviewInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _PreviewInfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          SizedBox(
            width: 75,
            child: Text(
              label,
              style: const TextStyle(
                color:
                    AdminWebTheme.textSecondary,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color:
                    AdminWebTheme.textPrimary,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>>
      document;
  final VoidCallback onDelete;

  const _HistoryRow({
    required this.document,
    required this.onDelete,
  });

  String _formatDate(dynamic value) {
    if (value is! Timestamp) {
      return 'Just now';
    }

    final date = value.toDate();
    final day = date.day.toString().padLeft(2, '0');
    final month =
        date.month.toString().padLeft(2, '0');
    final hour =
        date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute =
        date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '$day/$month/${date.year} • '
        '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final data = document.data();

    final type =
        (data['type'] ?? 'announcement').toString();
    final audience =
        (data['targetRole'] ?? 'all').toString();
    final title =
        (data['title'] ?? 'Untitled Notification')
            .toString();
    final subtitle =
        (data['subtitle'] ?? '').toString();
    final body = (data['body'] ?? '').toString();
    final count = data['recipientCount'] is num
        ? (data['recipientCount'] as num).toInt()
        : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AdminWebTheme.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TypeIcon(type: type),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color:
                              AdminWebTheme.textPrimary,
                          fontSize: 11.5,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      _formatDate(data['createdAt']),
                      style: const TextStyle(
                        color:
                            AdminWebTheme.textSecondary,
                        fontSize: 8.5,
                      ),
                    ),
                  ],
                ),
                if (subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color:
                          AdminWebTheme.textSecondary,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 5),
                Text(
                  body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color:
                        AdminWebTheme.textSecondary,
                    fontSize: 9.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _HistoryChip(
                      label:
                          _AdminWebNotificationsScreenState
                                  ._notificationTypes[type] ??
                              type,
                    ),
                    _HistoryChip(
                      label:
                          _AdminWebNotificationsScreenState
                                  ._audiences[audience] ??
                              audience,
                    ),
                    _HistoryChip(
                      label:
                          '$count ${count == 1 ? 'recipient' : 'recipients'}',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Delete history record',
            onPressed: onDelete,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.redAccent,
              size: 19,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryChip extends StatelessWidget {
  final String label;

  const _HistoryChip({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color:
            AdminWebTheme.primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AdminWebTheme.primary,
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _InlineMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 32,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFD),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: AdminWebTheme.border,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: AdminWebTheme.primary,
            size: 30,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AdminWebTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AdminWebTheme.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AdminWebTheme.textPrimary,
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
