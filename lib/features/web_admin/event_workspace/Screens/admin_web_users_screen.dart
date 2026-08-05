// lib/features/web_admin/event_workspace/Screens/admin_web_users_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../admin_web_theme.dart';

class AdminWebUsersScreen extends StatefulWidget {
  final String eventId;
  final String eventName;

  const AdminWebUsersScreen({
    super.key,
    required this.eventId,
    required this.eventName,
  });

  @override
  State<AdminWebUsersScreen> createState() =>
      _AdminWebUsersScreenState();
}

class _AdminWebUsersScreenState extends State<AdminWebUsersScreen> {
  final TextEditingController _searchController =
      TextEditingController();

  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _attendeesStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'attendee')
        .where('eventIds', arrayContains: widget.eventId)
        .snapshots();
  }

  Future<void> _openEditUserDialog({
    required String userId,
    required Map<String, dynamic> userData,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditUserDialog(
        eventId: widget.eventId,
        eventName: widget.eventName,
        userId: userId,
        userData: userData,
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
          _PageHeader(eventName: widget.eventName),
          const SizedBox(height: 20),
          _SearchBar(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value.trim().toLowerCase();
              });
            },
            onClear: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
          ),
          const SizedBox(height: 18),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _attendeesStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const _LoadingCard();
              }

              if (snapshot.hasError) {
                return _MessageCard(
                  icon: Icons.error_outline_rounded,
                  title: 'Could not load users',
                  message: snapshot.error.toString(),
                );
              }

              final users = [...?snapshot.data?.docs]
                ..sort((a, b) {
                  final aName =
                      (a.data()['name'] ?? '').toString();
                  final bName =
                      (b.data()['name'] ?? '').toString();

                  return aName
                      .toLowerCase()
                      .compareTo(bName.toLowerCase());
                });

              final filtered = users.where((user) {
                if (_searchQuery.isEmpty) return true;

                final data = user.data();

                final searchable = [
                  data['name'],
                  data['email'],
                  data['company'],
                  data['position'],
                  data['phone'],
                  data['country'],
                  data['linkedin'],
                  data['twitter'],
                  data['website'],
                  data['github'],
                  data['medium'],
                  data['instagram'],
                ].map((value) {
                  return (value ?? '')
                      .toString()
                      .toLowerCase();
                }).join(' ');

                return searchable.contains(_searchQuery);
              }).toList();

              if (filtered.isEmpty) {
                return _MessageCard(
                  icon: Icons.people_outline_rounded,
                  title: users.isEmpty
                      ? 'No attendees found'
                      : 'No matching attendees',
                  message: users.isEmpty
                      ? 'No attendee accounts are currently linked to ${widget.eventName}.'
                      : 'Try searching with a different name, email, company, phone number, country, or social profile.',
                );
              }

              return _UsersTable(
                users: filtered,
                onEdit: (userId, userData) {
                  _openEditUserDialog(
                    userId: userId,
                    userData: userData,
                  );
                },
              );
            },
          ),
        ],
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
          'Users',
          style: TextStyle(
            color: AdminWebTheme.textPrimary,
            fontSize: 27,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'View attendee information, edit profile fields, and change user roles when needed.',
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

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: AdminWebTheme.border,
        ),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText:
              'Search by name, email, company, phone, country, or social profile',
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 19,
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  onPressed: onClear,
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                  ),
                ),
          filled: true,
          fillColor: const Color(0xFFFAFBFD),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: AdminWebTheme.border,
            ),
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
        ),
      ),
    );
  }
}

class _UsersTable extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> users;
  final void Function(
    String userId,
    Map<String, dynamic> userData,
  ) onEdit;

  const _UsersTable({
    required this.users,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: AdminWebTheme.border,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 850) {
            return Column(
              children: users.map((user) {
                return _MobileUserCard(
                  data: user.data(),
                  onEdit: () => onEdit(
                    user.id,
                    user.data(),
                  ),
                );
              }).toList(),
            );
          }

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: constraints.maxWidth,
              ),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFFFAFBFD),
                ),
                headingRowHeight: 46,
                dataRowMinHeight: 48,
                dataRowMaxHeight: 54,
                columnSpacing: 26,
                horizontalMargin: 20,
                headingTextStyle: const TextStyle(
                  color: AdminWebTheme.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
                dataTextStyle: const TextStyle(
                  color: AdminWebTheme.textPrimary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
                columns: const [
                  DataColumn(label: Text('USER')),
                  DataColumn(label: Text('COMPANY')),
                  DataColumn(label: Text('PHONE')),
                  DataColumn(label: Text('COUNTRY')),
                  DataColumn(label: Text('ROLE')),
                  DataColumn(label: Text('STATUS')),
                  DataColumn(label: Text('ACTIONS')),
                ],
              rows: users.map((user) {
                final data = user.data();

                final name =
                    (data['name'] ?? 'Unnamed User').toString();
                final email =
                    (data['email'] ?? '').toString();
                final company =
                    (data['company'] ?? '—').toString();
                final phone =
                    (data['phone'] ?? '—').toString();
                final country =
                    (data['country'] ?? '—').toString();
                final role =
                    (data['role'] ?? 'attendee').toString();
                final status =
                    (data['status'] ?? 'approved').toString();

                return DataRow(
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 230,
                        child: Row(
                          children: [
                            _UserAvatar(
                              imageUrl:
                                  (data['profileImageUrl'] ?? '')
                                      .toString(),
                              name: name,
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color:
                                          AdminWebTheme.textPrimary,
                                      fontSize: 11,
                                      fontWeight:
                                          FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    email,
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AdminWebTheme
                                          .textSecondary,
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
                        width: 150,
                        child: Text(
                          company.isEmpty ? '—' : company,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(Text(phone.isEmpty ? '—' : phone)),
                    DataCell(Text(country.isEmpty ? '—' : country)),
                    DataCell(_RoleBadge(role: role)),
                    DataCell(
                      _StatusBadge(
                        active:
                            status.toLowerCase() == 'approved',
                        activeText: 'Approved',
                        inactiveText: _capitalize(status),
                      ),
                    ),
                    DataCell(
                      OutlinedButton.icon(
                        onPressed: () =>
                            onEdit(user.id, data),
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 17,
                        ),
                        label: const Text('Edit'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              AdminWebTheme.primary,
                          side: const BorderSide(
                            color: AdminWebTheme.border,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                          minimumSize: const Size(72, 34),
                        ),
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

  static String _capitalize(String value) {
    if (value.isEmpty) return 'Unknown';

    return value[0].toUpperCase() +
        value.substring(1).toLowerCase();
  }
}

class _MobileUserCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onEdit;

  const _MobileUserCard({
    required this.data,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final name =
        (data['name'] ?? 'Unnamed User').toString();
    final email = (data['email'] ?? '').toString();
    final company = (data['company'] ?? '').toString();
    final role = (data['role'] ?? 'attendee').toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AdminWebTheme.border,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _UserAvatar(
                imageUrl:
                    (data['profileImageUrl'] ?? '').toString(),
                name: name,
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
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      email,
                      style: const TextStyle(
                        color: AdminWebTheme.textSecondary,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit user',
                onPressed: onEdit,
                icon: const Icon(
                  Icons.edit_outlined,
                  color: AdminWebTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SmallInfo(
                  label: 'Company',
                  value: company.isEmpty ? '—' : company,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SmallInfo(
                  label: 'Role',
                  value: role,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SmallInfo(
                  label: 'Status',
                  value:
                      (data['status'] ?? 'approved').toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditUserDialog extends StatefulWidget {
  final String eventId;
  final String eventName;
  final String userId;
  final Map<String, dynamic> userData;

  const _EditUserDialog({
    required this.eventId,
    required this.eventName,
    required this.userId,
    required this.userData,
  });

  @override
  State<_EditUserDialog> createState() =>
      _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _companyController;
  late final TextEditingController _positionController;
  late final TextEditingController _phoneController;
  late final TextEditingController _countryController;
  late final TextEditingController _bioController;

  late final TextEditingController _linkedInController;
  late final TextEditingController _twitterController;
  late final TextEditingController _websiteController;
  late final TextEditingController _githubController;
  late final TextEditingController _mediumController;
  late final TextEditingController _instagramController;
  late final TextEditingController _profileImageController;

  late String _selectedRole;
  late String _status;
  late String _profileVisibility;

  bool _saving = false;

  static const Map<String, String> _roles = {
    'attendee': 'Attendee',
    'staff': 'Staff',
    'speaker': 'Speaker',
    'moderator': 'Moderator',
    'admin': 'Admin',
  };

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: (widget.userData['name'] ?? '').toString(),
    );
    _emailController = TextEditingController(
      text: (widget.userData['email'] ?? '').toString(),
    );
    _companyController = TextEditingController(
      text: (widget.userData['company'] ?? '').toString(),
    );
    _positionController = TextEditingController(
      text: (widget.userData['position'] ??
              widget.userData['jobTitle'] ??
              '')
          .toString(),
    );
    _phoneController = TextEditingController(
      text: (widget.userData['phone'] ??
              widget.userData['phoneNumber'] ??
              '')
          .toString(),
    );
    _countryController = TextEditingController(
      text: (widget.userData['country'] ?? '').toString(),
    );
    _bioController = TextEditingController(
      text: (widget.userData['bio'] ?? '').toString(),
    );

    _linkedInController = TextEditingController(
      text: (widget.userData['linkedin'] ??
              widget.userData['linkedIn'] ??
              '')
          .toString(),
    );
    _twitterController = TextEditingController(
      text: (widget.userData['twitter'] ?? '').toString(),
    );
    _websiteController = TextEditingController(
      text: (widget.userData['website'] ?? '').toString(),
    );
    _githubController = TextEditingController(
      text: (widget.userData['github'] ?? '').toString(),
    );
    _mediumController = TextEditingController(
      text: (widget.userData['medium'] ?? '').toString(),
    );
    _instagramController = TextEditingController(
      text: (widget.userData['instagram'] ?? '').toString(),
    );
    _profileImageController = TextEditingController(
      text: (widget.userData['profileImageUrl'] ?? '').toString(),
    );

    final currentRole =
        (widget.userData['role'] ?? 'attendee')
            .toString()
            .toLowerCase();

    _selectedRole =
        _roles.containsKey(currentRole) ? currentRole : 'attendee';

    final rawStatus =
        (widget.userData['status'] ?? 'approved')
            .toString()
            .toLowerCase();

    _status = const [
      'approved',
      'pending',
      'suspended',
    ].contains(rawStatus)
        ? rawStatus
        : 'approved';

    final visibility =
        (widget.userData['profileVisibility'] ?? 'full')
            .toString()
            .toLowerCase();

    _profileVisibility = const [
      'full',
      'limited',
      'private',
    ].contains(visibility)
        ? visibility
        : 'full';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    _positionController.dispose();
    _phoneController.dispose();
    _countryController.dispose();
    _bioController.dispose();
    _linkedInController.dispose();
    _twitterController.dispose();
    _websiteController.dispose();
    _githubController.dispose();
    _mediumController.dispose();
    _instagramController.dispose();
    _profileImageController.dispose();
    super.dispose();
  }

  Future<bool> _confirmRoleChange() async {
    final oldRole =
        (widget.userData['role'] ?? 'attendee')
            .toString()
            .toLowerCase();

    if (oldRole == _selectedRole) return true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Change User Role?',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'This user will be changed from '
            '${_roles[oldRole] ?? oldRole} to '
            '${_roles[_selectedRole] ?? _selectedRole}.\n\n'
            'After saving, the user may move to another management page and disappear from the attendee list.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(true),
              child: const Text('Change Role'),
            ),
          ],
        );
      },
    );

    return confirmed == true;
  }

  Future<void> _saveChanges() async {
    FocusScope.of(context).unfocus();

    if (_saving || !_formKey.currentState!.validate()) {
      return;
    }

    final confirmed = await _confirmRoleChange();

    if (!confirmed) return;

    setState(() => _saving = true);

    try {
      final reference = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId);

      await reference.set({
        'name': _nameController.text.trim(),
        'company': _companyController.text.trim(),
        'position': _positionController.text.trim(),
        'jobTitle': _positionController.text.trim(),
        'phone': _phoneController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'country': _countryController.text.trim(),
        'bio': _bioController.text.trim(),

        'linkedin': _linkedInController.text.trim(),
        'linkedIn': _linkedInController.text.trim(),
        'twitter': _twitterController.text.trim(),
        'website': _websiteController.text.trim(),
        'github': _githubController.text.trim(),
        'medium': _mediumController.text.trim(),
        'instagram': _instagramController.text.trim(),
        'profileImageUrl': _profileImageController.text.trim(),

        'role': _selectedRole,
        'status': _status,
        'profileVisibility': _profileVisibility,
        'eventIds': FieldValue.arrayUnion([widget.eventId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_nameController.text.trim()} was updated successfully.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to update user: $error',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _WebDialogFrame(
      width: 980,
      title: 'Edit User',
      subtitle:
          'Review and update profile information for ${widget.eventName}.',
      icon: Icons.manage_accounts_outlined,
      onClose:
          _saving ? null : () => Navigator.of(context).pop(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProfileSummary(
              nameController: _nameController,
              emailController: _emailController,
              imageController: _profileImageController,
            ),
            const SizedBox(height: 16),
            _DialogSection(
              title: 'Personal Information',
              subtitle:
                  'Edit the profile fields shown to other users.',
              child: Column(
                children: [
                  _ResponsiveDialogFields(
                    children: [
                      _EditableField(
                        label: 'Full Name',
                        hint: 'Enter full name',
                        controller: _nameController,
                        icon: Icons.person_outline_rounded,
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'Name is required';
                          }

                          return null;
                        },
                      ),
                      _EditableField(
                        label: 'Email Address',
                        hint: '',
                        controller: _emailController,
                        icon: Icons.mail_outline_rounded,
                        enabled: false,
                        allowClear: false,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _ResponsiveDialogFields(
                    children: [
                      _EditableField(
                        label: 'Company / Organisation',
                        hint: 'Enter company',
                        controller: _companyController,
                        icon: Icons.business_outlined,
                      ),
                      _EditableField(
                        label: 'Job Title',
                        hint: 'Enter job title',
                        controller: _positionController,
                        icon: Icons.badge_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _ResponsiveDialogFields(
                    children: [
                      _EditableField(
                        label: 'Phone Number',
                        hint: 'Enter phone number',
                        controller: _phoneController,
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      _EditableField(
                        label: 'Country',
                        hint: 'Enter country',
                        controller: _countryController,
                        icon: Icons.public_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _EditableField(
                    label: 'Bio',
                    hint: 'Enter biography',
                    controller: _bioController,
                    icon: Icons.notes_rounded,
                    maxLines: 5,
                  ),
                  const SizedBox(height: 14),
                  _EditableField(
                    label: 'Profile Image URL',
                    hint: 'Paste the profile image URL',
                    controller: _profileImageController,
                    icon: Icons.image_outlined,
                    keyboardType: TextInputType.url,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _DialogSection(
              title: 'Social Profiles',
              subtitle:
                  'Add, update, or remove the user’s social links.',
              child: Column(
                children: [
                  _ResponsiveDialogFields(
                    children: [
                      _EditableField(
                        label: 'LinkedIn',
                        hint: 'LinkedIn profile URL',
                        controller: _linkedInController,
                        icon: Icons.link_rounded,
                        keyboardType: TextInputType.url,
                      ),
                      _EditableField(
                        label: 'Twitter / X',
                        hint: 'Twitter or X profile URL',
                        controller: _twitterController,
                        icon: Icons.alternate_email_rounded,
                        keyboardType: TextInputType.url,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _ResponsiveDialogFields(
                    children: [
                      _EditableField(
                        label: 'Website',
                        hint: 'Website URL',
                        controller: _websiteController,
                        icon: Icons.language_rounded,
                        keyboardType: TextInputType.url,
                      ),
                      _EditableField(
                        label: 'GitHub',
                        hint: 'GitHub profile URL',
                        controller: _githubController,
                        icon: Icons.code_rounded,
                        keyboardType: TextInputType.url,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _ResponsiveDialogFields(
                    children: [
                      _EditableField(
                        label: 'Medium',
                        hint: 'Medium profile URL',
                        controller: _mediumController,
                        icon: Icons.article_outlined,
                        keyboardType: TextInputType.url,
                      ),
                      _EditableField(
                        label: 'Instagram',
                        hint: 'Instagram profile URL',
                        controller: _instagramController,
                        icon: Icons.photo_camera_outlined,
                        keyboardType: TextInputType.url,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _DialogSection(
              title: 'Role & Access',
              subtitle:
                  'Changing the role changes which interface and management page the user belongs to.',
              child: Column(
                children: [
                  _ResponsiveDialogFields(
                    children: [
                      _DialogDropdown(
                        label: 'User Role',
                        value: _selectedRole,
                        icon:
                            Icons.admin_panel_settings_outlined,
                        items: _roles,
                        onChanged: (value) {
                          if (value == null) return;

                          setState(() {
                            _selectedRole = value;
                          });
                        },
                      ),
                      _DialogDropdown(
                        label: 'Account Status',
                        value: _status,
                        icon: Icons.verified_user_outlined,
                        items: const {
                          'approved': 'Approved',
                          'pending': 'Pending',
                          'suspended': 'Suspended',
                        },
                        onChanged: (value) {
                          if (value == null) return;

                          setState(() => _status = value);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _DialogDropdown(
                    label: 'Profile Visibility',
                    value: _profileVisibility,
                    icon: Icons.visibility_outlined,
                    items: const {
                      'full': 'Full',
                      'limited': 'Limited',
                      'private': 'Private',
                    },
                    onChanged: (value) {
                      if (value == null) return;

                      setState(() {
                        _profileVisibility = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _DialogActions(
              saving: _saving,
              onCancel: () => Navigator.of(context).pop(),
              onSubmit: _saveChanges,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSummary extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController imageController;

  const _ProfileSummary({
    required this.nameController,
    required this.emailController,
    required this.imageController,
  });

  @override
  Widget build(BuildContext context) {
    final name = nameController.text.trim();
    final imageUrl = imageController.text.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: AdminWebTheme.border,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor:
                AdminWebTheme.primary.withOpacity(0.10),
            backgroundImage:
                imageUrl.isEmpty ? null : NetworkImage(imageUrl),
            child: imageUrl.isEmpty
                ? Text(
                    name.isEmpty ? 'U' : name[0].toUpperCase(),
                    style: const TextStyle(
                      color: AdminWebTheme.primary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Unnamed User' : name,
                  style: const TextStyle(
                    color: AdminWebTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  emailController.text,
                  style: const TextStyle(
                    color: AdminWebTheme.textSecondary,
                    fontSize: 10.5,
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

class _EditableField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool enabled;
  final bool allowClear;
  final int maxLines;

  const _EditableField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.icon,
    this.validator,
    this.keyboardType,
    this.enabled = true,
    this.allowClear = true,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setLocalState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FieldLabel(label),
            const SizedBox(height: 7),
            TextFormField(
              controller: controller,
              enabled: enabled,
              validator: validator,
              keyboardType: keyboardType,
              maxLines: maxLines,
              onChanged: (_) => setLocalState(() {}),
              decoration: _dialogInputDecoration(
                hint: hint,
                icon: icon,
              ).copyWith(
                suffixIcon: enabled &&
                        allowClear &&
                        controller.text.trim().isNotEmpty
                    ? IconButton(
                        tooltip: 'Clear $label',
                        onPressed: () {
                          controller.clear();
                          setLocalState(() {});
                        },
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.redAccent,
                          size: 19,
                        ),
                      )
                    : null,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WebDialogFrame extends StatelessWidget {
  final double width;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onClose;
  final Widget child;

  const _WebDialogFrame({
    required this.width,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onClose,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: width,
          maxHeight:
              MediaQuery.sizeOf(context).height - 48,
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
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: AdminWebTheme.border,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 43,
                      height: 43,
                      decoration: BoxDecoration(
                        color: AdminWebTheme.primary
                            .withOpacity(0.08),
                        borderRadius:
                            BorderRadius.circular(11),
                      ),
                      child: Icon(
                        icon,
                        color: AdminWebTheme.primary,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 13),
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
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              color: AdminWebTheme
                                  .textSecondary,
                              fontSize: 10.5,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onClose,
                      icon: const Icon(
                        Icons.close_rounded,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _DialogSection({
    required this.title,
    required this.subtitle,
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
        border: Border.all(
          color: AdminWebTheme.border,
        ),
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
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: AdminWebTheme.textSecondary,
              fontSize: 9.5,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ResponsiveDialogFields extends StatelessWidget {
  final List<Widget> children;

  const _ResponsiveDialogFields({
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
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
          crossAxisAlignment: CrossAxisAlignment.start,
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

class _DialogDropdown extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Map<String, String> items;
  final ValueChanged<String?> onChanged;

  const _DialogDropdown({
    required this.label,
    required this.value,
    required this.icon,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 7),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          decoration: _dialogInputDecoration(
            hint: '',
            icon: icon,
          ),
          items: items.entries.map((entry) {
            return DropdownMenuItem(
              value: entry.key,
              child: Text(entry.value),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

InputDecoration _dialogInputDecoration({
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
    disabledBorder: OutlineInputBorder(
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

class _DialogActions extends StatelessWidget {
  final bool saving;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  const _DialogActions({
    required this.saving,
    required this.onCancel,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Spacer(),
        OutlinedButton(
          onPressed: saving ? null : onCancel,
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          onPressed: saving ? null : onSubmit,
          icon: saving
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(
                  Icons.save_outlined,
                  size: 18,
                ),
          label: Text(
            saving ? 'Saving...' : 'Save Changes',
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AdminWebTheme.primary,
          ),
        ),
      ],
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final String imageUrl;
  final String name;

  const _UserAvatar({
    required this.imageUrl,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty
        ? 'U'
        : name.trim()[0].toUpperCase();

    return CircleAvatar(
      radius: 22,
      backgroundColor:
          AdminWebTheme.primary.withOpacity(0.10),
      backgroundImage: imageUrl.trim().isEmpty
          ? null
          : NetworkImage(imageUrl.trim()),
      child: imageUrl.trim().isEmpty
          ? Text(
              initial,
              style: const TextStyle(
                color: AdminWebTheme.primary,
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;

  const _RoleBadge({
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final label = role.isEmpty
        ? 'Attendee'
        : role[0].toUpperCase() +
            role.substring(1).toLowerCase();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: AdminWebTheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AdminWebTheme.primary,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool active;
  final String activeText;
  final String inactiveText;

  const _StatusBadge({
    required this.active,
    required this.activeText,
    required this.inactiveText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: active
            ? Colors.green.withOpacity(0.10)
            : Colors.orange.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active ? activeText : inactiveText,
        style: TextStyle(
          color: active
              ? Colors.green.shade700
              : Colors.orange.shade800,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SmallInfo extends StatelessWidget {
  final String label;
  final String value;

  const _SmallInfo({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFD),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AdminWebTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AdminWebTheme.textSecondary,
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AdminWebTheme.textPrimary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
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

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: AdminWebTheme.border,
        ),
      ),
      child: const CircularProgressIndicator(),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 54,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: AdminWebTheme.border,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: AdminWebTheme.primary,
            size: 38,
          ),
          const SizedBox(height: 13),
          Text(
            title,
            textAlign: TextAlign.center,
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
