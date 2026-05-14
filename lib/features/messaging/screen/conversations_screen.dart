// lib/features/messaging/screen/conversations_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/core/models/conversation_model.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/features/messaging/screen/new_conversation_screen.dart';
import 'package:events_app_trueattempt/features/messaging/screen/widgets/conversation_list_tile.dart';

class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() =>
      _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  static const Color titleColor = Color(0xFF0D1496);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Conversation> _applySearch(List<Conversation> conversations) {
    if (_searchQuery.isEmpty) return conversations;

    final query = _searchQuery.toLowerCase();

    return conversations.where((conversation) {
      final memberNames = conversation.memberInfo.values
          .map((info) => (info['name'] as String? ?? '').toLowerCase())
          .join(' ');
      return memberNames.contains(query);
    }).toList();
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.arrow_back,
                size: 22,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Messages',
            style: TextStyle(
              fontSize: 22, // smaller
              fontWeight: FontWeight.w600,
              color: titleColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: SizedBox(
        height: 40, // slimmer
        child: TextField(
          controller: _searchController,
          style: const TextStyle(fontSize: 12.5),
          decoration: InputDecoration(
            hintText: 'Search conversations...',
            hintStyle: const TextStyle(
              fontSize: 12.5,
              color: Colors.grey,
            ),
            prefixIcon: const Icon(
              Icons.search,
              size: 18,
              color: Colors.grey,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.clear,
                      size: 16,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        _searchQuery = '';
                      });
                    },
                  )
                : null,
            filled: true,
            fillColor: const Color(0xFFF7F7F7),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20), // more curved
              borderSide: const BorderSide(
                color: Color(0xFFD9D9D9),
                width: 0.8,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20), // more curved
              borderSide: const BorderSide(
                color: titleColor,
                width: 1,
              ),
            ),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conversationsAsync = ref.watch(conversationsStreamProvider);

    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildSearchBar(),

            Expanded(
              child: conversationsAsync.when(
                data: (conversations) {
                  if (conversations.isEmpty) {
                    return const Center(
                      child: Text(
                        'You have no messages yet.\nStart a new conversation!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  }

                  final filteredConversations = _applySearch(conversations);

                  if (filteredConversations.isEmpty) {
                    return const Center(
                      child: Text(
                        'No conversations match your search.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 80),
                    itemCount: filteredConversations.length,
                    itemBuilder: (context, index) {
                      final conversation = filteredConversations[index];
                      return ConversationListTile(
                        conversation: conversation,
                      );
                    },
                  );
                },
                loading: () => const LoadingIndicator(),
                error: (err, stack) => Center(
                  child: Text(
                    'Error: $err',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.red,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFF4BE32),
        elevation: 4,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const NewConversationScreen(),
            ),
          );
        },
        child: const Icon(
          Icons.add_comment_outlined,
          size: 20,
          color: titleColor,
        ),
      ),
    );
  }
}