import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:flutter/material.dart';

class CheckRegistrationScreen extends StatefulWidget {
  final String eventId;
  final String eventName;

  const CheckRegistrationScreen({
    super.key,
    required this.eventId,
    required this.eventName,
  });

  @override
  State<CheckRegistrationScreen> createState() =>
      _CheckRegistrationScreenState();
}

class _CheckRegistrationScreenState extends State<CheckRegistrationScreen> {
  bool _isAddingToReport = false;
  bool _isSyncingUsers = false;

  Stream<QuerySnapshot<Map<String, dynamic>>> _registrationsStream() {
    return FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .collection('registrations')
        .orderBy('registeredAt', descending: true)
        .snapshots();
  }

  Future<void> _syncExistingUsers() async {
    if (_isSyncingUsers) return;

    setState(() => _isSyncingUsers = true);

    try {
      final firestore = FirebaseFirestore.instance;

      final usersSnap = await firestore
          .collection('users')
          .where('eventIds', arrayContains: widget.eventId)
          .get();

      if (usersSnap.docs.isEmpty) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No existing event users found to sync.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final batch = firestore.batch();

      for (final userDoc in usersSnap.docs) {
        final userData = userDoc.data();

        final registrationRef = firestore
            .collection('events')
            .doc(widget.eventId)
            .collection('registrations')
            .doc(userDoc.id);

        batch.set(
          registrationRef,
          {
            'userId': userDoc.id,
            'name': (userData['name'] ?? 'Unknown User').toString(),
            'email': (userData['email'] ?? '').toString(),
            'role': (userData['role'] ?? 'user').toString(),
            'status': 'registered',
            'source': 'sync_existing_users',
            'includedInReport': false,
            'registeredAt': userData['lastSeen'] ??
                userData['updatedAt'] ??
                userData['createdAt'] ??
                FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${usersSnap.docs.length} existing users synced.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to sync existing users: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSyncingUsers = false);
      }
    }
  }

  Future<void> _addToReport() async {
    if (_isAddingToReport) return;

    setState(() => _isAddingToReport = true);

    try {
      final firestore = FirebaseFirestore.instance;

      final registrationsSnap = await firestore
          .collection('events')
          .doc(widget.eventId)
          .collection('registrations')
          .get();

      final batch = firestore.batch();

      for (final doc in registrationsSnap.docs) {
        batch.update(doc.reference, {
          'includedInReport': true,
          'includedInReportAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registered users added to report successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add registrations to report: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isAddingToReport = false);
      }
    }
  }

  String _formatDate(dynamic value) {
    if (value == null) return '-';

    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    }

    if (date == null) return '-';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.namaLightGray,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _registrationsStream(),
          builder: (context, snapshot) {
            final registrations = snapshot.data?.docs ?? [];

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: 34,
                          width: 34,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: AppColors.namaNavyBlue,
                            size: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Check Registration',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.namaNavyBlue,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.namaNavyBlue,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.eventName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${registrations.length} registered user${registrations.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 36,
                          child: OutlinedButton.icon(
                            onPressed:
                                _isSyncingUsers ? null : _syncExistingUsers,
                            icon: _isSyncingUsers
                                ? const SizedBox(
                                    height: 14,
                                    width: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.sync_rounded,
                                    size: 16,
                                  ),
                            label: Text(
                              _isSyncingUsers
                                  ? 'Syncing Users...'
                                  : 'Sync Existing Users',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.white.withOpacity(0.55),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.namaNavyBlue,
                          ),
                        )
                      : snapshot.hasError
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Text(
                                  'Failed to load registrations:\n${snapshot.error}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            )
                          : registrations.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No registered users yet.',
                                    style: TextStyle(
                                      color: AppColors.namaMediumGray,
                                      fontSize: 13,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  itemCount: registrations.length,
                                  itemBuilder: (context, index) {
                                    final doc = registrations[index];
                                    final data = doc.data();

                                    final name =
                                        (data['name'] ?? 'Unknown User')
                                            .toString();
                                    final email =
                                        (data['email'] ?? '').toString();
                                    final role =
                                        (data['role'] ?? 'user').toString();
                                    final registeredAt =
                                        _formatDate(data['registeredAt']);
                                    final included =
                                        data['includedInReport'] == true;

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(13),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.045),
                                            blurRadius: 10,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 20,
                                            backgroundColor:
                                                AppColors.namaNavyBlue
                                                    .withOpacity(0.10),
                                            child: Text(
                                              name.isNotEmpty
                                                  ? name[0].toUpperCase()
                                                  : '?',
                                              style: const TextStyle(
                                                color: AppColors.namaNavyBlue,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
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
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color:
                                                        AppColors.namaNavyBlue,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  email.isEmpty ? '-' : email,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: AppColors
                                                        .namaMediumGray,
                                                    fontSize: 10.8,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '$role • $registeredAt',
                                                  style: const TextStyle(
                                                    color: AppColors
                                                        .namaMediumGray,
                                                    fontSize: 10.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (included)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.green
                                                    .withOpacity(0.10),
                                                borderRadius:
                                                    BorderRadius.circular(30),
                                              ),
                                              child: const Text(
                                                'Report',
                                                style: TextStyle(
                                                  color: Colors.green,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SizedBox(
                    height: 46,
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: registrations.isEmpty || _isAddingToReport
                          ? null
                          : _addToReport,
                      icon: _isAddingToReport
                          ? const SizedBox(
                              height: 17,
                              width: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.post_add_rounded, size: 18),
                      label: Text(
                        _isAddingToReport
                            ? 'Adding to Report...'
                            : 'Add to Report',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.namaNavyBlue,
                        disabledBackgroundColor:
                            AppColors.namaNavyBlue.withOpacity(0.45),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}