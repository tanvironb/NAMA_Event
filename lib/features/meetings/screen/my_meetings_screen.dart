import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/core/models/meeting_model.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:intl/intl.dart';

class MyMeetingsScreen extends ConsumerWidget {
  final int initialTab;

  const MyMeetingsScreen({super.key, this.initialTab = 0});

  static const Color tabColor = Color(0xFF3D3D9E);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meetingsAsync = ref.watch(meetingsStreamProvider);

    return DefaultTabController(
      length: 3,
      initialIndex: initialTab,
      child: Builder(
        builder: (context) {
          final tabController = DefaultTabController.of(context);

          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            body: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Row(
                          children: [
                            InkWell(
                              onTap: () => Navigator.pop(context),
                              child: const Icon(
                                Icons.arrow_back,
                                size: 20,
                                color: AppColors.namaNavyBlue,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'My Meetings',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.namaNavyBlue,
                                  ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: AnimatedBuilder(
                      animation: tabController,
                      builder: (context, _) {
                        return Row(
                          children: [
                            _buildTabBox(
                              text: 'Pending',
                              index: 0,
                              selectedIndex: tabController.index,
                              onTap: () => tabController.animateTo(0),
                            ),
                            const SizedBox(width: 6),
                            _buildTabBox(
                              text: 'Upcoming',
                              index: 1,
                              selectedIndex: tabController.index,
                              onTap: () => tabController.animateTo(1),
                            ),
                            const SizedBox(width: 6),
                            _buildTabBox(
                              text: 'Past',
                              index: 2,
                              selectedIndex: tabController.index,
                              onTap: () => tabController.animateTo(2),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  Expanded(
                    child: meetingsAsync.when(
                      data: (meetings) {
                        final safeMeetings = meetings.whereType<Meeting>().toList();

                        return TabBarView(
                          children: [
                            _buildMeetingsList(
                              context,
                              ref,
                              safeMeetings
                                  .where((m) => m.status == 'pending')
                                  .toList(),
                              'pending',
                            ),
                            _buildMeetingsList(
                              context,
                              ref,
                              safeMeetings
                                  .where((m) => m.status == 'accepted')
                                  .toList(),
                              'upcoming',
                            ),
                            _buildMeetingsList(
                              context,
                              ref,
                              safeMeetings
                                  .where((m) => m.status == 'rejected')
                                  .toList(),
                              'past',
                            ),
                          ],
                        );
                      },
                      loading: () => const Center(child: LoadingIndicator()),
                      error: (error, stack) => Center(
                        child: Text(
                          'Error loading meetings: $error',
                          style: const TextStyle(fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabBox({
    required String text,
    required int index,
    required int selectedIndex,
    required VoidCallback onTap,
  }) {
    final isSelected = selectedIndex == index;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? tabColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : tabColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMeetingsList(
    BuildContext context,
    WidgetRef ref,
    List<Meeting> meetings,
    String type,
  ) {
    if (meetings.isEmpty) {
      return Center(
        child: Text(
          type == 'pending'
              ? 'No pending meetings'
              : type == 'upcoming'
                  ? 'No upcoming meetings'
                  : 'No past meetings',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.namaMediumGray,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: meetings.length,
      itemBuilder: (context, index) {
        final meeting = meetings[index];
        return _buildMeetingCard(context, ref, meeting, type);
      },
    );
  }

  Widget _buildMeetingCard(
    BuildContext context,
    WidgetRef ref,
    Meeting meeting,
    String type,
  ) {
    final currentUserId = ref.watch(firebaseAuthProvider).currentUser?.uid;
    final isRequester = meeting.requesterId == currentUserId;
    final otherUserInfo =
        isRequester ? meeting.recipientInfo : meeting.requesterInfo;
    final otherUserName = (otherUserInfo['name'] ?? 'Unknown User').toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: AppColors.avatarPlaceholder,
              child: Text(
                otherUserName.isNotEmpty
                    ? otherUserName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.avatarPlaceholderText,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isRequester
                        ? 'Meeting with $otherUserName'
                        : 'Meeting request from $otherUserName',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM dd, yyyy at HH:mm')
                        .format(meeting.proposedTime.toDate()),
                    style: const TextStyle(fontSize: 11.5),
                  ),
                ],
              ),
            ),
            _buildStatusChip(meeting.status),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color chipColor;
    String label;

    switch (status) {
      case 'accepted':
        chipColor = Colors.green;
        label = 'Accepted';
        break;
      case 'rejected':
        chipColor = Colors.red;
        label = 'Rejected';
        break;
      case 'pending':
      default:
        chipColor = Colors.orange;
        label = 'Pending';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: chipColor,
        ),
      ),
    );
  }
}