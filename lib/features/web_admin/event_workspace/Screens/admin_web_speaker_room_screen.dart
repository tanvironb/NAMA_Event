import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Place in lib/features/web_admin/event_workspace/screens/.
class AdminWebSpeakerRoomScreen extends StatefulWidget {
  final String eventId;
  final String eventName;
  const AdminWebSpeakerRoomScreen({super.key, required this.eventId,
    this.eventName = ''});
  @override
  State<AdminWebSpeakerRoomScreen> createState() => _SpeakerRoomState();
}

class _SpeakerRoomState extends State<AdminWebSpeakerRoomScreen> {
  static const _navy = Color(0xFF0B0B83);
  final _input = TextEditingController();
  late DocumentReference<Map<String, dynamic>> _room;
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _roomStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _messages;
  final Set<String> _busy = {};
  bool _sending = false;

  @override
  void initState() { super.initState(); _subscribe(); }
  void _subscribe() {
    _room = FirebaseFirestore.instance.collection('speaker_moderator_rooms')
        .doc(widget.eventId);
    _roomStream = _room.snapshots();
    // Sorting locally includes messages whose server timestamp is still pending.
    _messages = _room.collection('messages').snapshots();
  }
  @override
  void didUpdateWidget(covariant AdminWebSpeakerRoomScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eventId != widget.eventId) {
      _subscribe(); _input.clear();
    }
  }
  @override
  void dispose() { _input.dispose(); super.dispose(); }

  Future<User> _requireAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Sign in to continue.');
    final profile = await FirebaseFirestore.instance.collection('users')
        .doc(user.uid).get();
    if ((profile.data()?['role'] ?? '').toString().toLowerCase() != 'admin') {
      throw StateError('Administrator access is required.');
    }
    return user;
  }

  void _error(Object error) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Action failed: $error')));
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (_sending || text.isEmpty) return;
    final room = _room;
    setState(() => _sending = true);
    try {
      final user = await _requireAdmin();
      final profile = await FirebaseFirestore.instance.collection('users')
          .doc(user.uid).get();
      final data = profile.data() ?? {};
      final name = (data['fullName'] ?? data['name'] ?? user.displayName ?? 'Admin')
          .toString();
      await room.collection('messages').add({
        'text': text, 'messageType': 'text', 'fileUrl': '', 'fileName': '',
        'fileType': '', 'fileSize': 0, 'senderId': user.uid,
        'senderName': name, 'senderRole': 'admin',
        'senderImageUrl': data['profileImageUrl'] ?? user.photoURL ?? '',
        'timestamp': FieldValue.serverTimestamp(), 'readBy': [user.uid],
        'mentionedUserIds': <String>[], 'mentionedUserNames': <String>[],
        'deletedForEveryone': false,
      });
      if (mounted && _room.path == room.path && _input.text.trim() == text) {
        _input.clear();
      }
    } catch (e) { _error(e); }
    finally { if (mounted) setState(() => _sending = false); }
  }

  Future<void> _action(String key, Future<void> Function(User) action) async {
    if (_busy.contains(key)) return;
    setState(() => _busy.add(key));
    try { await action(await _requireAdmin()); }
    catch (e) { _error(e); }
    finally { if (mounted) setState(() => _busy.remove(key)); }
  }

  Future<void> _mute(String uid, bool muted) {
    final room = _room;
    return _action('mute:$uid', (user) => room.set({
      'mutedUsers': muted ? FieldValue.arrayUnion([uid])
          : FieldValue.arrayRemove([uid]),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': user.uid,
    }, SetOptions(merge: true)));
  }

  String _time(dynamic value) {
    if (value is! Timestamp) return 'Sending…';
    final date = value.toDate().toLocal();
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: const Color(0xFFF5F6FC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE3E6ED))),
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _roomStream,
              builder: (context, roomSnapshot) {
                if (roomSnapshot.hasError) {
                  return Center(child: Text('Unable to load room: ${roomSnapshot.error}'));
                }
                if (!roomSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final muted = roomSnapshot.data!.data()?['mutedUsers'];
                final mutedIds = muted is List ? muted.map((e) => e.toString()).toSet()
                    : <String>{};
                return Column(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(color: Colors.white,
                      border: Border(bottom: BorderSide(color: Color(0xFFE2E5EB)))),
                    child: Row(children: [
                      Container(width: 40, height: 40,
                        decoration: BoxDecoration(color: const Color(0xFFEEEEFA),
                          borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.forum_rounded, color: _navy, size: 22)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Speaker Room', style: TextStyle(color: _navy,
                            fontSize: 17, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 3),
                          Text('Speakers & moderators group chat', maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0xFF687483), fontSize: 12)),
                        ])),
                      const Tooltip(message: 'Live group chat', child:
                        Icon(Icons.circle, color: Color(0xFF25A76A), size: 9)),
                    ]),
                  ),
                  if (mutedIds.isNotEmpty) Padding(
                    padding: const EdgeInsets.all(8),
                    child: Wrap(spacing: 8, runSpacing: 4,
                      children: mutedIds.map((uid) => _MutedUserChip(
                        uid: uid, busy: _busy.contains('mute:$uid'),
                        onUnmute: () => _mute(uid, false))).toList())),
                  Expanded(child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _messages,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return Center(child: Text(
                          'Unable to load messages: ${snapshot.error}'));
                      if (!snapshot.hasData) return const Center(
                          child: CircularProgressIndicator());
                      final docs = snapshot.data!.docs.toList()..sort((a, b) {
                        final at = a.data()['timestamp'];
                        final bt = b.data()['timestamp'];
                        final compare = (bt is Timestamp ? bt.millisecondsSinceEpoch : 9007199254740991)
                            .compareTo(at is Timestamp ? at.millisecondsSinceEpoch : 9007199254740991);
                        return compare == 0 ? b.id.compareTo(a.id) : compare;
                      });
                      if (docs.isEmpty) return const Center(child: Text('No messages yet.'));
                      return LayoutBuilder(builder: (context, constraints) => ListView.builder(
                        reverse: true, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final timestamp = docs[index].data()['timestamp'];
                          final older = index + 1 < docs.length
                            ? docs[index + 1].data()['timestamp'] : null;
                          final date = timestamp is Timestamp ? timestamp.toDate().toLocal() : null;
                          final olderDate = older is Timestamp ? older.toDate().toLocal() : null;
                          final startsDay = date != null && (olderDate == null ||
                            date.year != olderDate.year || date.month != olderDate.month ||
                            date.day != olderDate.day);
                          return Column(children: [
                            if (startsDay && date != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(color: const Color(0xFFF9F8F5),
                                  borderRadius: BorderRadius.circular(8)),
                                child: Text('${date.day}/${date.month}/${date.year}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF66717C))))),
                            _bubble(docs[index], constraints.maxWidth, mutedIds),
                          ]);
                        }));
                    },
                  )),
                  const Divider(height: 1),
                  Container(color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Expanded(child: TextField(controller: _input, minLines: 1,
                      maxLines: 4, maxLength: 4000,
                      enabled: !_sending, textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(hintText: 'Message speaker room…',
                        counterText: '', filled: true, fillColor: Color(0xFFF3F4FB),
                        isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(28)),
                          borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(28)),
                          borderSide: BorderSide.none)),
                      onSubmitted: (_) => _send())),
                    const SizedBox(width: 8),
                    IconButton.filled(onPressed: _sending ? null : _send,
                      style: IconButton.styleFrom(backgroundColor: _navy),
                      tooltip: 'Send message', icon: _sending
                        ? const SizedBox(width: 18, height: 18, child:
                            CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded)),
                  ])),
                ]);
              },
            ),
          )),
        ]),
      )),
    );
  }

  Widget _bubble(QueryDocumentSnapshot<Map<String, dynamic>> doc,
      double width, Set<String> muted) {
    final m = doc.data();
    final uid = (m['senderId'] ?? '').toString();
    final me = uid == FirebaseAuth.instance.currentUser?.uid;
    final deleted = m['deletedForEveryone'] == true;
    final foreground = me ? Colors.white : const Color(0xFF101239);
    final secondary = me ? Colors.white70 : const Color(0xFF687297);
    final file = (m['fileUrl'] ?? '').toString();
    final bubble = Container(margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(12, 6, 10, 8),
        constraints: BoxConstraints(maxWidth: width < 640 ? (width - 44) * .88 : 520),
        decoration: BoxDecoration(color: me ? _navy : Colors.white,
          borderRadius: BorderRadius.only(topLeft: const Radius.circular(15),
            topRight: const Radius.circular(15), bottomLeft: Radius.circular(me ? 15 : 4),
            bottomRight: Radius.circular(me ? 4 : 15)),
          border: me ? null : Border.all(color: const Color(0xFFE7EAF2)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.045),
            blurRadius: 2, offset: const Offset(0, 1))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(child: Text(me ? 'You' : (m['senderName'] ?? 'Unknown user').toString(),
              style: TextStyle(color: foreground, fontSize: 12, fontWeight: FontWeight.w700))),
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.more_horiz, color: secondary, size: 18),
              enabled: !_busy.contains('delete:${doc.id}') && !_busy.contains('mute:$uid'),
              onSelected: (value) {
                if (value == 'delete') {
                  _action('delete:${doc.id}', (_) => doc.reference.delete());
                } else { _mute(uid, !muted.contains(uid)); }
              }, itemBuilder: (_) => [
                const PopupMenuItem(value: 'delete', child: Text('Remove message')),
                if (uid.isNotEmpty && !me) PopupMenuItem(value: 'mute',
                    child: Text(muted.contains(uid) ? 'Unmute user' : 'Mute user')),
              ]),
          ]),
          Text('${m['senderRole'] ?? 'speaker'}${muted.contains(uid) ? ' • Muted' : ''}',
            style: TextStyle(color: secondary, fontSize: 10)),
          const SizedBox(height: 7),
          SelectableText(deleted ? 'Message removed' : (m['text'] ?? '').toString(),
              style: TextStyle(color: foreground, fontSize: 14)),
          if (!deleted && file.isNotEmpty) ...[
            const SizedBox(height: 6),
            if (m['messageType'] == 'image' || m['fileType'] == 'image')
              Image.network(file, height: 160, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Text('Image unavailable',
                      style: TextStyle(color: foreground))),
            TextButton.icon(onPressed: () async {
              await Clipboard.setData(ClipboardData(text: file));
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Attachment link copied.')));
            }, icon: Icon(Icons.attach_file, color: foreground),
                label: Text((m['fileName'] ?? 'Copy attachment link').toString(),
                    style: TextStyle(color: foreground))),
          ],
          const SizedBox(height: 5),
          Text(_time(m['timestamp']), style: TextStyle(
              color: secondary, fontSize: 9)),
        ]),
      );
    return Row(
      mainAxisAlignment: me ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!me) ...[
          Padding(padding: const EdgeInsets.only(bottom: 12),
            child: _RoomAvatar(key: ValueKey('avatar:${doc.id}:$uid'), uid: uid,
              name: (m['senderName'] ?? 'Unknown user').toString(),
              imageUrl: (m['senderImageUrl'] ?? '').toString())),
          const SizedBox(width: 8),
        ],
        Flexible(child: bubble),
      ],
    );
  }
}

class _MutedUserChip extends StatefulWidget {
  final String uid;
  final bool busy;
  final VoidCallback onUnmute;
  const _MutedUserChip({required this.uid, required this.busy, required this.onUnmute});
  @override
  State<_MutedUserChip> createState() => _MutedUserChipState();
}
class _MutedUserChipState extends State<_MutedUserChip> {
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _profile;
  @override
  void initState() { super.initState(); _subscribe(); }
  void _subscribe() { _profile = FirebaseFirestore.instance.collection('users').doc(widget.uid).snapshots(); }
  @override
  void didUpdateWidget(covariant _MutedUserChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) _subscribe();
  }
  @override
  Widget build(BuildContext context) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: _profile, builder: (context, snapshot) {
      final d = snapshot.data?.data();
      return InputChip(label: Text('${d?['fullName'] ?? d?['name'] ?? 'Muted user'} • Muted'),
        onDeleted: widget.busy ? null : widget.onUnmute, deleteButtonTooltipMessage: 'Unmute user');
    });
}

class _RoomAvatar extends StatefulWidget {
  final String uid, name, imageUrl;
  const _RoomAvatar({super.key, required this.uid, required this.name,
    required this.imageUrl});
  @override
  State<_RoomAvatar> createState() => _RoomAvatarState();
}

class _RoomAvatarState extends State<_RoomAvatar> {
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _profile;
  @override
  void initState() { super.initState(); _subscribe(); }
  void _subscribe() {
    _profile = widget.uid.isEmpty ? null : FirebaseFirestore.instance
      .collection('users').doc(widget.uid).snapshots();
  }
  @override
  void didUpdateWidget(covariant _RoomAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) _subscribe();
  }
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _profile,
      builder: (context, snapshot) {
        final profile = snapshot.data?.data();
        String url = '';
        for (final value in [profile?['profileImageUrl'], profile?['photoURL'],
          profile?['photoUrl'], profile?['imageUrl'], widget.imageUrl]) {
          final candidate = (value ?? '').toString().trim();
          if (candidate.isNotEmpty) { url = candidate; break; }
        }
        final name = (profile?['fullName'] ?? profile?['name'] ?? widget.name)
          .toString().trim();
        final fallback = Center(child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase(),
          style: const TextStyle(color: Color(0xFF0B0B83), fontSize: 13,
            fontWeight: FontWeight.w700)));
        return Container(width: 32, height: 32,
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(color: Color(0xFFE8EAF8), shape: BoxShape.circle),
          child: url.isEmpty ? fallback : Image.network(url, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback));
      },
    );
  }
}
