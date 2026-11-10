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
  final Set<String> _resendingAdmissionIds = {};

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

      final csvText = utf8
          .decode(bytes, allowMalformed: true)
          .replaceFirst('\uFEFF', '');
      final rows = _parseCsv(csvText);

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
        final email = emailIndex < row.length
            ? _cleanInvitationEmail(row[emailIndex])
            : '';

        if (name.isEmpty && email.isEmpty) continue;

        participants.add({
          'name': name,
          'email': email,
        });
      }

      if (participants.isEmpty) {
        throw Exception('No participant rows were found.');
      }

      setState(() {
        _uploading = true;
        _message = 'Preparing ${participants.length} participants…';
        _messageIsError = false;
      });

      const batchSize = 200;
      final totalBatches = (participants.length + batchSize - 1) ~/ batchSize;
      var createdCount = 0;
      var retriedCount = 0;
      var sentCount = 0;
      var failedCount = 0;
      var alreadySentCount = 0;
      var skippedCount = 0;
      var invalidCount = 0;
      var failedBatchCount = 0;
      final failedDetails = <String>[];

      for (var batchIndex = 0;
          batchIndex < totalBatches;
          batchIndex++) {
        final start = batchIndex * batchSize;
        final batch = participants.skip(start).take(batchSize).toList();

        if (mounted) {
          setState(() {
            _message =
                'Processing batch ${batchIndex + 1} of $totalBatches '
                '(${batch.length} participants)…';
          });
        }

        try {
          final createResult = await _functions
              .httpsCallable('createEventInvitations')
              .call({
            'eventId': widget.eventId,
            'participants': batch,
          });

          final createData =
              Map<String, dynamic>.from(createResult.data as Map);
          final created = (createData['created'] as List? ?? const [])
              .whereType<Map>()
              .map((value) => Map<String, dynamic>.from(value))
              .toList();
          final retried = (createData['retried'] as List? ?? const [])
              .whereType<Map>()
              .map((value) => Map<String, dynamic>.from(value))
              .toList();
          final invitationsToSend = [...created, ...retried];
          createdCount += created.length;
          retriedCount += retried.length;
          skippedCount += (createData['skipped'] as List? ?? const []).length;
          invalidCount += (createData['invalid'] as List? ?? const []).length;

          if (invitationsToSend.isEmpty) continue;

          final emailResult = await _functions
              .httpsCallable('sendEventAdmissionEmails')
              .call({
            'eventId': widget.eventId,
            'invitations': invitationsToSend
                .map((entry) => {
                      'admissionId': entry['admissionId'],
                      'token': entry['token'],
                    })
                .toList(),
          });

          final emailData =
              Map<String, dynamic>.from(emailResult.data as Map);
          sentCount += (emailData['sent'] as List? ?? const []).length;
          alreadySentCount +=
              (emailData['alreadySent'] as List? ?? const []).length;
          final failed = (emailData['failed'] as List? ?? const [])
              .whereType<Map>()
              .map((value) => Map<String, dynamic>.from(value))
              .toList();
          failedCount += failed.length;
          failedDetails.addAll(
            failed.take(5).map((entry) {
              final email = (entry['email'] ?? '').toString();
              final reason = (entry['reason'] ?? 'Email failed').toString();
              return email.isEmpty ? reason : '$email: $reason';
            }),
          );
        } catch (error) {
          failedBatchCount++;
          failedDetails.add('Batch ${batchIndex + 1}: $error');
        }
      }

      final parts = <String>[
        '$createdCount new invitation(s)',
        if (retriedCount > 0)
          '$retriedCount existing invitation(s) retried',
        '$sentCount QR email(s) sent',
        if (alreadySentCount > 0)
          '$alreadySentCount email(s) were already sent',
        if (failedCount > 0)
          '$failedCount email(s) failed${failedDetails.isEmpty ? '' : ': ${failedDetails.join(' · ')}'}',
        if (failedBatchCount > 0)
          '$failedBatchCount batch(es) could not be processed',
        if (skippedCount > 0)
          '$skippedCount existing participant(s) skipped',
        if (invalidCount > 0) '$invalidCount invalid row(s)',
      ];

      if (!mounted) return;

      setState(() {
        _message = parts.join(' · ');
        _messageIsError =
            failedCount > 0 || failedBatchCount > 0 || invalidCount > 0;
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

  Future<void> _resendInvitation({
    required String admissionId,
    required String participantName,
    required String email,
  }) async {
    if (_resendingAdmissionIds.contains(admissionId)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Resend invitation?'),
        content: Text(
          'Send a fresh QR invitation to $email? Any previous QR for '
          '$participantName will stop working.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Resend'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    setState(() => _resendingAdmissionIds.add(admissionId));

    try {
      final createResult = await _functions
          .httpsCallable('createEventInvitations')
          .call({
        'eventId': widget.eventId,
        'forceResendExisting': true,
        'participants': [
          {
            'name': participantName,
            'email': _cleanInvitationEmail(email),
            'existingAdmissionId': admissionId,
          },
        ],
      });

      final createData = Map<String, dynamic>.from(createResult.data as Map);
      final created = (createData['created'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => Map<String, dynamic>.from(value))
          .toList();
      final retried = (createData['retried'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => Map<String, dynamic>.from(value))
          .toList();
      final invitations = [...created, ...retried];

      if (invitations.isEmpty) {
        throw Exception(
          'The participant could not be resent. They may have joined or been revoked.',
        );
      }

      final emailResult = await _functions
          .httpsCallable('sendEventAdmissionEmails')
          .call({
        'eventId': widget.eventId,
        'invitations': invitations
            .map((entry) => {
                  'admissionId': entry['admissionId'],
                  'token': entry['token'],
                })
            .toList(),
      });

      final emailData = Map<String, dynamic>.from(emailResult.data as Map);
      final sent = (emailData['sent'] as List? ?? const []).length;
      final failed = (emailData['failed'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => Map<String, dynamic>.from(value))
          .toList();
      final resendSucceeded = sent > 0 && failed.isEmpty;

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resendSucceeded
                ? 'Invitation resent to $email.'
                : 'Could not send to $email: '
                    '${(failed.first['reason'] ?? 'Email failed').toString()}',
          ),
          backgroundColor:
              resendSucceeded ? null : const Color(0xFFB42318),
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Could not resend this invitation.'),
          backgroundColor: const Color(0xFFB42318),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not resend this invitation: $error'),
          backgroundColor: const Color(0xFFB42318),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _resendingAdmissionIds.remove(admissionId));
      }
    }
  }

  String _cleanInvitationEmail(String value) {
    return value
        .replaceAll(
          RegExp(r'[\u200B-\u200F\u202A-\u202E\u2060-\u206F\uFEFF]'),
          '',
        )
        .replaceAll('\u00A0', ' ')
        .trim()
        .toLowerCase();
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
                        'Upload multiple CSV files with Name and Email columns. '
                        'Duplicates are skipped. Re-upload a file to retry failed invitations, or use Resend beside a participant.',
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
                    final isResending =
                        _resendingAdmissionIds.contains(document.id);
                    final admissionStatus =
                        (data['status'] ?? '').toString().toLowerCase();
                    final canResend = !isWalkIn &&
                        email.isNotEmpty &&
                        admissionStatus != 'joined' &&
                        admissionStatus != 'verified_by_staff' &&
                        admissionStatus != 'revoked';

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
                          if (canResend)
                            IconButton(
                              tooltip: 'Resend invitation with a new QR',
                              onPressed: isResending || isDeleting
                                  ? null
                                  : () => _resendInvitation(
                                        admissionId: document.id,
                                        participantName: name,
                                        email: email,
                                      ),
                              icon: isResending
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.forward_to_inbox_outlined,
                                      color: AdminWebTheme.primary,
                                    ),
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
