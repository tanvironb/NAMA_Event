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
  bool _hasCheckedUnread = false;
  bool _hasMarkedAsRead = false;

  @override
  void initState() {
    super.initState();
    // Mark as read after a delay to ensure UI is rendered first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleMarkAsRead();
    });
  }

  @override
  void dispose() {
    // If user navigates away before marking as read completes, still mark as read
    // This handles the case where user opens chat quickly and closes it
    if (!_hasMarkedAsRead && _hasCheckedUnread) {
      _markMessagesAsRead();
    }
    super.dispose();
  }

  void _checkUnreadMessages(List<Message> messages, String currentUserId) {
    // Only check once when first opening the chat
    if (_hasCheckedUnread) return;
    
    final unreadMessages = messages.where((m) => 
      m.senderId != currentUserId && !m.isReadBy(currentUserId)
    ).toList();
    
    if (unreadMessages.isNotEmpty) {
      setState(() {
        _showUnreadSection = true;
        _unreadCount = unreadMessages.length;
        _hasCheckedUnread = true;
      });
    } else {
      _hasCheckedUnread = true;
    }
  }

  void _scheduleMarkAsRead() {
    // Wait for UI to render, then mark as read
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted || _hasMarkedAsRead) return;
      _markMessagesAsRead();
    });
  }

  Future<void> _markMessagesAsRead() async {
    if (!mounted || _hasMarkedAsRead) return;
    final currentUser = ref.read(firebaseAuthProvider).currentUser;
    if (currentUser == null) return;

    try {
      _hasMarkedAsRead = true;
      await ref.read(messagingRepositoryProvider).markMessagesAsRead(
        conversationId: widget.conversationId,
        userId: currentUser.uid,
      );
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
      _hasMarkedAsRead = false;
    }
  }

  List<Widget> _buildGroupedMessages(List<Message> messages, String currentUserId) {
    if (messages.isEmpty) return [];

    final widgets = <Widget>[];
    final groupedByDate = <String, List<Message>>{};
    
    // Group ALL messages by date (keep chronological order)
    for (final message in messages) {
      final dateKey = _getDateKey(message.timestamp.toDate());
      groupedByDate.putIfAbsent(dateKey, () => []).add(message);
    }

    // Sort dates (most recent first for reverse ListView)
    final sortedDates = groupedByDate.keys.toList()
      ..sort((a, b) {
        final dateA = groupedByDate[a]!.first.timestamp.toDate();
        final dateB = groupedByDate[b]!.first.timestamp.toDate();
        return dateB.compareTo(dateA);
      });

    // Track if we've added the unread separator
    bool unreadSeparatorAdded = false;
    
    // Build widgets with date separators and unread separator
    for (final dateKey in sortedDates) {
      final messagesForDate = groupedByDate[dateKey]!;
      
      // Sort messages within date group (oldest first)
      messagesForDate.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      // Process messages in reverse for ListView (newest at bottom = index 0)
      for (int i = messagesForDate.length - 1; i >= 0; i--) {
        final message = messagesForDate[i];
        final isMe = message.senderId == currentUserId;
        
        // Add unread separator BEFORE the first unread message
        if (_showUnreadSection && 
            !unreadSeparatorAdded && 
            message.senderId != currentUserId && 
            !message.isReadBy(currentUserId)) {
          widgets.add(_buildUnreadSeparator(_unreadCount));
          unreadSeparatorAdded = true;
        }
        
        widgets.add(ChatBubble(message: message, isMe: isMe));
      }
      
      // Add date separator at the end (will appear at top due to reverse)
      widgets.add(_buildDateSeparator(dateKey));
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
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(
            child: Divider(
              color: AppColors.errorRed,
              thickness: 1,
              endIndent: 8,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.errorRed,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count == 1 ? '1 UNREAD MESSAGE' : '$count UNREAD MESSAGES',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const Expanded(
            child: Divider(
              color: AppColors.errorRed,
              thickness: 1,
              indent: 8,
            ),
          ),
        ],
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
              backgroundColor: AppColors.avatarPlaceholder,
              child: widget.otherUserProfileImage.isEmpty
                  ? Text(
                      widget.otherUserName.isNotEmpty ? widget.otherUserName[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.avatarPlaceholderText,
                      ),
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
                    // Check for unread messages on first build
                    _checkUnreadMessages(messages, currentUser.uid);
                    
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