// lib/features/directories/presentation/attendee_directory_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/core/models/app_user.dart';
import 'package:events_app_trueattempt/core/enums/profile_visibility.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/config/app_icons.dart';
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
    List<AppUser> attendees,
    AppUser? currentUser,
  ) {
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
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Scan QR to view profile',
                  style: TextStyle(fontSize: 12),
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

  String _getInitials(String name) {
    final trimmedName = name.trim();

    if (trimmedName.isEmpty || trimmedName == 'Anonymous') {
      return '?';
    }

    final parts = trimmedName.split(RegExp(r'\s+'));

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String _getProfileImageUrl(AppUser user) {
    try {
      final value = (user as dynamic).profileImageUrl;
      if (value is String && value.trim().isNotEmpty) return value.trim();
    } catch (_) {}

    try {
      final value = (user as dynamic).photoUrl;
      if (value is String && value.trim().isNotEmpty) return value.trim();
    } catch (_) {}

    try {
      final value = (user as dynamic).photoURL;
      if (value is String && value.trim().isNotEmpty) return value.trim();
    } catch (_) {}

    try {
      final value = (user as dynamic).imageUrl;
      if (value is String && value.trim().isNotEmpty) return value.trim();
    } catch (_) {}

    try {
      final value = (user as dynamic).avatarUrl;
      if (value is String && value.trim().isNotEmpty) return value.trim();
    } catch (_) {}

    try {
      final value = (user as dynamic).profilePictureUrl;
      if (value is String && value.trim().isNotEmpty) return value.trim();
    } catch (_) {}

    return '';
  }

  Widget _buildInitialsAvatar(String displayName) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.namaNavyBlue.withOpacity(0.08),
        border: Border.all(
          color: AppColors.namaNavyBlue.withOpacity(0.12),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        _getInitials(displayName),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.namaNavyBlue,
        ),
      ),
    );
  }

  Widget _buildProfileAvatar(AppUser user, String displayName) {
    final imageUrl = _getProfileImageUrl(user);

    if (imageUrl.isEmpty) {
      return _buildInitialsAvatar(displayName);
    }

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.namaNavyBlue.withOpacity(0.12),
          width: 1,
        ),
      ),
      child: ClipOval(
        child: Image.network(
          imageUrl,
          width: 42,
          height: 42,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildInitialsAvatar(displayName);
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;

            return Container(
              color: AppColors.namaNavyBlue.withOpacity(0.06),
              alignment: Alignment.center,
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: AppColors.namaNavyBlue.withOpacity(0.7),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCompactAttendeeCard({
    required AppUser user,
    required AppUser currentUser,
    required bool viewerIsAdmin,
  }) {
    final privacy = ProfileVisibility.fromString(user.profileVisibility);
    final isConnected = user.isConnectedWith(currentUser.uid);

    final displayName = user.getDisplayNameFor(
      currentUser.uid,
      viewerIsAdmin,
    );

    final displayEmail = user.getDisplayEmailFor(
      currentUser.uid,
      viewerIsAdmin,
    );

    final title = user.title.trim();
    final company = user.company.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _handleUserTap(context, user, currentUser),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.035),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              _buildProfileAvatar(user, displayName),

              const SizedBox(width: 11),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF222222),
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (title.isNotEmpty)
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                          height: 1.15,
                        ),
                      ),
                    if (title.isNotEmpty) const SizedBox(height: 2),
                    Text(
                      company.isNotEmpty ? company : displayEmail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey.shade600,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isConnected && !viewerIsAdmin)
                    Container(
                      margin: const EdgeInsets.only(bottom: 5),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.successGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: AppColors.successGreen,
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            AppIcons.qrCodeScanner,
                            size: 9,
                            color: AppColors.successGreen,
                          ),
                          const SizedBox(width: 3),
                          const Text(
                            'Connected',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: AppColors.successGreen,
                            ),
                          ),
                        ],
                      ),
                    ),

                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (viewerIsAdmin &&
                          privacy == ProfileVisibility.anonymous)
                        Text(
                          AppIcons.privacyAnonymous,
                          style: const TextStyle(fontSize: 14),
                        ),
                      if (viewerIsAdmin &&
                          privacy == ProfileVisibility.anonymous)
                        const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        size: 17,
                        color: Colors.grey.shade500,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final attendeesAsync = ref.watch(attendeesFutureProvider);
    final currentUserAsync = ref.watch(userAppProfileStreamProvider);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 12.5),
                decoration: InputDecoration(
                  hintText: 'Search attendees...',
                  hintStyle: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey.shade500,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 18,
                    color: Colors.grey.shade500,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            size: 17,
                            color: Colors.grey.shade500,
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
                  contentPadding: EdgeInsets.zero,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(
                      color: Color(0xFF24158A),
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
          ),

          Expanded(
            child: currentUserAsync.when(
              data: (currentUser) {
                if (currentUser == null) {
                  return const Center(
                    child: Text(
                      'Login required',
                      style: TextStyle(fontSize: 12),
                    ),
                  );
                }

                final viewerIsAdmin = currentUser.role == 'admin';

                return attendeesAsync.when(
                  data: (attendees) {
                    final filteredAttendees =
                        _applySearchAndPrivacyFilter(attendees, currentUser);

                    if (filteredAttendees.isEmpty) {
                      return Center(
                        child: Text(
                          _searchQuery.isEmpty
                              ? 'No attendees to display.'
                              : 'No attendees match your search.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.only(
                        top: 4,
                        bottom: 16,
                      ),
                      itemCount: filteredAttendees.length,
                      itemBuilder: (context, index) {
                        final user = filteredAttendees[index];

                        return _buildCompactAttendeeCard(
                          user: user,
                          currentUser: currentUser,
                          viewerIsAdmin: viewerIsAdmin,
                        );
                      },
                    );
                  },
                  loading: () => const LoadingIndicator(),
                  error: (err, stack) => const Center(
                    child: Text(
                      'Error',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                );
              },
              loading: () => const LoadingIndicator(),
              error: (err, stack) => const Center(
                child: Text(
                  'Error',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}