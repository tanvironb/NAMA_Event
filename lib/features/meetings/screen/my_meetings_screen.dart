// lib/features/meetings/screen/my_meetings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/core/models/meeting_model.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:intl/intl.dart';

class MyMeetingsScreen extends ConsumerWidget {
  const MyMeetingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meetingsAsync = ref.watch(meetingsStreamProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Meetings'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pending'),
              Tab(text: 'Upcoming'),
              Tab(text: 'Past'),
            ],
          ),
        ),
        body: meetingsAsync.when(
          data: (meetings) => TabBarView(
            children: [
              _buildMeetingsList(context, ref, meetings.where((m) => m.status == 'pending').toList(), 'pending'),
              _buildMeetingsList(context, ref, meetings.where((m) => m.status == 'accepted').toList(), 'upcoming'),
              _buildMeetingsList(context, ref, meetings.where((m) => m.status == 'rejected').toList(), 'past'),
            ],
          ),
          loading: () => const Center(child: LoadingIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text('Error loading meetings: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.refresh(meetingsStreamProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMeetingsList(BuildContext context, WidgetRef ref, List<Meeting> meetings, String type) {
    if (meetings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == 'pending' ? Icons.schedule : 
              type == 'upcoming' ? Icons.calendar_today : Icons.history,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              type == 'pending' ? 'No pending meetings' :
              type == 'upcoming' ? 'No upcoming meetings' : 'No past meetings',
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.namaMediumGray,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              type == 'pending' ? 'Meeting requests will appear here' :
              type == 'upcoming' ? 'Accepted meetings will appear here' : 'Completed meetings will appear here',
              style: const TextStyle(color: AppColors.namaMediumGray),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: meetings.length,
      itemBuilder: (context, index) {
        final meeting = meetings[index];
        return _buildMeetingCard(context, ref, meeting, type);
      },
    );
  }

  Widget _buildMeetingCard(BuildContext context, WidgetRef ref, Meeting meeting, String type) {
    final currentUserId = ref.watch(firebaseAuthProvider).currentUser?.uid;
    final isRequester = meeting.requesterId == currentUserId;
    final otherUserInfo = isRequester ? meeting.recipientInfo : meeting.requesterInfo;
    final otherUserName = otherUserInfo['name'] ?? 'Unknown User';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.avatarPlaceholder,
                  child: Text(
                    otherUserName.isNotEmpty ? otherUserName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: AppColors.avatarPlaceholderText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isRequester ? 'Meeting with $otherUserName' : 'Meeting request from $otherUserName',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('MMM dd, yyyy at HH:mm').format(meeting.proposedTime.toDate()),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      if (meeting.location.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                meeting.location,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                _buildStatusChip(meeting.status),
              ],
            ),
            
            // Show action buttons only for pending meetings and if current user is the recipient
            if (type == 'pending' && !isRequester) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _handleMeetingResponse(context, ref, meeting.id, 'rejected'),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Decline'),
                        style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.errorRed,
                        side: const BorderSide(color: AppColors.errorRed),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _handleMeetingResponse(context, ref, meeting.id, 'accepted'),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Accept'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.successGreen,
                        foregroundColor: AppColors.namaWhite,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;
    String label;

    switch (status) {
      case 'pending':
        backgroundColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange;
        label = 'Pending';
        break;
      case 'accepted':
        backgroundColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green;
        label = 'Accepted';
        break;
      case 'rejected':
        backgroundColor = Colors.red.withOpacity(0.1);
        textColor = Colors.red;
        label = 'Declined';
        break;
      default:
        backgroundColor = Colors.grey.withOpacity(0.1);
        textColor = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _handleMeetingResponse(BuildContext context, WidgetRef ref, String meetingId, String status) async {
    try {
      await ref.read(meetingRepositoryProvider).updateMeetingStatus(meetingId, status);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'accepted' ? 'Meeting accepted!' : 'Meeting declined.',
            ),
            backgroundColor: status == 'accepted' ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating meeting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}