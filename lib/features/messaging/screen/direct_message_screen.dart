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
  final String? conversationId;
  final String otherUserId;
  final String otherUserName;
  final String otherUserProfileImage;

  const DirectMessageScreen({
    super.key,
    this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserProfileImage = '',
  });

  @override
  ConsumerState<DirectMessageScreen> createState() =>
      _DirectMessageScreenState();
}

class _DirectMessageScreenState extends ConsumerState<DirectMessageScreen> {
  bool _showUnreadSection = false;
  int _unreadCount = 0;
  bool _hasCheckedUnread = false;

  final Set<String> _unreadMessageIds = {};
  DateTime? _lastMarkAsReadTime;
  String? _conversationId;

  static const Color namaBlue = Color(0xFF0D1496);

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversationId;

    if (_conversationId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduleInitialMarkAsRead();
      });
    }
  }

  @override
  void dispose() {
    _markMessagesAsRead();
    super.dispose();
  }

  void _checkUnreadMessages(List<Message> messages, String currentUserId) {
    if (!_hasCheckedUnread) {
      final unreadMessages = messages
          .where(
            (m) => m.senderId != currentUserId && !m.isReadBy(currentUserId),
          )
          .toList();

      if (unreadMessages.isNotEmpty) {
        setState(() {
          _showUnreadSection = true;
          _unreadCount = unreadMessages.length;
          _hasCheckedUnread = true;
          _unreadMessageIds.addAll(unreadMessages.map((m) => m.id));
        });
      } else {
        _hasCheckedUnread = true;
      }
      return;
    }

    if (_showUnreadSection) {
      final userSentMessage = messages.any(
        (m) =>
            m.senderId == currentUserId &&
            m.timestamp
                .toDate()
                .isAfter(DateTime.now().subtract(const Duration(seconds: 2))),
      );

      if (userSentMessage) {
        setState(() {
          _showUnreadSection = false;
        });
      } else {
        final newUnreadMessages = messages
            .where(
              (m) =>
                  m.senderId != currentUserId &&
                  !m.isReadBy(currentUserId) &&
                  !_unreadMessageIds.contains(m.id),
            )
            .toList();

        if (newUnreadMessages.isNotEmpty) {
          setState(() {
            _unreadMessageIds.addAll(newUnreadMessages.map((m) => m.id));
            _unreadCount = _unreadMessageIds.length;
          });
        }
      }
    }

    _markMessagesAsReadIfNeeded();
  }

  void _scheduleInitialMarkAsRead() {
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      _markMessagesAsRead();
    });
  }

  void _markMessagesAsReadIfNeeded() {
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

  List<Widget> _buildGroupedMessages(
    List<Message> messages,
    String currentUserId,
  ) {
    if (messages.isEmpty) return [];

    final widgets = <Widget>[];
    final groupedByDate = <String, List<Message>>{};

    final unreadMessages = <Message>[];
    final readMessages = <Message>[];

    if (_showUnreadSection && _unreadMessageIds.isNotEmpty) {
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

    if (_showUnreadSection && unreadMessages.isNotEmpty) {
      unreadMessages.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      for (final message in unreadMessages) {
        widgets.add(ChatBubble(message: message, isMe: false));
      }

      widgets.add(_buildUnreadSeparator(_unreadCount));
    }

    for (final message in readMessages) {
      final dateKey = _getDateKey(message.timestamp.toDate());
      groupedByDate.putIfAbsent(dateKey, () => []).add(message);
    }

    final sortedDates = groupedByDate.keys.toList()
      ..sort((a, b) {
        final dateA = groupedByDate[a]!.first.timestamp.toDate();
        final dateB = groupedByDate[b]!.first.timestamp.toDate();
        return dateB.compareTo(dateA);
      });

    for (final dateKey in sortedDates) {
      final messagesForDate = groupedByDate[dateKey]!;
      messagesForDate.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      for (int i = messagesForDate.length - 1; i >= 0; i--) {
        final message = messagesForDate[i];
        final isMe = message.senderId == currentUserId;
        widgets.add(ChatBubble(message: message, isMe: isMe));
      }

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
    } else {
      return DateTimeUtils.getDateSeparator(date);
    }
  }

  Widget _buildDateSeparator(String text) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 10.5,
            color: Color(0xFF6F6F6F),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildUnreadSeparator(int count) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 11),
      decoration: BoxDecoration(
        color: AppColors.errorRed.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.errorRed.withOpacity(0.25),
          width: 0.8,
        ),
      ),
      child: Text(
        count == 1 ? '1 UNREAD MESSAGE' : '$count UNREAD MESSAGES',
        style: const TextStyle(
          fontSize: 9.5,
          color: AppColors.errorRed,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.7,
        ),
      ),
    );
  }

  Widget _buildTopUserHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE6E6E6),
            width: 0.7,
          ),
        ),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(22),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.arrow_back,
                size: 25,
                color: Colors.black,
              ),
            ),
          ),

          const SizedBox(width: 22),

          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserDetailsScreen(
                    userId: widget.otherUserId,
                  ),
                ),
              );
            },
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: widget.otherUserProfileImage.isNotEmpty
                      ? NetworkImage(widget.otherUserProfileImage)
                      : null,
                  backgroundColor: AppColors.avatarPlaceholder,
                  child: widget.otherUserProfileImage.isEmpty
                      ? Text(
                          widget.otherUserName.isNotEmpty
                              ? widget.otherUserName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.avatarPlaceholderText,
                          ),
                        )
                      : null,
                ),

                const SizedBox(width: 12),

                Text(
                  widget.otherUserName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF222222),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposerWrapper(dynamic currentUser) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Color(0xFFE6E6E6),
            width: 0.7,
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Theme(
          data: Theme.of(context).copyWith(
            inputDecorationTheme: const InputDecorationTheme(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
            ),
          ),
          child: DirectMessageComposer(
            conversationId: _conversationId,
            otherUserId: widget.otherUserId,
            currentUser: currentUser,
            onConversationCreated: (String newConversationId) {
              setState(() {
                _conversationId = newConversationId;
              });
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = _conversationId != null
        ? ref.watch(directMessagesStreamProvider(_conversationId!))
        : null;

    final currentUserAsync = ref.watch(userAppProfileStreamProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: currentUserAsync.when(
          data: (currentUser) {
            if (currentUser == null) {
              return Column(
                children: [
                  _buildTopUserHeader(context),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'You must be logged in to chat.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            return Column(
              children: [
                _buildTopUserHeader(context),

                Expanded(
                  child: messagesAsync == null
                      ? const Center(
                          child: Text(
                            'Say hello to start the conversation!',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : messagesAsync.when(
                          data: (messages) {
                            _checkUnreadMessages(messages, currentUser.uid);

                            if (messages.isEmpty) {
                              return const Center(
                                child: Text(
                                  'Say hello!',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.grey,
                                  ),
                                ),
                              );
                            }

                            final groupedWidgets = _buildGroupedMessages(
                              messages,
                              currentUser.uid,
                            );

                            return ListView.builder(
                              reverse: true,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              itemCount: groupedWidgets.length,
                              itemBuilder: (context, index) {
                                return groupedWidgets[index];
                              },
                            );
                          },
                          loading: () => const LoadingIndicator(),
                          error: (err, stack) => Center(
                            child: Text(
                              'Error: $err',
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                ),

                _buildComposerWrapper(currentUser),
              ],
            );
          },
          loading: () => const LoadingIndicator(),
          error: (err, stack) => Column(
            children: [
              _buildTopUserHeader(context),
              Expanded(
                child: Center(
                  child: Text(
                    'Error: $err',
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}