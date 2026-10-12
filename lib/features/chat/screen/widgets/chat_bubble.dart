import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/models/message_model.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/features/chat/screen/widgets/message_moderation_dialog.dart';
import 'package:events_app_trueattempt/features/profile/screen/user_details_screen.dart';
import 'package:url_launcher/url_launcher.dart';
class ChatBubble extends ConsumerWidget {
  final Message message;
  final bool isMe;
  final List<String> sessionSpeakerIds;
  final bool isUserMuted;
  final VoidCallback? onMuteUser;
  final VoidCallback? onUnmuteUser;
  final VoidCallback? onDeleteMessage;
  final bool isSessionChat;
  const ChatBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.sessionSpeakerIds = const [],
    this.isUserMuted = false,
    this.onMuteUser,
    this.onUnmuteUser,
    this.onDeleteMessage,
    this.isSessionChat = true,
  });
  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return AppColors.adminColor;
      case 'speaker':
      case 'moderator':
        return AppColors.speakerColor;
      case 'staff':
        return AppColors.staffColor;
      case 'attendee':
      default:
        return AppColors.attendeeColor;
    }
  }
  Future<void> _openFile(BuildContext context) async {
    if (message.fileUrl.trim().isEmpty) {
      return;
    }
    final uri = Uri.tryParse(message.fileUrl);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid file link.'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }
    final canOpen = await canLaunchUrl(uri);
    if (!canOpen) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot open this file.'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }
    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }
  Future<void> _showDeleteFromEveryoneDialog(BuildContext context) async {
    if (onDeleteMessage == null) return;
    final shouldDelete = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_forever_rounded,
                    color: AppColors.errorRed,
                  ),
                  title: const Text(
                    'Delete from everyone',
                    style: TextStyle(
                      color: AppColors.errorRed,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text(
                    'This message will be removed for all users.',
                    style: TextStyle(fontSize: 12),
                  ),
                  onTap: () => Navigator.of(context).pop(true),
                ),
                ListTile(
                  leading: const Icon(Icons.close_rounded),
                  title: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (shouldDelete == true) {
      onDeleteMessage?.call();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message deleted from everyone'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }
  TextSpan _buildMessageTextSpan({
    required String text,
    required Color normalColor,
    required Color mentionColor,
  }) {
    final mentionRegex = RegExp(r'(@[A-Za-z0-9_. -]+)');
    final spans = <TextSpan>[];
    int currentIndex = 0;
    for (final match in mentionRegex.allMatches(text)) {
      if (match.start > currentIndex) {
        spans.add(
          TextSpan(
            text: text.substring(currentIndex, match.start),
            style: TextStyle(
              color: normalColor,
              fontSize: 14,
              height: 1.35,
            ),
          ),
        );
      }
      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: TextStyle(
            color: mentionColor,
            fontSize: 14,
            height: 1.35,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
      currentIndex = match.end;
    }
    if (currentIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(currentIndex),
          style: TextStyle(
            color: normalColor,
            fontSize: 14,
            height: 1.35,
          ),
        ),
      );
    }
    return TextSpan(children: spans);
  }
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(userAppProfileStreamProvider).asData?.value;
    final currentRole = currentUser?.role.toLowerCase().trim() ?? '';
    final bool isAdmin = currentRole == 'admin';
    final bool isStaff = currentRole == 'staff';
    final bool isSpeaker = sessionSpeakerIds.contains(currentUser?.uid);
    final bool canModerate =
        isSessionChat && (isAdmin || isStaff || isSpeaker) && !isMe;
    final bool canDeleteFromEveryone = isMe || canModerate || isAdmin || isStaff;
    String displayName = message.senderName;
    String displayImageUrl = message.senderImageUrl;
    if (!isSessionChat && !isMe && currentUser != null) {
      final senderProfile =
          ref.watch(userProfileByIdProvider(message.senderId)).asData?.value;
      if (senderProfile != null) {
        displayName = senderProfile.getDisplayNameFor(
          currentUser.uid,
          currentUser.role == 'admin',
        );
        displayImageUrl = senderProfile.getDisplayImageUrlFor(
          currentUser.uid,
          currentUser.role == 'admin',
        );
      }
    }
    return GestureDetector(
      onLongPress: () {
        if (canDeleteFromEveryone && onDeleteMessage != null) {
          _showDeleteFromEveryoneDialog(context);
          return;
        }
        if (canModerate) {
          MessageModerationDialog.show(
            context: context,
            message: message,
            isUserMuted: isUserMuted,
            onMute: () {
              onMuteUser?.call();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${message.senderName} has been muted'),
                  backgroundColor: AppColors.warningAmber,
                ),
              );
            },
            onUnmute: () {
              onUnmuteUser?.call();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${message.senderName} has been unmuted'),
                  backgroundColor: AppColors.successGreen,
                ),
              );
            },
            onDelete: () {
              onDeleteMessage?.call();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Message deleted'),
                  backgroundColor: AppColors.errorRed,
                ),
              );
            },
          );
        }
      },
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 4),
              child: GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => UserDetailsScreen(userId: message.senderId))),
                child: _ChatSenderAvatar(name: displayName, imageUrl: displayImageUrl),
              ),
            ),
            const SizedBox(width: 2),
          ],
          Flexible(
            child: Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 8,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .72),
                decoration: BoxDecoration(
                  color: isMe ? AppColors.navyBlue : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                  border: canModerate && isUserMuted
                      ? Border.all(
                          color: AppColors.warningAmber,
                          width: 2,
                        )
                      : null,
                ),
                child: Column(
                  crossAxisAlignment:
                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (!isMe)
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UserDetailsScreen(
                                userId: message.senderId,
                              ),
                            ),
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: _getRoleColor(message.senderRole),
                                    ),
                              ),
                            ),
                            if (canModerate && isUserMuted) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.volume_off,
                                size: 12,
                                color: AppColors.warningAmber,
                              ),
                            ],
                          ],
                        ),
                      ),
                    if (!isMe) const SizedBox(height: 6),
                    if (message.isImageMessage && message.fileUrl.isNotEmpty)
                      _buildImageMessage(context)
                    else if (message.isFileMessage && message.fileUrl.isNotEmpty)
                      _buildFileMessage(context),
                    if (message.text.trim().isNotEmpty) ...[
                      if (message.fileUrl.isNotEmpty) const SizedBox(height: 8),
                      RichText(
                        text: _buildMessageTextSpan(
                          text: message.text,
                          normalColor: isMe ? Colors.white : Colors.black87,
                          mentionColor: isMe
                              ? AppColors.namaGoldenYellow
                              : AppColors.namaNavyBlue,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildImageMessage(BuildContext context) {
    return InkWell(
      onTap: () => _openFile(context),
      borderRadius: BorderRadius.circular(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 230,
            maxHeight: 260,
          ),
          child: Image.network(
            message.fileUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                return child;
              }
              return Container(
                height: 170,
                width: 220,
                alignment: Alignment.center,
                color: Colors.black.withOpacity(0.06),
                child: const CircularProgressIndicator(strokeWidth: 2),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return _buildFileFallback(
                icon: Icons.broken_image_outlined,
                title: 'Image unavailable',
                subtitle: 'Tap to open',
                context: context,
              );
            },
          ),
        ),
      ),
    );
  }
  Widget _buildFileMessage(BuildContext context) {
    final bool isPdf = message.isPdfFile;
    return InkWell(
      onTap: () => _openFile(context),
      borderRadius: BorderRadius.circular(12),
      child: _buildFileFallback(
        icon: isPdf
            ? Icons.picture_as_pdf_rounded
            : Icons.insert_drive_file_rounded,
        title: message.fileName.isNotEmpty ? message.fileName : 'Shared file',
        subtitle: message.readableFileSize.isNotEmpty
            ? '${isPdf ? 'PDF' : 'File'} • ${message.readableFileSize}'
            : isPdf
                ? 'PDF document'
                : 'Tap to open',
        context: context,
      ),
    );
  }
  Widget _buildFileFallback({
    required IconData icon,
    required String title,
    required String subtitle,
    required BuildContext context,
  }) {
    final Color foregroundColor = isMe ? Colors.white : AppColors.namaNavyBlue;
    final Color backgroundColor =
        isMe ? Colors.white.withOpacity(0.14) : Colors.white;
    return Container(
      constraints: const BoxConstraints(maxWidth: 245),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe
              ? Colors.white.withOpacity(0.16)
              : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 30,
            color: foregroundColor,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isMe
                        ? Colors.white.withOpacity(0.78)
                        : Colors.black54,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatSenderAvatar extends StatelessWidget {
  final String name;
  final String imageUrl;
  const _ChatSenderAvatar({required this.name, required this.imageUrl});
  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    final fallback = Center(child: Text(initial,
      style: const TextStyle(color: AppColors.navyBlue, fontWeight: FontWeight.w700, fontSize: 13)));
    return Container(width: 32, height: 32, clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(shape: BoxShape.circle,
        color: AppColors.navyBlue.withOpacity(.08)),
      child: imageUrl.trim().isEmpty ? fallback : Image.network(imageUrl.trim(),
        fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback));
  }
}
