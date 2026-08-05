// lib/features/web_admin/event_workspace/Screens/admin_web_help_center_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:events_app_trueattempt/core/models/help_ticket_model.dart';
import 'package:events_app_trueattempt/features/help/data/help_repository.dart';

import '../../admin_web_theme.dart';

final adminWebHelpRepositoryProvider = Provider<HelpRepository>(
  (ref) => HelpRepository(FirebaseFirestore.instance),
);

class AdminWebHelpCenterScreen extends ConsumerStatefulWidget {
  final String eventId;
  final String eventName;

  const AdminWebHelpCenterScreen({
    super.key,
    required this.eventId,
    required this.eventName,
  });

  @override
  ConsumerState<AdminWebHelpCenterScreen> createState() =>
      _AdminWebHelpCenterScreenState();
}

class _AdminWebHelpCenterScreenState
    extends ConsumerState<AdminWebHelpCenterScreen> {
  final _searchController = TextEditingController();
  String _search = '';
  String _filter = 'all';

  static const filters = <String, String>{
    'all': 'All',
    TicketStatus.pending: 'Pending',
    TicketStatus.critical: 'Critical',
    TicketStatus.processing: 'Processing',
    TicketStatus.processed: 'Processed',
    TicketStatus.spam: 'Spam',
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<HelpTicket> _filtered(List<HelpTicket> tickets) {
    final query = _search.trim().toLowerCase();

    return tickets.where((ticket) {
      if (ticket.eventId != widget.eventId) return false;
      if (_filter != 'all' && ticket.status != _filter) return false;
      if (query.isEmpty) return true;

      return [
        ticket.userName,
        ticket.userEmail,
        ticket.subject,
        ticket.message,
        ticket.status,
      ].join(' ').toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(adminWebHelpRepositoryProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.eventName.toUpperCase(),
            style: const TextStyle(
              color: AdminWebTheme.primary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Help Center',
            style: TextStyle(
              color: AdminWebTheme.textPrimary,
              fontSize: 27,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Review event support requests, update progress, and reply directly to the user who reported the issue.',
            style: TextStyle(
              color: AdminWebTheme.textSecondary,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          StreamBuilder<List<HelpTicket>>(
            stream: repository.getTicketsByEventStream(widget.eventId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _LoadingCard();
              }

              if (snapshot.hasError) {
                return _EmptyCard(
                  icon: Icons.error_outline_rounded,
                  title: 'Could not load tickets',
                  message: snapshot.error.toString(),
                );
              }

              final allTickets = snapshot.data ?? <HelpTicket>[];
              final tickets = _filtered(allTickets);

              return Column(
                children: [
                  _Stats(tickets: allTickets),
                  const SizedBox(height: 18),
                  _Toolbar(
                    controller: _searchController,
                    selectedFilter: _filter,
                    onSearch: (value) {
                      setState(() => _search = value);
                    },
                    onClear: () {
                      _searchController.clear();
                      setState(() => _search = '');
                    },
                    onFilter: (value) {
                      setState(() => _filter = value);
                    },
                  ),
                  const SizedBox(height: 18),
                  if (tickets.isEmpty)
                    _EmptyCard(
                      icon: Icons.inbox_outlined,
                      title: allTickets.isEmpty
                          ? 'No tickets for this event'
                          : 'No matching tickets',
                      message: allTickets.isEmpty
                          ? 'Only help requests submitted from ${widget.eventName} will appear here.'
                          : 'Try changing the search or status filter.',
                    )
                  else
                    _TicketsTable(
                      tickets: tickets,
                      onOpen: (ticket) {
                        showDialog<void>(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => _TicketDialog(
                            eventId: widget.eventId,
                            eventName: widget.eventName,
                            ticket: ticket,
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  final List<HelpTicket> tickets;

  const _Stats({required this.tickets});

  int count(String status) =>
      tickets.where((ticket) => ticket.status == status).length;

  @override
  Widget build(BuildContext context) {
    final values = [
      ('All Tickets', tickets.length, Icons.confirmation_number_outlined),
      ('Pending', count(TicketStatus.pending), Icons.schedule_rounded),
      ('Processing', count(TicketStatus.processing), Icons.sync_rounded),
      ('Critical', count(TicketStatus.critical), Icons.warning_amber_rounded),
      ('Processed', count(TicketStatus.processed), Icons.check_circle_outline),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 700
            ? 1
            : constraints.maxWidth < 1050
                ? 2
                : constraints.maxWidth < 1300
                    ? 3
                    : 5;
        const spacing = 12.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: values.map((item) {
            return SizedBox(
              width: width,
              child: Container(
                height: 90,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: AdminWebTheme.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AdminWebTheme.primary.withOpacity(.08),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        item.$3,
                        color: AdminWebTheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.$2}',
                          style: const TextStyle(
                            color: AdminWebTheme.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          item.$1,
                          style: const TextStyle(
                            color: AdminWebTheme.textSecondary,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _Toolbar extends StatelessWidget {
  final TextEditingController controller;
  final String selectedFilter;
  final ValueChanged<String> onSearch;
  final VoidCallback onClear;
  final ValueChanged<String> onFilter;

  const _Toolbar({
    required this.controller,
    required this.selectedFilter,
    required this.onSearch,
    required this.onClear,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AdminWebTheme.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final search = TextField(
            controller: controller,
            onChanged: onSearch,
            decoration: _inputDecoration(
              hint: 'Search by user, email, subject, message, or status',
              icon: Icons.search_rounded,
            ).copyWith(
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: onClear,
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
            ),
          );

          final filter = DropdownButtonFormField<String>(
            value: selectedFilter,
            isExpanded: true,
            decoration: _inputDecoration(
              hint: '',
              icon: Icons.filter_alt_outlined,
            ),
            items: _AdminWebHelpCenterScreenState.filters.entries
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) onFilter(value);
            },
          );

          if (constraints.maxWidth < 720) {
            return Column(
              children: [
                search,
                const SizedBox(height: 12),
                filter,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 12),
              SizedBox(width: 220, child: filter),
            ],
          );
        },
      ),
    );
  }
}

class _TicketsTable extends StatelessWidget {
  final List<HelpTicket> tickets;
  final ValueChanged<HelpTicket> onOpen;

  const _TicketsTable({
    required this.tickets,
    required this.onOpen,
  });

  String formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '$day/$month/${value.year} • $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AdminWebTheme.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 900) {
            return Column(
              children: tickets.map((ticket) {
                return ListTile(
                  onTap: () => onOpen(ticket),
                  leading: _Avatar(name: ticket.userName),
                  title: Text(
                    ticket.subject,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    '${ticket.userName}\n${ticket.message}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9.5),
                  ),
                  trailing: _StatusBadge(status: ticket.status),
                );
              }).toList(),
            );
          }

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFFFAFBFD),
                ),
                headingRowHeight: 46,
                dataRowMinHeight: 56,
                dataRowMaxHeight: 64,
                columnSpacing: 28,
                horizontalMargin: 18,
                headingTextStyle: const TextStyle(
                  color: AdminWebTheme.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
                dataTextStyle: const TextStyle(
                  color: AdminWebTheme.textPrimary,
                  fontSize: 10.5,
                ),
                columns: const [
                  DataColumn(label: Text('USER')),
                  DataColumn(label: Text('SUBJECT')),
                  DataColumn(label: Text('MESSAGE')),
                  DataColumn(label: Text('STATUS')),
                  DataColumn(label: Text('CREATED')),
                  DataColumn(label: Text('ACTIONS')),
                ],
                rows: tickets.map((ticket) {
                  return DataRow(
                    cells: [
                      DataCell(
                        SizedBox(
                          width: 210,
                          child: Row(
                            children: [
                              _Avatar(name: ticket.userName),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ticket.userName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      ticket.userEmail,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AdminWebTheme.textSecondary,
                                        fontSize: 8.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 170,
                          child: Text(
                            ticket.subject,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 260,
                          child: Text(
                            ticket.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AdminWebTheme.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ),
                      DataCell(_StatusBadge(status: ticket.status)),
                      DataCell(Text(formatDate(ticket.createdAt))),
                      DataCell(
                        OutlinedButton.icon(
                          onPressed: () => onOpen(ticket),
                          icon: const Icon(Icons.open_in_new_rounded, size: 16),
                          label: const Text('Open'),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TicketDialog extends ConsumerStatefulWidget {
  final String eventId;
  final String eventName;
  final HelpTicket ticket;

  const _TicketDialog({
    required this.eventId,
    required this.eventName,
    required this.ticket,
  });

  @override
  ConsumerState<_TicketDialog> createState() => _TicketDialogState();
}

class _TicketDialogState extends ConsumerState<_TicketDialog> {
  final _replyController = TextEditingController();
  late String _status;
  bool _updating = false;
  bool _sending = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _status = widget.ticket.status;
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  void showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? Colors.redAccent : null,
      ),
    );
  }

  Future<void> updateStatus(String status) async {
    if (_updating || status == _status) return;

    final previousStatus = _status;

    setState(() {
      _updating = true;
      _status = status;
    });

    try {
      await ref
          .read(adminWebHelpRepositoryProvider)
          .updateTicketStatus(widget.ticket.id, status);

      showMessage('Ticket status updated.');
    } catch (error) {
      if (mounted) {
        setState(() {
          _status = previousStatus;
        });
      }

      showMessage('Failed to update status: $error', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _updating = false;
        });
      }
    }
  }

  Future<String> conversationId({
    required String adminId,
    required String userId,
  }) async {
    final members = [adminId, userId]..sort();
    final id = '${widget.eventId}_${members.join('_')}';
    final db = FirebaseFirestore.instance;
    final ref = db.collection('directMessages').doc(id);
    final doc = await ref.get();

    if (!doc.exists) {
      final adminDoc = await db.collection('users').doc(adminId).get();
      final userDoc = await db.collection('users').doc(userId).get();
      final admin = adminDoc.data() ?? {};
      final user = userDoc.data() ?? {};

      await ref.set({
        'eventId': widget.eventId,
        'members': members,
        'memberInfo': {
          adminId: {
            'name': (admin['name'] ?? 'Admin').toString(),
            'profileImageUrl':
                (admin['profileImageUrl'] ?? '').toString(),
          },
          userId: {
            'name': (user['name'] ?? widget.ticket.userName).toString(),
            'profileImageUrl':
                (user['profileImageUrl'] ?? '').toString(),
          },
        },
        'lastMessageText': '',
        'lastMessageSenderId': '',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'unreadCount': {adminId: 0, userId: 0},
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    return id;
  }

  Future<void> sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty || _sending) return;

    final admin = FirebaseAuth.instance.currentUser;
    if (admin == null) {
      showMessage('Admin account not found.', error: true);
      return;
    }

    setState(() => _sending = true);

    try {
      final db = FirebaseFirestore.instance;
      final id = await conversationId(
        adminId: admin.uid,
        userId: widget.ticket.userId,
      );
      final conversation = db.collection('directMessages').doc(id);
      final message = conversation.collection('messages').doc();
      final notification = db
          .collection('users')
          .doc(widget.ticket.userId)
          .collection('notifications')
          .doc();

      final batch = db.batch();

      batch.set(message, {
        'senderId': admin.uid,
        'receiverId': widget.ticket.userId,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'readBy': [admin.uid],
        'eventId': widget.eventId,
        'helpTicketId': widget.ticket.id,
        'messageType': 'help_ticket_reply',
      });

      batch.update(conversation, {
        'lastMessageText': text,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastMessageSenderId': admin.uid,
        'unreadCount.${widget.ticket.userId}': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.set(notification, {
        'title': 'Help Center Reply',
        'subtitle': widget.eventName,
        'body': text,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': 'information',
        'eventId': widget.eventId,
        'eventName': widget.eventName,
        'createdBy': admin.uid,
        'source': 'help_center',
        'data': {
          'type': 'help_ticket_reply',
          'eventId': widget.eventId,
          'ticketId': widget.ticket.id,
          'conversationId': id,
        },
      });

      await batch.commit();

      // Do not automatically overwrite the status after sending a reply.
      // The administrator's selected status remains the source of truth.
      _replyController.clear();
      showMessage('Reply sent to ${widget.ticket.userName}.');
    } catch (error) {
      showMessage('Failed to send reply: $error', error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> deleteTicket() async {
    if (_deleting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Ticket?'),
        content: const Text(
          'This permanently deletes the ticket. The direct conversation is kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => _deleting = true);

    try {
      await ref
          .read(adminWebHelpRepositoryProvider)
          .deleteTicket(widget.ticket.id);

      if (!mounted) return;
      Navigator.pop(context);
      showMessage('Ticket deleted.');
    } catch (error) {
      showMessage('Failed to delete ticket: $error', error: true);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 920,
          maxHeight: MediaQuery.sizeOf(context).height - 48,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FC),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(
                    bottom: BorderSide(color: AdminWebTheme.border),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.support_agent_rounded,
                      color: AdminWebTheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.ticket.subject,
                            style: const TextStyle(
                              color: AdminWebTheme.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${widget.ticket.userName} • ${widget.ticket.userEmail}',
                            style: const TextStyle(
                              color: AdminWebTheme.textSecondary,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _Section(
                        title: 'Issue Message',
                        child: SelectableText(
                          widget.ticket.message,
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.55,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _Section(
                        title: 'Ticket Status',
                        child: DropdownButtonFormField<String>(
                          value: _status,
                          isExpanded: true,
                          decoration: _inputDecoration(
                            hint: '',
                            icon: Icons.flag_outlined,
                          ),
                          items: const [
                            TicketStatus.pending,
                            TicketStatus.critical,
                            TicketStatus.processing,
                            TicketStatus.processed,
                            TicketStatus.spam,
                          ].map((status) {
                            return DropdownMenuItem(
                              value: status,
                              child: Text(
                                TicketStatus.getDisplayName(status),
                              ),
                            );
                          }).toList(),
                          onChanged: _updating
                              ? null
                              : (value) {
                                  if (value != null && value != _status) {
                                    updateStatus(value);
                                  }
                                },
                        ),
                      ),
                      const SizedBox(height: 16),
                      _Section(
                        title: 'Reply to User',
                        child: Column(
                          children: [
                            TextField(
                              controller: _replyController,
                              minLines: 4,
                              maxLines: 7,
                              decoration: _inputDecoration(
                                hint:
                                    'Write your reply to ${widget.ticket.userName}',
                                icon: Icons.chat_outlined,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'The reply is sent through Direct Messages and is restricted to this selected event.',
                                    style: TextStyle(
                                      color: AdminWebTheme.textSecondary,
                                      fontSize: 9.5,
                                    ),
                                  ),
                                ),
                                FilledButton.icon(
                                  onPressed: _sending ? null : sendReply,
                                  icon: _sending
                                      ? const SizedBox(
                                          width: 17,
                                          height: 17,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.send_rounded),
                                  label: Text(
                                    _sending ? 'Sending...' : 'Send Reply',
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AdminWebTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: AdminWebTheme.border),
                  ),
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: _deleting ? null : deleteTicket,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: Text(
                        _deleting ? 'Deleting...' : 'Delete Ticket',
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AdminWebTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AdminWebTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;

  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial =
        name.trim().isEmpty ? 'U' : name.trim()[0].toUpperCase();

    return CircleAvatar(
      radius: 20,
      backgroundColor: AdminWebTheme.primary.withOpacity(.1),
      child: Text(
        initial,
        style: const TextStyle(
          color: AdminWebTheme.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  Color get color {
    switch (status) {
      case TicketStatus.pending:
        return Colors.orange;
      case TicketStatus.processing:
        return Colors.blue;
      case TicketStatus.critical:
        return Colors.redAccent;
      case TicketStatus.processed:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        TicketStatus.getDisplayName(status),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AdminWebTheme.border),
      ),
      child: const CircularProgressIndicator(),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 54),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AdminWebTheme.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: AdminWebTheme.primary, size: 38),
          const SizedBox(height: 13),
          Text(
            title,
            style: const TextStyle(
              color: AdminWebTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AdminWebTheme.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _inputDecoration({
  required String hint,
  required IconData icon,
}) {
  return InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, size: 19, color: AdminWebTheme.primary),
    filled: true,
    fillColor: const Color(0xFFFAFBFD),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 14,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AdminWebTheme.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AdminWebTheme.primary),
    ),
  );
}
