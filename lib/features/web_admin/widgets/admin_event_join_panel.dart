import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

class AdminEventJoinPanel extends StatefulWidget {
  final String eventId;

  const AdminEventJoinPanel({
    super.key,
    required this.eventId,
  });

  @override
  State<AdminEventJoinPanel> createState() =>
      _AdminEventJoinPanelState();
}

class _AdminEventJoinPanelState extends State<AdminEventJoinPanel> {
  static const _navy = Color(0xFF0B0B83);

  late Future<void> _generation;
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _credentials;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void didUpdateWidget(covariant AdminEventJoinPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.eventId != widget.eventId) {
      _connect();
    }
  }

  void _connect() {
    _credentials = FirebaseFirestore.instance
        .collection('eventJoinCredentials')
        .doc(widget.eventId)
        .snapshots();

    _generation = _ensureCode();
  }

  Future<void> _ensureCode() async {
    await FirebaseFunctions.instanceFor(
      region: 'asia-southeast1',
    ).httpsCallable('ensureEventJoinCredentials').call({
      'eventId': widget.eventId,
    });
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Event code copied.'),
      ),
    );
  }

  Widget _failure(Object? error) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Unable to load event joining code: $error',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red),
        ),
        TextButton.icon(
          onPressed: () => setState(_connect),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE5E7F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Event Joining QR & Code',
            style: TextStyle(
              color: _navy,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Share with participants so they can join this event.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 20),
          FutureBuilder<void>(
            future: _generation,
            builder: (context, generated) {
              if (generated.hasError) {
                return _failure(generated.error);
              }

              if (generated.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              return StreamBuilder<
                  DocumentSnapshot<Map<String, dynamic>>>(
                stream: _credentials,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _failure(snapshot.error);
                  }

                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final data = snapshot.data!.data();
                  final code = (data?['code'] ?? '').toString();
                  final payload =
                      (data?['qrPayload'] ?? '').toString();

                  if (code.isEmpty || payload.isEmpty) {
                    return _failure(
                      'Joining credentials are unavailable.',
                    );
                  }

                  return Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFE5E7F0),
                            ),
                          ),
                          child: QrImageView(
                            data: payload,
                            size: 200,
                            backgroundColor: Colors.white,
                            foregroundColor: _navy,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Event Code',
                          style: TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          code,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _navy,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => _copy(code),
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text('Copy Code'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _navy,
                          ),
                        ),
                      ],
                    ),
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