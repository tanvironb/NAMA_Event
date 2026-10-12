import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/models/app_user.dart';
import 'package:events_app_trueattempt/core/models/message_model.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/features/chat/screen/widgets/chat_bubble.dart';
import 'package:events_app_trueattempt/common_widgets/chat_input_bar.dart';
class SpeakerModeratorRoomScreen extends ConsumerStatefulWidget {
  const SpeakerModeratorRoomScreen({super.key});
  @override
  ConsumerState<SpeakerModeratorRoomScreen> createState() =>
      _SpeakerModeratorRoomScreenState();
}
class _SpeakerModeratorRoomScreenState
    extends ConsumerState<SpeakerModeratorRoomScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isSending = false;
  bool _showMentionBox = false;
  String _mentionSearchText = '';
  Uint8List? _selectedFileBytes;
  String _selectedFileName = '';
  String _selectedFileExtension = '';
  int _selectedFileSize = 0;
  final Map<String, _MentionUser> _selectedMentionUsers = {};
  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChange);
  }
  @override
  void dispose() {
    _controller.removeListener(_handleTextChange);
    _controller.dispose();
    super.dispose();
  }
  bool _canAccessRoom(AppUser user) {
    final role = user.role.toLowerCase().trim();
    return role == 'speaker' ||
        role == 'moderator' ||
        role == 'admin' ||
        role == 'staff';
  }
  bool get _hasSelectedFile {
    return _selectedFileBytes != null && _selectedFileName.isNotEmpty;
  }
  void _handleTextChange() {
    final text = _controller.text;
    final selection = _controller.selection;
    if (!selection.isValid) {
      _hideMentionBox();
      return;
    }
    final cursorPosition = selection.baseOffset;
    if (cursorPosition < 0 || cursorPosition > text.length) {
      _hideMentionBox();
      return;
    }
    final textBeforeCursor = text.substring(0, cursorPosition);
    final lastAtIndex = textBeforeCursor.lastIndexOf('@');
    if (lastAtIndex == -1) {
      _hideMentionBox();
      return;
    }
    final afterAt = textBeforeCursor.substring(lastAtIndex + 1);
    if (afterAt.contains('\n')) {
      _hideMentionBox();
      return;
    }
    final hasSpaceBeforeAt = lastAtIndex == 0 ||
        textBeforeCursor.substring(lastAtIndex - 1, lastAtIndex).trim().isEmpty;
    if (!hasSpaceBeforeAt) {
      _hideMentionBox();
      return;
    }
    if (afterAt.contains('  ')) {
      _hideMentionBox();
      return;
    }
    setState(() {
      _showMentionBox = true;
      _mentionSearchText = afterAt.trim().toLowerCase();
    });
  }
  void _hideMentionBox() {
    if (!_showMentionBox && _mentionSearchText.isEmpty) return;
    setState(() {
      _showMentionBox = false;
      _mentionSearchText = '';
    });
  }
  Future<List<_MentionUser>> _loadMentionUsers(String eventId) async {
    final snapshot = await FirebaseFirestore.instance.collection('users').get();
    final users = <_MentionUser>[];
    final seenIds = <String>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final role = (data['role'] ??
              data['userRole'] ??
              data['userType'] ??
              data['type'] ??
              '')
          .toString()
          .trim()
          .toLowerCase();
      final normalizedRole = _normalizeRole(role);
      if (normalizedRole != 'speaker' && normalizedRole != 'moderator') {
        continue;
      }
      final rawEventIds = data['eventIds'];
      final currentEventId = (data['currentEventId'] ?? '').toString().trim();
      final activeEventId = (data['activeEventId'] ?? '').toString().trim();
      bool belongsToEvent = false;
      if (currentEventId == eventId || activeEventId == eventId) {
        belongsToEvent = true;
      }
      if (rawEventIds is List && rawEventIds.map((e) => e.toString()).contains(eventId)) {
        belongsToEvent = true;
      }
      if (!belongsToEvent) {
        continue;
      }
      final name = (data['name'] ??
              data['fullName'] ??
              data['displayName'] ??
              data['firstName'] ??
              'User')
          .toString()
          .trim();
      if (name.isEmpty) {
        continue;
      }
      if (seenIds.contains(doc.id)) {
        continue;
      }
      seenIds.add(doc.id);
      users.add(
        _MentionUser(
          uid: doc.id,
          name: name,
          role: normalizedRole,
          imageUrl: (data['profileImageUrl'] ?? data['photoUrl'] ?? '')
              .toString()
              .trim(),
        ),
      );
    }
    users.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return users;
  }
  String _normalizeRole(String role) {
    final cleanRole = role.trim().toLowerCase();
    if (cleanRole == 'speaker_user' ||
        cleanRole == 'speaker user' ||
        cleanRole == 'speaker-user') {
      return 'speaker';
    }
    if (cleanRole == 'moderator_user' ||
        cleanRole == 'moderator user' ||
        cleanRole == 'moderator-user' ||
        cleanRole == 'mod') {
      return 'moderator';
    }
    return cleanRole;
  }
  void _insertMention(_MentionUser mentionUser) {
    final text = _controller.text;
    final selection = _controller.selection;
    if (!selection.isValid) {
      return;
    }
    final cursorPosition = selection.baseOffset;
    final textBeforeCursor = text.substring(0, cursorPosition);
    final textAfterCursor = text.substring(cursorPosition);
    final lastAtIndex = textBeforeCursor.lastIndexOf('@');
    if (lastAtIndex == -1) {
      return;
    }
    final mentionText = '@${mentionUser.name} ';
    final newText = text.substring(0, lastAtIndex) + mentionText + textAfterCursor;
    final newCursorPosition = lastAtIndex + mentionText.length;
    _selectedMentionUsers[mentionUser.uid] = mentionUser;
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPosition),
    );
    setState(() {
      _showMentionBox = false;
      _mentionSearchText = '';
    });
  }
  List<String> _getMentionedUserIds() {
    final text = _controller.text;
    return _selectedMentionUsers.entries
        .where((entry) => text.contains('@${entry.value.name}'))
        .map((entry) => entry.key)
        .toList();
  }
  List<String> _getMentionedUserNames() {
    final text = _controller.text;
    return _selectedMentionUsers.values
        .where((user) => text.contains('@${user.name}'))
        .map((user) => user.name)
        .toList();
  }
  Future<void> _pickMaterial() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'png',
          'jpg',
          'jpeg',
          'webp',
        ],
      );
      if (result == null || result.files.isEmpty) {
        return;
      }
      final PlatformFile pickedFile = result.files.single;
      final Uint8List? fileBytes = pickedFile.bytes;
      if (fileBytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to read selected file. Please try again.'),
            backgroundColor: AppColors.errorRed,
          ),
        );
        return;
      }
      const int maxFileSizeBytes = 15 * 1024 * 1024;
      if (pickedFile.size > maxFileSizeBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File is too large. Maximum allowed size is 15 MB.'),
            backgroundColor: AppColors.warningAmber,
          ),
        );
        return;
      }
      setState(() {
        _selectedFileBytes = fileBytes;
        _selectedFileName = pickedFile.name;
        _selectedFileExtension = _getFileExtension(pickedFile.name);
        _selectedFileSize = pickedFile.size;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to select material: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }
  Future<void> _sendRoomMessage({
    required String eventId,
    required AppUser currentUser,
  }) async {
    final text = _controller.text.trim();
    if (text.isEmpty && !_hasSelectedFile) {
      return;
    }
    setState(() {
      _isSending = true;
      _showMentionBox = false;
    });
    final chatRepo = ref.read(chatRepositoryProvider);
    final mentionedUserIds = _getMentionedUserIds();
    final mentionedUserNames = _getMentionedUserNames();
    try {
      if (_hasSelectedFile) {
        final String fileType = _getMaterialType(_selectedFileExtension);
        final String contentType = _getContentType(_selectedFileExtension);
        final String safeFileName = _cleanFileName(_selectedFileName);
        final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        final String storagePath =
            'speaker_moderator_rooms/$eventId/materials/${currentUser.uid}_${timestamp}_$safeFileName';
        final Reference storageRef =
            FirebaseStorage.instance.ref().child(storagePath);
        final UploadTask uploadTask = storageRef.putData(
          _selectedFileBytes!,
          SettableMetadata(
            contentType: contentType,
            customMetadata: {
              'eventId': eventId,
              'uploadedBy': currentUser.uid,
              'uploadedByName': currentUser.name,
              'uploadedByRole': currentUser.role,
              'fileType': fileType,
            },
          ),
        );
        final TaskSnapshot uploadSnapshot = await uploadTask;
        final String downloadUrl = await uploadSnapshot.ref.getDownloadURL();
        await chatRepo.sendSpeakerModeratorRoomMaterialMessage(
          eventId: eventId,
          senderId: currentUser.uid,
          senderName: currentUser.name,
          senderImageUrl: currentUser.profileImageUrl,
          senderRole: currentUser.role,
          fileUrl: downloadUrl,
          fileName: _selectedFileName,
          fileType: fileType,
          fileSize: _selectedFileSize,
          caption: text,
          mentionedUserIds: mentionedUserIds,
          mentionedUserNames: mentionedUserNames,
        );
      } else {
        await chatRepo.sendSpeakerModeratorRoomMessage(
          eventId: eventId,
          text: text,
          senderId: currentUser.uid,
          senderName: currentUser.name,
          senderImageUrl: currentUser.profileImageUrl,
          senderRole: currentUser.role,
          mentionedUserIds: mentionedUserIds,
          mentionedUserNames: mentionedUserNames,
        );
      }
      _controller.clear();
      _selectedMentionUsers.clear();
      _clearSelectedFile();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }
  void _clearSelectedFile() {
    setState(() {
      _selectedFileBytes = null;
      _selectedFileName = '';
      _selectedFileExtension = '';
      _selectedFileSize = 0;
    });
  }
  String _getFileExtension(String fileName) {
    final parts = fileName.split('.');
    if (parts.length < 2) {
      return '';
    }
    return parts.last.toLowerCase().trim();
  }
  String _getMaterialType(String extension) {
    if (extension == 'png' ||
        extension == 'jpg' ||
        extension == 'jpeg' ||
        extension == 'webp') {
      return 'image';
    }
    if (extension == 'pdf') {
      return 'pdf';
    }
    return 'file';
  }
  String _getContentType(String extension) {
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }
  String _cleanFileName(String fileName) {
    final cleanName = fileName
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    if (cleanName.trim().isEmpty) {
      return 'material_file';
    }
    return cleanName;
  }
  String _readableFileSize(int fileSize) {
    if (fileSize <= 0) {
      return '';
    }
    if (fileSize < 1024) {
      return '$fileSize B';
    }
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  bool _isSelectedFileImage() {
    return _selectedFileExtension == 'png' ||
        _selectedFileExtension == 'jpg' ||
        _selectedFileExtension == 'jpeg' ||
        _selectedFileExtension == 'webp';
  }
  bool _canDeleteMessage({
    required AppUser currentUser,
    required Message message,
  }) {
    final role = currentUser.role.toLowerCase().trim();
    return message.senderId == currentUser.uid ||
        role == 'admin' ||
        role == 'staff';
  }
  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(activeEventFutureProvider);
    final currentUserAsync = ref.watch(userAppProfileStreamProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      body: currentUserAsync.when(
        data: (currentUser) {
          if (currentUser == null) {
            return _buildInfoScreen(
              icon: Icons.lock_outline,
              title: 'Login Required',
              message: 'You must be logged in to access this room.',
            );
          }
          if (!_canAccessRoom(currentUser)) {
            return _buildInfoScreen(
              icon: Icons.lock_outline,
              title: 'Access Denied',
              message: 'This room is only for speakers and moderators.',
            );
          }
          return eventAsync.when(
            data: (event) {
              final messagesAsync = ref.watch(
                speakerModeratorRoomMessagesStreamProvider(event.id),
              );
              return Column(
                children: [
                  _RoomHeader(eventName: event.name),
                  Expanded(
                    child: messagesAsync.when(
                      data: (messages) {
                        if (messages.isEmpty) {
                          return const _EmptyRoomState();
                        }
                        return ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 6,
                          ),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final Message message = messages[index];
                            final bool isMe = message.senderId == currentUser.uid;
                            return ChatBubble(
                              message: message,
                              isMe: isMe,
                              sessionSpeakerIds: const [],
                              isSessionChat: false,
                              onDeleteMessage: _canDeleteMessage(
                                currentUser: currentUser,
                                message: message,
                              )
                                  ? () async {
                                      await ref
                                          .read(chatRepositoryProvider)
                                          .deleteSpeakerModeratorRoomMessage(
                                            eventId: event.id,
                                            messageId: message.id,
                                          );
                                    }
                                  : null,
                            );
                          },
                        );
                      },
                      loading: () => const LoadingIndicator(),
                      error: (error, stackTrace) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Failed to load room messages: $error',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  _buildComposer(
                    eventId: event.id,
                    currentUser: currentUser,
                  ),
                ],
              );
            },
            loading: () => const LoadingIndicator(),
            error: (error, stackTrace) {
              return _buildInfoScreen(
                icon: Icons.error_outline,
                title: 'Unable to Load Event',
                message: error.toString(),
              );
            },
          );
        },
        loading: () => const LoadingIndicator(),
        error: (error, stackTrace) {
          return _buildInfoScreen(
            icon: Icons.error_outline,
            title: 'Unable to Load Profile',
            message: error.toString(),
          );
        },
      ),
    );
  }
  Widget _buildComposer({
    required String eventId,
    required AppUser currentUser,
  }) {
    return FutureBuilder<List<_MentionUser>>(
      future: _loadMentionUsers(eventId),
      builder: (context, snapshot) {
        final allMentionUsers = snapshot.data ?? [];
        final filteredUsers = allMentionUsers.where((user) {
          if (_mentionSearchText.isEmpty) {
            return true;
          }
          return user.name.toLowerCase().contains(_mentionSearchText) ||
              user.role.toLowerCase().contains(_mentionSearchText);
        }).toList();
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(
              top: BorderSide(color: AppColors.lightGray),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_showMentionBox)
                  _MentionSuggestionBox(
                    users: filteredUsers,
                    isLoading: snapshot.connectionState == ConnectionState.waiting,
                    onUserSelected: _insertMention,
                  ),
                if (_hasSelectedFile) _buildSelectedFilePreview(),
                ChatInputBar(
                  controller: _controller,
                  isSending: _isSending,
                  hintText: _hasSelectedFile
                      ? 'Add a caption...'
                      : 'Type a message...',
                  onAttach: _pickMaterial,
                  onSend: () => _sendRoomMessage(
                    eventId: eventId,
                    currentUser: currentUser,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  Widget _buildSelectedFilePreview() {
    final bool isImage = _isSelectedFileImage();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 2),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.lightGray.withOpacity(0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.navyBlue.withOpacity(0.12),
        ),
      ),
      child: Row(
        children: [
          if (isImage && _selectedFileBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                _selectedFileBytes!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.navyBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _selectedFileExtension == 'pdf'
                    ? Icons.picture_as_pdf_rounded
                    : Icons.insert_drive_file_rounded,
                color: AppColors.navyBlue,
                size: 28,
              ),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedFileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.navyBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_selectedFileExtension.toUpperCase()} • ${_readableFileSize(_selectedFileSize)}',
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.55),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove selected file',
            onPressed: _isSending ? null : _clearSelectedFile,
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildInfoScreen({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Column(
      children: [
        const _RoomHeader(eventName: 'Speaker & Moderator Room'),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 44, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.navyBlue,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
class _MentionUser {
  final String uid;
  final String name;
  final String role;
  final String imageUrl;
  const _MentionUser({
    required this.uid,
    required this.name,
    required this.role,
    required this.imageUrl,
  });
}
class _MentionSuggestionBox extends StatelessWidget {
  final List<_MentionUser> users;
  final bool isLoading;
  final ValueChanged<_MentionUser> onUserSelected;
  const _MentionSuggestionBox({
    required this.users,
    required this.isLoading,
    required this.onUserSelected,
  });
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        height: 74,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (users.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        alignment: Alignment.centerLeft,
        child: const Text(
          'No speakers or moderators found',
          style: TextStyle(
            color: Colors.black54,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }
    return Container(
      constraints: const BoxConstraints(maxHeight: 210),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.black.withOpacity(0.06)),
          bottom: BorderSide(color: Colors.black.withOpacity(0.06)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: users.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: Colors.black.withOpacity(0.05),
        ),
        itemBuilder: (context, index) {
          final user = users[index];
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 17,
              backgroundColor: AppColors.namaNavyBlue.withOpacity(0.10),
              backgroundImage:
                  user.imageUrl.isNotEmpty ? NetworkImage(user.imageUrl) : null,
              child: user.imageUrl.isEmpty
                  ? Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: AppColors.namaNavyBlue,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  : null,
            ),
            title: Text(
              user.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.namaNavyBlue,
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
            subtitle: Text(
              user.role == 'moderator' ? 'Moderator' : 'Speaker',
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 11.5,
              ),
            ),
            trailing: const Text(
              '@',
              style: TextStyle(
                color: AppColors.namaGoldenYellow,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            onTap: () => onUserSelected(user),
          );
        },
      ),
    );
  }
}
class _RoomHeader extends StatelessWidget {
  final String eventName;
  const _RoomHeader({
    required this.eventName,
  });
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Color(0xFFE5E7EB)),
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.arrow_back,
                color: AppColors.navyBlue,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.groups_2_outlined,
              color: AppColors.navyBlue,
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Speaker & Moderator Room',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.navyBlue,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    eventName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
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
}
class _EmptyRoomState extends StatelessWidget {
  const _EmptyRoomState();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.forum_outlined,
              color: Colors.grey,
              size: 42,
            ),
            SizedBox(height: 12),
            Text(
              'No messages yet',
              style: TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Speakers and moderators can discuss here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black38,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
