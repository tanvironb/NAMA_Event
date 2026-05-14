// lib/features/messaging/screen/new_conversation_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/core/models/app_user.dart';
import 'package:events_app_trueattempt/features/messaging/screen/direct_message_screen.dart';
import 'package:events_app_trueattempt/features/directories/screen/widgets/user_list_tile.dart';

class NewConversationScreen extends ConsumerStatefulWidget {
  const NewConversationScreen({super.key});

  @override
  ConsumerState<NewConversationScreen> createState() =>
      _NewConversationScreenState();
}

class _NewConversationScreenState extends ConsumerState<NewConversationScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const Color titleColor = Color(0xFF0D1496);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
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
          const SizedBox(width: 14),
          const Text(
            'New Conversation',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: titleColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: SizedBox(
        height: 42,
        child: TextField(
          controller: _searchController,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF333333),
          ),
          decoration: InputDecoration(
            hintText: 'Search for people...',
            hintStyle: const TextStyle(
              fontSize: 13,
              color: Color(0xFF8A8A8A),
            ),
            prefixIcon: const Icon(
              Icons.search,
              size: 19,
              color: Color(0xFF6F6F6F),
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.clear,
                      size: 17,
                      color: Color(0xFF6F6F6F),
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: const Color(0xFFF7F7F7),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: const BorderSide(
                color: Color(0xFFD9D9D9),
                width: 0.8,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: const BorderSide(
                color: titleColor,
                width: 1,
              ),
            ),
          ),
          onChanged: (value) {
            setState(() => _searchQuery = value.trim());
          },
        ),
      ),
    );
  }

  Widget _buildEmptySearchState(BuildContext context) {
    return Center(
      child: Transform.translate(
        offset: const Offset(0, -40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search,
              size: 50,
              color: Colors.grey.withOpacity(0.45),
            ),
            const SizedBox(height: 12),
            Text(
              'Search for people to message',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.withOpacity(0.85),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoUsersState(BuildContext context) {
    return Center(
      child: Transform.translate(
        offset: const Offset(0, -40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_search,
              size: 50,
              color: Colors.grey.withOpacity(0.45),
            ),
            const SizedBox(height: 12),
            Text(
              'No users found',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.withOpacity(0.85),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Transform.translate(
        offset: const Offset(0, -40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 50,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            const Text(
              'Error searching users',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchResultsAsync = ref.watch(userSearchProvider(_searchQuery));

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildSearchBar(),

            Expanded(
              child: searchResultsAsync.when(
                data: (users) {
                  if (_searchQuery.isEmpty) {
                    return _buildEmptySearchState(context);
                  }

                  if (users.isEmpty) {
                    return _buildNoUsersState(context);
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 20),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      final currentUserId =
                          ref.read(firebaseAuthProvider).currentUser?.uid;

                      if (user.uid == currentUserId) {
                        return const SizedBox.shrink();
                      }

                      return UserListTile(
                        user: user,
                        onTap: () => _startConversation(context, user),
                      );
                    },
                  );
                },
                loading: () {
                  if (_searchQuery.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return const LoadingIndicator();
                },
                error: (err, stack) => _buildErrorState(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startConversation(BuildContext context, AppUser otherUser) async {
    final currentUserId = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (currentUserId == null) return;

    try {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DirectMessageScreen(
            conversationId: null,
            otherUserId: otherUser.uid,
            otherUserName: otherUser.name,
            otherUserProfileImage: otherUser.profileImageUrl,
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open conversation: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}