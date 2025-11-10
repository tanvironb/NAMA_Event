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
  ConsumerState<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Filter conversations by search query (participant names)
  List<Conversation> _applySearch(List<Conversation> conversations) {
    if (_searchQuery.isEmpty) return conversations;
    final query = _searchQuery.toLowerCase();
    return conversations.where((conversation) {
      // Search in member names from memberInfo
      final memberNames = conversation.memberInfo.values
          .map((info) => (info['name'] as String? ?? '').toLowerCase())
          .join(' ');
      return memberNames.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final conversationsAsync = ref.watch(conversationsStreamProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        // Using theme's default AppBar styling (navy blue)
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search conversations...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          
          // Conversations list
          Expanded(
            child: conversationsAsync.when(
              data: (conversations) {
                if (conversations.isEmpty) {
                  return const Center(
                    child: Text(
                      'You have no messages yet.\nStart a new conversation!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                  );
                }

                // Apply search filter
                final filteredConversations = _applySearch(conversations);

                if (filteredConversations.isEmpty) {
                  return const Center(
                    child: Text(
                      'No conversations match your search.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                  );
                }
                
                return ListView.builder(
                  itemCount: filteredConversations.length,
                  itemBuilder: (context, index) {
                    final conversation = filteredConversations[index];
                    return ConversationListTile(conversation: conversation);
                  },
                );
              },
              loading: () => const LoadingIndicator(),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const NewConversationScreen(),
          ));
        },
        child: const Icon(Icons.add_comment_outlined),
      ),
    );
  }
}
