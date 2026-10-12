import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/core/models/app_user.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
class MessageComposer extends ConsumerStatefulWidget {
  final Session session;
  final AppUser currentUser;
  const MessageComposer({
    super.key,
    required this.session,
    required this.currentUser,
  });
  @override
  ConsumerState<MessageComposer> createState() => _MessageComposerState();
}
class _MessageComposerState extends ConsumerState<MessageComposer> {
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
  bool get _isAdmin {
    return widget.currentUser.role.toLowerCase().trim() == 'admin';
  }
  bool get _isStaff {
    return widget.currentUser.role.toLowerCase().trim() == 'staff';
  }
  bool get _isAssignedSpeaker {
    return widget.session.speakerIds.contains(widget.currentUser.uid);
  }
  bool get _isAssignedModerator {
    return widget.session.moderatorIds.contains(widget.currentUser.uid);
  }
  bool get _isAssignedSpeakerOrModerator {
    return _isAssignedSpeaker || _isAssignedModerator;
  }
  bool get _canOverrideClosedChat {
    return _isAdmin || _isStaff || _isAssignedSpeakerOrModerator;
  }
  bool get _canShareMaterials {
    return _isAdmin || _isStaff || _isAssignedSpeakerOrModerator;
  }
  bool get _isMuted {
    return widget.session.isUserMuted(widget.currentUser.uid);
  }
  bool get _hasSelectedFile {
    return _selectedFileBytes != null && _selectedFileName.isNotEmpty;
  }
  bool get _sessionEndedForUser {
    return widget.session.hasEnded &&
        !_isAdmin &&
        !_isStaff &&
        !(_isAssignedSpeakerOrModerator && widget.session.isWithinGracePeriod);
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
  Future<List<_MentionUser>> _loadMentionUsers() async {
    final ids = <String>{
      ...widget.session.speakerIds,
      ...widget.session.moderatorIds,
    };
    final users = <_MentionUser>[];
    for (final uid in ids) {
      if (uid.trim().isEmpty) continue;
      DocumentSnapshot<Map<String, dynamic>> userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      Map<String, dynamic>? data = userDoc.data();
      if (data == null) {
        final speakerDoc =
            await FirebaseFirestore.instance.collection('speakers').doc(uid).get();
        data = speakerDoc.data();
      }
      if (data == null) continue;
      final role = widget.session.moderatorIds.contains(uid)
          ? 'moderator'
          : widget.session.speakerIds.contains(uid)
              ? 'speaker'
              : _normalizeRole(
                  (data['role'] ??
                          data['userRole'] ??
                          data['userType'] ??
                          data['type'] ??
                          '')
                      .toString(),
                );
      final name = (data['name'] ??
              data['fullName'] ??
              data['displayName'] ??
              data['firstName'] ??
              'User')
          .toString()
          .trim();
      if (name.isEmpty) continue;
      users.add(
        _MentionUser(
          uid: uid,
          name: name,
          role: role,
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
  bool _canSendNow({required bool showMessage}) {
    if (_isMuted) {
      if (showMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have been muted'),
            backgroundColor: AppColors.warningAmber,
          ),
        );
      }
      return false;
    }
    if (widget.session.hasEnded) {
      if (_isAdmin || _isStaff) {
        return true;
      }
      if (_isAssignedSpeakerOrModerator && widget.session.isWithinGracePeriod) {
        return true;
      }
      if (showMessage) {
        final gracePeriodEnd =
            widget.session.endTime.add(const Duration(minutes: 35));
        final minutesRemaining =
            gracePeriodEnd.difference(DateTime.now()).inMinutes;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isAssignedSpeakerOrModerator && minutesRemaining <= 0
                  ? 'Speaker/moderator grace period has expired'
                  : 'Session has ended',
            ),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
      return false;
    }
    if (!widget.session.isChatEnabled && !_canOverrideClosedChat) {
      if (showMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chat has been closed for this session'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
      return false;
    }
    return true;
  }
  Future<void> _pickMaterial() async {
    if (!_canShareMaterials) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Only assigned speakers or moderators can share materials.',
          ),
          backgroundColor: AppColors.warningAmber,
        ),
      );
      return;
    }
    if (!_canSendNow(showMessage: true)) {
      return;
    }
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
  Future<void> _sendMessage() async {
    final String text = _controller.text.trim();
    if (text.isEmpty && !_hasSelectedFile) {
      return;
    }
    if (!_canSendNow(showMessage: true)) {
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
        final String timestamp =
            DateTime.now().millisecondsSinceEpoch.toString();
        final String storagePath =
            'sessions/${widget.session.id}/materials/${widget.currentUser.uid}_${timestamp}_$safeFileName';
        final Reference storageRef =
            FirebaseStorage.instance.ref().child(storagePath);
        final UploadTask uploadTask = storageRef.putData(
          _selectedFileBytes!,
          SettableMetadata(
            contentType: contentType,
            customMetadata: {
              'sessionId': widget.session.id,
              'uploadedBy': widget.currentUser.uid,
              'uploadedByName': widget.currentUser.name,
              'uploadedByRole': widget.currentUser.role,
              'fileType': fileType,
            },
          ),
        );
        final TaskSnapshot uploadSnapshot = await uploadTask;
        final String downloadUrl = await uploadSnapshot.ref.getDownloadURL();
        await chatRepo.sendMaterialMessage(
          sessionId: widget.session.id,
          senderId: widget.currentUser.uid,
          senderName: widget.currentUser.name,
          senderImageUrl: widget.currentUser.profileImageUrl,
          senderRole: widget.currentUser.role,
          fileUrl: downloadUrl,
          fileName: _selectedFileName,
          fileType: fileType,
          fileSize: _selectedFileSize,
          caption: text,
          mentionedUserIds: mentionedUserIds,
          mentionedUserNames: mentionedUserNames,
        );
      } else {
        await chatRepo.sendMessage(
          sessionId: widget.session.id,
          text: text,
          senderId: widget.currentUser.uid,
          senderName: widget.currentUser.name,
          senderImageUrl: widget.currentUser.profileImageUrl,
          senderRole: widget.currentUser.role,
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
  @override
  Widget build(BuildContext context) {
    final bool showModeratorOverrideBanner =
        !_sessionEndedForUser &&
            !widget.session.isChatEnabled &&
            _canOverrideClosedChat &&
            !_isMuted;
    final bool showGracePeriodBanner =
        widget.session.hasEnded &&
            _isAssignedSpeakerOrModerator &&
            widget.session.isWithinGracePeriod &&
            !_isMuted;
    if (_isMuted) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.lightGray),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.volume_off,
              color: AppColors.warningAmber,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'You have been muted',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.warningAmber,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      );
    }
    if (_sessionEndedForUser) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.lightGray),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.event_busy,
              color: AppColors.errorRed,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Session has ended',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.errorRed,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      );
    }
    if (!widget.session.isChatEnabled && !_canOverrideClosedChat) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.lightGray),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock,
              color: AppColors.errorRed,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Chat has been closed',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.errorRed,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      );
    }
    return FutureBuilder<List<_MentionUser>>(
      future: _loadMentionUsers(),
      builder: (context, snapshot) {
        final allMentionUsers = snapshot.data ?? [];
        final filteredUsers = allMentionUsers.where((user) {
          if (_mentionSearchText.isEmpty) {
            return true;
          }
          return user.name.toLowerCase().contains(_mentionSearchText) ||
              user.role.toLowerCase().contains(_mentionSearchText);
        }).toList();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showGracePeriodBanner)
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.infoBlue.withOpacity(0.1),
                  border: Border(
                    top: BorderSide(
                      color: AppColors.infoBlue.withOpacity(0.3),
                    ),
                    bottom: BorderSide(
                      color: AppColors.infoBlue.withOpacity(0.3),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.access_time,
                      color: AppColors.infoBlue,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Builder(
                        builder: (context) {
                          final gracePeriodEnd = widget.session.endTime.add(
                            const Duration(minutes: 35),
                          );
                          final minutesLeft =
                              gracePeriodEnd.difference(DateTime.now()).inMinutes +
                                  1;
                          return Text(
                            'Session ended - Grace period: $minutesLeft min remaining',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.infoBlue,
                                  fontWeight: FontWeight.w500,
                                ),
                            textAlign: TextAlign.center,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            if (showModeratorOverrideBanner)
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warningAmber.withOpacity(0.1),
                  border: Border(
                    top: BorderSide(
                      color: AppColors.warningAmber.withOpacity(0.3),
                    ),
                    bottom: BorderSide(
                      color: AppColors.warningAmber.withOpacity(0.3),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.lock_open,
                      color: AppColors.warningAmber,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Chat closed by ${widget.session.closedBy} (you can still send as ${_isAdmin ? 'admin' : _isStaff ? 'staff' : _isAssignedModerator ? 'moderator' : 'speaker'})',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.warningAmber,
                              fontWeight: FontWeight.w500,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            Container(
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
                        isLoading:
                            snapshot.connectionState == ConnectionState.waiting,
                        onUserSelected: _insertMention,
                      ),
                    if (_hasSelectedFile) _buildSelectedFilePreview(),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (_canShareMaterials)
                            IconButton(
                              tooltip: 'Select material',
                              onPressed: _isSending ? null : _pickMaterial,
                              icon: const Icon(
                                Icons.attach_file_rounded,
                                color: AppColors.navyBlue,
                              ),
                            ),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              minLines: 1,
                              maxLines: 4,
                              decoration: InputDecoration(
                                hintText: _hasSelectedFile
                                    ? 'Add a caption...'
                                    : 'Type a message...',
                                filled: true,
                                fillColor: AppColors.navyBlue.withOpacity(.045),
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(26),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(26),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(26),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              ),
                              textCapitalization: TextCapitalization.sentences,
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            tooltip: 'Send message',
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.navyBlue,
                              disabledBackgroundColor: AppColors.navyBlue.withOpacity(.5),
                              foregroundColor: Colors.white,
                            ),
                            icon: _isSending
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.send_rounded,
                                    color: Colors.white,
                                  ),
                            onPressed: _isSending ? null : _sendMessage,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
