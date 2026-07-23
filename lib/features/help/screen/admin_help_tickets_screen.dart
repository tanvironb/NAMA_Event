// lib/features/admin/screen/admin_help_tickets_screen.dart

import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/models/help_ticket_model.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/features/help/data/help_repository.dart';
import 'package:events_app_trueattempt/features/messaging/screen/new_conversation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

class AdminHelpTicketsScreen extends ConsumerStatefulWidget {
  final String? eventId;
  final String? eventName;

  const AdminHelpTicketsScreen({
    super.key,
    this.eventId,
    this.eventName,
  });

  @override
  ConsumerState<AdminHelpTicketsScreen> createState() =>
      _AdminHelpTicketsScreenState();
}

class _AdminHelpTicketsScreenState
    extends ConsumerState<AdminHelpTicketsScreen> {
  String _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    /*
      IMPORTANT FIX:

      Admin and Staff must always read tickets for the CURRENT active event.
      Do not rely only on an eventId passed by a previous page because that ID
      can be stale after the active event changes.

      We listen to all tickets and filter them in the app. This also lets us
      show legacy tickets that were created without an eventId.
    */
    final activeEventAsync = ref.watch(activeEventFutureProvider);
    final ticketsStream =
        ref.watch(helpRepositoryProvider).getAllTicketsStream();

    return Scaffold(
      backgroundColor: AppColors.namaWhite,
      body: SafeArea(
        child: activeEventAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              color: AppColors.namaNavyBlue,
            ),
          ),
          error: (error, stack) => _buildErrorState(
            'Failed to load the active event:\n$error',
          ),
          data: (activeEvent) {
            final currentEventId = activeEvent.id;
            final currentEventName = activeEvent.name;

            return Column(
              children: [
                _buildHeader(
                  context,
                  eventName: currentEventName,
                ),
                _buildFilters(),
                Expanded(
                  child: StreamBuilder<List<HelpTicket>>(
                    stream: ticketsStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                              ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.namaNavyBlue,
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return _buildErrorState(
                          'Failed to load help tickets:\n${snapshot.error}',
                        );
                      }

                      final allTickets = snapshot.data ?? <HelpTicket>[];

                      final eventTickets = allTickets.where((ticket) {
                        final ticketEventId = ticket.eventId.trim();

                        // Correct current-event tickets.
                        if (ticketEventId == currentEventId) {
                          return true;
                        }

                        /*
                          Backward compatibility:
                          Tickets submitted by the old Help screen had an empty
                          eventId. Admin and Staff can still see those tickets
                          instead of losing them.
                        */
                        if (ticketEventId.isEmpty) {
                          return true;
                        }

                        return false;
                      }).toList();

                      eventTickets.sort(
                        (a, b) => b.createdAt.compareTo(a.createdAt),
                      );

                      final filteredTickets = _selectedFilter == 'all'
                          ? eventTickets
                          : eventTickets
                              .where(
                                (ticket) =>
                                    ticket.status == _selectedFilter,
                              )
                              .toList();

                      if (filteredTickets.isEmpty) {
                        return _buildEmptyState();
                      }

                      return ListView.separated(
                        padding:
                            const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: filteredTickets.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          return _buildTicketCard(
                            filteredTickets[index],
                            currentEventId: currentEventId,
                            currentEventName: currentEventName,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required String eventName,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      AppColors.namaGoldenYellow.withOpacity(0.7),
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.namaNavyBlue,
                size: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Help Tickets',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.namaNavyBlue,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  eventName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.namaMediumGray,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 0, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filters',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.namaNavyBlue,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                _buildFilterChip('all', 'All'),
                const SizedBox(width: 8),
                _buildFilterChip(
                  TicketStatus.pending,
                  'Pending',
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  TicketStatus.critical,
                  'Critical',
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  TicketStatus.processing,
                  'Processing',
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  TicketStatus.processed,
                  'Processed',
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  TicketStatus.spam,
                  'Spam',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _selectedFilter = value);
      },
      showCheckmark: true,
      checkmarkColor: AppColors.namaNavyBlue,
      backgroundColor: Colors.white,
      selectedColor:
          AppColors.namaNavyBlue.withOpacity(0.12),
      side: BorderSide(
        color: isSelected
            ? AppColors.namaNavyBlue.withOpacity(0.25)
            : Colors.grey.shade300,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      labelStyle: TextStyle(
        color: isSelected
            ? AppColors.namaNavyBlue
            : Colors.grey.shade700,
        fontWeight:
            isSelected ? FontWeight.w600 : FontWeight.w400,
        fontSize: 12,
      ),
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.inbox_outlined,
            size: 48,
            color: AppColors.namaMediumGray,
          ),
          const SizedBox(height: 12),
          Text(
            _selectedFilter == 'all'
                ? 'No tickets found for the active event'
                : 'No ${TicketStatus.getDisplayName(_selectedFilter).toLowerCase()} tickets found',
            style: const TextStyle(
              color: AppColors.namaMediumGray,
              fontSize: 13,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.red,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildTicketCard(
    HelpTicket ticket, {
    required String currentEventId,
    required String currentEventName,
  }) {
    final isLegacyTicket = ticket.eventId.trim().isEmpty;

    return Card(
      elevation: 1.5,
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color:
              _getStatusColor(ticket.status).withOpacity(0.25),
          width: 1.2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showTicketDetails(
          ticket,
          currentEventId: currentEventId,
          currentEventName: currentEventName,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ticket.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChip(ticket.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'From: ${ticket.userName}',
                style: const TextStyle(
                  color: AppColors.namaMediumGray,
                  fontSize: 11,
                ),
              ),
              if (isLegacyTicket) ...[
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Legacy ticket — event not recorded',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                ticket.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 13,
                    color: AppColors.namaMediumGray,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    timeago.format(ticket.createdAt),
                    style: const TextStyle(
                      color: AppColors.namaMediumGray,
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'Tap to view details',
                    style: TextStyle(
                      color: AppColors.namaNavyBlue,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        TicketStatus.getDisplayName(status),
        style: TextStyle(
          color: _getStatusColor(status),
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case TicketStatus.pending:
        return Colors.orange;
      case TicketStatus.processing:
        return Colors.blue;
      case TicketStatus.critical:
        return Colors.red;
      case TicketStatus.processed:
        return Colors.green;
      case TicketStatus.spam:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  void _showTicketDetails(
    HelpTicket ticket, {
    required String currentEventId,
    required String currentEventName,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TicketDetailsSheet(
        ticket: ticket,
        currentEventId: currentEventId,
        currentEventName: currentEventName,
      ),
    );
  }
}

class _TicketDetailsSheet extends ConsumerWidget {
  final HelpTicket ticket;
  final String currentEventId;
  final String currentEventName;

  const _TicketDetailsSheet({
    required this.ticket,
    required this.currentEventId,
    required this.currentEventName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 10, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Ticket Details',
                    style: TextStyle(
                      fontSize: 17,
                      color: AppColors.namaNavyBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _infoCard(
                    Icons.person_outline,
                    'User',
                    ticket.userName,
                  ),
                  const SizedBox(height: 8),
                  _infoCard(
                    Icons.email_outlined,
                    'Email',
                    ticket.userEmail,
                  ),
                  const SizedBox(height: 8),
                  _infoCard(
                    Icons.event_outlined,
                    'Event',
                    currentEventName,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Subject',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.namaNavyBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ticket.subject,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Message',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.namaNavyBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      ticket.message,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: ticket.status,
                  decoration: InputDecoration(
                    labelText: 'Change Status',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  items: const [
                    TicketStatus.pending,
                    TicketStatus.processing,
                    TicketStatus.critical,
                    TicketStatus.processed,
                    TicketStatus.spam,
                  ].map((status) {
                    return DropdownMenuItem<String>(
                      value: status,
                      child:
                          Text(TicketStatus.getDisplayName(status)),
                    );
                  }).toList(),
                  onChanged: (status) async {
                    if (status == null ||
                        status == ticket.status) {
                      return;
                    }

                    await ref
                        .read(helpRepositoryProvider)
                        .updateTicketStatus(ticket.id, status);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const NewConversationScreen(),
                            ),
                          );
                        },
                        icon:
                            const Icon(Icons.chat_outlined, size: 17),
                        label: const Text('Chat'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await ref
                              .read(helpRepositoryProvider)
                              .deleteTicket(ticket.id);

                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 17,
                        ),
                        label: const Text('Delete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(
    IconData icon,
    String title,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: AppColors.namaMediumGray,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.namaMediumGray,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.trim().isEmpty ? '-' : value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
