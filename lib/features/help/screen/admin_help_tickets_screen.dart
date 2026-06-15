import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/models/help_ticket_model.dart';
import 'package:events_app_trueattempt/features/help/data/help_repository.dart';
import 'package:events_app_trueattempt/features/messaging/screen/new_conversation_screen.dart';
import 'package:timeago/timeago.dart' as timeago;

class AdminHelpTicketsScreen extends ConsumerStatefulWidget {
  final String? eventId;
  final String? eventName;

  const AdminHelpTicketsScreen({
    super.key,
    this.eventId,
    this.eventName,
  });

  bool get isEventSpecific => eventId != null && eventId!.isNotEmpty;

  @override
  ConsumerState<AdminHelpTicketsScreen> createState() =>
      _AdminHelpTicketsScreenState();
}

class _AdminHelpTicketsScreenState
    extends ConsumerState<AdminHelpTicketsScreen> {
  String _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final ticketsStream = widget.isEventSpecific
        ? ref
            .watch(helpRepositoryProvider)
            .getTicketsByEventStream(widget.eventId!)
        : ref.watch(helpRepositoryProvider).getAllTicketsStream();

    return Scaffold(
      backgroundColor: AppColors.namaWhite,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildFilters(),
            Expanded(
              child: StreamBuilder<List<HelpTicket>>(
                stream: ticketsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.namaNavyBlue,
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Text(
                          'Error: ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    );
                  }

                  final tickets = snapshot.data ?? [];

                  final filteredTickets = _selectedFilter == 'all'
                      ? tickets
                      : tickets
                          .where((ticket) => ticket.status == _selectedFilter)
                          .toList();

                  if (filteredTickets.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 48,
                            color: AppColors.namaMediumGray,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.isEventSpecific
                                ? 'No tickets found for this event'
                                : 'No tickets found',
                            style: TextStyle(
                              color: AppColors.namaMediumGray,
                              fontSize: 13,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: filteredTickets.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final ticket = filteredTickets[index];
                      return _buildTicketCard(ticket);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
                color: AppColors.namaGoldenYellow.withOpacity(0.7),
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

              if (widget.isEventSpecific)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    widget.eventName ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.namaMediumGray,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
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
          Text(
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
                _buildFilterChip(TicketStatus.pending, 'Pending'),
                const SizedBox(width: 8),
                _buildFilterChip(TicketStatus.critical, 'Critical'),
                const SizedBox(width: 8),
                _buildFilterChip(TicketStatus.processing, 'Processing'),
                const SizedBox(width: 8),
                _buildFilterChip(TicketStatus.processed, 'Processed'),
                const SizedBox(width: 8),
                _buildFilterChip(TicketStatus.spam, 'Spam'),
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
      selectedColor: AppColors.namaNavyBlue.withOpacity(0.12),
      side: BorderSide(
        color: isSelected
            ? AppColors.namaNavyBlue.withOpacity(0.25)
            : Colors.grey.shade300,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.namaNavyBlue : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        fontSize: 12,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildTicketCard(HelpTicket ticket) {
    return Card(
      elevation: 1.5,
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: _getStatusColor(ticket.status).withOpacity(0.25),
          width: 1.2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showTicketDetails(ticket),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ticket.subject,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'From: ${ticket.userName}',
                          style: TextStyle(
                            color: AppColors.namaMediumGray,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChip(ticket.status),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                ticket.message,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                  height: 1.35,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 13,
                    color: AppColors.namaMediumGray,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    timeago.format(ticket.createdAt),
                    style: TextStyle(
                      color: AppColors.namaMediumGray,
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  Text(
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

  void _showTicketDetails(HelpTicket ticket) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TicketDetailsSheet(ticket: ticket),
    );
  }
}

class _TicketDetailsSheet extends ConsumerWidget {
  final HelpTicket ticket;

  const _TicketDetailsSheet({
    required this.ticket,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
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
                Expanded(
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
                  iconSize: 22,
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
                  _buildInfoCard(
                    icon: Icons.person_outline,
                    title: 'User',
                    value: ticket.userName,
                  ),
                  const SizedBox(height: 8),
                  _buildInfoCard(
                    icon: Icons.email_outlined,
                    title: 'Email',
                    value: ticket.userEmail,
                  ),
                  const SizedBox(height: 14),
                  Text(
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
                  Text(
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
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      ticket.message,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.calendar_today,
                          title: 'Created',
                          value: timeago.format(ticket.createdAt),
                        ),
                      ),
                      if (ticket.updatedAt != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildInfoCard(
                            icon: Icons.update,
                            title: 'Updated',
                            value: timeago.format(ticket.updatedAt!),
                          ),
                        ),
                      ],
                    ],
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  value: ticket.status,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Change Status',
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: AppColors.namaMediumGray,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: AppColors.namaNavyBlue),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  items: [
                    TicketStatus.pending,
                    TicketStatus.processing,
                    TicketStatus.critical,
                    TicketStatus.processed,
                    TicketStatus.spam,
                  ].map((status) {
                    return DropdownMenuItem(
                      value: status,
                      child: Text(
                        TicketStatus.getDisplayName(status),
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  }).toList(),
                  onChanged: (newStatus) async {
                    if (newStatus != null && newStatus != ticket.status) {
                      await ref.read(helpRepositoryProvider).updateTicketStatus(
                            ticket.id,
                            newStatus,
                          );

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Status updated'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    }
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
                              builder: (_) => const NewConversationScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat_outlined, size: 17),
                        label: const Text(
                          'Chat',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.namaNavyBlue,
                          side: BorderSide(color: AppColors.namaNavyBlue),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final shouldDelete = await showDialog<bool>(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text(
                                  'Delete Ticket',
                                  style: TextStyle(fontSize: 16),
                                ),
                                content: const Text(
                                  'Are you sure you want to delete this ticket? This action cannot be undone.',
                                  style: TextStyle(fontSize: 13),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                    child: const Text(
                                      'Delete',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );

                          if (shouldDelete == true) {
                            await ref
                                .read(helpRepositoryProvider)
                                .deleteTicket(ticket.id);

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Ticket deleted'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.delete_outline, size: 17),
                        label: const Text(
                          'Delete',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
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

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
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
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.namaMediumGray,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}