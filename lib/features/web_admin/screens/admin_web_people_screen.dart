import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../admin_web_theme.dart';

class AdminWebPeopleScreen extends StatefulWidget {
  final String role;
  final String pageTitle;
  final String pageDescription;

  const AdminWebPeopleScreen({
    super.key,
    required this.role,
    required this.pageTitle,
    required this.pageDescription,
  });

  @override
  State<AdminWebPeopleScreen> createState() =>
      _AdminWebPeopleScreenState();
}

class _AdminWebPeopleScreenState
    extends State<AdminWebPeopleScreen> {
  final TextEditingController _searchController =
      TextEditingController();

  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _peopleStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: widget.role)
        .snapshots();
  }

  Future<void> _openCreateDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return _CreateEventRoleDialog(
          role: widget.role,
        );
      },
    );
  }

  Future<void> _openAssignDialog({
    required String userId,
    required Map<String, dynamic> userData,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return _CreateEventRoleDialog(
          role: widget.role,
          existingUserId: userId,
          existingName: (userData['name'] ?? '').toString(),
          existingEmail:
              (userData['email'] ?? '').toString(),
          existingCompany:
              (userData['company'] ?? '').toString(),
          assignmentOnly: true,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _peopleStream(),
      builder: (context, snapshot) {
        final allPeople = snapshot.data?.docs ?? [];

        final filteredPeople = allPeople.where((doc) {
          final data = doc.data();

          final query = _searchQuery.trim().toLowerCase();

          if (query.isEmpty) return true;

          final name =
              (data['name'] ?? '').toString().toLowerCase();

          final email =
              (data['email'] ?? '').toString().toLowerCase();

          final company =
              (data['company'] ?? '').toString().toLowerCase();

          return name.contains(query) ||
              email.contains(query) ||
              company.contains(query);
        }).toList()
          ..sort((a, b) {
            final aName =
                (a.data()['name'] ?? '').toString().toLowerCase();

            final bName =
                (b.data()['name'] ?? '').toString().toLowerCase();

            return aName.compareTo(bName);
          });

        return SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PeoplePageHeader(
                title: widget.pageTitle,
                description: widget.pageDescription,
                role: widget.role,
                totalCount: allPeople.length,
                onAdd: _openCreateDialog,
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AdminWebTheme.border,
                  ),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText:
                            'Search ${widget.pageTitle.toLowerCase()} by name, email or company',
                        prefixIcon:
                            const Icon(Icons.search_rounded),
                        suffixIcon: _searchQuery.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _searchController.clear();

                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                                icon: const Icon(
                                  Icons.close_rounded,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (snapshot.connectionState ==
                        ConnectionState.waiting)
                      const Padding(
                        padding: EdgeInsets.all(50),
                        child: CircularProgressIndicator(
                          color: AdminWebTheme.primary,
                        ),
                      )
                    else if (snapshot.hasError)
                      Padding(
                        padding: const EdgeInsets.all(30),
                        child: Text(
                          'Failed to load ${widget.pageTitle.toLowerCase()}: ${snapshot.error}',
                        ),
                      )
                    else if (filteredPeople.isEmpty)
                      _EmptyPeopleState(
                        role: widget.role,
                        hasSearch:
                            _searchQuery.trim().isNotEmpty,
                        onAdd: _openCreateDialog,
                      )
                    else
                      _PeopleTable(
                        people: filteredPeople,
                        role: widget.role,
                        onAssign: _openAssignDialog,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PeoplePageHeader extends StatelessWidget {
  final String title;
  final String description;
  final String role;
  final int totalCount;
  final VoidCallback onAdd;

  const _PeoplePageHeader({
    required this.title,
    required this.description,
    required this.role,
    required this.totalCount,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AdminWebTheme.textPrimary,
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                description,
                style: const TextStyle(
                  color: AdminWebTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 13),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AdminWebTheme.primary.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  '$totalCount total',
                  style: const TextStyle(
                    color: AdminWebTheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded),
          label: Text(
            role == 'speaker'
                ? 'Add Speaker'
                : 'Add Moderator',
          ),
        ),
      ],
    );
  }
}

class _PeopleTable extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> people;
  final String role;

  final void Function({
    required String userId,
    required Map<String, dynamic> userData,
  }) onAssign;

  const _PeopleTable({
    required this.people,
    required this.role,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 850) {
          return Column(
            children: people.map((doc) {
              return _PersonMobileCard(
                userId: doc.id,
                data: doc.data(),
                role: role,
                onAssign: () {
                  onAssign(
                    userId: doc.id,
                    userData: doc.data(),
                  );
                },
              );
            }).toList(),
          );
        }

        return Column(
          children: [
            const _PeopleTableHeader(),
            ...people.map((doc) {
              return _PeopleTableRow(
                userId: doc.id,
                data: doc.data(),
                role: role,
                onAssign: () {
                  onAssign(
                    userId: doc.id,
                    userData: doc.data(),
                  );
                },
              );
            }),
          ],
        );
      },
    );
  }
}

class _PeopleTableHeader extends StatelessWidget {
  const _PeopleTableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              'PERSON',
              style: _headerStyle,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'COMPANY',
              style: _headerStyle,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'EVENTS',
              style: _headerStyle,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'STATUS',
              style: _headerStyle,
            ),
          ),
          SizedBox(
            width: 150,
            child: Text(
              'ACTIONS',
              style: _headerStyle,
            ),
          ),
        ],
      ),
    );
  }

  static const TextStyle _headerStyle = TextStyle(
    color: Color(0xFF8B93A5),
    fontSize: 10,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.7,
  );
}

class _PeopleTableRow extends StatelessWidget {
  final String userId;
  final Map<String, dynamic> data;
  final String role;
  final VoidCallback onAssign;

  const _PeopleTableRow({
    required this.userId,
    required this.data,
    required this.role,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    final name = (data['name'] ?? 'Unnamed').toString();
    final email = (data['email'] ?? '').toString();
    final company = (data['company'] ?? '').toString();
    final imageUrl =
        (data['profileImageUrl'] ?? '').toString();

    final eventIds =
        List<String>.from(data['eventIds'] as List? ?? []);

    final status =
        (data['status'] ?? 'approved').toString();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AdminWebTheme.border,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                _PersonAvatar(
                  name: name,
                  imageUrl: imageUrl,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color:
                              AdminWebTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color:
                              AdminWebTheme.textSecondary,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              company.trim().isEmpty ? '—' : company,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AdminWebTheme.textPrimary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${eventIds.length} event${eventIds.length == 1 ? '' : 's'}',
              style: const TextStyle(
                color: AdminWebTheme.textPrimary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: _StatusBadge(status: status),
          ),
          SizedBox(
            width: 150,
            child: OutlinedButton.icon(
              onPressed: onAssign,
              icon: const Icon(
                Icons.add_link_rounded,
                size: 17,
              ),
              label: const Text(
                'Assign Event',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonMobileCard extends StatelessWidget {
  final String userId;
  final Map<String, dynamic> data;
  final String role;
  final VoidCallback onAssign;

  const _PersonMobileCard({
    required this.userId,
    required this.data,
    required this.role,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    final name = (data['name'] ?? 'Unnamed').toString();
    final email = (data['email'] ?? '').toString();
    final company = (data['company'] ?? '').toString();
    final imageUrl =
        (data['profileImageUrl'] ?? '').toString();

    final eventIds =
        List<String>.from(data['eventIds'] as List? ?? []);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFD),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: AdminWebTheme.border,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _PersonAvatar(
                name: name,
                imageUrl: imageUrl,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: AdminWebTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      email,
                      style: const TextStyle(
                        color:
                            AdminWebTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(
                status:
                    (data['status'] ?? 'approved').toString(),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: Text(
                  company.trim().isEmpty
                      ? 'No company'
                      : company,
                  style: const TextStyle(
                    color: AdminWebTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
              Text(
                '${eventIds.length} event${eventIds.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: AdminWebTheme.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onAssign,
              icon: const Icon(Icons.add_link_rounded),
              label: const Text('Assign to Event'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonAvatar extends StatelessWidget {
  final String name;
  final String imageUrl;

  const _PersonAvatar({
    required this.name,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty
        ? '?'
        : name.trim().substring(0, 1).toUpperCase();

    return Container(
      height: 42,
      width: 42,
      decoration: BoxDecoration(
        color: AdminWebTheme.primary.withOpacity(0.08),
        shape: BoxShape.circle,
      ),
      child: imageUrl.trim().isNotEmpty
          ? ClipOval(
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: AdminWebTheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  );
                },
              ),
            )
          : Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: AdminWebTheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toLowerCase();

    final approved =
        normalized == 'approved' || normalized == 'active';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: approved
            ? const Color(0xFFEAF8EE)
            : const Color(0xFFFFF4D8),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        normalized.isEmpty
            ? 'Pending'
            : normalized.substring(0, 1).toUpperCase() +
                normalized.substring(1),
        style: TextStyle(
          color: approved
              ? Colors.green
              : const Color(0xFFB77800),
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyPeopleState extends StatelessWidget {
  final String role;
  final bool hasSearch;
  final VoidCallback onAdd;

  const _EmptyPeopleState({
    required this.role,
    required this.hasSearch,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final roleLabel =
        role == 'speaker' ? 'speaker' : 'moderator';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 50),
      child: Column(
        children: [
          Icon(
            role == 'speaker'
                ? Icons.record_voice_over_outlined
                : Icons.forum_outlined,
            color: AdminWebTheme.primary,
            size: 48,
          ),
          const SizedBox(height: 14),
          Text(
            hasSearch
                ? 'No matching ${roleLabel}s'
                : 'No ${roleLabel}s created yet',
            style: const TextStyle(
              color: AdminWebTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasSearch
                ? 'Try a different search.'
                : 'Create a $roleLabel and assign them to a particular event.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AdminWebTheme.textSecondary,
            ),
          ),
          if (!hasSearch) ...[
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: Text('Add ${roleLabel.substring(0, 1).toUpperCase()}${roleLabel.substring(1)}'),
            ),
          ],
        ],
      ),
    );
  }
}

class _CreateEventRoleDialog extends StatefulWidget {
  final String role;
  final String? existingUserId;
  final String existingName;
  final String existingEmail;
  final String existingCompany;
  final bool assignmentOnly;

  const _CreateEventRoleDialog({
    required this.role,
    this.existingUserId,
    this.existingName = '',
    this.existingEmail = '',
    this.existingCompany = '',
    this.assignmentOnly = false,
  });

  @override
  State<_CreateEventRoleDialog> createState() =>
      _CreateEventRoleDialogState();
}

class _CreateEventRoleDialogState
    extends State<_CreateEventRoleDialog> {
  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _companyController;

  String? _selectedEventId;
  String _selectedEventName = '';

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.existingName,
    );

    _emailController = TextEditingController(
      text: widget.existingEmail,
    );

    _companyController = TextEditingController(
      text: widget.existingCompany,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _eventsStream() {
    return FirebaseFirestore.instance
        .collection('events')
        .orderBy('startDate', descending: true)
        .snapshots();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (_selectedEventId == null ||
        _selectedEventId!.trim().isEmpty) {
      _showMessage('Please select an event.');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('createEventRoleAccount');

      await callable.call({
        'name': _nameController.text.trim(),
        'email': _emailController.text
            .trim()
            .toLowerCase(),
        'company': _companyController.text.trim(),
        'role': widget.role,
        'eventId': _selectedEventId,
        'eventName': _selectedEventName,
      });

      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.assignmentOnly
                ? '${widget.role == 'speaker' ? 'Speaker' : 'Moderator'} assigned to $_selectedEventName. The event invitation was sent.'
                : '${widget.role == 'speaker' ? 'Speaker' : 'Moderator'} created for $_selectedEventName. The invitation was sent.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      _showMessage(
        error.message ??
            'Failed to create ${widget.role} account.',
      );
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roleTitle =
        widget.role == 'speaker' ? 'Speaker' : 'Moderator';

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 620,
          maxHeight: 760,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: AdminWebTheme.primary
                            .withOpacity(0.08),
                        borderRadius:
                            BorderRadius.circular(14),
                      ),
                      child: Icon(
                        widget.role == 'speaker'
                            ? Icons.record_voice_over_rounded
                            : Icons.forum_rounded,
                        color: AdminWebTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.assignmentOnly
                                ? 'Assign $roleTitle to Event'
                                : 'Add $roleTitle',
                            style: const TextStyle(
                              color:
                                  AdminWebTheme.textPrimary,
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.assignmentOnly
                                ? 'The person will receive a new invitation for the selected event.'
                                : 'The person will be created for a particular event and receive an invitation email.',
                            style: const TextStyle(
                              color:
                                  AdminWebTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _saving
                          ? null
                          : () =>
                              Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                const _DialogFieldLabel('Full Name'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  enabled:
                      !_saving && !widget.assignmentOnly,
                  decoration: const InputDecoration(
                    hintText: 'Enter full name',
                    prefixIcon:
                        Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Name is required.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 18),
                const _DialogFieldLabel('Email Address'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  enabled:
                      !_saving && !widget.assignmentOnly,
                  keyboardType:
                      TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'Enter email address',
                    prefixIcon:
                        Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';

                    if (email.isEmpty) {
                      return 'Email address is required.';
                    }

                    if (!email.contains('@') ||
                        !email.contains('.')) {
                      return 'Enter a valid email address.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 18),
                const _DialogFieldLabel('Company'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _companyController,
                  enabled:
                      !_saving && !widget.assignmentOnly,
                  decoration: const InputDecoration(
                    hintText: 'Company or organisation',
                    prefixIcon:
                        Icon(Icons.business_outlined),
                  ),
                ),
                const SizedBox(height: 18),
                const _DialogFieldLabel('Assign to Event'),
                const SizedBox(height: 8),
                StreamBuilder<
                    QuerySnapshot<Map<String, dynamic>>>(
                  stream: _eventsStream(),
                  builder: (context, snapshot) {
                    final events = snapshot.data?.docs
                            .where((doc) {
                          final data = doc.data();

                          final status =
                              (data['status'] ?? '')
                                  .toString()
                                  .trim()
                                  .toLowerCase();

                          return status != 'archived' &&
                              data['isArchived'] != true;
                        }).toList() ??
                        [];

                    return DropdownButtonFormField<String>(
                      value: _selectedEventId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        hintText: 'Select event',
                        prefixIcon:
                            Icon(Icons.event_outlined),
                      ),
                      items: events.map((event) {
                        final name =
                            (event.data()['name'] ??
                                    'Unnamed Event')
                                .toString();

                        return DropdownMenuItem<String>(
                          value: event.id,
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: _saving
                          ? null
                          : (eventId) {
                              if (eventId == null) return;

                              final selectedEvent =
                                  events.firstWhere(
                                (event) =>
                                    event.id == eventId,
                              );

                              setState(() {
                                _selectedEventId = eventId;
                                _selectedEventName =
                                    (selectedEvent.data()[
                                                'name'] ??
                                            'Unnamed Event')
                                        .toString();
                              });
                            },
                      validator: (value) {
                        if (value == null ||
                            value.trim().isEmpty) {
                          return 'Please select an event.';
                        }

                        return null;
                      },
                    );
                  },
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AdminWebTheme.gold
                          .withOpacity(0.35),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.email_outlined,
                        color: AdminWebTheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'The invitation email will state that this person has been invited to the selected event as a ${widget.role}.',
                          style: const TextStyle(
                            color:
                                AdminWebTheme.textSecondary,
                            fontSize: 11.5,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () =>
                                Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            _saving ? null : _submit,
                        icon: _saving
                            ? const SizedBox(
                                height: 17,
                                width: 17,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                              ),
                        label: Text(
                          _saving
                              ? 'Processing...'
                              : widget.assignmentOnly
                                  ? 'Assign & Send'
                                  : 'Create & Send',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogFieldLabel extends StatelessWidget {
  final String label;

  const _DialogFieldLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AdminWebTheme.textPrimary,
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}