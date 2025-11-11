// lib/features/messaging/screen/direct_message_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/features/chat/screen/widgets/chat_bubble.dart';
import 'package:events_app_trueattempt/features/messaging/screen/widgets/direct_message_composer.dart';
import 'package:events_app_trueattempt/features/profile/screen/user_details_screen.dart';
import 'package:events_app_trueattempt/core/models/message_model.dart';
import 'package:events_app_trueattempt/utils/date_time_utils.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';

class DirectMessageScreen extends ConsumerStatefulWidget {
  final String? conversationId; // Made optional
  final String otherUserId;
  final String otherUserName;
  final String otherUserProfileImage;

  const DirectMessageScreen({
    super.key,
    this.conversationId, // Optional now
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
  
  // Cache the unread message IDs to persist the unread section even after marking as read
  final Set<String> _unreadMessageIds = {};
  
  // Track the last time we marked messages as read
  DateTime? _lastMarkAsReadTime;
  
  // Track conversation ID (will be created when first message is sent)
  String? _conversationId;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversationId;
    // Schedule initial mark as read only if conversation exists
    if (_conversationId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduleInitialMarkAsRead();
      });
    }
  }

  @override
  void dispose() {
    // Mark any remaining messages as read when leaving
    _markMessagesAsRead();
    super.dispose();
  }

  void _checkUnreadMessages(List<Message> messages, String currentUserId) {
    // First time opening chat - initialize unread section
    if (!_hasCheckedUnread) {
      final unreadMessages = messages.where((m) => 
        m.senderId != currentUserId && !m.isReadBy(currentUserId)
      ).toList();
      
      if (unreadMessages.isNotEmpty) {
        setState(() {
          _showUnreadSection = true;
          _unreadCount = unreadMessages.length;
          _hasCheckedUnread = true;
          // Cache the message IDs that are unread at this moment
          _unreadMessageIds.addAll(unreadMessages.map((m) => m.id));
        });
      } else {
        _hasCheckedUnread = true;
      }
      return;
    }
    
    // After initial check, handle new messages
    if (_showUnreadSection) {
      // Check if current user sent any message
      final userSentMessage = messages.any((m) => 
        m.senderId == currentUserId && 
        m.timestamp.toDate().isAfter(DateTime.now().subtract(const Duration(seconds: 2)))
      );
      
      if (userSentMessage) {
        // User sent a message - hide unread section but keep messages visible
        setState(() {
          _showUnreadSection = false;
        });
      } else {
        // Check for new messages from other user and add to unread section
        final newUnreadMessages = messages.where((m) => 
          m.senderId != currentUserId && 
          !m.isReadBy(currentUserId) &&
          !_unreadMessageIds.contains(m.id)
        ).toList();
        
        if (newUnreadMessages.isNotEmpty) {
          setState(() {
            _unreadMessageIds.addAll(newUnreadMessages.map((m) => m.id));
            _unreadCount = _unreadMessageIds.length;
          });
        }
      }
    }
    
    // Continuously mark messages as read (Instagram/WhatsApp behavior)
    _markMessagesAsReadIfNeeded();
  }

  void _scheduleInitialMarkAsRead() {
    // Wait for UI to render, then mark initial unread messages as read
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      _markMessagesAsRead();
    });
  }

  void _markMessagesAsReadIfNeeded() {
    // Continuously mark messages as read while chat is open (Instagram/WhatsApp behavior)
    // Only mark every 500ms to avoid excessive writes
    final now = DateTime.now();
    if (_lastMarkAsReadTime != null && 
        now.difference(_lastMarkAsReadTime!).inMilliseconds < 500) {
      return;
    }
    
    _lastMarkAsReadTime = now;
    _markMessagesAsRead();
  }

  Future<void> _markMessagesAsRead() async {
    if (!mounted || _conversationId == null) return;
    final currentUser = ref.read(firebaseAuthProvider).currentUser;
    if (currentUser == null) return;

    try {
      await ref.read(messagingRepositoryProvider).markMessagesAsRead(
        conversationId: _conversationId!,
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
    
    // Separate messages based on CACHED unread IDs (not live read status)
    final unreadMessages = <Message>[];
    final readMessages = <Message>[];
    
    if (_showUnreadSection && _unreadMessageIds.isNotEmpty) {
      // Use the cached unread message IDs to determine which messages go in unread section
      for (final message in messages) {
        if (_unreadMessageIds.contains(message.id)) {
          unreadMessages.add(message);
        } else {
          readMessages.add(message);
        }
      }
    } else {
      readMessages.addAll(messages);
    }
    
    // Add unread section FIRST (will appear at bottom/most recent due to reverse ListView)
    if (_showUnreadSection && unreadMessages.isNotEmpty) {
      // Sort unread messages (newest first)
      unreadMessages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      // Add unread messages first (will appear at bottom in reverse ListView)
      for (final message in unreadMessages) {
        widgets.add(ChatBubble(message: message, isMe: false));
      }
      
      // Add unread separator last (will appear ABOVE the unread messages in reverse ListView)
      widgets.add(_buildUnreadSeparator(_unreadCount));
    }
    
    // Group read messages by date
    for (final message in readMessages) {
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
    
    // Build read messages with date separators
    for (final dateKey in sortedDates) {
      final messagesForDate = groupedByDate[dateKey]!;
      
      // Sort messages within date group (oldest first)
      messagesForDate.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      // Process messages in reverse for ListView (newest at bottom = index 0)
      for (int i = messagesForDate.length - 1; i >= 0; i--) {
        final message = messagesForDate[i];
        final isMe = message.senderId == currentUserId;
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
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.errorRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.errorRed.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.errorRed,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.fiber_manual_record,
              size: 8,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            count == 1 ? '1 UNREAD MESSAGE' : '$count UNREAD MESSAGES',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.errorRed,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.errorRed,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.fiber_manual_record,
              size: 8,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only watch messages if conversation exists
    final messagesAsync = _conversationId != null 
        ? ref.watch(directMessagesStreamProvider(_conversationId!))
        : null;
    final currentUserAsync = ref.watch(userAppProfileStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserDetailsScreen(userId: widget.otherUserId),
              ),
            );
          },
          child: Row(
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
      ),
      body: currentUserAsync.when(
        data: (currentUser) {
          if (currentUser == null) {
            return const Center(child: Text('You must be logged in to chat.'));
          }
          
          return Column(
            children: [
              Expanded(
                child: messagesAsync == null
                    ? Center(
                        child: Text(
                          'Say hello to start the conversation!',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      )
                    : messagesAsync.when(
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
                conversationId: _conversationId,
                otherUserId: widget.otherUserId,
                currentUser: currentUser,
                onConversationCreated: (String newConversationId) {
                  setState(() {
                    _conversationId = newConversationId;
                  });
                },
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