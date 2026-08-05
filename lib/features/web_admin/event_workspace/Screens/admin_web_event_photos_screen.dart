// lib/features/web_admin/event_workspace/Screens/admin_web_event_photos_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../../admin_web_theme.dart';

class AdminWebEventPhotosScreen extends StatefulWidget {
  final String eventId;
  final String eventName;

  const AdminWebEventPhotosScreen({
    super.key,
    required this.eventId,
    required this.eventName,
  });

  @override
  State<AdminWebEventPhotosScreen> createState() =>
      _AdminWebEventPhotosScreenState();
}

class _AdminWebEventPhotosScreenState
    extends State<AdminWebEventPhotosScreen> {
  final TextEditingController _searchController =
      TextEditingController();

  String _searchQuery = '';
  String _statusFilter = 'All';
  String _sessionFilter = 'All Sessions';
  _PhotoViewMode _viewMode = _PhotoViewMode.grid;

  final Set<String> _updatingPhotoIds = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _photosStream() {
    return FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .collection('eventPhotos')
        .orderBy('uploadedAt', descending: true)
        .snapshots();
  }

  Future<void> _updatePhotoStatus({
    required String photoId,
    required String status,
  }) async {
    if (_updatingPhotoIds.contains(photoId)) return;

    setState(() {
      _updatingPhotoIds.add(photoId);
    });

    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('eventPhotos')
          .doc(photoId)
          .update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      _showMessage('Photo marked as ${_displayStatus(status)}.');
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Failed to update photo: $error',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingPhotoIds.remove(photoId);
        });
      }
    }
  }

  Future<void> _confirmDeletePhoto({
    required String photoId,
    required String storagePath,
    required String uploaderName,
  }) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
              ),
              SizedBox(width: 10),
              Text('Delete Photo'),
            ],
          ),
          content: Text(
            'Delete the photo uploaded by $uploaderName? '
            'This will remove it from Firestore and Firebase Storage.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.of(context).pop(true),
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 17,
              ),
              label: const Text('Delete'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      await _deletePhoto(
        photoId: photoId,
        storagePath: storagePath,
      );
    }
  }

  Future<void> _deletePhoto({
    required String photoId,
    required String storagePath,
  }) async {
    if (_updatingPhotoIds.contains(photoId)) return;

    setState(() {
      _updatingPhotoIds.add(photoId);
    });

    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('eventPhotos')
          .doc(photoId)
          .delete();

      if (storagePath.trim().isNotEmpty) {
        try {
          await FirebaseStorage.instance
              .ref(storagePath.trim())
              .delete();
        } catch (_) {
          // The Firestore record has already been removed.
        }
      }

      if (!mounted) return;

      _showMessage('Photo deleted successfully.');
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Failed to delete photo: $error',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingPhotoIds.remove(photoId);
        });
      }
    }
  }

  void _showMessage(
    String message, {
    bool error = false,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: error
              ? Colors.redAccent
              : AdminWebTheme.primary,
        ),
      );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>>
      _filterPhotos(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final query = _searchQuery.trim().toLowerCase();

    return docs.where((doc) {
      final data = doc.data();

      final userName =
          (data['userName'] ?? '').toString().toLowerCase();
      final userEmail =
          (data['userEmail'] ?? '').toString().toLowerCase();
      final caption =
          (data['caption'] ?? '').toString().toLowerCase();
      final sessionTitle =
          (data['sessionTitle'] ?? 'Unknown Session')
              .toString()
              .toLowerCase();
      final status = _normalizeStatus(
        (data['status'] ?? 'pending').toString(),
      );

      final matchesQuery = query.isEmpty ||
          userName.contains(query) ||
          userEmail.contains(query) ||
          caption.contains(query) ||
          sessionTitle.contains(query);

      if (!matchesQuery) return false;

      if (_statusFilter != 'All' &&
          status != _statusFilter.toLowerCase()) {
        return false;
      }

      if (_sessionFilter != 'All Sessions' &&
          sessionTitle != _sessionFilter.toLowerCase()) {
        return false;
      }

      return true;
    }).toList();
  }

  Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _groupPhotosBySession(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final grouped =
        <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};

    for (final doc in docs) {
      final sessionTitle =
          (doc.data()['sessionTitle'] ?? 'Unknown Session')
              .toString()
              .trim();

      grouped.putIfAbsent(
        sessionTitle.isEmpty
            ? 'Unknown Session'
            : sessionTitle,
        () => [],
      );

      grouped[
              sessionTitle.isEmpty
                  ? 'Unknown Session'
                  : sessionTitle]!
          .add(doc);
    }

    return grouped;
  }

  List<String> _sessionOptions(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final sessions = docs
        .map(
          (doc) =>
              (doc.data()['sessionTitle'] ?? 'Unknown Session')
                  .toString()
                  .trim(),
        )
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return ['All Sessions', ...sessions];
  }

  void _openPhotoPreview(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => _PhotoPreviewDialog(
        document: doc,
        isUpdating: _updatingPhotoIds.contains(doc.id),
        onApprove: () {
          _updatePhotoStatus(
            photoId: doc.id,
            status: 'approved',
          );
        },
        onReject: () {
          _updatePhotoStatus(
            photoId: doc.id,
            status: 'rejected',
          );
        },
        onDelete: () {
          final data = doc.data();

          Navigator.of(context).pop();

          _confirmDeletePhoto(
            photoId: doc.id,
            storagePath:
                (data['storagePath'] ?? '').toString(),
            uploaderName:
                (data['userName'] ?? 'Attendee').toString(),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: _photosStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: AdminWebTheme.primary,
            ),
          );
        }

        if (snapshot.hasError) {
          return _ErrorState(
            message: snapshot.error.toString(),
          );
        }

        final docs = snapshot.data?.docs ?? const [];
        final filteredDocs = _filterPhotos(docs);

        final approved = docs
            .where(
              (doc) =>
                  _normalizeStatus(
                    (doc.data()['status'] ?? 'pending')
                        .toString(),
                  ) ==
                  'approved',
            )
            .length;

        final pending = docs
            .where(
              (doc) =>
                  _normalizeStatus(
                    (doc.data()['status'] ?? 'pending')
                        .toString(),
                  ) ==
                  'pending',
            )
            .length;

        final rejected = docs
            .where(
              (doc) =>
                  _normalizeStatus(
                    (doc.data()['status'] ?? 'pending')
                        .toString(),
                  ) ==
                  'rejected',
            )
            .length;

        final sessionOptions = _sessionOptions(docs);

        if (!sessionOptions.contains(_sessionFilter)) {
          _sessionFilter = 'All Sessions';
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PageHeader(
                eventName: widget.eventName,
                totalPhotos: docs.length,
              ),
              const SizedBox(height: 18),
              _OverviewBanner(
                eventName: widget.eventName,
                total: docs.length,
                pending: pending,
              ),
              const SizedBox(height: 18),
              _SummaryGrid(
                total: docs.length,
                approved: approved,
                pending: pending,
                rejected: rejected,
              ),
              const SizedBox(height: 18),
              _Toolbar(
                searchController: _searchController,
                searchQueryChanged: (value) {
                  setState(() => _searchQuery = value);
                },
                statusFilter: _statusFilter,
                statusChanged: (value) {
                  setState(() => _statusFilter = value);
                },
                sessionFilter: _sessionFilter,
                sessionOptions: sessionOptions,
                sessionChanged: (value) {
                  setState(() => _sessionFilter = value);
                },
                viewMode: _viewMode,
                viewModeChanged: (mode) {
                  setState(() => _viewMode = mode);
                },
              ),
              const SizedBox(height: 18),
              if (filteredDocs.isEmpty)
                _EmptyState(
                  hasPhotos: docs.isNotEmpty,
                )
              else if (_viewMode == _PhotoViewMode.grid)
                _PhotoGrid(
                  docs: filteredDocs,
                  updatingIds: _updatingPhotoIds,
                  onPreview: _openPhotoPreview,
                  onApprove: (doc) {
                    _updatePhotoStatus(
                      photoId: doc.id,
                      status: 'approved',
                    );
                  },
                  onReject: (doc) {
                    _updatePhotoStatus(
                      photoId: doc.id,
                      status: 'rejected',
                    );
                  },
                  onDelete: (doc) {
                    final data = doc.data();

                    _confirmDeletePhoto(
                      photoId: doc.id,
                      storagePath:
                          (data['storagePath'] ?? '').toString(),
                      uploaderName:
                          (data['userName'] ?? 'Attendee')
                              .toString(),
                    );
                  },
                )
              else
                _GroupedPhotoView(
                  grouped:
                      _groupPhotosBySession(filteredDocs),
                  updatingIds: _updatingPhotoIds,
                  onPreview: _openPhotoPreview,
                  onApprove: (doc) {
                    _updatePhotoStatus(
                      photoId: doc.id,
                      status: 'approved',
                    );
                  },
                  onReject: (doc) {
                    _updatePhotoStatus(
                      photoId: doc.id,
                      status: 'rejected',
                    );
                  },
                  onDelete: (doc) {
                    final data = doc.data();

                    _confirmDeletePhoto(
                      photoId: doc.id,
                      storagePath:
                          (data['storagePath'] ?? '').toString(),
                      uploaderName:
                          (data['userName'] ?? 'Attendee')
                              .toString(),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

enum _PhotoViewMode {
  grid,
  sessions,
}

class _PageHeader extends StatelessWidget {
  final String eventName;
  final int totalPhotos;

  const _PageHeader({
    required this.eventName,
    required this.totalPhotos,
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
                eventName.toUpperCase(),
                style: const TextStyle(
                  color: AdminWebTheme.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Event Photos',
                style: TextStyle(
                  color: AdminWebTheme.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Review attendee uploads, approve photos for the report, reject unsuitable content, and manage the event gallery.',
                style: TextStyle(
                  color: AdminWebTheme.textSecondary,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: AdminWebTheme.primary.withOpacity(0.07),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.photo_library_outlined,
                color: AdminWebTheme.primary,
                size: 17,
              ),
              const SizedBox(width: 7),
              Text(
                '$totalPhotos photos',
                style: const TextStyle(
                  color: AdminWebTheme.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OverviewBanner extends StatelessWidget {
  final String eventName;
  final int total;
  final int pending;

  const _OverviewBanner({
    required this.eventName,
    required this.total,
    required this.pending,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF11117A),
            Color(0xFF08084B),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PHOTO MODERATION',
                  style: TextStyle(
                    color: AdminWebTheme.gold,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  eventName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  '$total uploaded photo${total == 1 ? '' : 's'} • '
                  '$pending awaiting review',
                  style: const TextStyle(
                    color: Color(0xFFC8CAE2),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.collections_outlined,
              color: AdminWebTheme.gold,
              size: 34,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final int total;
  final int approved;
  final int pending;
  final int rejected;

  const _SummaryGrid({
    required this.total,
    required this.approved,
    required this.pending,
    required this.rejected,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _SummaryItem(
        label: 'Total Photos',
        value: '$total',
        icon: Icons.photo_library_outlined,
        color: const Color(0xFF246BFD),
      ),
      _SummaryItem(
        label: 'Approved',
        value: '$approved',
        icon: Icons.check_circle_outline_rounded,
        color: const Color(0xFF18A66F),
      ),
      _SummaryItem(
        label: 'Pending',
        value: '$pending',
        icon: Icons.schedule_rounded,
        color: const Color(0xFFF59E0B),
      ),
      _SummaryItem(
        label: 'Rejected',
        value: '$rejected',
        icon: Icons.cancel_outlined,
        color: const Color(0xFFEF476F),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 950
            ? 4
            : constraints.maxWidth >= 560
                ? 2
                : 1;

        const spacing = 12.0;
        final width =
            (constraints.maxWidth - spacing * (count - 1)) /
                count;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items.map((item) {
            return Container(
              width: width,
              height: 112,
              padding: const EdgeInsets.all(15),
              decoration: _cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: item.color.withOpacity(0.10),
                          borderRadius:
                              BorderRadius.circular(11),
                        ),
                        child: Icon(
                          item.icon,
                          color: item.color,
                          size: 20,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        item.value,
                        style: const TextStyle(
                          color: AdminWebTheme.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    item.label,
                    style: const TextStyle(
                      color: AdminWebTheme.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _SummaryItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _Toolbar extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String> searchQueryChanged;
  final String statusFilter;
  final ValueChanged<String> statusChanged;
  final String sessionFilter;
  final List<String> sessionOptions;
  final ValueChanged<String> sessionChanged;
  final _PhotoViewMode viewMode;
  final ValueChanged<_PhotoViewMode> viewModeChanged;

  const _Toolbar({
    required this.searchController,
    required this.searchQueryChanged,
    required this.statusFilter,
    required this.statusChanged,
    required this.sessionFilter,
    required this.sessionOptions,
    required this.sessionChanged,
    required this.viewMode,
    required this.viewModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final search = TextField(
            controller: searchController,
            onChanged: searchQueryChanged,
            style: const TextStyle(fontSize: 11.5),
            decoration: const InputDecoration(
              hintText:
                  'Search by uploader, email, session, or caption',
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 18,
              ),
              isDense: true,
            ),
          );

          final status = SizedBox(
            width: 155,
            child: DropdownButtonFormField<String>(
              value: statusFilter,
              decoration: const InputDecoration(
                labelText: 'Status',
                isDense: true,
              ),
              items: const [
                'All',
                'Pending',
                'Approved',
                'Rejected',
              ].map((item) {
                return DropdownMenuItem(
                  value: item,
                  child: Text(
                    item,
                    style: const TextStyle(fontSize: 10.5),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  statusChanged(value);
                }
              },
            ),
          );

          final session = SizedBox(
            width: 210,
            child: DropdownButtonFormField<String>(
              value: sessionFilter,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Session',
                isDense: true,
              ),
              items: sessionOptions.map((item) {
                return DropdownMenuItem(
                  value: item,
                  child: Text(
                    item,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  sessionChanged(value);
                }
              },
            ),
          );

          final modeButtons = Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AdminWebTheme.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ViewModeButton(
                  icon: Icons.grid_view_rounded,
                  tooltip: 'Grid view',
                  selected:
                      viewMode == _PhotoViewMode.grid,
                  onTap: () =>
                      viewModeChanged(_PhotoViewMode.grid),
                ),
                _ViewModeButton(
                  icon: Icons.view_agenda_outlined,
                  tooltip: 'Group by session',
                  selected:
                      viewMode == _PhotoViewMode.sessions,
                  onTap: () => viewModeChanged(
                    _PhotoViewMode.sessions,
                  ),
                ),
              ],
            ),
          );

          if (constraints.maxWidth < 900) {
            return Column(
              children: [
                search,
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: status),
                    const SizedBox(width: 10),
                    Expanded(child: session),
                    const SizedBox(width: 10),
                    modeButtons,
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 10),
              status,
              const SizedBox(width: 10),
              session,
              const SizedBox(width: 10),
              modeButtons,
            ],
          );
        },
      ),
    );
  }
}

class _ViewModeButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  const _ViewModeButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: selected
            ? AdminWebTheme.primary
            : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              size: 17,
              color: selected
                  ? Colors.white
                  : AdminWebTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final Set<String> updatingIds;
  final ValueChanged<
      QueryDocumentSnapshot<Map<String, dynamic>>> onPreview;
  final ValueChanged<
      QueryDocumentSnapshot<Map<String, dynamic>>> onApprove;
  final ValueChanged<
      QueryDocumentSnapshot<Map<String, dynamic>>> onReject;
  final ValueChanged<
      QueryDocumentSnapshot<Map<String, dynamic>>> onDelete;

  const _PhotoGrid({
    required this.docs,
    required this.updatingIds,
    required this.onPreview,
    required this.onApprove,
    required this.onReject,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 1250
            ? 4
            : constraints.maxWidth >= 900
                ? 3
                : constraints.maxWidth >= 600
                    ? 2
                    : 1;

        const spacing = 14.0;
        final width =
            (constraints.maxWidth - spacing * (count - 1)) /
                count;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: docs.map((doc) {
            return SizedBox(
              width: width,
              child: _PhotoCard(
                document: doc,
                isUpdating: updatingIds.contains(doc.id),
                onPreview: () => onPreview(doc),
                onApprove: () => onApprove(doc),
                onReject: () => onReject(doc),
                onDelete: () => onDelete(doc),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _GroupedPhotoView extends StatelessWidget {
  final Map<
      String,
      List<QueryDocumentSnapshot<Map<String, dynamic>>>> grouped;
  final Set<String> updatingIds;
  final ValueChanged<
      QueryDocumentSnapshot<Map<String, dynamic>>> onPreview;
  final ValueChanged<
      QueryDocumentSnapshot<Map<String, dynamic>>> onApprove;
  final ValueChanged<
      QueryDocumentSnapshot<Map<String, dynamic>>> onReject;
  final ValueChanged<
      QueryDocumentSnapshot<Map<String, dynamic>>> onDelete;

  const _GroupedPhotoView({
    required this.grouped,
    required this.updatingIds,
    required this.onPreview,
    required this.onApprove,
    required this.onReject,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: grouped.entries.map((entry) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.event_note_outlined,
                    color: AdminWebTheme.primary,
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        color: AdminWebTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AdminWebTheme.primary
                          .withOpacity(0.07),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${entry.value.length} photo${entry.value.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: AdminWebTheme.primary,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _PhotoGrid(
                docs: entry.value,
                updatingIds: updatingIds,
                onPreview: onPreview,
                onApprove: onApprove,
                onReject: onReject,
                onDelete: onDelete,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> document;
  final bool isUpdating;
  final VoidCallback onPreview;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onDelete;

  const _PhotoCard({
    required this.document,
    required this.isUpdating,
    required this.onPreview,
    required this.onApprove,
    required this.onReject,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final data = document.data();

    final photoUrl =
        (data['photoUrl'] ?? data['imageUrl'] ?? '').toString();
    final caption = (data['caption'] ?? '').toString();
    final userName =
        (data['userName'] ?? 'Attendee').toString();
    final userEmail =
        (data['userEmail'] ?? '').toString();
    final sessionTitle =
        (data['sessionTitle'] ?? 'Unknown Session').toString();
    final status = _normalizeStatus(
      (data['status'] ?? 'pending').toString(),
    );
    final uploadedAt = _readDate(
      data['uploadedAt'] ?? data['createdAt'],
    );

    return Container(
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.45,
            child: InkWell(
              onTap: onPreview,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _NetworkPhoto(
                    photoUrl: photoUrl,
                  ),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: _StatusChip(status: status),
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Material(
                      color: Colors.black.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: onPreview,
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.all(7),
                          child: Icon(
                            Icons.open_in_full_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sessionTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AdminWebTheme.primary,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AdminWebTheme.textPrimary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (userEmail.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    userEmail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AdminWebTheme.textSecondary,
                      fontSize: 8.5,
                    ),
                  ),
                ],
                if (caption.trim().isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Text(
                    caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AdminWebTheme.textSecondary,
                      fontSize: 9.5,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 9),
                Text(
                  uploadedAt == null
                      ? 'Upload time unavailable'
                      : _formatDateTime(uploadedAt),
                  style: const TextStyle(
                    color: AdminWebTheme.textSecondary,
                    fontSize: 8.5,
                  ),
                ),
                const SizedBox(height: 12),
                if (isUpdating)
                  const SizedBox(
                    height: 36,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AdminWebTheme.primary,
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              status == 'approved' ? null : onApprove,
                          icon: const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 15,
                          ),
                          label: const Text('Approve'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                const Color(0xFF159A62),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              status == 'rejected' ? null : onReject,
                          icon: const Icon(
                            Icons.cancel_outlined,
                            size: 15,
                          ),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      IconButton(
                        tooltip: 'Delete photo',
                        onPressed: onDelete,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.redAccent,
                          size: 19,
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
}

class _NetworkPhoto extends StatelessWidget {
  final String photoUrl;

  const _NetworkPhoto({
    required this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (photoUrl.trim().isEmpty) {
      return Container(
        color: const Color(0xFFF4F5FA),
        child: const Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: AdminWebTheme.textSecondary,
            size: 34,
          ),
        ),
      );
    }

    return Image.network(
      photoUrl,
      fit: BoxFit.cover,
      loadingBuilder: (
        context,
        child,
        loadingProgress,
      ) {
        if (loadingProgress == null) return child;

        return const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AdminWebTheme.primary,
          ),
        );
      },
      errorBuilder: (_, __, ___) {
        return Container(
          color: const Color(0xFFF4F5FA),
          child: const Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: AdminWebTheme.textSecondary,
              size: 34,
            ),
          ),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = _normalizeStatus(status);
    final color = _statusColor(normalized);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _displayStatus(normalized),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PhotoPreviewDialog extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> document;
  final bool isUpdating;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onDelete;

  const _PhotoPreviewDialog({
    required this.document,
    required this.isUpdating,
    required this.onApprove,
    required this.onReject,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final data = document.data();

    final photoUrl =
        (data['photoUrl'] ?? data['imageUrl'] ?? '').toString();
    final userName =
        (data['userName'] ?? 'Attendee').toString();
    final userEmail =
        (data['userEmail'] ?? '').toString();
    final sessionTitle =
        (data['sessionTitle'] ?? 'Unknown Session').toString();
    final caption =
        (data['caption'] ?? '').toString();
    final status = _normalizeStatus(
      (data['status'] ?? 'pending').toString(),
    );
    final uploadedAt = _readDate(
      data['uploadedAt'] ?? data['createdAt'],
    );

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 1050,
          maxHeight: 760,
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Container(
                color: const Color(0xFF11131A),
                child: Center(
                  child: _NetworkPhoto(
                    photoUrl: photoUrl,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 330,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            sessionTitle,
                            style: const TextStyle(
                              color:
                                  AdminWebTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.close_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _StatusChip(status: status),
                    const SizedBox(height: 18),
                    _PreviewDetail(
                      label: 'Uploaded by',
                      value: userName,
                    ),
                    if (userEmail.trim().isNotEmpty)
                      _PreviewDetail(
                        label: 'Email',
                        value: userEmail,
                      ),
                    _PreviewDetail(
                      label: 'Uploaded',
                      value: uploadedAt == null
                          ? '-'
                          : _formatDateTime(uploadedAt),
                    ),
                    if (caption.trim().isNotEmpty)
                      _PreviewDetail(
                        label: 'Caption',
                        value: caption,
                      ),
                    const Spacer(),
                    if (isUpdating)
                      const Center(
                        child: CircularProgressIndicator(
                          color: AdminWebTheme.primary,
                        ),
                      )
                    else ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: status == 'approved'
                              ? null
                              : onApprove,
                          icon: const Icon(
                            Icons.check_circle_outline_rounded,
                          ),
                          label: const Text('Approve Photo'),
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                const Color(0xFF159A62),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: status == 'rejected'
                              ? null
                              : onReject,
                          icon: const Icon(
                            Icons.cancel_outlined,
                          ),
                          label: const Text('Reject Photo'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: onDelete,
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                          ),
                          label: const Text('Delete Photo'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewDetail extends StatelessWidget {
  final String label;
  final String value;

  const _PreviewDetail({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AdminWebTheme.textSecondary,
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AdminWebTheme.textPrimary,
              fontSize: 10.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasPhotos;

  const _EmptyState({
    required this.hasPhotos,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 54,
      ),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          const Icon(
            Icons.photo_library_outlined,
            color: AdminWebTheme.primary,
            size: 42,
          ),
          const SizedBox(height: 12),
          Text(
            hasPhotos
                ? 'No photos match the filters'
                : 'No photos uploaded yet',
            style: const TextStyle(
              color: AdminWebTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasPhotos
                ? 'Try changing the search text, status, or session filter.'
                : 'Photos uploaded by attendees will appear here for moderation.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AdminWebTheme.textSecondary,
              fontSize: 10.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: _cardDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 42,
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load event photos',
              style: TextStyle(
                color: AdminWebTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AdminWebTheme.textSecondary,
                fontSize: 10,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(
      color: AdminWebTheme.border,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.025),
        blurRadius: 14,
        offset: const Offset(0, 5),
      ),
    ],
  );
}

String _normalizeStatus(String status) {
  final value = status.trim().toLowerCase();

  if (value == 'accepted') return 'approved';
  if (value == 'declined') return 'rejected';
  if (value == 'new' || value.isEmpty) return 'pending';

  return value;
}

String _displayStatus(String status) {
  final normalized = _normalizeStatus(status);

  if (normalized.isEmpty) return 'Pending';

  return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
}

Color _statusColor(String status) {
  switch (_normalizeStatus(status)) {
    case 'approved':
      return const Color(0xFF159A62);
    case 'rejected':
      return Colors.redAccent;
    default:
      return const Color(0xFFF59E0B);
  }
}

DateTime? _readDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String _formatDateTime(DateTime date) {
  return '${_formatDate(date)} • ${_formatTime(date)}';
}

String _formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _formatTime(DateTime date) {
  final hour = date.hour;
  final minute = date.minute.toString().padLeft(2, '0');
  final suffix = hour >= 12 ? 'PM' : 'AM';
  final displayHour =
      hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);

  return '$displayHour:$minute $suffix';
}
