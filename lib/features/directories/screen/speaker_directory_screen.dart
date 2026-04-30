// lib/features/directories/presentation/speaker_directory_screen.dart
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

class SpeakerDirectoryScreen extends ConsumerStatefulWidget {
  const SpeakerDirectoryScreen({super.key});

  @override
  ConsumerState<SpeakerDirectoryScreen> createState() =>
      _SpeakerDirectoryScreenState();
}

class _SpeakerDirectoryScreenState
    extends ConsumerState<SpeakerDirectoryScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AppUser> _applySearchAndPrivacyFilter(
      List<AppUser> speakers, AppUser? currentUser) {
    if (currentUser == null) return [];

    final viewerId = currentUser.uid;
    final viewerIsAdmin = currentUser.role == 'admin';

    var filtered = speakers.where((user) {
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

  void _handleUserTap(BuildContext context, AppUser user, AppUser currentUser) {
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
              Text(
                AppIcons.privacyAnonymous,
                style: const TextStyle(fontSize: 16),
              ),
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

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UserDetailsScreen(userId: user.uid),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final speakersAsync = ref.watch(speakersFutureProvider);
    final currentUserAsync = ref.watch(userAppProfileStreamProvider);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        children: [
          // Smaller search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: SizedBox(
              height: 42,
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search speakers...',
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

          // Speakers list
          Expanded(
            child: currentUserAsync.when(
              data: (currentUser) {
                if (currentUser == null) {
                  return const Center(
                    child: Text(
                      'Login required',
                      style: TextStyle(fontSize: 13),
                    ),
                  );
                }

                final viewerIsAdmin = currentUser.role == 'admin';

                return speakersAsync.when(
                  data: (speakers) {
                    final filteredSpeakers =
                        _applySearchAndPrivacyFilter(speakers, currentUser);

                    if (filteredSpeakers.isEmpty) {
                      return Center(
                        child: Text(
                          _searchQuery.isEmpty
                              ? 'No speakers to display.'
                              : 'No speakers match your search.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: filteredSpeakers.length,
                      itemBuilder: (context, index) {
                        final user = filteredSpeakers[index];
                        final privacy =
                            ProfileVisibility.fromString(user.profileVisibility);
                        final isConnected =
                            user.isConnectedWith(currentUser.uid);
                        final displayName = user.getDisplayNameFor(
                          currentUser.uid,
                          viewerIsAdmin,
                        );

                        return UserListTile(
                          user: user,
                          displayName: displayName,
                          onTap: () =>
                              _handleUserTap(context, user, currentUser),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isConnected && !viewerIsAdmin)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.successGreen
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppColors.successGreen,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        AppIcons.qrCodeScanner,
                                        size: 11,
                                        color: AppColors.successGreen,
                                      ),
                                      const SizedBox(width: 3),
                                      const Text(
                                        'Connected',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.successGreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              const SizedBox(width: 6),

                              if (viewerIsAdmin &&
                                  privacy == ProfileVisibility.anonymous)
                                Text(
                                  AppIcons.privacyAnonymous,
                                  style: const TextStyle(fontSize: 16),
                                ),

                              if (viewerIsAdmin &&
                                  privacy == ProfileVisibility.anonymous)
                                const SizedBox(width: 6),

                              const Icon(Icons.chevron_right, size: 18),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const LoadingIndicator(),
                  error: (err, stack) => const Center(
                    child: Text(
                      'Error',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                );
              },
              loading: () => const LoadingIndicator(),
              error: (err, stack) => const Center(
                child: Text(
                  'Error',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}