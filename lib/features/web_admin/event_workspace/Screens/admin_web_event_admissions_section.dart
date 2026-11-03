import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../admin_web_theme.dart';

/// CSV invitations and the live admission source/status list for one event.
class AdminWebEventAdmissionsSection extends StatefulWidget {
  final String eventId;

  const AdminWebEventAdmissionsSection({
    super.key,
    required this.eventId,
  });

  @override
  State<AdminWebEventAdmissionsSection> createState() =>
      _AdminWebEventAdmissionsSectionState();
}

class _AdminWebEventAdmissionsSectionState
    extends State<AdminWebEventAdmissionsSection> {
  bool _uploading = false;
  String? _message;
  bool _messageIsError = false;
  final Set<String> _deletingAdmissionIds = {};

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  List<List<String>> _parseCsv(String input) {
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var quoted = false;

    for (var index = 0; index < input.length; index++) {
      final character = input[index];

      if (character == '"') {
        if (quoted &&
            index + 1 < input.length &&
            input[index + 1] == '"') {
          field.write('"');
          index++;
        } else {
          quoted = !quoted;
        }
      } else if (character == ',' && !quoted) {
        row.add(field.toString().trim());
        field.clear();
      } else if ((character == '\n' || character == '\r') && !quoted) {
        if (character == '\r' &&
            index + 1 < input.length &&
            input[index + 1] == '\n') {
          index++;
        }

        row.add(field.toString().trim());
        field.clear();

        if (row.any((cell) => cell.isNotEmpty)) {
          rows.add(row);
        }

        row = <String>[];
      } else {
        field.write(character);
      }
    }

    row.add(field.toString().trim());

    if (row.any((cell) => cell.isNotEmpty)) {
      rows.add(row);
    }

    if (quoted) {
      throw const FormatException('A quoted CSV field is not closed.');
    }

    return rows;
  }

  Future<void> _uploadCsv() async {
    if (_uploading) return;

    try {
      final selection = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        withData: true,
      );

      if (selection == null || selection.files.isEmpty) return;

      final bytes = selection.files.single.bytes;
      if (bytes == null) {
        throw Exception('Could not read the selected CSV file.');
      }

      final rows = _parseCsv(utf8.decode(bytes, allowMalformed: true));

      if (rows.length < 2) {
        throw Exception(
          'The CSV needs a header and at least one participant row.',
        );
      }

      final headers = rows.first
          .map((value) => value.toLowerCase().trim())
          .toList();

      final nameIndex = headers.indexWhere(
        (value) =>
            value == 'name' ||
            value == 'full name' ||
            value == 'fullname',
      );

      final emailIndex = headers.indexWhere(
        (value) => value == 'email' || value == 'email address',
      );

      if (nameIndex < 0 || emailIndex < 0) {
        throw Exception('CSV headers must include Name and Email columns.');
      }

      final participants = <Map<String, String>>[];

      for (final row in rows.skip(1)) {
        final name = nameIndex < row.length ? row[nameIndex].trim() : '';
        final email = emailIndex < row.length ? row[emailIndex].trim() : '';

        if (name.isEmpty && email.isEmpty) continue;

        participants.add({
          'name': name,
          'email': email,
        });
      }

      if (participants.isEmpty) {
        throw Exception('No participant rows were found.');
      }

      if (participants.length > 200) {
        throw Exception('Upload up to 200 participants per CSV file.');
      }

      setState(() {
        _uploading = true;
        _message = 'Creating invitations and sending QR emails…';
        _messageIsError = false;
      });

      final createResult = await _functions
          .httpsCallable('createEventInvitations')
          .call({
        'eventId': widget.eventId,
        'participants': participants,
      });

      final createData =
          Map<String, dynamic>.from(createResult.data as Map);

      final created = (createData['created'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => Map<String, dynamic>.from(value))
          .toList();

      var sentCount = 0;
      var failedCount = 0;

      if (created.isNotEmpty) {
        final emailResult = await _functions
            .httpsCallable('sendEventAdmissionEmails')
            .call({
          'eventId': widget.eventId,
          'invitations': created
              .map(
                (entry) => {
                  'admissionId': entry['admissionId'],
                  'token': entry['token'],
                },
              )
              .toList(),
        });

        final emailData =
            Map<String, dynamic>.from(emailResult.data as Map);

        sentCount = (emailData['sent'] as List? ?? const []).length;
        failedCount = (emailData['failed'] as List? ?? const []).length;
      }

      final skipped = (createData['skipped'] as List? ?? const []).length;
      final invalid = (createData['invalid'] as List? ?? const []).length;

      final parts = <String>[
        '${created.length} invitation(s) created',
        '$sentCount QR email(s) sent',
        if (failedCount > 0) '$failedCount email(s) failed',
        if (skipped > 0) '$skipped duplicate(s) skipped',
        if (invalid > 0) '$invalid invalid row(s)',
      ];

      if (!mounted) return;

      setState(() {
        _message = parts.join(' · ');
        _messageIsError = failedCount > 0 || invalid > 0;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _message = error.toString();
        _messageIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  Future<void> _deleteAdmission({
    required String admissionId,
    required String participantName,
    required String email,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete admission record?'),
          content: Text(
            'Remove $participantName${email.isEmpty ? '' : ' ($email)'} '
            'from this event’s admission list?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB42318),
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) return;

    setState(() {
      _deletingAdmissionIds.add(admissionId);
    });

    try {
      await _functions
          .httpsCallable('adminDeleteEventAdmission')
          .call({
        'eventId': widget.eventId,
        'admissionId': admissionId,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Admission record deleted.'),
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'Could not delete the admission record.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete the admission record: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _deletingAdmissionIds.remove(admissionId);
        });
      }
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _admissionsStream() {
    return FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .collection('admissions')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  String _statusLabel(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString().toLowerCase();
    final emailStatus =
        (data['invitationEmailStatus'] ?? '').toString().toLowerCase();

    if (status == 'joined') return 'Joined event';
    if (status == 'verified_by_staff') return 'Admitted by staff';
    if (status == 'revoked') return 'Revoked';
    if (emailStatus == 'failed') return 'Email failed';
    if (emailStatus == 'sent') return 'Invitation sent';

    return 'Pending';
  }

  Color _statusColor(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString().toLowerCase();
    final emailStatus =
        (data['invitationEmailStatus'] ?? '').toString().toLowerCase();

    if (status == 'joined' || status == 'verified_by_staff') {
      return const Color(0xFF15803D);
    }

    if (status == 'revoked' || emailStatus == 'failed') {
      return const Color(0xFFB42318);
    }

    return const Color(0xFFB54708);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.upload_file_outlined,
                  color: AdminWebTheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Invited participants',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Upload a CSV with Name and Email columns. '
                        'Each new invitee receives a QR code by email.',
                      ),
                      if (_message != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _message!,
                          style: TextStyle(
                            color: _messageIsError
                                ? const Color(0xFFB42318)
                                : const Color(0xFF15803D),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: _uploading ? null : _uploadCsv,
                  icon: _uploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_rounded),
                  label: Text(_uploading ? 'Uploading…' : 'Upload CSV'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _admissionsStream(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _AdmissionsMessage(
                'Could not load admissions: ${snapshot.error}',
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final records = snapshot.data!.docs;

            if (records.isEmpty) {
              return const _AdmissionsMessage(
                'No invited participants or walk-ins recorded yet.',
              );
            }

            return Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
                    child: Text(
                      'Admission list (${records.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ...records.map((document) {
                    final data = document.data();
                    final source =
                        (data['source'] ?? 'invitation').toString();
                    final isWalkIn = source == 'walk_in';
                    final name =
                        (data['name'] ?? 'Participant').toString();
                    final email = (data['email'] ?? '').toString();
                    final color = _statusColor(data);
                    final isDeleting =
                        _deletingAdmissionIds.contains(document.id);

                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        backgroundColor: isWalkIn
                            ? const Color(0xFFFFF4E5)
                            : const Color(0xFFEFF4FF),
                        child: Icon(
                          isWalkIn
                              ? Icons.directions_walk
                              : Icons.mail_outline,
                          size: 18,
                          color: isWalkIn
                              ? const Color(0xFFB54708)
                              : AdminWebTheme.primary,
                        ),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        email.isEmpty ? 'No email' : email,
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _AdmissionTag(
                            label: isWalkIn ? 'Walk-in' : 'By Invitation',
                            color: isWalkIn
                                ? const Color(0xFFB54708)
                                : AdminWebTheme.primary,
                          ),
                          _AdmissionTag(
                            label: _statusLabel(data),
                            color: color,
                          ),
                          IconButton(
                            tooltip: 'Delete admission record',
                            onPressed: isDeleting
                                ? null
                                : () => _deleteAdmission(
                                      admissionId: document.id,
                                      participantName: name,
                                      email: email,
                                    ),
                            icon: isDeleting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.delete_outline_rounded,
                                    color: Color(0xFFB42318),
                                  ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _AdmissionTag extends StatelessWidget {
  final String label;
  final Color color;

  const _AdmissionTag({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _AdmissionsMessage extends StatelessWidget {
  final String message;

  const _AdmissionsMessage(this.message);

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Center(
            child: Text(
              message,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
}