// lib/features/admin/screen/user_management_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/models/app_user.dart';
import 'package:events_app_trueattempt/features/admin/screen/user_detail_admin_screen.dart';
import 'package:events_app_trueattempt/features/profile/screen/user_details_screen.dart';

class UserManagementScreen extends StatefulWidget {
  final String? eventId;
  final String? eventName;

  const UserManagementScreen({
    super.key,
    this.eventId,
    this.eventName,
  });

  bool get isEventSpecific => eventId != null && eventId!.isNotEmpty;

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  String _selectedRoleFilter = 'All';
  String _selectedStatusFilter = 'All';
  String _searchQuery = '';

  final TextEditingController _searchController = TextEditingController();

  static const Color _primaryColor = Color(0xFF1B0F72);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textMuted = Color(0xFF6B7280);
  static const Color _borderColor = Color(0xFFE8E4F8);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _usersStream() {
    return FirebaseFirestore.instance.collection('users').snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _eventSessionsStream() {
    if (!widget.isEventSpecific) {
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('sessions')
        .where('eventId', isEqualTo: widget.eventId)
        .snapshots();
  }

  Set<String> _extractUserIdsFromEventSessions(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> sessionDocs,
  ) {
    final Set<String> userIds = {};

    for (final doc in sessionDocs) {
      final data = doc.data();

      void addListField(String fieldName) {
        final value = data[fieldName];

        if (value is List) {
          for (final item in value) {
            final id = item.toString().trim();
            if (id.isNotEmpty) {
              userIds.add(id);
            }
          }
        }
      }

      addListField('speakerIds');
      addListField('moderatorIds');
      addListField('checkedInAttendees');
      addListField('uniqueParticipants');
      addListField('bookmarkedBy');
      addListField('registeredUsers');
      addListField('attendeeIds');
      addListField('staffIds');
      addListField('adminIds');
    }

    return userIds;
  }

  bool _rawUserBelongsToEvent({
    required String userId,
    required Map<String, dynamic> userData,
    required Set<String> eventUserIds,
  }) {
    if (!widget.isEventSpecific) return true;

    final eventId = widget.eventId!;
    final role = (userData['role'] ?? '').toString().toLowerCase();

    if (role == 'admin') return true;

    if (eventUserIds.contains(userId)) return true;

    final directEventId = userData['eventId']?.toString();
    final currentEventId = userData['currentEventId']?.toString();
    final activeEventId = userData['activeEventId']?.toString();

    if (directEventId == eventId ||
        currentEventId == eventId ||
        activeEventId == eventId) {
      return true;
    }

    bool arrayContainsEvent(String fieldName) {
      final value = userData[fieldName];

      if (value is List) {
        return value.map((e) => e.toString()).contains(eventId);
      }

      return false;
    }

    return arrayContainsEvent('eventIds') ||
        arrayContainsEvent('registeredEventIds') ||
        arrayContainsEvent('registeredEvents') ||
        arrayContainsEvent('joinedEvents') ||
        arrayContainsEvent('assignedEventIds');
  }

  List<_UserRecord> _buildUserRecords({
    required QuerySnapshot<Map<String, dynamic>> usersSnapshot,
    required Set<String> eventUserIds,
  }) {
    final records = <_UserRecord>[];

    for (final doc in usersSnapshot.docs) {
      final rawData = doc.data();

      final belongsToEvent = _rawUserBelongsToEvent(
        userId: doc.id,
        userData: rawData,
        eventUserIds: eventUserIds,
      );

      if (!belongsToEvent) continue;

      try {
        records.add(
          _UserRecord(
            user: AppUser.fromFirestore(doc),
            rawData: rawData,
          ),
        );
      } catch (_) {
        continue;
      }
    }

    records.sort(
      (a, b) => a.user.name.toLowerCase().compareTo(
            b.user.name.toLowerCase(),
          ),
    );

    return records;
  }

  List<_UserRecord> _applyFilters(List<_UserRecord> records) {
    return records.where((record) {
      final user = record.user;

      final matchesRole = _selectedRoleFilter == 'All' ||
          user.role.toLowerCase() == _selectedRoleFilter.toLowerCase();

      final matchesStatus = _selectedStatusFilter == 'All' ||
          user.status.toLowerCase() == _selectedStatusFilter.toLowerCase();

      final query = _searchQuery.trim().toLowerCase();

      final matchesSearch = query.isEmpty ||
          user.name.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query);

      return matchesRole && matchesStatus && matchesSearch;
    }).toList();
  }

  List<String> _getUniqueStatuses(List<_UserRecord> records) {
    final statuses = records
        .map((record) => record.user.status.trim())
        .where((status) => status.isNotEmpty)
        .toSet()
        .toList();

    statuses.sort();

    return statuses;
  }

  String _formatStatusLabel(String status) {
    if (status.isEmpty) return status;
    return status[0].toUpperCase() + status.substring(1).toLowerCase();
  }

 Widget _buildHeader() {
  return Padding(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
    child: Row(
      children: [
        InkWell(
          onTap: () => Navigator.of(context).pop(),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 32,
            width: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFE4B544).withOpacity(0.55),
              ),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1B0F72),
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
                'Manage Users',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF1B0F72),
                  fontSize: 19,
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
                      color: Color(0xFF6B7280),
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

  Widget _buildContent({
    required QuerySnapshot<Map<String, dynamic>> usersSnapshot,
    required Set<String> eventUserIds,
  }) {
    final allRecords = _buildUserRecords(
      usersSnapshot: usersSnapshot,
      eventUserIds: eventUserIds,
    );

    final uniqueStatuses = _getUniqueStatuses(allRecords);
    final filteredRecords = _applyFilters(allRecords);

    if (allRecords.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            widget.isEventSpecific
                ? 'No users found for this event yet.'
                : 'No users found.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildFilterSection(uniqueStatuses),
        _buildSearchBox(),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 6,
          ),
          child: Row(
            children: [
              Text(
                '${filteredRecords.length} user${filteredRecords.length != 1 ? 's' : ''} found',
                style: const TextStyle(
                  color: _textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filteredRecords.isEmpty
              ? const Center(
                  child: Text(
                    'No users match the selected filters.',
                    style: TextStyle(
                      color: _textMuted,
                      fontSize: 12,
                    ),
                  ),
                )
              : SafeArea(
                  top: false,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: filteredRecords.length,
                    itemBuilder: (context, index) {
                      final record = filteredRecords[index];

                      return _AdminUserCard(
                        user: record.user,
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _usersStream(),
                builder: (context, usersSnapshot) {
                  if (usersSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const LoadingIndicator();
                  }

                  if (usersSnapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${usersSnapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  }

                  if (!usersSnapshot.hasData) {
                    return const Center(
                      child: Text(
                        'No users found.',
                        style: TextStyle(fontSize: 12),
                      ),
                    );
                  }

                  if (!widget.isEventSpecific) {
                    return _buildContent(
                      usersSnapshot: usersSnapshot.data!,
                      eventUserIds: {},
                    );
                  }

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _eventSessionsStream(),
                    builder: (context, sessionsSnapshot) {
                      if (sessionsSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const LoadingIndicator();
                      }

                      if (sessionsSnapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error loading event sessions: ${sessionsSnapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      }

                      final eventUserIds = _extractUserIdsFromEventSessions(
                        sessionsSnapshot.data?.docs ?? [],
                      );

                      return _buildContent(
                        usersSnapshot: usersSnapshot.data!,
                        eventUserIds: eventUserIds,
                      );
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

  Widget _buildFilterSection(List<String> uniqueStatuses) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filters',
            style: TextStyle(
              color: _textDark,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildFilterDropdown<String>(
                  label: 'Role',
                  value: _selectedRoleFilter,
                  items: const [
                    'All',
                    'Attendee',
                    'Speaker',
                    'Staff',
                    'Admin',
                  ],
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      _selectedRoleFilter = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildFilterDropdown<String>(
                  label: 'Status',
                  value: _selectedStatusFilter,
                  items: [
                    'All',
                    ...uniqueStatuses.map(_formatStatusLabel),
                  ],
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      _selectedStatusFilter = value;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: TextField(
        controller: _searchController,
        cursorColor: _primaryColor,
        style: const TextStyle(
          fontSize: 12.5,
          color: _textDark,
        ),
        decoration: InputDecoration(
          hintText: 'Search by name or email...',
          hintStyle: const TextStyle(
            color: _textMuted,
            fontSize: 12.5,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: _textMuted,
            size: 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.clear,
                    color: _textMuted,
                    size: 18,
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
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 11,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(
              color: _borderColor,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(
              color: _primaryColor,
              width: 1.2,
            ),
          ),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildFilterDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      borderRadius: BorderRadius.circular(20),
      iconSize: 20,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: _textMuted,
          fontSize: 10.5,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 8,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(
            color: _borderColor,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(
            color: _primaryColor,
            width: 1.2,
          ),
        ),
      ),
      items: items.map((item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(
            item.toString(),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: _textDark,
            ),
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}

class _UserRecord {
  final AppUser user;
  final Map<String, dynamic> rawData;

  const _UserRecord({
    required this.user,
    required this.rawData,
  });
}

class _AdminUserCard extends StatelessWidget {
  final AppUser user;

  const _AdminUserCard({
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _getStatusBorderColor(user.status),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        minVerticalPadding: 8,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 6,
        ),
        leading: GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => UserDetailsScreen(userId: user.uid),
              ),
            );
          },
          child: CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.namaNavyBlue.withOpacity(0.1),
            backgroundImage: user.profileImageUrl.isNotEmpty
                ? NetworkImage(user.profileImageUrl)
                : null,
            child: user.profileImageUrl.isEmpty
                ? Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.namaNavyBlue,
                    ),
                  )
                : null,
          ),
        ),
        title: GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => UserDetailsScreen(userId: user.uid),
              ),
            );
          },
          child: Text(
            user.name.isNotEmpty ? user.name : 'Unnamed User',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: Color(0xFF333333),
            ),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Row(
            children: [
              _buildRoleBadge(user.role),
              const SizedBox(width: 7),
              _buildStatusBadge(user.status),
            ],
          ),
        ),
        trailing: IconButton(
          icon: const Icon(
            Icons.edit,
            size: 20,
          ),
          color: AppColors.namaNavyBlue,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => UserDetailAdminScreen(user: user),
              ),
            );
          },
          tooltip: 'Edit User',
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: AppColors.namaNavyBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        role.toUpperCase(),
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          color: AppColors.namaNavyBlue,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          color: _getStatusColor(status),
        ),
      ),
    );
  }

  Color _getStatusBorderColor(String status) {
    switch (status.toLowerCase()) {
      case 'blocked':
        return AppColors.errorRed;
      case 'pending':
        return AppColors.warningAmber;
      case 'approved':
        return AppColors.successGreen;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'blocked':
        return AppColors.errorRed;
      case 'pending':
        return AppColors.warningAmber;
      case 'approved':
        return AppColors.successGreen;
      case 'rejected':
        return AppColors.errorRed;
      default:
        return Colors.grey;
    }
  }
}