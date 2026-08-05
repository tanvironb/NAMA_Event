// lib/features/web_admin/event_workspace/Screens/admin_web_moderators_screen.dart

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../admin_web_theme.dart';

class AdminWebModeratorsScreen extends StatefulWidget {
  final String eventId;
  final String eventName;

  const AdminWebModeratorsScreen({
    super.key,
    required this.eventId,
    required this.eventName,
  });

  @override
  State<AdminWebModeratorsScreen> createState() =>
      _AdminWebModeratorsScreenState();
}

class _AdminWebModeratorsScreenState
    extends State<AdminWebModeratorsScreen> {
  final TextEditingController _searchController =
      TextEditingController();

  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _moderatorsStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'moderator')
        .where('eventIds', arrayContains: widget.eventId)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _sessionsStream() {
    return FirebaseFirestore.instance
        .collection('sessions')
        .where('eventId', isEqualTo: widget.eventId)
        .snapshots();
  }

  Future<void> _openCreateModeratorDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CreateModeratorDialog(
        eventId: widget.eventId,
        eventName: widget.eventName,
      ),
    );
  }

  Future<void> _openEditModeratorDialog({
    required String moderatorId,
    required Map<String, dynamic> moderatorData,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>>
        sessions,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditModeratorDialog(
        eventId: widget.eventId,
        eventName: widget.eventName,
        moderatorId: moderatorId,
        moderatorData: moderatorData,
        sessions: sessions,
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
            onCreateModerator: _openCreateModeratorDialog,
          ),
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
            stream: _sessionsStream(),
            builder: (context, sessionsSnapshot) {
              if (sessionsSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const _LoadingCard();
              }

              if (sessionsSnapshot.hasError) {
                return _MessageCard(
                  icon: Icons.error_outline_rounded,
                  title: 'Could not load sessions',
                  message: sessionsSnapshot.error.toString(),
                );
              }

              final sessions = [...?sessionsSnapshot.data?.docs]
                ..sort((a, b) {
                  final aTime = a.data()['startTime'];
                  final bTime = b.data()['startTime'];

                  if (aTime is Timestamp && bTime is Timestamp) {
                    return aTime.compareTo(bTime);
                  }

                  return 0;
                });

              return StreamBuilder<
                  QuerySnapshot<Map<String, dynamic>>>(
                stream: _moderatorsStream(),
                builder: (context, moderatorsSnapshot) {
                  if (moderatorsSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const _LoadingCard();
                  }

                  if (moderatorsSnapshot.hasError) {
                    return _MessageCard(
                      icon: Icons.error_outline_rounded,
                      title: 'Could not load moderators',
                      message: moderatorsSnapshot.error.toString(),
                    );
                  }

                  final moderators = [
                    ...?moderatorsSnapshot.data?.docs
                  ]..sort((a, b) {
                      final aName =
                          (a.data()['name'] ?? '').toString();
                      final bName =
                          (b.data()['name'] ?? '').toString();

                      return aName
                          .toLowerCase()
                          .compareTo(bName.toLowerCase());
                    });

                  final filtered = moderators.where((moderator) {
                    if (_searchQuery.isEmpty) return true;

                    final data = moderator.data();

                    final searchable = [
                      data['name'],
                      data['email'],
                      data['company'],
                      data['position'],
                      data['title'],
                    ].map((value) {
                      return (value ?? '')
                          .toString()
                          .toLowerCase();
                    }).join(' ');

                    return searchable.contains(_searchQuery);
                  }).toList();

                  if (filtered.isEmpty) {
                    return _MessageCard(
                      icon: Icons.support_agent_outlined,
                      title: moderators.isEmpty
                          ? 'No moderators created yet'
                          : 'No matching moderators',
                      message: moderators.isEmpty
                          ? 'Create the first moderator for ${widget.eventName}.'
                          : 'Try searching with a different name, email, or company.',
                      buttonLabel:
                          moderators.isEmpty ? 'Create Moderator' : null,
                      onPressed: moderators.isEmpty
                          ? _openCreateModeratorDialog
                          : null,
                    );
                  }

                  return _ModeratorsTable(
                    moderators: filtered,
                    sessions: sessions,
                    onEdit: (
                      moderatorId,
                      moderatorData,
                    ) {
                      _openEditModeratorDialog(
                        moderatorId: moderatorId,
                        moderatorData: moderatorData,
                        sessions: sessions,
                      );
                    },
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
  final VoidCallback onCreateModerator;

  const _PageHeader({
    required this.eventName,
    required this.onCreateModerator,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final heading = Column(
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
              'Moderators',
              style: TextStyle(
                color: AdminWebTheme.textPrimary,
                fontSize: 27,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Create moderators, assign them to event sessions, and update their profile and account details.',
              style: TextStyle(
                color: AdminWebTheme.textSecondary,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        );

        final action = FilledButton.icon(
          onPressed: onCreateModerator,
          icon: const Icon(
            Icons.person_add_alt_1_rounded,
            size: 18,
          ),
          label: const Text('Create Moderator'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(150, 43),
            backgroundColor: AdminWebTheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

        if (constraints.maxWidth < 700) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              const SizedBox(height: 16),
              action,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: heading),
            const SizedBox(width: 20),
            action,
          ],
        );
      },
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
              'Search by name, email, company, position, or title',
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

class _ModeratorsTable extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>>
      moderators;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>>
      sessions;
  final void Function(
    String moderatorId,
    Map<String, dynamic> moderatorData,
  ) onEdit;

  const _ModeratorsTable({
    required this.moderators,
    required this.sessions,
    required this.onEdit,
  });

  int _sessionCount(String moderatorId) {
    return sessions.where((session) {
      final ids = session.data()['moderatorIds'];

      return ids is List &&
          ids.map((value) => value.toString()).contains(moderatorId);
    }).length;
  }

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
              children: moderators.map((moderator) {
                final data = moderator.data();

                return _MobileModeratorCard(
                  moderatorId: moderator.id,
                  data: data,
                  sessionCount: _sessionCount(moderator.id),
                  onEdit: () => onEdit(moderator.id, data),
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
              columnSpacing: 26,
              horizontalMargin: 18,
              columns: const [
                DataColumn(label: Text('MODERATOR')),
                DataColumn(label: Text('COMPANY')),
                DataColumn(label: Text('POSITION')),
                DataColumn(
  label: SizedBox(
    width: 90,
    child: Center(
      child: Text('SESSIONS'),
    ),
  ),
),
                DataColumn(label: Text('STATUS')),
                DataColumn(label: Text('VERIFICATION')),
                DataColumn(label: Text('ACTIONS')),
              ],
              rows: moderators.map((moderator) {
                final data = moderator.data();

                final name =
                    (data['name'] ?? 'Unnamed Moderator').toString();
                final email =
                    (data['email'] ?? '').toString();
                final company =
                    (data['company'] ?? '—').toString();
                final position =
                    (data['position'] ?? '').toString().trim();
                final status =
                    (data['status'] ?? 'approved').toString();
                final verified =
                    data['emailVerified'] == true;

                return DataRow(
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 230,
                        child: Row(
                          children: [
                            _ModeratorAvatar(
                              imageUrl: (data['profileImageUrl'] ?? '')
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
                    DataCell(
                      SizedBox(
                        width: 150,
                        child: Text(
                          position.isEmpty ? '—' : position,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
DataCell(
  SizedBox(
    width: 90,
    child: Center(
      child: Text(
        '${_sessionCount(moderator.id)}',
        style: const TextStyle(
          color: AdminWebTheme.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  ),
),
                    DataCell(
                      _StatusBadge(
                        active:
                            status.toLowerCase() == 'approved',
                        activeText: 'Approved',
                        inactiveText: status.isEmpty
                            ? 'Unknown'
                            : _capitalize(status),
                      ),
                    ),
                    DataCell(
                      _StatusBadge(
                        active: verified,
                        activeText: 'Verified',
                        inactiveText: 'Pending',
                      ),
                    ),
                    DataCell(
                      OutlinedButton.icon(
                        onPressed: () =>
                            onEdit(moderator.id, data),
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
                          minimumSize: const Size(72, 34),
                          textStyle: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
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
    if (value.isEmpty) return value;

    return value[0].toUpperCase() +
        value.substring(1).toLowerCase();
  }
}

class _MobileModeratorCard extends StatelessWidget {
  final String moderatorId;
  final Map<String, dynamic> data;
  final int sessionCount;
  final VoidCallback onEdit;

  const _MobileModeratorCard({
    required this.moderatorId,
    required this.data,
    required this.sessionCount,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final name =
        (data['name'] ?? 'Unnamed Moderator').toString();
    final email = (data['email'] ?? '').toString();
    final company = (data['company'] ?? '').toString();
    final position = (data['position'] ?? '').toString();

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
              _ModeratorAvatar(
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
                tooltip: 'Edit moderator',
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
                  label: 'Position',
                  value: position.isEmpty ? '—' : position,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SmallInfo(
                  label: 'Sessions',
                  value: '$sessionCount',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreateModeratorDialog extends StatefulWidget {
  final String eventId;
  final String eventName;

  const _CreateModeratorDialog({
    required this.eventId,
    required this.eventName,
  });

  @override
  State<_CreateModeratorDialog> createState() =>
      _CreateModeratorDialogState();
}

class _CreateModeratorDialogState
    extends State<_CreateModeratorDialog> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _companyController = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  String _generateTemporaryPassword() {
    const upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    const lower = 'abcdefghijkmnopqrstuvwxyz';
    const numbers = '23456789';
    const symbols = '@#%!';
    final random = Random.secure();

    String pick(String source) =>
        source[random.nextInt(source.length)];

    final values = <String>[
      pick(upper),
      pick(lower),
      pick(numbers),
      pick(symbols),
    ];

    const all = '$upper$lower$numbers$symbols';

    while (values.length < 12) {
      values.add(pick(all));
    }

    values.shuffle(random);

    return values.join();
  }

  Future<String> _createAuthAccount({
    required String name,
    required String email,
    required String password,
  }) async {
    FirebaseApp? secondaryApp;

    try {
      secondaryApp = await Firebase.initializeApp(
        name:
            'web_moderator_${DateTime.now().microsecondsSinceEpoch}',
        options: Firebase.app().options,
      );

      final secondaryAuth =
          FirebaseAuth.instanceFor(app: secondaryApp);

      final credential =
          await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;

      if (user == null || user.uid.isEmpty) {
        throw Exception(
          'Moderator account could not be created.',
        );
      }

      await user.updateDisplayName(name);
      await user.sendEmailVerification();
      await secondaryAuth.signOut();

      return user.uid;
    } finally {
      if (secondaryApp != null) {
        await secondaryApp.delete();
      }
    }
  }

  Future<void> _createModerator() async {
    FocusScope.of(context).unfocus();

    if (_saving || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _saving = true);

    final name = _nameController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final company = _companyController.text.trim();

    try {
      final existing = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        final doc = existing.docs.first;
        final data = doc.data();
        final existingRole =
            (data['role'] ?? '').toString().toLowerCase();

        if (existingRole.isNotEmpty &&
            existingRole != 'moderator') {
          throw Exception(
            'This email already belongs to a $existingRole account.',
          );
        }

        await doc.reference.set({
          'uid': doc.id,
          'name': name,
          'email': email,
          'company': company,
          'role': 'moderator',
          'title': (data['title'] ?? 'Moderator').toString(),
          'position': (data['position'] ?? '').toString(),
          'bio': (data['bio'] ?? '').toString(),
          'status': 'approved',
          'eventIds':
              FieldValue.arrayUnion([widget.eventId]),
          'createdByAdmin': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (!mounted) return;

        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$name was added to ${widget.eventName}.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );

        return;
      }

      final password = _generateTemporaryPassword();

      final uid = await _createAuthAccount(
        name: name,
        email: email,
        password: password,
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({
        'uid': uid,
        'name': name,
        'email': email,
        'role': 'moderator',
        'company': company,
        'title': 'Moderator',
        'position': '',
        'bio': '',
        'profileImageUrl': '',
        'status': 'approved',
        'points': 0,
        'eventIds': [widget.eventId],
        'activeEventId': widget.eventId,
        'currentEventId': widget.eventId,
        'profileVisibility': 'full',
        'needsPrivacySelection': false,
        'createdByAdmin': true,
        'authAccountCreated': true,
        'emailVerificationRequired': true,
        'emailVerified': false,
        'moderatorPassword': password,
        'plainPassword': password,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.of(context).pop();

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text(
              'Moderator Created',
              style: TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
            content: SelectableText(
              '$name has been created and added to ${widget.eventName}.\n\n'
              'Email: $email\n'
              'Temporary password: $password\n\n'
              'The existing verification and moderator invitation email flow will continue from the account and Firestore role creation.',
            ),
            actions: [
              FilledButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(),
                child: const Text('Done'),
              ),
            ],
          );
        },
      );
    } on FirebaseAuthException catch (error) {
      _showError(
        error.message ?? error.code,
      );
    } catch (error) {
      _showError(
        error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showError(String message) {
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
    return _WebDialogFrame(
      width: 650,
      title: 'Create Moderator',
      subtitle:
          'Create a moderator account for ${widget.eventName}. Session assignment can be completed from Edit Moderator.',
      icon: Icons.person_add_alt_1_rounded,
      onClose:
          _saving ? null : () => Navigator.of(context).pop(),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _DialogTextField(
              label: 'Full Name',
              hint: 'Enter moderator name',
              controller: _nameController,
              icon: Icons.person_outline_rounded,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Moderator name is required';
                }

                return null;
              },
            ),
            const SizedBox(height: 14),
            _DialogTextField(
              label: 'Email Address',
              hint: 'moderator@example.com',
              controller: _emailController,
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                final email =
                    value?.trim().toLowerCase() ?? '';

                if (email.isEmpty) {
                  return 'Email address is required';
                }

                if (!email.contains('@') ||
                    !email.contains('.')) {
                  return 'Enter a valid email address';
                }

                return null;
              },
            ),
            const SizedBox(height: 14),
            _DialogTextField(
              label: 'Company / Organisation',
              hint: 'Enter company or organisation',
              controller: _companyController,
              icon: Icons.business_outlined,
            ),
            const SizedBox(height: 20),
            _DialogActions(
              saving: _saving,
              cancelLabel: 'Cancel',
              submitLabel: 'Create Moderator',
              submitIcon: Icons.person_add_alt_1_rounded,
              onCancel: () => Navigator.of(context).pop(),
              onSubmit: _createModerator,
            ),
          ],
        ),
      ),
    );
  }
}

class _EditModeratorDialog extends StatefulWidget {
  final String eventId;
  final String eventName;
  final String moderatorId;
  final Map<String, dynamic> moderatorData;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>>
      sessions;

  const _EditModeratorDialog({
    required this.eventId,
    required this.eventName,
    required this.moderatorId,
    required this.moderatorData,
    required this.sessions,
  });

  @override
  State<_EditModeratorDialog> createState() =>
      _EditModeratorDialogState();
}

class _EditModeratorDialogState
    extends State<_EditModeratorDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _companyController;
  late final TextEditingController _titleController;
  late final TextEditingController _positionController;
  late final TextEditingController _bioController;

  late final TextEditingController _phoneController;
  late final TextEditingController _countryController;
  late final TextEditingController _linkedInController;
  late final TextEditingController _twitterController;
  late final TextEditingController _websiteController;
  late final TextEditingController _githubController;
  late final TextEditingController _mediumController;
  late final TextEditingController _instagramController;
  late final TextEditingController _profileImageController;

  late String _status;
  late String _profileVisibility;

  final Set<String> _selectedSessionIds = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: (widget.moderatorData['name'] ?? '').toString(),
    );
    _emailController = TextEditingController(
      text: (widget.moderatorData['email'] ?? '').toString(),
    );
    _companyController = TextEditingController(
      text: (widget.moderatorData['company'] ?? '').toString(),
    );
    _titleController = TextEditingController(
      text: (widget.moderatorData['title'] ?? 'Moderator')
          .toString(),
    );
    _positionController = TextEditingController(
      text: (widget.moderatorData['position'] ?? '').toString(),
    );
    _bioController = TextEditingController(
      text: (widget.moderatorData['bio'] ?? '').toString(),
    );

    _phoneController = TextEditingController(
      text: (widget.moderatorData['phone'] ??
              widget.moderatorData['phoneNumber'] ??
              '')
          .toString(),
    );
    _countryController = TextEditingController(
      text: (widget.moderatorData['country'] ?? '').toString(),
    );
    _linkedInController = TextEditingController(
      text: (widget.moderatorData['linkedin'] ??
              widget.moderatorData['linkedIn'] ??
              '')
          .toString(),
    );
    _twitterController = TextEditingController(
      text: (widget.moderatorData['twitter'] ?? '').toString(),
    );
    _websiteController = TextEditingController(
      text: (widget.moderatorData['website'] ?? '').toString(),
    );
    _githubController = TextEditingController(
      text: (widget.moderatorData['github'] ?? '').toString(),
    );
    _mediumController = TextEditingController(
      text: (widget.moderatorData['medium'] ?? '').toString(),
    );
    _instagramController = TextEditingController(
      text: (widget.moderatorData['instagram'] ?? '').toString(),
    );
    _profileImageController = TextEditingController(
      text: (widget.moderatorData['profileImageUrl'] ?? '').toString(),
    );

    final rawStatus =
        (widget.moderatorData['status'] ?? 'approved')
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
        (widget.moderatorData['profileVisibility'] ?? 'full')
            .toString()
            .toLowerCase();

    _profileVisibility = const [
      'full',
      'limited',
      'private',
    ].contains(visibility)
        ? visibility
        : 'full';

    for (final session in widget.sessions) {
      final moderatorIds = session.data()['moderatorIds'];

      if (moderatorIds is List &&
          moderatorIds
              .map((value) => value.toString())
              .contains(widget.moderatorId)) {
        _selectedSessionIds.add(session.id);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    _titleController.dispose();
    _positionController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    _countryController.dispose();
    _linkedInController.dispose();
    _twitterController.dispose();
    _websiteController.dispose();
    _githubController.dispose();
    _mediumController.dispose();
    _instagramController.dispose();
    _profileImageController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    FocusScope.of(context).unfocus();

    if (_saving || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _saving = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      final userReference =
          firestore.collection('users').doc(widget.moderatorId);

      batch.set(
        userReference,
        {
          'name': _nameController.text.trim(),
          'company': _companyController.text.trim(),
          'title': _titleController.text.trim().isEmpty
              ? 'Moderator'
              : _titleController.text.trim(),
          'position': _positionController.text.trim(),
          'jobTitle': _positionController.text.trim(),
          'bio': _bioController.text.trim(),
          'phone': _phoneController.text.trim(),
          'phoneNumber': _phoneController.text.trim(),
          'country': _countryController.text.trim(),
          'linkedin': _linkedInController.text.trim(),
          'linkedIn': _linkedInController.text.trim(),
          'twitter': _twitterController.text.trim(),
          'website': _websiteController.text.trim(),
          'github': _githubController.text.trim(),
          'medium': _mediumController.text.trim(),
          'instagram': _instagramController.text.trim(),
          'profileImageUrl': _profileImageController.text.trim(),
          'role': 'moderator',
          'status': _status,
          'profileVisibility': _profileVisibility,
          'eventIds':
              FieldValue.arrayUnion([widget.eventId]),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      for (final session in widget.sessions) {
        if (_selectedSessionIds.contains(session.id)) {
          batch.update(
            session.reference,
            {
              'moderatorIds':
                  FieldValue.arrayUnion([widget.moderatorId]),
              'updatedAt': FieldValue.serverTimestamp(),
            },
          );
        } else {
          batch.update(
            session.reference,
            {
              'moderatorIds':
                  FieldValue.arrayRemove([widget.moderatorId]),
              'updatedAt': FieldValue.serverTimestamp(),
            },
          );
        }
      }

      await batch.commit();

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
            'Failed to update moderator: $error',
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
      width: 880,
      title: 'Edit Moderator',
      subtitle:
          'Update moderator details and assign sessions from ${widget.eventName}.',
      icon: Icons.manage_accounts_outlined,
      onClose:
          _saving ? null : () => Navigator.of(context).pop(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DialogSection(
              title: 'Account Information',
              subtitle:
                  'The email is linked to Firebase Authentication and cannot be changed here.',
              child: Column(
                children: [
                  _ResponsiveDialogFields(
                    children: [
                      _DialogTextField(
                        label: 'Full Name',
                        hint: 'Enter moderator name',
                        controller: _nameController,
                        icon:
                            Icons.person_outline_rounded,
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'Name is required';
                          }

                          return null;
                        },
                      ),
                      _DialogTextField(
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
                      _DialogTextField(
                        label: 'Company / Organisation',
                        hint: 'Enter company',
                        controller: _companyController,
                        icon: Icons.business_outlined,
                      ),
                      _DialogTextField(
                        label: 'Position',
                        hint: 'Example: Director',
                        controller: _positionController,
                        icon: Icons.badge_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _DialogTextField(
                    label: 'Profile Title',
                    hint: 'Example: Keynote Moderator',
                    controller: _titleController,
                    icon:
                        Icons.workspace_premium_outlined,
                  ),
                  const SizedBox(height: 14),
                  _DialogTextField(
                    label: 'Biography',
                    hint: 'Enter moderator biography',
                    controller: _bioController,
                    icon: Icons.notes_rounded,
                    maxLines: 5,
                  ),

                  const SizedBox(height: 14),
                  _ResponsiveDialogFields(
                    children: [
                      _DialogTextField(
                        label: 'Phone Number',
                        hint: 'Enter phone number',
                        controller: _phoneController,
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      _DialogTextField(
                        label: 'Country',
                        hint: 'Enter country',
                        controller: _countryController,
                        icon: Icons.public_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _DialogTextField(
                    label: 'Profile Image URL',
                    hint: 'Paste profile image URL',
                    controller: _profileImageController,
                    icon: Icons.image_outlined,
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 14),
                  _ResponsiveDialogFields(
                    children: [
                      _DialogDropdown(
                        label: 'Account Status',
                        value: _status,
                        icon:
                            Icons.verified_user_outlined,
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

                          setState(
                            () => _profileVisibility = value,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _DialogSection(
              title: 'Social Profiles',
              subtitle:
                  'Add, update, or clear the profile links shown to users.',
              child: Column(
                children: [
                  _ResponsiveDialogFields(
                    children: [
                      _DialogTextField(
                        label: 'LinkedIn',
                        hint: 'LinkedIn profile URL',
                        controller: _linkedInController,
                        icon: Icons.link_rounded,
                        keyboardType: TextInputType.url,
                      ),
                      _DialogTextField(
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
                      _DialogTextField(
                        label: 'Website',
                        hint: 'Website URL',
                        controller: _websiteController,
                        icon: Icons.language_rounded,
                        keyboardType: TextInputType.url,
                      ),
                      _DialogTextField(
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
                      _DialogTextField(
                        label: 'Medium',
                        hint: 'Medium profile URL',
                        controller: _mediumController,
                        icon: Icons.article_outlined,
                        keyboardType: TextInputType.url,
                      ),
                      _DialogTextField(
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
              title: 'Session Assignment',
              subtitle:
                  'Select every session where this moderator should appear.',
              child: widget.sessions.isEmpty
                  ? const _InlineEmptyState(
                      title: 'No sessions available',
                      message:
                          'Create event sessions first, then return here to assign the moderator.',
                    )
                  : Column(
                      children: widget.sessions.map((session) {
                        final data = session.data();
                        final selected =
                            _selectedSessionIds.contains(session.id);

                        return _SessionAssignmentTile(
                          title: (data['title'] ??
                                  'Untitled Session')
                              .toString(),
                          category:
                              (data['category'] ?? '').toString(),
                          schedule:
                              _formatTimestamp(data['startTime']),
                          selected: selected,
                          onChanged: (value) {
                            setState(() {
                              if (value) {
                                _selectedSessionIds.add(session.id);
                              } else {
                                _selectedSessionIds
                                    .remove(session.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: 20),
            _DialogActions(
              saving: _saving,
              cancelLabel: 'Cancel',
              submitLabel: 'Save Changes',
              submitIcon: Icons.save_outlined,
              onCancel: () => Navigator.of(context).pop(),
              onSubmit: _saveChanges,
            ),
          ],
        ),
      ),
    );
  }

  static String _formatTimestamp(dynamic value) {
    if (value is! Timestamp) return 'Not scheduled';

    final date = value.toDate();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour =
        date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute =
        date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '$day/$month/${date.year} • $hour:$minute $period';
  }
}

class _SessionAssignmentTile extends StatelessWidget {
  final String title;
  final String category;
  final String schedule;
  final bool selected;
  final ValueChanged<bool> onChanged;

  const _SessionAssignmentTile({
    required this.title,
    required this.category,
    required this.schedule,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: selected
            ? AdminWebTheme.primary.withOpacity(0.05)
            : const Color(0xFFFAFBFD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected
              ? AdminWebTheme.primary.withOpacity(0.35)
              : AdminWebTheme.border,
        ),
      ),
      child: CheckboxListTile(
        value: selected,
        onChanged: (value) => onChanged(value == true),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 3,
        ),
        activeColor: AdminWebTheme.primary,
        title: Text(
          title,
          style: const TextStyle(
            color: AdminWebTheme.textPrimary,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          [
            if (category.trim().isNotEmpty) category.trim(),
            schedule,
          ].join(' • '),
          style: const TextStyle(
            color: AdminWebTheme.textSecondary,
            fontSize: 9.5,
          ),
        ),
      ),
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

class _DialogTextField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool enabled;
  final bool allowClear;
  final int maxLines;

  const _DialogTextField({
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
  final String cancelLabel;
  final String submitLabel;
  final IconData submitIcon;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  const _DialogActions({
    required this.saving,
    required this.cancelLabel,
    required this.submitLabel,
    required this.submitIcon,
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
          child: Text(cancelLabel),
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
              : Icon(
                  submitIcon,
                  size: 18,
                ),
          label: Text(
            saving ? 'Saving...' : submitLabel,
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AdminWebTheme.primary,
          ),
        ),
      ],
    );
  }
}

class _ModeratorAvatar extends StatelessWidget {
  final String imageUrl;
  final String name;

  const _ModeratorAvatar({
    required this.imageUrl,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty
        ? 'S'
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

class _InlineEmptyState extends StatelessWidget {
  final String title;
  final String message;

  const _InlineEmptyState({
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AdminWebTheme.border,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.event_busy_outlined,
            color: AdminWebTheme.primary,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: AdminWebTheme.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
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
  final String? buttonLabel;
  final VoidCallback? onPressed;

  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
    this.buttonLabel,
    this.onPressed,
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
          if (buttonLabel != null && onPressed != null) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(
                Icons.person_add_alt_1_rounded,
              ),
              label: Text(buttonLabel!),
              style: FilledButton.styleFrom(
                backgroundColor: AdminWebTheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
