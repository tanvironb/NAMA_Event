import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/core/models/meeting_model.dart';
import 'package:events_app_trueattempt/core/providers.dart';

class MyMeetingsScreen extends ConsumerWidget {
  final int initialTab;

  const MyMeetingsScreen({
    super.key,
    this.initialTab = 0,
  });

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
                        final safeMeetings =
                            meetings.whereType<Meeting>().toList();

                        return TabBarView(
                          children: [
                            _buildMeetingsList(
                              context,
                              ref,
                              safeMeetings
                                  .where(
                                    (meeting) =>
                                        meeting.status.toLowerCase().trim() ==
                                        'pending',
                                  )
                                  .toList(),
                              'pending',
                            ),
                            _buildMeetingsList(
                              context,
                              ref,
                              safeMeetings
                                  .where(
                                    (meeting) =>
                                        meeting.status.toLowerCase().trim() ==
                                        'accepted',
                                  )
                                  .toList(),
                              'upcoming',
                            ),
                            _buildMeetingsList(
                              context,
                              ref,
                              safeMeetings
                                  .where(
                                    (meeting) =>
                                        meeting.status.toLowerCase().trim() ==
                                        'rejected',
                                  )
                                  .toList(),
                              'past',
                            ),
                          ],
                        );
                      },
                      loading: () {
                        return const Center(
                          child: LoadingIndicator(),
                        );
                      },
                      error: (error, stack) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              'Error loading meetings: $error',
                              style: const TextStyle(fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      },
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
    final bool isSelected = selectedIndex == index;

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

        return _buildMeetingCard(
          context,
          ref,
          meeting,
          type,
        );
      },
    );
  }

  Widget _buildMeetingCard(
    BuildContext context,
    WidgetRef ref,
    Meeting meeting,
    String type,
  ) {
    final String? currentUserId =
        ref.watch(firebaseAuthProvider).currentUser?.uid;

    final bool isRequester = meeting.requesterId == currentUserId;

    final Map<String, dynamic> otherUserInfo =
        isRequester ? meeting.recipientInfo : meeting.requesterInfo;

    final String otherUserName =
        (otherUserInfo['name'] ?? 'Unknown User').toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MeetingDetailsScreen(
                meeting: meeting,
                currentUserId: currentUserId ?? '',
              ),
            ),
          );
        },
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
                      DateFormat('MMM dd, yyyy at HH:mm').format(
                        meeting.proposedTime.toDate(),
                      ),
                      style: const TextStyle(
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusChip(meeting.status),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color chipColor;
    String label;

    switch (status.toLowerCase().trim()) {
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
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 3,
      ),
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

class MeetingDetailsScreen extends StatelessWidget {
  final Meeting meeting;
  final String currentUserId;

  const MeetingDetailsScreen({
    super.key,
    required this.meeting,
    required this.currentUserId,
  });

  static const Color primaryColor = Color(0xFF3D3D9E);

  @override
  Widget build(BuildContext context) {
    final bool isRequester = meeting.requesterId == currentUserId;

    final Map<String, dynamic> otherUserInfo =
        isRequester ? meeting.recipientInfo : meeting.requesterInfo;

    final Map<String, dynamic> currentUserInfo =
        isRequester ? meeting.requesterInfo : meeting.recipientInfo;

    final String otherUserName =
        (otherUserInfo['name'] ?? 'Unknown User').toString();

    final String currentUserName =
        (currentUserInfo['name'] ?? 'You').toString();

    final String dateText = DateFormat('EEEE, MMMM dd, yyyy').format(
      meeting.proposedTime.toDate(),
    );

    final String timeText = DateFormat('hh:mm a').format(
      meeting.proposedTime.toDate(),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(20),
                        child: const Icon(
                          Icons.arrow_back,
                          size: 20,
                          color: AppColors.namaNavyBlue,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Meeting Details',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.namaNavyBlue,
                        ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderCard(
                      otherUserName: otherUserName,
                      isRequester: isRequester,
                    ),

                    const SizedBox(height: 16),

                    _buildSectionCard(
                      title: 'Meeting Information',
                      children: [
                        _buildInfoRow(
                          icon: Icons.info_outline_rounded,
                          label: 'Status',
                          value: _getStatusLabel(meeting.status),
                          trailing: _buildStatusChip(meeting.status),
                        ),
                        _buildInfoRow(
                          icon: Icons.calendar_today_rounded,
                          label: 'Date',
                          value: dateText,
                        ),
                        _buildInfoRow(
                          icon: Icons.access_time_rounded,
                          label: 'Time',
                          value: timeText,
                        ),
                        _buildInfoRow(
                          icon: Icons.location_on_outlined,
                          label: 'Location',
                          value: meeting.location.trim().isEmpty
                              ? 'Not specified'
                              : meeting.location,
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    _buildSectionCard(
                      title: 'Participants',
                      children: [
                        _buildInfoRow(
                          icon: Icons.person_outline_rounded,
                          label: 'Requester',
                          value:
                              (meeting.requesterInfo['name'] ?? 'Unknown User')
                                  .toString(),
                        ),
                        _buildInfoRow(
                          icon: Icons.person_add_alt_1_outlined,
                          label: 'Recipient',
                          value:
                              (meeting.recipientInfo['name'] ?? 'Unknown User')
                                  .toString(),
                        ),
                        _buildInfoRow(
                          icon: Icons.account_circle_outlined,
                          label: 'Viewing as',
                          value: currentUserName,
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    _buildSectionCard(
                      title: 'Request Details',
                      children: [
                        _buildInfoRow(
                          icon: Icons.confirmation_number_outlined,
                          label: 'Meeting ID',
                          value: meeting.id,
                        ),
                        _buildInfoRow(
                          icon: Icons.event_available_outlined,
                          label: 'Created',
                          value: DateFormat('MMM dd, yyyy at hh:mm a').format(
                            meeting.createdAt.toDate(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard({
    required String otherUserName,
    required bool isRequester,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white.withOpacity(0.16),
            child: Text(
              otherUserName.isNotEmpty ? otherUserName[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRequester
                      ? 'Meeting with $otherUserName'
                      : 'Meeting request from $otherUserName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _getStatusDescription(meeting.status),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.86),
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.black.withOpacity(0.04),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.namaNavyBlue,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: primaryColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.namaMediumGray,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.namaNavyBlue,
                    fontSize: 13.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color chipColor;
    String label;

    switch (status.toLowerCase().trim()) {
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
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: chipColor,
        ),
      ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase().trim()) {
      case 'accepted':
        return 'Accepted';
      case 'rejected':
        return 'Rejected';
      case 'pending':
      default:
        return 'Pending';
    }
  }

  String _getStatusDescription(String status) {
    switch (status.toLowerCase().trim()) {
      case 'accepted':
        return 'This meeting has been accepted and is ready.';
      case 'rejected':
        return 'This meeting request was rejected.';
      case 'pending':
      default:
        return 'This meeting request is waiting for response.';
    }
  }
}