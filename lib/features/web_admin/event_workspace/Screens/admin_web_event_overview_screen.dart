
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../admin_web_theme.dart';

class AdminWebEventOverviewScreen extends StatelessWidget {
  final String eventId;
  final String eventName;
  final ValueChanged<String> onNavigate;

  const AdminWebEventOverviewScreen({
    super.key,
    required this.eventId,
    required this.eventName,
    required this.onNavigate,
  });

  Stream<int> _sessionsCountStream() {
    return FirebaseFirestore.instance
        .collection('sessions')
        .where('eventId', isEqualTo: eventId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<int> _registrationsCountStream() {
    return FirebaseFirestore.instance
        .collection('events')
        .doc(eventId)
        .collection('registrations')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<int> _roleCountStream(String role) {
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: role)
        .where('eventIds', arrayContains: eventId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<int> _helpCountStream() {
    return FirebaseFirestore.instance
        .collection('help_tickets')
        .where('eventId', isEqualTo: eventId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('events')
                .doc(eventId)
                .snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data() ?? {};
              final description =
                  (data['description'] ?? '').toString();
              final active = data['isActive'] == true;

              return _EventOverviewHeader(
                eventName: eventName,
                description: description,
                active: active,
              );
            },
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              int columns = 4;

              if (constraints.maxWidth < 700) {
                columns = 1;
              } else if (constraints.maxWidth < 1100) {
                columns = 2;
              }

              const spacing = 14.0;

              final width =
                  (constraints.maxWidth -
                          (spacing * (columns - 1))) /
                      columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  SizedBox(
                    width: width,
                    child: _OverviewStatCard(
                      title: 'Sessions',
                      subtitle: 'Event sessions',
                      icon: Icons.view_agenda_rounded,
                      stream: _sessionsCountStream(),
                      onTap: () => onNavigate('Sessions'),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _OverviewStatCard(
                      title: 'Registrations',
                      subtitle: 'Registered users',
                      icon: Icons.groups_rounded,
                      stream: _registrationsCountStream(),
                      onTap: () => onNavigate('Users'),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _OverviewStatCard(
                      title: 'Speakers',
                      subtitle: 'Assigned speakers',
                      icon: Icons.record_voice_over_rounded,
                      stream: _roleCountStream('speaker'),
                      onTap: () => onNavigate('Speakers'),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _OverviewStatCard(
                      title: 'Moderators',
                      subtitle: 'Assigned moderators',
                      icon: Icons.support_agent_rounded,
                      stream: _roleCountStream('moderator'),
                      onTap: () => onNavigate('Moderators'),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 900) {
                return Column(
                  children: [
                    _SetupChecklist(
                      eventId: eventId,
                      sessionsStream: _sessionsCountStream(),
                      speakersStream: _roleCountStream('speaker'),
                      moderatorsStream: _roleCountStream('moderator'),
                    ),
                    const SizedBox(height: 18),
                    _EventManagement(
                      eventId: eventId,
                      eventName: eventName,
                      onNavigate: onNavigate,
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: _SetupChecklist(
                      eventId: eventId,
                      sessionsStream: _sessionsCountStream(),
                      speakersStream: _roleCountStream('speaker'),
                      moderatorsStream: _roleCountStream('moderator'),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    flex: 5,
                    child: _EventManagement(
                      eventId: eventId,
                      eventName: eventName,
                      onNavigate: onNavigate,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          _OverviewStatCard(
            title: 'Help Center Tickets',
            subtitle: 'Support requests for this event',
            icon: Icons.help_rounded,
            stream: _helpCountStream(),
            onTap: () => onNavigate('Help Center'),
          ),
        ],
      ),
    );
  }
}

class _EventOverviewHeader extends StatelessWidget {
  final String eventName;
  final String description;
  final bool active;

  const _EventOverviewHeader({
    required this.eventName,
    required this.description,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AdminWebTheme.primary,
            Color(0xFF24249A),
          ],
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eventName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (description.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFD9DAF6),
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 20),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              active ? 'ACTIVE EVENT' : 'SETUP IN PROGRESS',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewStatCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Stream<int> stream;
  final VoidCallback onTap;

  const _OverviewStatCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.stream,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          height: 120,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            border: Border.all(
              color: AdminWebTheme.border,
            ),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color:
                      AdminWebTheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: AdminWebTheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: StreamBuilder<int>(
                  stream: stream,
                  builder: (context, snapshot) {
                    final value =
                        snapshot.connectionState ==
                                ConnectionState.waiting
                            ? '...'
                            : (snapshot.data ?? 0).toString();

                    return Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          value,
                          style: const TextStyle(
                            color:
                                AdminWebTheme.textPrimary,
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          title,
                          style: const TextStyle(
                            color:
                                AdminWebTheme.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color:
                                AdminWebTheme.textSecondary,
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: AdminWebTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetupChecklist extends StatelessWidget {
  final String eventId;
  final Stream<int> sessionsStream;
  final Stream<int> speakersStream;
  final Stream<int> moderatorsStream;

  const _SetupChecklist({
    required this.eventId,
    required this.sessionsStream,
    required this.speakersStream,
    required this.moderatorsStream,
  });

  @override
  Widget build(BuildContext context) {
    return _WorkspaceCard(
      title: 'Event Setup Progress',
      child: Column(
        children: [
          const _ChecklistRow(
            title: 'Event information created',
            complete: true,
          ),
          StreamBuilder<int>(
            stream: sessionsStream,
            builder: (context, snapshot) {
              return _ChecklistRow(
                title: 'Create event sessions',
                complete: (snapshot.data ?? 0) > 0,
              );
            },
          ),
          StreamBuilder<int>(
            stream: speakersStream,
            builder: (context, snapshot) {
              return _ChecklistRow(
                title: 'Assign speakers',
                complete: (snapshot.data ?? 0) > 0,
              );
            },
          ),
          StreamBuilder<int>(
            stream: moderatorsStream,
            builder: (context, snapshot) {
              return _ChecklistRow(
                title: 'Assign moderators',
                complete: (snapshot.data ?? 0) > 0,
              );
            },
          ),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('events')
                .doc(eventId)
                .snapshots(),
            builder: (context, snapshot) {
              final active =
                  snapshot.data?.data()?['isActive'] == true;

              return _ChecklistRow(
                title: 'Activate event for users',
                complete: active,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  final String title;
  final bool complete;

  const _ChecklistRow({
    required this.title,
    required this.complete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 13,
      ),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFD),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: AdminWebTheme.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            complete
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: complete
                ? Colors.green
                : AdminWebTheme.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: complete
                    ? AdminWebTheme.textSecondary
                    : AdminWebTheme.textPrimary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventManagement extends StatelessWidget {
  final ValueChanged<String> onNavigate;
  final String eventId;
  final String eventName;

  const _EventManagement({
    required this.onNavigate,
    required this.eventId,
    required this.eventName,
  });

  @override
  Widget build(BuildContext context) {
    return _WorkspaceCard(
      title: 'Event Management',
      child: Column(
        children: [
          _ManagementActionButton(
            icon: Icons.add_box_outlined,
            title: 'Create Session',
            subtitle: 'Create a new session for this event.',
            onTap: () => onNavigate('Sessions'),
          ),
          _ManagementActionButton(
            icon: Icons.notifications_active_outlined,
            title: 'Send Notification',
            subtitle: 'Send an update to event participants.',
            onTap: () => onNavigate('Notifications'),
          ),
          _ManagementActionButton(
            icon: Icons.manage_accounts_outlined,
            title: 'Manage Users',
            subtitle:
                'View and manage users assigned to this event.',
            onTap: () => onNavigate('Users'),
          ),
          _EventActivationTile(
            eventId: eventId,
            eventName: eventName,
          ),
        ],
      ),
    );
  }
}

class _ManagementActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ManagementActionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: const Color(0xFFFAFBFD),
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(
                color: AdminWebTheme.border,
              ),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AdminWebTheme.primary
                        .withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: AdminWebTheme.primary,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 11),
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
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color:
                              AdminWebTheme.textSecondary,
                          fontSize: 9.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: AdminWebTheme.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EventActivationTile extends StatefulWidget {
  final String eventId;
  final String eventName;

  const _EventActivationTile({
    required this.eventId,
    required this.eventName,
  });

  @override
  State<_EventActivationTile> createState() =>
      _EventActivationTileState();
}

class _EventActivationTileState
    extends State<_EventActivationTile> {
  bool _updating = false;

  Future<bool> _confirmChange({
    required bool activate,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            activate
                ? 'Activate Event?'
                : 'Deactivate Event?',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            activate
                ? '"${widget.eventName}" will become the active event. '
                    'All other events will be deactivated.'
                : '"${widget.eventName}" will no longer be shown as '
                    'the active event to app users.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(
                activate ? 'Activate' : 'Deactivate',
              ),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  Future<void> _updateActiveState(bool value) async {
    if (_updating) return;

    final confirmed = await _confirmChange(
      activate: value,
    );

    if (!confirmed) return;

    setState(() {
      _updating = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;

      final eventsSnapshot =
          await firestore.collection('events').get();

      final batch = firestore.batch();

      for (final document in eventsSnapshot.docs) {
        batch.update(
          document.reference,
          {
            'isActive':
                value && document.id == widget.eventId,
            'updatedAt':
                FieldValue.serverTimestamp(),
          },
        );
      }

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? '${widget.eventName} is now the active event.'
                : '${widget.eventName} is no longer active.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to update event activation: $error',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<
        DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .snapshots(),
      builder: (context, snapshot) {
        final isActive =
            snapshot.data?.data()?['isActive'] == true;

        return Container(
          padding:
              const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFBFD),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: AdminWebTheme.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.green.withOpacity(0.10)
                      : AdminWebTheme.primary
                          .withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.toggle_on_rounded,
                  color: isActive
                      ? Colors.green
                      : AdminWebTheme.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Event Activation',
                      style: TextStyle(
                        color:
                            AdminWebTheme.textPrimary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Set this event as the active event shown to app users.',
                      style: TextStyle(
                        color:
                            AdminWebTheme.textSecondary,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (_updating)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              else
                Switch(
                  value: isActive,
                  onChanged: _updateActiveState,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _WorkspaceCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _WorkspaceCard({
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
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 15),
          child,
        ],
      ),
    );
  }
}
