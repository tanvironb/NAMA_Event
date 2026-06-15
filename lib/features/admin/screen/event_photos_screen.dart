import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class EventPhotosScreen extends StatefulWidget {
  final String eventId;
  final String eventName;

  const EventPhotosScreen({
    super.key,
    required this.eventId,
    required this.eventName,
  });

  @override
  State<EventPhotosScreen> createState() => _EventPhotosScreenState();
}

class _EventPhotosScreenState extends State<EventPhotosScreen> {
  bool _isUpdating = false;

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
    if (_isUpdating) return;

    try {
      setState(() => _isUpdating = true);

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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Photo marked as $status.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update photo: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _confirmDeletePhoto({
    required String photoId,
    required String storagePath,
  }) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Delete Photo?',
            style: TextStyle(
              color: AppColors.namaNavyBlue,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const Text(
            'This photo will be deleted from the event photos list.',
            style: TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: AppColors.namaMediumGray,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text(
                'Delete',
                style: TextStyle(fontWeight: FontWeight.w800),
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
    if (_isUpdating) return;

    try {
      setState(() => _isUpdating = true);

      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('eventPhotos')
          .doc(photoId)
          .delete();

      if (storagePath.trim().isNotEmpty) {
        try {
          await FirebaseStorage.instance.ref(storagePath).delete();
        } catch (_) {
          // Ignore storage delete errors. Firestore record is already deleted.
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo deleted successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete photo: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _groupPhotosBySession(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final grouped =
        <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};

    for (final doc in docs) {
      final data = doc.data();
      final sessionTitle =
          (data['sessionTitle'] ?? 'Unknown Session').toString();

      grouped.putIfAbsent(sessionTitle, () => []);
      grouped[sessionTitle]!.add(doc);
    }

    return grouped;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  Widget _statusChip(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: color.withOpacity(0.35),
        ),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _photoCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    final photoUrl = (data['photoUrl'] ?? '').toString();
    final caption = (data['caption'] ?? '').toString();
    final userName = (data['userName'] ?? 'Attendee').toString();
    final userEmail = (data['userEmail'] ?? '').toString();
    final status = (data['status'] ?? 'pending').toString();
    final storagePath = (data['storagePath'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (photoUrl.isNotEmpty)
            Image.network(
              photoUrl,
              height: 190,
              width: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;

                return const SizedBox(
                  height: 190,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.namaNavyBlue,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 190,
                  color: const Color(0xFFF4F2FB),
                  child: const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.namaNavyBlue,
                      size: 34,
                    ),
                  ),
                );
              },
            )
          else
            Container(
              height: 190,
              color: const Color(0xFFF4F2FB),
              child: const Center(
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: AppColors.namaNavyBlue,
                  size: 34,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        userName,
                        style: const TextStyle(
                          color: AppColors.namaNavyBlue,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _statusChip(status),
                  ],
                ),
                if (userEmail.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    userEmail,
                    style: const TextStyle(
                      color: AppColors.namaMediumGray,
                      fontSize: 11.5,
                    ),
                  ),
                ],
                if (caption.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    caption,
                    style: const TextStyle(
                      color: AppColors.namaDarkGray,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 13),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isUpdating
                            ? null
                            : () {
                                _updatePhotoStatus(
                                  photoId: doc.id,
                                  status: 'approved',
                                );
                              },
                        icon: const Icon(Icons.check_circle_outline, size: 16),
                        label: const Text(
                          'Approve',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                          side: BorderSide(
                            color: Colors.green.withOpacity(0.45),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isUpdating
                            ? null
                            : () {
                                _updatePhotoStatus(
                                  photoId: doc.id,
                                  status: 'rejected',
                                );
                              },
                        icon: const Icon(Icons.cancel_outlined, size: 16),
                        label: const Text(
                          'Reject',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: BorderSide(
                            color: Colors.red.withOpacity(0.45),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 42,
                      child: OutlinedButton(
                        onPressed: _isUpdating
                            ? null
                            : () {
                                _confirmDeletePhoto(
                                  photoId: doc.id,
                                  storagePath: storagePath,
                                );
                              },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: BorderSide(
                            color: Colors.red.withOpacity(0.45),
                          ),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Icon(Icons.delete_outline, size: 17),
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

  Widget _summaryCard({
    required int total,
    required int approved,
    required int pending,
    required int rejected,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _summaryItem(
              title: 'Total',
              value: total.toString(),
              color: AppColors.namaNavyBlue,
            ),
          ),
          Expanded(
            child: _summaryItem(
              title: 'Approved',
              value: approved.toString(),
              color: Colors.green,
            ),
          ),
          Expanded(
            child: _summaryItem(
              title: 'Pending',
              value: pending.toString(),
              color: Colors.orange,
            ),
          ),
          Expanded(
            child: _summaryItem(
              title: 'Rejected',
              value: rejected.toString(),
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem({
    required String title,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.namaMediumGray,
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.namaLightGray,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _photosStream(),
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? [];

            final approved = docs
                .where((doc) => (doc.data()['status'] ?? '') == 'approved')
                .length;
            final pending = docs
                .where((doc) => (doc.data()['status'] ?? 'pending') == 'pending')
                .length;
            final rejected = docs
                .where((doc) => (doc.data()['status'] ?? '') == 'rejected')
                .length;

            final groupedPhotos = _groupPhotosBySession(docs);

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              children: [
               Padding(
  padding: const EdgeInsets.only(bottom: 18),
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
              color: AppColors.namaGoldenYellow.withOpacity(0.55),
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
              'Event Photos',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.namaNavyBlue,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.eventName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.namaMediumGray,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ],
  ),
),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.namaNavyBlue,
                      ),
                    ),
                  )
                else if (snapshot.hasError)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      'Failed to load photos: ${snapshot.error}',
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  )
                else ...[
                  _summaryCard(
                    total: docs.length,
                    approved: approved,
                    pending: pending,
                    rejected: rejected,
                  ),
                  const SizedBox(height: 18),
                  if (docs.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.photo_library_outlined,
                            color: AppColors.namaNavyBlue,
                            size: 35,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'No photos uploaded yet',
                            style: TextStyle(
                              color: AppColors.namaNavyBlue,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Photos uploaded by attendees will appear here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.namaMediumGray,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...groupedPhotos.entries.map((entry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: const TextStyle(
                              color: AppColors.namaNavyBlue,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...entry.value.map(_photoCard),
                          const SizedBox(height: 8),
                        ],
                      );
                    }),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}