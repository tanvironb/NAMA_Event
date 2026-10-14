import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../session_monitoring_repository.dart' as monitoring;

class SessionChatTab extends StatefulWidget {
  final monitoring.SessionMonitoringRepository repository;
  final Map<String, dynamic> data;

  const SessionChatTab({
    super.key,
    required this.repository,
    required this.data,
  });

  @override
  State<SessionChatTab> createState() => _SessionChatTabState();
}

class _SessionChatTabState extends State<SessionChatTab> {
  static const Color _primary = Color(0xFF0B0B83);
  static const Color _ink = Color(0xFF101239);
  static const Color _muted = Color(0xFF687297);

  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  late Stream<QuerySnapshot<Map<String, dynamic>>> _messages;
  bool _sending = false;
  final Set<String> _selectedMessages = {};
  bool _deletingSelected = false;

  CollectionReference<Map<String, dynamic>> get _chat => widget.repository.db
      .collection('sessions')
      .doc(widget.repository.sessionId)
      .collection('chat');

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void didUpdateWidget(covariant SessionChatTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.repository != widget.repository) {
      _connect();
    }
  }

  void _connect() {
    _selectedMessages.clear();
    _messages = _chat.snapshots();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _showError(Object error) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Chat action failed: $error')));
  }

  Future<void> _send() async {
    final text = _input.text.trim();

    if (_sending || text.isEmpty || widget.data['isChatEnabled'] == false) {
      return;
    }

    if (widget.repository.messagesPath != _chat.path) {
      _showError(
        'Set messagesPath in session_monitoring_repository.dart '
        'to ${_chat.path}.',
      );
      return;
    }

    setState(() => _sending = true);

    try {
      await widget.repository.sendMessage(text);

      if (!mounted) return;

      if (_input.text.trim() == text) {
        _input.clear();
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scroll.hasClients) return;

        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      });
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _changeChat(bool enabled) async {
    try {
      await widget.repository.setChat(enabled);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _removeMessage(String id) async {
    try {
      await widget.repository.deleteMessage(id);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _deleteSelected(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> messages,
  ) async {
    if (_deletingSelected) return;
    final selected =
        messages.where((doc) => _selectedMessages.contains(doc.id)).toList();
    if (selected.isEmpty) return;
    final repository = widget.repository;
    setState(() => _deletingSelected = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('Delete selected messages?'),
              content: Text(
                'Permanently delete ${selected.length} selected messages from this session for everyone?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),
                  child: const Text('Delete'),
                ),
              ],
            ),
      );
      if (confirmed != true || !mounted || widget.repository != repository)
        return;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw StateError('Sign in to delete messages.');
      final profile =
          await repository.db.collection('users').doc(user.uid).get();
      if ((profile.data()?['role'] ?? '').toString().toLowerCase() != 'admin') {
        throw StateError('Administrator access is required.');
      }
      for (final doc in selected) {
        await repository.deleteMessage(doc.id);
        if (mounted && widget.repository == repository) {
          setState(() => _selectedMessages.remove(doc.id));
        }
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _deletingSelected = false);
    }
  }

  Widget _selectionToolbar(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> messages,
  ) {
    final ids = messages.map((doc) => doc.id).toSet();
    final count = ids.intersection(_selectedMessages).length;
    final allSelected = ids.isNotEmpty && count == ids.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('$count selected'),
          TextButton(
            onPressed:
                _deletingSelected
                    ? null
                    : () => setState(() {
                      if (allSelected) {
                        _selectedMessages.removeAll(ids);
                      } else {
                        _selectedMessages.addAll(ids);
                      }
                    }),
            child: Text(allSelected ? 'Deselect All' : 'Select All'),
          ),
          FilledButton.icon(
            onPressed:
                _deletingSelected || count == 0
                    ? null
                    : () => _deleteSelected(messages),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            icon: const Icon(Icons.delete_outline),
            label: Text(_deletingSelected ? 'Deleting…' : 'Delete Selected'),
          ),
        ],
      ),
    );
  }

  Future<void> _setMuted(String uid, bool muted) async {
    try {
      await widget.repository.mute(uid, muted);
    } catch (error) {
      _showError(error);
    }
  }

  Widget _header(bool enabled) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.forum_rounded, color: _primary, size: 20),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Live Session Chat',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 7,
                      color: enabled ? const Color(0xFF00AA66) : _muted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      enabled ? 'Chat enabled' : 'Chat disabled',
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Switch(value: enabled, activeColor: _primary, onChanged: _changeChat),
        ],
      ),
    );
  }

  Widget _avatar(String name, String imageUrl) {
    final initial =
        name.trim().isEmpty
            ? '?'
            : String.fromCharCode(name.trim().runes.first).toUpperCase();

    final fallback = Center(
      child: Text(
        initial,
        style: const TextStyle(
          color: _primary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    return Container(
      width: 30,
      height: 30,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: Color(0xFFE7EAF7),
        shape: BoxShape.circle,
      ),
      child:
          imageUrl.isEmpty
              ? fallback
              : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              ),
    );
  }

  Widget _attachment(Map<String, dynamic> message, bool isMe) {
    final url = (message['fileUrl'] ?? '').toString().trim();
    final fileName = (message['fileName'] ?? 'Attachment').toString();

    if (message['messageType'] == 'image') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          url,
          height: 180,
          fit: BoxFit.contain,
          errorBuilder:
              (_, __, ___) => Text(
                'Image unavailable',
                style: TextStyle(
                  color: isMe ? Colors.white70 : _muted,
                  fontSize: 12,
                ),
              ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withOpacity(0.12) : const Color(0xFFF1F3F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.insert_drive_file_outlined,
                size: 23,
                color: isMe ? Colors.white : _primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isMe ? Colors.white : _ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          SelectableText(
            url,
            style: TextStyle(
              color: isMe ? Colors.white70 : _primary,
              fontSize: 10,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _message(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
    double availableWidth,
  ) {
    final message = document.data();
    final uid = (message['senderId'] ?? '').toString();
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    final isMe = currentUid != null && uid == currentUid;
    final deleted = message['deletedForEveryone'] == true;
    final name = monitoring.monitorName(message);
    final role = (message['senderRole'] ?? 'attendee').toString();
    final text = (message['text'] ?? '').toString();
    final imageUrl = (message['senderImageUrl'] ?? '').toString().trim();
    final fileUrl = (message['fileUrl'] ?? '').toString().trim();

    final mutedUsers = widget.data['mutedUsers'];
    final muted = mutedUsers is List && mutedUsers.contains(uid);

    final bubbleWidth =
        availableWidth < 600
            ? availableWidth * 0.78
            : availableWidth * 0.65 < 520
            ? availableWidth * 0.65
            : 520.0;

    final foreground = isMe ? Colors.white : _ink;
    final secondary = isMe ? Colors.white70 : _muted;

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: bubbleWidth),
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(
        color: isMe ? _primary : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(15),
          topRight: const Radius.circular(15),
          bottomLeft: Radius.circular(isMe ? 15 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 15),
        ),
        border: isMe ? null : Border.all(color: const Color(0xFFE7EAF2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  isMe ? 'You' : name,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                enabled: !_deletingSelected,
                tooltip: 'Message actions',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(Icons.more_horiz, color: secondary, size: 18),
                onSelected: (action) {
                  if (action == 'delete') {
                    _removeMessage(document.id);
                  } else if (action == 'mute') {
                    _setMuted(uid, !muted);
                  }
                },
                itemBuilder:
                    (_) => [
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Text('Remove message'),
                      ),
                      if (!isMe && uid.isNotEmpty)
                        PopupMenuItem<String>(
                          value: 'mute',
                          child: Text(muted ? 'Unmute user' : 'Mute user'),
                        ),
                    ],
              ),
            ],
          ),
          Text(
            '$role${muted ? ' • Muted' : ''}',
            style: TextStyle(color: secondary, fontSize: 10),
          ),
          const SizedBox(height: 7),
          if (deleted)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.block, size: 13, color: secondary),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'Message removed',
                    style: TextStyle(
                      color: secondary,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            )
          else ...[
            if (text.isNotEmpty)
              SelectableText(
                text,
                style: TextStyle(color: foreground, fontSize: 13, height: 1.45),
              ),
            if (fileUrl.isNotEmpty) ...[
              if (text.isNotEmpty) const SizedBox(height: 8),
              _attachment(message, isMe),
            ],
          ],
          const SizedBox(height: 7),
          Text(
            monitoring.monitorTime(message['timestamp']),
            style: TextStyle(color: secondary, fontSize: 9),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Checkbox(
            value: _selectedMessages.contains(document.id),
            onChanged:
                _deletingSelected
                    ? null
                    : (selected) => setState(() {
                      if (selected == true) {
                        _selectedMessages.add(document.id);
                      } else {
                        _selectedMessages.remove(document.id);
                      }
                    }),
          ),
          if (!isMe) ...[_avatar(name, imageUrl), const SizedBox(width: 8)],
          Flexible(child: bubble),
        ],
      ),
    );
  }

  Widget _messageList() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 600;
        final padding = mobile ? 12.0 : 20.0;

        return SizedBox(
          height: mobile ? 360 : 420,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _messages,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                final error = snapshot.error;
                final details =
                    error is FirebaseException
                        ? '${error.code}: ${error.message ?? ''}'
                        : error.toString();

                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: SelectableText(
                      'Unable to load chat.\n$details',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: _primary,
                    strokeWidth: 2,
                  ),
                );
              }

              final documents = snapshot.data!.docs.toList();

              // Newest first; reverse:true places newest at the bottom.
              documents.sort((a, b) {
                final first = monitoring.monitorDate(a.data()['timestamp']);
                final second = monitoring.monitorDate(b.data()['timestamp']);

                if (first == null && second == null) {
                  return b.id.compareTo(a.id);
                }
                if (first == null) return -1;
                if (second == null) return 1;

                final comparison = second.compareTo(first);

                return comparison == 0 ? b.id.compareTo(a.id) : comparison;
              });

              if (documents.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 38,
                        color: _primary.withOpacity(0.35),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Start the conversation',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Session messages will appear here.',
                        style: TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  _selectionToolbar(documents),
                  Expanded(
                    child: Scrollbar(
                      controller: _scroll,
                      child: ListView.builder(
                        controller: _scroll,
                        primary: false,
                        reverse: true,
                        padding: EdgeInsets.all(padding),
                        itemCount: documents.length,
                        itemBuilder:
                            (_, index) => _message(
                              documents[index],
                              constraints.maxWidth - padding * 2,
                            ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _composer(bool enabled) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE9ECF3))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              enabled: enabled && !_sending,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              style: const TextStyle(color: _ink, fontSize: 13),
              decoration: InputDecoration(
                hintText:
                    enabled ? 'Type a message…' : 'Session chat is disabled',
                hintStyle: const TextStyle(color: _muted, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFFF3F5FA),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 17,
                  vertical: 13,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: _primary.withOpacity(0.3)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton.filled(
              tooltip: 'Send message',
              style: IconButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                shape: const CircleBorder(),
              ),
              onPressed: enabled && !_sending ? _send : null,
              icon:
                  _sending
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                      : const Icon(Icons.send_rounded, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.data['isChatEnabled'] != false;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EBF3)),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.035),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(enabled),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE9ECF3)),
          Container(color: const Color(0xFFF5F7FB), child: _messageList()),
          _composer(enabled),
        ],
      ),
    );
  }
}
