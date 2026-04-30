import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/core/models/app_user.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/features/profile/screen/user_details_screen.dart';

class ConnectionsScreen extends ConsumerWidget {
  const ConnectionsScreen({super.key});

  static const Color _primaryPurple = Color(0xFF4A3B95);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserAsync = ref.watch(userAppProfileStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.namaWhite,
      body: SafeArea(
        child: currentUserAsync.when(
          data: (currentUser) {
            if (currentUser == null) {
              return const Center(
                child: Text(
                  'You must be logged in',
                  style: TextStyle(color: AppColors.namaMediumGray),
                ),
              );
            }

            return DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  /// 🔹 HEADER (CENTERED TITLE)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back),
                            color: AppColors.namaNavyBlue,
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        const Text(
                          'My Connections',
                          style: TextStyle(
                            fontSize: 18, // ↓ reduced
                            fontWeight: FontWeight.w600,
                            color: AppColors.namaNavyBlue,
                          ),
                        ),
                      ],
                    ),
                  ),

                  /// 🔹 SMALL PILL TAB
                  Container(
                    height: 34,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7E4F0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TabBar(
                      dividerColor: Colors.transparent,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: _primaryPurple,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.black87,
                      labelPadding: EdgeInsets.zero,
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.qr_code, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'I Scanned (${currentUser.usersIScanned.length})',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.qr_code_scanner, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'Scanned Me (${currentUser.scannedByUsers.length})',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  /// 🔹 CONTENT
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildConnectionsList(
                          context,
                          ref,
                          currentUser.usersIScanned,
                          'You haven\'t scanned anyone yet',
                          'Scan someone\'s QR code to connect',
                        ),
                        _buildConnectionsList(
                          context,
                          ref,
                          currentUser.scannedByUsers,
                          'No one has scanned you yet',
                          'Share your QR code to get connections',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: LoadingIndicator()),
          error: (error, stack) => const Center(
            child: Text(
              'Error loading connections',
              style: TextStyle(color: AppColors.namaMediumGray),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionsList(
    BuildContext context,
    WidgetRef ref,
    List<String> userIds,
    String emptyTitle,
    String emptySubtitle,
  ) {
    if (userIds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 60,
              color: AppColors.namaMediumGray.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            Text(
              emptyTitle,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.namaMediumGray,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              emptySubtitle,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.namaMediumGray.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<List<AppUser>>(
      future: ref.read(userProfileRepositoryProvider).getUsersByIds(userIds),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: LoadingIndicator());
        }

        final users = snapshot.data ?? [];

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return _buildConnectionTile(context, user);
          },
        );
      },
    );
  }

  Widget _buildConnectionTile(BuildContext context, AppUser user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.namaWhite,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          radius: 22,
          backgroundImage: user.profileImageUrl.isNotEmpty
              ? NetworkImage(user.profileImageUrl)
              : null,
          backgroundColor: AppColors.namaNavyBlue.withOpacity(0.1),
          child: user.profileImageUrl.isEmpty
              ? Text(
                  user.name.isNotEmpty
                      ? user.name[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.namaNavyBlue,
                  ),
                )
              : null,
        ),
        title: Text(
          user.name,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.namaNavyBlue,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          size: 18,
          color: AppColors.namaMediumGray,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  UserDetailsScreen(userId: user.uid),
            ),
          );
        },
      ),
    );
  }
}