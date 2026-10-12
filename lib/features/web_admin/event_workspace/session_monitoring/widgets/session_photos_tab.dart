import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../session_monitoring_repository.dart' as monitoring;
import 'monitoring_ui.dart'
    show MonitorPanel, monitorEmpty, monitorInk, monitorMuted, monitorPill;

class SessionPhotosTab extends StatefulWidget {
  final monitoring.SessionMonitoringRepository repository;

  const SessionPhotosTab({
    super.key,
    required this.repository,
  });

  @override
  State<SessionPhotosTab> createState() => _SessionPhotosTabState();
}

class _SessionPhotosTabState extends State<SessionPhotosTab> {
  static const _primary = Color(0xFF0B0B83);

  late Stream<QuerySnapshot<Map<String, dynamic>>> _photos;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void didUpdateWidget(covariant SessionPhotosTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.repository != widget.repository) {
      _connect();
    }
  }

  void _connect() {
    _photos = widget.repository.db
        .collection('events')
        .doc(widget.repository.eventId)
        .collection('eventPhotos')
        .where(
          'sessionId',
          isEqualTo: widget.repository.sessionId,
        )
        .snapshots();
  }

  String _text(Iterable<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String _url(Map<String, dynamic> data) => _text([
        data['photoUrl'],
        data['imageUrl'],
        data['downloadUrl'],
        data['url'],
      ]);

  DateTime? _uploadedAt(Map<String, dynamic> data) {
    for (final key in ['uploadedAt', 'createdAt', 'timestamp']) {
      final time = monitoring.monitorDate(data[key]);
      if (time != null) return time;
    }
    return null;
  }

  String _status(Map<String, dynamic> data) {
    final status =
        (data['status'] ?? 'pending').toString().trim().toLowerCase();

    if (status == 'accepted') return 'approved';
    if (status.isEmpty || status == 'new') return 'pending';
    return status;
  }

  void _message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> _approve(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final path = document.reference.path;
    if (_busy.contains(path)) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _message('Please sign in again.');
      return;
    }

    setState(() => _busy.add(path));

    try {
      await document.reference.update({
        'status': 'approved',
        'reviewedBy': user.uid,
        'reviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      _message(
        error is FirebaseException
            ? error.message ?? error.code
            : 'Unable to approve photo.',
      );
    } finally {
      if (mounted) setState(() => _busy.remove(path));
    }
  }

  Future<void> _delete(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final path = document.reference.path;
    if (_busy.contains(path)) return;

    setState(() => _busy.add(path));

    try {
      // Read the latest record before deleting its image.
      final latest = await document.reference.get();
      final data = latest.data();

      if (data != null) {
        final storagePath = _text([data['storagePath']]);
        final url = _url(data);

        if (storagePath.isEmpty && url.isEmpty) {
          throw StateError(
            'No image location is recorded. The photo was not deleted.',
          );
        }

        final storage = FirebaseStorage.instance;
        final imageReference = storagePath.isNotEmpty
            ? storage.ref(storagePath)
            : storage.refFromURL(url);

        try {
          await imageReference.delete();
        } on FirebaseException catch (error) {
          // A missing image should not prevent removal of its record.
          if (error.code != 'object-not-found') rethrow;
        }

        await document.reference.delete();
      }

      _message('Photo deleted.');
    } catch (error) {
      _message(
        error is FirebaseException
            ? error.message ?? error.code
            : 'Unable to finish deleting the photo. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _busy.remove(path));
    }
  }

  void _preview(String url) {
    if (url.isEmpty) return;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 900,
            maxHeight: 700,
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Center(child: Text('Image unavailable')),
                  ),
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: IconButton.filled(
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
    double width,
  ) {
    final data = document.data();
    final url = _url(data);
    final status = _status(data);
    final approved = status == 'approved';
    final busy = _busy.contains(document.reference.path);
    final time = _uploadedAt(data);
    final caption = _text([data['caption']]);

    final name = _text([
      data['userName'],
      data['uploaderName'],
      data['attendeeName'],
      data['fullName'],
      data['name'],
    ]);

    final uid = _text([
      data['userId'],
      data['uploaderId'],
      data['uid'],
    ]);

    return SizedBox(
      width: width,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEAEAF5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: GestureDetector(
                onTap: url.isEmpty ? null : () => _preview(url),
                child: SizedBox(
                  height: 170,
                  width: double.infinity,
                  child: url.isEmpty
                      ? const Center(
                          child: Icon(Icons.image_not_supported_outlined),
                        )
                      : Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PhotoUploaderName(
                    db: widget.repository.db,
                    uid: uid,
                    savedName: name,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    time == null
                        ? 'Upload time not recorded'
                        : '${monitoring.monitorDay(time)}'
                            ' • ${monitoring.monitorTime(time)}',
                    style: const TextStyle(
                      color: monitorMuted,
                      fontSize: 11,
                    ),
                  ),
                  if (caption.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      caption,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 10),
                  monitorPill(
                    approved ? 'Approved' : status,
                    color: approved ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      FilledButton.icon(
                        onPressed: busy || approved
                            ? null
                            : () => _approve(document),
                        icon: const Icon(Icons.check, size: 16),
                        label: Text(approved ? 'Approved' : 'Approve'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _primary,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: busy ? null : () => _delete(document),
                        icon: const Icon(Icons.delete_outline, size: 17),
                        label: const Text('Delete'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Saving…',
                        style: TextStyle(
                          color: monitorMuted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MonitorPanel(
      title: 'Session Photos',
      icon: Icons.photo_library_outlined,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _photos,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return monitorEmpty(
              'Unable to load session photos: ${snapshot.error}',
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _primary),
            );
          }

          final documents = snapshot.data!.docs.toList();

          documents.sort((a, b) {
            final first = _uploadedAt(a.data());
            final second = _uploadedAt(b.data());

            if (first == null) {
              return second == null ? a.id.compareTo(b.id) : 1;
            }
            if (second == null) return -1;
            return second.compareTo(first);
          });

          if (documents.isEmpty) {
            return monitorEmpty('No session photos uploaded yet.');
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 1100
                  ? 4
                  : constraints.maxWidth > 780
                      ? 3
                      : constraints.maxWidth > 480
                          ? 2
                          : 1;

              final width =
                  (constraints.maxWidth - 14 * (columns - 1)) / columns;

              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: documents
                    .map(
                      (document) => KeyedSubtree(
                        key: ValueKey(document.reference.path),
                        child: _card(document, width),
                      ),
                    )
                    .toList(),
              );
            },
          );
        },
      ),
    );
  }
}

class _PhotoUploaderName extends StatefulWidget {
  final FirebaseFirestore db;
  final String uid;
  final String savedName;

  const _PhotoUploaderName({
    required this.db,
    required this.uid,
    required this.savedName,
  });

  @override
  State<_PhotoUploaderName> createState() => _PhotoUploaderNameState();
}

class _PhotoUploaderNameState extends State<_PhotoUploaderName> {
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _profile;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void didUpdateWidget(covariant _PhotoUploaderName oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.uid != widget.uid || oldWidget.db != widget.db) {
      _connect();
    }
  }

  void _connect() {
    _profile = widget.uid.isEmpty
        ? null
        : widget.db.collection('users').doc(widget.uid).snapshots();
  }

  String _name(Map<String, dynamic>? profile) {
    final first = (profile?['firstName'] ?? '').toString().trim();
    final last = (profile?['lastName'] ?? '').toString().trim();

    for (final value in [
      profile?['fullName'],
      profile?['name'],
      profile?['displayName'],
      '$first $last'.trim(),
      widget.savedName,
    ]) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }

    return 'Name unavailable';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _profile,
      builder: (context, snapshot) => Text(
        _name(snapshot.data?.data()),
        style: const TextStyle(
          color: monitorInk,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}