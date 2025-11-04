// lib/features/messaging/screen/direct_message_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/features/chat/screen/widgets/chat_bubble.dart';
import 'package:events_app_trueattempt/features/messaging/screen/widgets/direct_message_composer.dart';
import 'package:events_app_trueattempt/core/models/message_model.dart';
import 'package:events_app_trueattempt/utils/date_time_utils.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';

class DirectMessageScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUserName;
  final String otherUserProfileImage;

  const DirectMessageScreen({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserProfileImage = '',
  });

  @override
  ConsumerState<DirectMessageScreen> createState() => _DirectMessageScreenState();
}

class _DirectMessageScreenState extends ConsumerState<DirectMessageScreen> {
  bool _showUnreadSection = false;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndMarkMessagesAsRead();
    });
  }

  Future<void> _checkAndMarkMessagesAsRead() async {
    if (!mounted) return;
    final currentUser = ref.read(firebaseAuthProvider).currentUser;
    if (currentUser == null) return;

    try {
      // Get current messages to check unread count
      final messagesAsync = ref.read(directMessagesStreamProvider(widget.conversationId));
      messagesAsync.whenData((messages) {
        final unread = messages.where((m) => 
          m.senderId != currentUser.uid && !m.isReadBy(currentUser.uid)
        ).length;
        
        if (mounted && unread > 0) {
          setState(() {
            _showUnreadSection = true;
            _unreadCount = unread;
          });
        }
      });

      // Mark as read
      await ref.read(messagingRepositoryProvider).markMessagesAsRead(
        conversationId: widget.conversationId,
        userId: currentUser.uid,
      );
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  List<Widget> _buildGroupedMessages(List<Message> messages, String currentUserId) {
    if (messages.isEmpty) return [];

    final widgets = <Widget>[];
    final groupedByDate = <String, List<Message>>{};
    final unreadMessages = <Message>[];

    // Separate unread messages if showing unread section
    final messagesToGroup = <Message>[];
    if (_showUnreadSection) {
      for (final msg in messages) {
        if (msg.senderId != currentUserId && !msg.isReadBy(currentUserId)) {
          unreadMessages.add(msg);
        } else {
          messagesToGroup.add(msg);
        }
      }
    } else {
      messagesToGroup.addAll(messages);
    }

    // Group messages by date
    for (final message in messagesToGroup) {
      final dateKey = _getDateKey(message.timestamp.toDate());
      groupedByDate.putIfAbsent(dateKey, () => []).add(message);
    }

    // Build read messages with date separators
    final sortedDates = groupedByDate.keys.toList()
      ..sort((a, b) {
        final dateA = groupedByDate[a]!.first.timestamp.toDate();
        final dateB = groupedByDate[b]!.first.timestamp.toDate();
        return dateB.compareTo(dateA); // Most recent first (for reverse list)
      });

    for (final dateKey in sortedDates) {
      final messagesForDate = groupedByDate[dateKey]!;
      
      // Add messages for this date (oldest first within the group)
      for (final message in messagesForDate.reversed) {
        final isMe = message.senderId == currentUserId;
        widgets.add(ChatBubble(message: message, isMe: isMe));
      }
      
      // Add date separator at the end (will appear at top due to reverse)
      widgets.add(_buildDateSeparator(dateKey));
    }

    // Add unread section if exists
    if (_showUnreadSection && unreadMessages.isNotEmpty) {
      // Add unread messages (oldest first)
      for (final message in unreadMessages.reversed) {
        widgets.add(ChatBubble(message: message, isMe: false));
      }
      
      // Add "UNREAD MESSAGES" separator
      widgets.add(_buildUnreadSeparator(_unreadCount));
    }

    return widgets;
  }

  String _getDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);
    final difference = today.difference(messageDate).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference <= 6) {
      // Return day name for current week
      return DateTimeUtils.getDateSeparator(date);
    } else {
      // Return date for 7+ days
      return DateTimeUtils.getDateSeparator(date);
    }
  }

  Widget _buildDateSeparator(String text) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.namaLightGray.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.namaMediumGray,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildUnreadSeparator(int count) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.errorRed.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.errorRed.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.mark_chat_unread,
              size: 16,
              color: AppColors.errorRed,
            ),
            const SizedBox(width: 8),
            Text(
              count == 1 ? '1 UNREAD MESSAGE' : '$count UNREAD MESSAGES',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.errorRed,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(directMessagesStreamProvider(widget.conversationId));
    final currentUserAsync = ref.watch(userAppProfileStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: widget.otherUserProfileImage.isNotEmpty
                  ? NetworkImage(widget.otherUserProfileImage)
                  : null,
              backgroundColor: AppColors.namaLightGray,
              child: widget.otherUserProfileImage.isEmpty
                  ? Text(
                      widget.otherUserName.isNotEmpty ? widget.otherUserName[0].toUpperCase() : 'U',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.otherUserName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: currentUserAsync.when(
        data: (currentUser) {
          if (currentUser == null) {
            return const Center(child: Text('You must be logged in to chat.'));
          }
          
          return Column(
            children: [
              Expanded(
                child: messagesAsync.when(
                  data: (messages) {
                    if (messages.isEmpty) {
                      return Center(
                        child: Text(
                          'Say hello!',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      );
                    }
                    
                    final groupedWidgets = _buildGroupedMessages(messages, currentUser.uid);
                    
                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      itemCount: groupedWidgets.length,
                      itemBuilder: (context, index) => groupedWidgets[index],
                    );
                  },
                  loading: () => const LoadingIndicator(),
                  error: (err, stack) => Center(
                    child: Text(
                      'Error: $err',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ),
              DirectMessageComposer(
                conversationId: widget.conversationId,
                currentUser: currentUser,
              ),
            ],
          );
        },
        loading: () => const LoadingIndicator(),
        error: (err, stack) => Center(
          child: Text(
            'Error: $err',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
    );
  }
}