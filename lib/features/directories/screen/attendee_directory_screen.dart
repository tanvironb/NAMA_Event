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
  ConsumerState<AttendeeDirectoryScreen> createState() => _AttendeeDirectoryScreenState();
}

class _AttendeeDirectoryScreenState extends ConsumerState<AttendeeDirectoryScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Filter attendees by search query (name, email, company, title)
  /// Also applies privacy filtering based on viewer permissions
  List<AppUser> _applySearchAndPrivacyFilter(List<AppUser> attendees, AppUser? currentUser) {
    if (currentUser == null) return [];
    
    final viewerId = currentUser.uid;
    final viewerIsAdmin = currentUser.role == 'admin';
    
    // First, filter by visibility (only show users the viewer can see)
    var filtered = attendees.where((user) {
      return user.canBeViewedBy(viewerId, viewerIsAdmin);
    }).toList();
    
    // Then apply search filter
    if (_searchQuery.isEmpty) return filtered;
    
    final query = _searchQuery.toLowerCase();
    return filtered.where((user) {
      // Get display name based on viewer permissions
      final displayName = user.getDisplayNameFor(viewerId, viewerIsAdmin).toLowerCase();
      final email = user.getDisplayEmailFor(viewerId, viewerIsAdmin).toLowerCase();
      final company = user.company.toLowerCase();
      final title = user.title.toLowerCase();
      
      return displayName.contains(query) || 
             email.contains(query) || 
             company.contains(query) || 
             title.contains(query);
    }).toList();
  }
  
  /// Handle tap on anonymous user
  void _handleUserTap(BuildContext context, AppUser user, AppUser currentUser) {
    final viewerId = currentUser.uid;
    final viewerIsAdmin = currentUser.role == 'admin';
    final privacy = ProfileVisibility.fromString(user.profileVisibility);
    
    // If user is anonymous and viewer hasn't scanned them, show snackbar
    if (privacy == ProfileVisibility.anonymous && 
        !user.isConnectedWith(viewerId) && 
        !viewerIsAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Text(AppIcons.privacyAnonymous, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('This user is anonymous. Scan their QR code to connect and view their profile.'),
              ),
            ],
          ),
          backgroundColor: AppColors.namaNavyBlue,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }
    
    // Navigate to profile
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => UserDetailsScreen(userId: user.uid),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final attendeesAsync = ref.watch(attendeesFutureProvider);
    final currentUserAsync = ref.watch(userAppProfileStreamProvider);
    
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search attendees...',
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
        
        // Attendees list
        Expanded(
          child: currentUserAsync.when(
            data: (currentUser) {
              if (currentUser == null) {
                return const Center(child: Text('Please log in to view attendees.'));
              }
              
              final viewerIsAdmin = currentUser.role == 'admin';
              
              return attendeesAsync.when(
                data: (attendees) {
                  if (attendees.isEmpty) {
                    return const Center(child: Text('No attendees to display.'));
                  }

                  // Apply privacy filtering and search
                  final filteredAttendees = _applySearchAndPrivacyFilter(attendees, currentUser);

                  if (filteredAttendees.isEmpty) {
                    return Center(
                      child: Text(
                        _searchQuery.isEmpty 
                          ? 'No visible attendees.'
                          : 'No attendees match your search.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                    );
                  }
                  
                  return ListView.builder(
                    itemCount: filteredAttendees.length,
                    itemBuilder: (context, index) {
                      final user = filteredAttendees[index];
                      final privacy = ProfileVisibility.fromString(user.profileVisibility);
                      final isConnected = user.isConnectedWith(currentUser.uid);
                      final displayName = user.getDisplayNameFor(currentUser.uid, viewerIsAdmin);
                      
                      return UserListTile(
                        user: user,
                        displayName: displayName,
                        onTap: () => _handleUserTap(context, user, currentUser),
                        // Show privacy indicator badge
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Connected via QR indicator
                            if (isConnected && !viewerIsAdmin)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.successGreen.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.successGreen,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(AppIcons.qrCodeScanner, size: 12, color: AppColors.successGreen),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Connected',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.successGreen,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(width: 8),
                            // Admin detective icon for anonymous users
                            if (viewerIsAdmin && privacy == ProfileVisibility.anonymous)
                              Text(
                                AppIcons.privacyAnonymous,
                                style: const TextStyle(fontSize: 20),
                              ),
                            if (viewerIsAdmin && privacy == ProfileVisibility.anonymous)
                              const SizedBox(width: 8),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const LoadingIndicator(),
                error: (err, stack) => Center(child: Text('Error: $err')),
              );
            },
            loading: () => const LoadingIndicator(),
            error: (err, stack) => Center(child: Text('Error loading profile: $err')),
          ),
          ),
        ],
      ),
    );
  }
}