// lib/features/directories/presentation/attendee_directory_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/core/models/app_user.dart';
import 'package:events_app_trueattempt/core/enums/profile_visibility.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/config/app_icons.dart';
import 'package:events_app_trueattempt/features/directories/screen/widgets/user_list_tile.dart';
import 'package:events_app_trueattempt/features/profile/screen/user_details_screen.dart';

class AttendeeDirectoryScreen extends ConsumerStatefulWidget {
  const AttendeeDirectoryScreen({super.key});

  @override
  ConsumerState<AttendeeDirectoryScreen> createState() =>
      _AttendeeDirectoryScreenState();
}

class _AttendeeDirectoryScreenState
    extends ConsumerState<AttendeeDirectoryScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AppUser> _applySearchAndPrivacyFilter(
      List<AppUser> attendees, AppUser? currentUser) {
    if (currentUser == null) return [];

    final viewerId = currentUser.uid;
    final viewerIsAdmin = currentUser.role == 'admin';

    var filtered = attendees.where((user) {
      return user.canBeViewedBy(viewerId, viewerIsAdmin);
    }).toList();

    if (_searchQuery.isEmpty) return filtered;

    final query = _searchQuery.toLowerCase();
    return filtered.where((user) {
      final displayName =
          user.getDisplayNameFor(viewerId, viewerIsAdmin).toLowerCase();
      final email =
          user.getDisplayEmailFor(viewerId, viewerIsAdmin).toLowerCase();
      final company = user.company.toLowerCase();
      final title = user.title.toLowerCase();

      return displayName.contains(query) ||
          email.contains(query) ||
          company.contains(query) ||
          title.contains(query);
    }).toList();
  }

  void _handleUserTap(
      BuildContext context, AppUser user, AppUser currentUser) {
    final viewerId = currentUser.uid;
    final viewerIsAdmin = currentUser.role == 'admin';
    final privacy = ProfileVisibility.fromString(user.profileVisibility);

    if (privacy == ProfileVisibility.anonymous &&
        !user.isConnectedWith(viewerId) &&
        !viewerIsAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Text(AppIcons.privacyAnonymous,
                  style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Scan QR to view profile',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.namaNavyBlue,
        ),
      );
      return;
    }

    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => UserDetailsScreen(userId: user.uid),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final attendeesAsync = ref.watch(attendeesFutureProvider);
    final currentUserAsync = ref.watch(userAppProfileStreamProvider);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        children: [
          // 🔹 SMALLER SEARCH BOX
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: SizedBox(
              height: 42,
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search attendees...',
                  hintStyle: const TextStyle(fontSize: 13),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
          ),

          Expanded(
            child: currentUserAsync.when(
              data: (currentUser) {
                if (currentUser == null) {
                  return const Center(
                      child: Text('Login required',
                          style: TextStyle(fontSize: 13)));
                }

                final viewerIsAdmin = currentUser.role == 'admin';

                return attendeesAsync.when(
                  data: (attendees) {
                    final filtered =
                        _applySearchAndPrivacyFilter(attendees, currentUser);

                    if (filtered.isEmpty) {
                      return const Center(
                        child: Text(
                          'No results',
                          style: TextStyle(fontSize: 13),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final user = filtered[index];
                        final isConnected =
                            user.isConnectedWith(currentUser.uid);
                        final displayName = user.getDisplayNameFor(
                            currentUser.uid, viewerIsAdmin);

                        return UserListTile(
                          user: user,
                          displayName: displayName,
                          onTap: () =>
                              _handleUserTap(context, user, currentUser),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isConnected)
                                const Text(
                                  '✓',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.green),
                                ),
                              const SizedBox(width: 6),
                              const Icon(Icons.chevron_right, size: 18),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const LoadingIndicator(),
                  error: (err, stack) =>
                      Center(child: Text('Error', style: TextStyle(fontSize: 13))),
                );
              },
              loading: () => const LoadingIndicator(),
              error: (err, stack) =>
                  Center(child: Text('Error', style: TextStyle(fontSize: 13))),
            ),
          ),
        ],
      ),
    );
  }
}