import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/core/models/app_user.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/features/profile/screen/user_details_screen.dart';

class ConnectionsScreen extends ConsumerWidget {
  const ConnectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserAsync = ref.watch(userAppProfileStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My QR Connections'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
      ),
      body: currentUserAsync.when(
        data: (currentUser) {
          if (currentUser == null) {
            return const Center(
              child: Text(
                'You must be logged in',
                style: TextStyle(fontSize: 16, color: AppColors.namaMediumGray),
              ),
            );
          }

          return DefaultTabController(
            length: 2,
            child: Column(
              children: [
                Container(
                  color: AppColors.namaWhite,
                  child: TabBar(
                    labelColor: AppColors.namaNavyBlue,
                    unselectedLabelColor: AppColors.namaMediumGray,
                    indicatorColor: AppColors.namaNavyBlue,
                    indicatorWeight: 3,
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.qr_code_scanner, size: 18),
                            const SizedBox(width: 8),
                            Text('I Scanned (${currentUser.usersIScanned.length})'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.qr_code, size: 18),
                            const SizedBox(width: 8),
                            Text('Scanned Me (${currentUser.scannedByUsers.length})'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.namaMediumGray),
              const SizedBox(height: 16),
              Text(
                'Error loading connections',
                style: const TextStyle(fontSize: 16, color: AppColors.namaMediumGray),
              ),
            ],
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
              size: 80,
              color: AppColors.namaMediumGray.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              emptyTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.namaMediumGray,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              emptySubtitle,
              style: TextStyle(
                fontSize: 14,
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

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading connections',
              style: const TextStyle(color: AppColors.namaMediumGray),
            ),
          );
        }

        final users = snapshot.data ?? [];
        if (users.isEmpty) {
          return Center(
            child: Text(
              'No connections found',
              style: const TextStyle(color: AppColors.namaMediumGray),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
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
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.namaWhite,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 28,
          backgroundImage: user.profileImageUrl.isNotEmpty
              ? NetworkImage(user.profileImageUrl)
              : null,
          backgroundColor: AppColors.namaNavyBlue.withOpacity(0.1),
          child: user.profileImageUrl.isEmpty
              ? Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.namaNavyBlue,
                  ),
                )
              : null,
        ),
        title: Text(
          user.name,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.namaNavyBlue,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user.title.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                user.title,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.namaMediumGray,
                ),
              ),
            ],
            if (user.company.isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.business, size: 12, color: AppColors.namaMediumGray),
                  const SizedBox(width: 4),
                  Text(
                    user.company,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.namaMediumGray,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Privacy indicator
            if (user.isAnonymous)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.namaMediumGray.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '🕵️',
                      style: TextStyle(fontSize: 10),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Anonymous',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.namaMediumGray,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.namaMediumGray),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserDetailsScreen(userId: user.uid),
            ),
          );
        },
      ),
    );
  }
}
