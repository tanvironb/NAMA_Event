import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/models/help_ticket_model.dart';
import 'package:events_app_trueattempt/features/help/data/help_repository.dart';
import 'package:events_app_trueattempt/features/messaging/screen/new_conversation_screen.dart';
import 'package:timeago/timeago.dart' as timeago;

class AdminHelpTicketsScreen extends ConsumerStatefulWidget {
  const AdminHelpTicketsScreen({super.key});

  @override
  ConsumerState<AdminHelpTicketsScreen> createState() => _AdminHelpTicketsScreenState();
}

class _AdminHelpTicketsScreenState extends ConsumerState<AdminHelpTicketsScreen> {
  String _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final ticketsStream = ref.watch(helpRepositoryProvider).getAllTicketsStream();

    return Scaffold(
      backgroundColor: AppColors.namaWhite,
      appBar: AppBar(
        title: const Text('Help Tickets'),
        backgroundColor: AppColors.namaNavyBlue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
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
          ),

          // Tickets list
          Expanded(
            child: StreamBuilder<List<HelpTicket>>(
              stream: ticketsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final tickets = snapshot.data ?? [];
                final filteredTickets = _selectedFilter == 'all'
                    ? tickets
                    : tickets.where((t) => t.status == _selectedFilter).toList();

                if (filteredTickets.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 64,
                          color: AppColors.namaMediumGray,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No tickets found',
                          style: TextStyle(
                            color: AppColors.namaMediumGray,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredTickets.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
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
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _selectedFilter = value);
      },
      backgroundColor: Colors.grey.shade100,
      selectedColor: AppColors.namaNavyBlue.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.namaNavyBlue : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      checkmarkColor: AppColors.namaNavyBlue,
    );
  }

  Widget _buildTicketCard(HelpTicket ticket) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getStatusColor(ticket.status).withOpacity(0.3),
          width: 2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showTicketDetails(ticket),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ticket.subject,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'From: ${ticket.userName}',
                          style: TextStyle(
                            color: AppColors.namaMediumGray,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(ticket.status),
                ],
              ),
              const SizedBox(height: 12),

              // Message preview
              Text(
                ticket.message,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              // Footer
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: AppColors.namaMediumGray),
                  const SizedBox(width: 4),
                  Text(
                    timeago.format(ticket.createdAt),
                    style: TextStyle(
                      color: AppColors.namaMediumGray,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Tap to view details',
                    style: TextStyle(
                      color: AppColors.namaNavyBlue,
                      fontSize: 12,
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
        color: _getStatusColor(status).withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        TicketStatus.getDisplayName(status),
        style: TextStyle(
          color: _getStatusColor(status),
          fontSize: 12,
          fontWeight: FontWeight.bold,
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

  const _TicketDetailsSheet({required this.ticket});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Ticket Details',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
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

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // User info
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
                  const SizedBox(height: 16),

                  // Subject
                  Text(
                    'Subject',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ticket.subject,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),

                  // Message
                  Text(
                    'Message',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      ticket.message,
                      style: const TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Timestamps
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

          // Actions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Change status
                DropdownButtonFormField<String>(
                  value: ticket.status,
                  decoration: InputDecoration(
                    labelText: 'Change Status',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
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
                      child: Text(TicketStatus.getDisplayName(status)),
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

                // Action buttons
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
                        icon: const Icon(Icons.chat_outlined),
                        label: const Text('Chat'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.namaNavyBlue,
                          side: BorderSide(color: AppColors.namaNavyBlue),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Ticket'),
                              content: const Text(
                                'Are you sure you want to delete this ticket? This action cannot be undone.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );

                          if (shouldDelete == true) {
                            await ref.read(helpRepositoryProvider).deleteTicket(ticket.id);
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
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.namaMediumGray),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.namaMediumGray,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
