import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Staff tool for validating invitations and recording walk-in admissions.
///
/// The currently selected event comes from the signed-in staff profile's
/// eventIds. If multiple events are assigned, staff can select the event.
class StaffAdmissionScannerScreen extends StatefulWidget {
  const StaffAdmissionScannerScreen({super.key});

  @override
  State<StaffAdmissionScannerScreen> createState() =>
      _StaffAdmissionScannerScreenState();
}

class _StaffAdmissionScannerScreenState
    extends State<StaffAdmissionScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-southeast1');
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  List<String> _eventIds = [];
  String? _eventId;
  Map<String, dynamic>? _invitation;
  String? _error;
  bool _loadingEvents = true;
  bool _busy = false;
  bool _showWalkInForm = false;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw StateError('Please sign in again.');

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = snapshot.data() ?? <String, dynamic>{};
      final ids = <String>{};
      final rawIds = data['eventIds'];
      if (rawIds is Iterable) {
        ids.addAll(rawIds.map((value) => value.toString().trim()).where(
              (value) => value.isNotEmpty && !value.contains('/'),
            ));
      }
      for (final key in ['activeEventId', 'currentEventId']) {
        final value = (data[key] ?? '').toString().trim();
        if (value.isNotEmpty && !value.contains('/')) ids.add(value);
      }

      final ordered = ids.toList();
      final preferred = (data['activeEventId'] ?? data['currentEventId'] ?? '')
          .toString()
          .trim();
      if (preferred.isNotEmpty && ordered.remove(preferred)) {
        ordered.insert(0, preferred);
      }

      if (!mounted) return;
      setState(() {
        _eventIds = ordered;
        _eventId = ordered.isEmpty ? null : ordered.first;
        _loadingEvents = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(error);
        _loadingEvents = false;
      });
    }
  }

  String _friendlyError(Object error) {
    if (error is FirebaseFunctionsException) {
      return error.message ?? 'The request could not be completed.';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  String _tokenFrom(String raw) {
    final value = raw.trim();
    if (value.startsWith('{')) {
      try {
        final decoded = Map<String, dynamic>.from(jsonDecode(value) as Map);
        final token = (decoded['token'] ?? decoded['invitationToken'] ?? '')
            .toString()
            .trim();
        if (token.isNotEmpty) return token;
      } catch (_) {
        // The invitation email currently encodes the token directly.
      }
    }
    return value;
  }

  Future<void> _scanInvitation(BarcodeCapture capture) async {
    if (_busy || _eventId == null) return;
    final raw = capture.barcodes
        .map((barcode) => barcode.rawValue ?? '')
        .firstWhere((value) => value.trim().isNotEmpty, orElse: () => '');
    final token = _tokenFrom(raw);
    if (token.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
      _invitation = null;
    });
    try {
      final result = await _functions
          .httpsCallable('staffScanInvitationQr')
          .call(<String, dynamic>{'eventId': _eventId, 'token': token});
      final data = Map<String, dynamic>.from(result.data as Map);
      if (!mounted) return;
      setState(() {
        _invitation = <String, dynamic>{...data, 'token': token};
        _busy = false;
      });
      await _controller.stop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(error);
        _busy = false;
      });
    }
  }

  Future<void> _confirmInvitation() async {
    final invitation = _invitation;
    final eventId = _eventId;
    if (_busy || invitation == null || eventId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _functions.httpsCallable('staffConfirmInvitation').call({
        'eventId': eventId,
        'token': invitation['token'],
      });
      if (!mounted) return;
      setState(() {
        _invitation = null;
        _busy = false;
        _error = null;
      });
      _showMessage('Invitation verified. They can now scan the event QR.');
      await _controller.start();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(error);
        _busy = false;
      });
    }
  }

  Future<void> _createWalkIn() async {
    final eventId = _eventId;
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    if (eventId == null) return;
    if (name.isEmpty || email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter the participant’s name and a valid email.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _functions.httpsCallable('staffCreateWalkInAdmission').call({
        'eventId': eventId,
        'name': name,
        'email': email,
      });
      if (!mounted) return;
      _nameController.clear();
      _emailController.clear();
      setState(() {
        _showWalkInForm = false;
        _busy = false;
      });
      _showMessage('Walk-in recorded. They can now scan the event QR.');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(error);
        _busy = false;
      });
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingEvents) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_eventIds.isEmpty) {
      return _messageCard(
        'No event assigned',
        'This staff account does not have an event assigned yet.',
        Icons.event_busy_outlined,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      children: [
        const Text(
          'Event admission',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        Text(
          'Verify invited participants before they scan the event QR.',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 16),
        if (_eventIds.length > 1)
          DropdownButtonFormField<String>(
            value: _eventId,
            decoration: const InputDecoration(
              labelText: 'Event',
              border: OutlineInputBorder(),
            ),
            items: _eventIds
                .map((id) => DropdownMenuItem(value: id, child: Text(id)))
                .toList(),
            onChanged: (value) {
              setState(() {
                _eventId = value;
                _invitation = null;
                _error = null;
              });
            },
          )
        else
          _eventLabel(_eventId!),
        const SizedBox(height: 14),
        if (_error != null) ...[
          _notice(_error!, isError: true),
          const SizedBox(height: 12),
        ],
        if (_invitation != null) ...[
          _invitationCard(),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : () async {
              setState(() => _invitation = null);
              await _controller.start();
            },
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan another invitation'),
          ),
        ] else if (!_showWalkInForm) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 300,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(controller: _controller, onDetect: _scanInvitation),
                  IgnorePointer(
                    child: Center(
                      child: Container(
                        width: 230,
                        height: 190,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 3),
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                  if (_busy)
                    Container(
                      color: Colors.black45,
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => setState(() => _showWalkInForm = true),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Register walk-in'),
          ),
        ] else ...[
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Participant name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Participant email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _createWalkIn,
            icon: const Icon(Icons.check),
            label: Text(_busy ? 'Saving…' : 'Confirm walk-in'),
          ),
          TextButton(
            onPressed: _busy ? null : () => setState(() {
              _showWalkInForm = false;
              _error = null;
            }),
            child: const Text('Cancel'),
          ),
        ],
      ],
    );
  }

  Widget _eventLabel(String id) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('Event: $id', style: const TextStyle(fontWeight: FontWeight.w600)),
      );

  Widget _invitationCard() {
    final data = _invitation!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.verified_user_outlined, color: Colors.green),
              SizedBox(width: 8),
              Text('Invitation found', style: TextStyle(fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 14),
            _detail('Name', (data['name'] ?? '').toString()),
            _detail('Email', (data['email'] ?? '').toString()),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _confirmInvitation,
                icon: const Icon(Icons.how_to_reg),
                label: Text(_busy ? 'Verifying…' : 'Confirm By Invitation'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detail(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 64, child: Text(label, style: TextStyle(color: Colors.grey.shade700))),
          Expanded(child: Text(value.isEmpty ? '—' : value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );

  Widget _notice(String text, {required bool isError}) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isError ? Colors.red.shade50 : Colors.green.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(text, style: TextStyle(color: isError ? Colors.red.shade800 : Colors.green.shade800)),
      );

  Widget _messageCard(String title, String text, IconData icon) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 44, color: Colors.grey),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(text, textAlign: TextAlign.center),
          ]),
        ),
      );
}
