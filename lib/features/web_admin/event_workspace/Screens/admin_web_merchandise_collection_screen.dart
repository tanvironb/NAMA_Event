import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../admin_web_theme.dart';

class AdminWebMerchandiseCollectionScreen extends StatefulWidget {
  final String eventId;
  final String eventName;
  const AdminWebMerchandiseCollectionScreen({
    super.key,
    required this.eventId,
    required this.eventName,
  });
  @override
  State<AdminWebMerchandiseCollectionScreen> createState() => _AdminWebMerchandiseCollectionScreenState();
}

class _AdminWebMerchandiseCollectionScreenState extends State<AdminWebMerchandiseCollectionScreen> {
  String _query = '';
  String _statusFilter = 'all';
  String _roleFilter = 'all';
  DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
  String _formatDate(dynamic value) {
    final date = _toDateTime(value);
    if (date == null) return '-';
    return DateFormat('dd MMM yyyy, h:mm a').format(date);
  }
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').where('eventIds', arrayContains: widget.eventId).snapshots(),
      builder: (context, userSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('events').doc(widget.eventId).collection('merchandiseCollections').snapshots(),
          builder: (context, collectionSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting || collectionSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (userSnapshot.hasError) {
              return Center(child: Text('Failed to load users: ${userSnapshot.error}'));
            }
            if (collectionSnapshot.hasError) {
              return Center(child: Text('Failed to load merchandise data: ${collectionSnapshot.error}'));
            }
            final users = userSnapshot.data?.docs ?? [];
            final collectionDocs = collectionSnapshot.data?.docs ?? [];
            final collectionMap = <String, Map<String, dynamic>>{};
            for (final doc in collectionDocs) {
              collectionMap[doc.id] = doc.data();
            }
            final rows = users.map((doc) {
              final data = doc.data();
              final collection = collectionMap[doc.id];
              final collected = (collection?['status'] ?? '').toString().toLowerCase() == 'collected';
              return {
                'uid': doc.id,
                'name': (data['name'] ?? data['fullName'] ?? data['displayName'] ?? 'User').toString(),
                'email': (data['email'] ?? '').toString(),
                'role': (data['role'] ?? 'attendee').toString(),
                'collected': collected,
                'collectedBy': (collection?['collectedByName'] ?? '').toString(),
                'collectedAt': collection?['collectedAt'],
              };
            }).where((row) {
              final query = _query.trim().toLowerCase();
              final role = row['role'].toString().toLowerCase();
              final collected = row['collected'] == true;
              final matchesQuery = query.isEmpty || row['name'].toString().toLowerCase().contains(query) || row['email'].toString().toLowerCase().contains(query) || role.contains(query);
              final matchesStatus = _statusFilter == 'all' || (_statusFilter == 'collected' && collected) || (_statusFilter == 'pending' && !collected);
              final matchesRole = _roleFilter == 'all' || role == _roleFilter;
              return matchesQuery && matchesStatus && matchesRole;
            }).toList();
            rows.sort((a, b) {
              final aCollected = a['collected'] == true;
              final bCollected = b['collected'] == true;
              if (aCollected != bCollected) return aCollected ? 1 : -1;
              return a['name'].toString().toLowerCase().compareTo(b['name'].toString().toLowerCase());
            });
            final total = users.length;
            final collectedCount = collectionMap.values.where((data) => (data['status'] ?? '').toString().toLowerCase() == 'collected').length;
            final pendingCount = total - collectedCount;
            return SizedBox.expand(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Merchandise Collection',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: AdminWebTheme.textPrimary,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.eventName,
                                style: const TextStyle(
                                  color: AdminWebTheme.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _summaryCard('Total', total.toString(), AdminWebTheme.info),
                        const SizedBox(width: 12),
                        _summaryCard('Collected', collectedCount.toString(), AdminWebTheme.success),
                        const SizedBox(width: 12),
                        _summaryCard('Pending', pendingCount.toString(), AdminWebTheme.warning),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                onChanged: (value) => setState(() => _query = value),
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.search_rounded),
                                  hintText: 'Search by name, email, or role',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 170,
                              child: DropdownButtonFormField<String>(
                                value: _statusFilter,
                                decoration: const InputDecoration(labelText: 'Status'),
                                items: const [
                                  DropdownMenuItem(value: 'all', child: Text('All')),
                                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                                  DropdownMenuItem(value: 'collected', child: Text('Collected')),
                                ],
                                onChanged: (value) => setState(() => _statusFilter = value ?? 'all'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 170,
                              child: DropdownButtonFormField<String>(
                                value: _roleFilter,
                                decoration: const InputDecoration(labelText: 'Role'),
                                items: const [
                                  DropdownMenuItem(value: 'all', child: Text('All roles')),
                                  DropdownMenuItem(value: 'attendee', child: Text('Attendee')),
                                  DropdownMenuItem(value: 'speaker', child: Text('Speaker')),
                                  DropdownMenuItem(value: 'moderator', child: Text('Moderator')),
                                  DropdownMenuItem(value: 'staff', child: Text('Staff')),
                                ],
                                onChanged: (value) => setState(() => _roleFilter = value ?? 'all'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _buildFullWidthTable(rows),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
  Widget _buildFullWidthTable(List<Map<String, Object?>> rows) {
    return Card(
      margin: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            Container(
              color: const Color(0xFFF7F9FC),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              child: const Row(
                children: [
                  Expanded(flex: 26, child: Text('Name', style: _tableHeaderStyle)),
                  Expanded(flex: 28, child: Text('Email', style: _tableHeaderStyle)),
                  Expanded(flex: 13, child: Text('Role', style: _tableHeaderStyle)),
                  Expanded(flex: 13, child: Text('Status', style: _tableHeaderStyle)),
                  Expanded(flex: 16, child: Text('Collected By', style: _tableHeaderStyle)),
                  Expanded(flex: 18, child: Text('Collected Time', style: _tableHeaderStyle)),
                ],
              ),
            ),
            Expanded(
              child: rows.isEmpty
                  ? const Center(
                      child: Text(
                        'No users found.',
                        style: TextStyle(
                          color: AdminWebTheme.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: AdminWebTheme.border),
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        final collected = row['collected'] == true;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                          color: Colors.white,
                          child: Row(
                            children: [
                              Expanded(
                                flex: 26,
                                child: Text(
                                  row['name'].toString(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AdminWebTheme.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 28,
                                child: Text(
                                  row['email'].toString(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AdminWebTheme.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(flex: 13, child: Align(alignment: Alignment.centerLeft, child: _roleChip(row['role'].toString()))),
                              Expanded(flex: 13, child: Align(alignment: Alignment.centerLeft, child: _statusChip(collected))),
                              Expanded(
                                flex: 16,
                                child: Text(
                                  row['collectedBy'].toString().isEmpty ? '-' : row['collectedBy'].toString(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AdminWebTheme.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 18,
                                child: Text(
                                  _formatDate(row['collectedAt']),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AdminWebTheme.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _summaryCard(String label, String value, Color color) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminWebTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AdminWebTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
  static Widget _statusChip(bool collected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: collected ? AdminWebTheme.success.withOpacity(0.10) : AdminWebTheme.warning.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        collected ? 'Collected' : 'Pending',
        style: TextStyle(
          color: collected ? AdminWebTheme.success : AdminWebTheme.warning,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
  static Widget _roleChip(String role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AdminWebTheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        role.toUpperCase(),
        style: const TextStyle(
          color: AdminWebTheme.primary,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

const TextStyle _tableHeaderStyle = TextStyle(
  color: AdminWebTheme.textPrimary,
  fontSize: 13,
  fontWeight: FontWeight.w800,
);