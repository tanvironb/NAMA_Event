import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/core/models/app_user.dart';
import 'package:events_app_trueattempt/core/constants/app_text_constants.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/features/profile/screen/edit_profile_screen.dart';
import 'package:events_app_trueattempt/features/messaging/screen/direct_message_screen.dart';
import 'package:events_app_trueattempt/features/profile/screen/widgets/speaker_sessions_bookmark_button.dart';
import 'package:events_app_trueattempt/features/meetings/screen/request_meeting_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class UserDetailsScreen extends ConsumerWidget {
  final String userId;

  const UserDetailsScreen({super.key, required this.userId});

  static const Color _mainColor = Color(0xFF24158A);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileByIdProvider(userId));
    final currentUserAsync = ref.watch(userAppProfileStreamProvider);
    final currentUserId = ref.watch(firebaseAuthProvider).currentUser?.uid;

    return userProfileAsync.when(
      data: (appUser) {
        if (appUser == null) {
          return _simpleScaffold(context, 'User not found');
        }

        return currentUserAsync.when(
          data: (currentUser) {
            final viewerIsAdmin = currentUser?.role == 'admin';
            final canViewProfile =
                appUser.canBeViewedBy(currentUserId ?? '', viewerIsAdmin);

            if (!canViewProfile) {
              return _anonymousScreen(context);
            }

            final canViewFullData =
                appUser.canViewFullDataBy(currentUserId ?? '', viewerIsAdmin);

            return Scaffold(
              backgroundColor: Colors.white,
              body: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 25),
                  child: Column(
                    children: [
                      _topBar(context, appUser, currentUserId),

                      const SizedBox(height: 25),

                      _profileImage(appUser),

                      const SizedBox(height: 16),

                      Text(
                        appUser.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: _mainColor,
                        ),
                      ),

                      if (appUser.title.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          appUser.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],

                      const SizedBox(height: 10),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (appUser.role.isNotEmpty && appUser.role != 'user')
                            _tag(_getRoleDisplayName(appUser.role)),
                          if (appUser.role.isNotEmpty &&
                              appUser.role != 'user' &&
                              appUser.company.isNotEmpty)
                            const SizedBox(width: 8),
                          if (appUser.company.isNotEmpty)
                            _tag(appUser.company, icon: Icons.business),
                        ],
                      ),

                      const SizedBox(height: 18),

                      if (currentUserId != null && currentUserId != userId)
                        _actionButtons(context, appUser, currentUserId, ref),

                      const SizedBox(height: 20),

                      if (canViewFullData && appUser.bio.isNotEmpty)
                        _card(
                          title: 'About',
                          icon: Icons.info_outline,
                          child: Text(
                            appUser.bio,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: Colors.black87,
                            ),
                          ),
                        ),

                      if (appUser.email.isNotEmpty ||
                          (canViewFullData && appUser.phone.isNotEmpty)) ...[
                        const SizedBox(height: 16),
                        _contactCard(context, appUser, canViewFullData),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
          loading: () => _loadingScaffold(context),
          error: (error, stack) =>
              _simpleScaffold(context, 'Error loading viewer info'),
        );
      },
      loading: () => _loadingScaffold(context),
      error: (error, stack) => _simpleScaffold(context, 'Error loading profile'),
    );
  }

  Widget _topBar(BuildContext context, AppUser appUser, String? currentUserId) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey.shade300,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.arrow_back, size: 18, color: Colors.black87),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        const Text(
          'Profile',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: _mainColor,
          ),
        ),
        if (currentUserId == userId)
          Align(
            alignment: Alignment.centerRight,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey.shade300,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.edit_outlined,
                    size: 17, color: Colors.black87),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditProfileScreen(user: appUser),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _profileImage(AppUser appUser) {
    return CircleAvatar(
      radius: 45,
      backgroundColor: const Color(0xFFEFEFEF),
      backgroundImage: appUser.profileImageUrl.isNotEmpty
          ? NetworkImage(appUser.profileImageUrl)
          : null,
      child: appUser.profileImageUrl.isEmpty
          ? const Icon(Icons.person, size: 40, color: _mainColor)
          : null,
    );
  }

  Widget _tag(String text, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEDECF7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: _mainColor),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: _mainColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButtons(
    BuildContext context,
    AppUser appUser,
    String currentUserId,
    WidgetRef ref,
  ) {
    return Column(
      children: [
        SizedBox(
          width: 240,
          height: 40,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => DirectMessageScreen(
                    conversationId: null,
                    otherUserId: appUser.uid,
                    otherUserName: appUser.name,
                    otherUserProfileImage: appUser.profileImageUrl,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.chat_bubble_outline, size: 16),
            label: const Text(
              'Say Hi',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _mainColor,
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        SizedBox(
          width: 240,
          height: 40,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => RequestMeetingScreen(recipient: appUser),
                ),
              );
            },
            icon: const Icon(Icons.calendar_today_outlined, size: 15),
            label: const Text(
              'Request Meeting',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _mainColor,
              side: const BorderSide(color: _mainColor, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),

        if (appUser.role == 'speaker') ...[
          const SizedBox(height: 8),
          SizedBox(
            width: 240,
            height: 40,
            child: Center(
              child: SpeakerSessionsBookmarkButton(
                speakerId: appUser.uid,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _card({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: _mainColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: _mainColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _contactCard(
      BuildContext context, AppUser appUser, bool canViewFullData) {
    return _card(
      title: 'Contact',
      icon: Icons.contact_mail_outlined,
      child: Column(
        children: [
          if (appUser.email.isNotEmpty)
            _contactRow(
              context,
              icon: Icons.email_outlined,
              text: appUser.email,
              onTap: () => _launchEmail(context, appUser.email),
            ),
          if (canViewFullData && appUser.personalEmail.isNotEmpty)
            _contactRow(
              context,
              icon: Icons.alternate_email,
              text: appUser.personalEmail,
              onTap: () => _launchEmail(context, appUser.personalEmail),
            ),
          if (canViewFullData && appUser.phone.isNotEmpty)
            _contactRow(
              context,
              icon: Icons.phone_outlined,
              text: appUser.phone,
              onTap: () => _launchUrl(context, 'tel:${appUser.phone}'),
            ),
        ],
      ),
    );
  }

  Widget _contactRow(
    BuildContext context, {
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Scaffold _loadingScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 18),
            _topBarOnlyBack(context),
            const Expanded(child: Center(child: LoadingIndicator())),
          ],
        ),
      ),
    );
  }

  Scaffold _simpleScaffold(BuildContext context, String message) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 18),
            _topBarOnlyBack(context),
            Expanded(
              child: Center(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.namaMediumGray,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBarOnlyBack(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey.shade300,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.arrow_back,
                    size: 18, color: Colors.black87),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          const Text(
            'Profile',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: _mainColor,
            ),
          ),
        ],
      ),
    );
  }

  Scaffold _anonymousScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 18),
            _topBarOnlyBack(context),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 45,
                        backgroundColor: Colors.grey.shade200,
                        child: const Icon(
                          Icons.person_off_outlined,
                          size: 42,
                          color: AppColors.namaMediumGray,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        AppTextConstants.anonymousProfileTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppColors.namaMediumGray,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        AppTextConstants.anonymousProfileMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRoleDisplayName(String role) {
    switch (role.toLowerCase()) {
      case 'speaker':
        return 'Speaker';
      case 'staff':
        return 'Staff';
      case 'admin':
        return 'Admin';
      case 'attendee':
        return 'Attendee';
      default:
        return role;
    }
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    String cleanUrl = url.trim();

    if (!cleanUrl.startsWith('http') &&
        !cleanUrl.startsWith('mailto:') &&
        !cleanUrl.startsWith('tel:')) {
      cleanUrl = 'https://$cleanUrl';
    }

    try {
      final uri = Uri.parse(cleanUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch URL';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open: $url'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }

  Future<void> _launchEmail(BuildContext context, String email) async {
    try {
      final emailUri = Uri.parse('mailto:$email');

      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri, mode: LaunchMode.externalApplication);
      } else {
        throw 'No email app available';
      }
    } catch (e) {
      if (context.mounted) {
        Clipboard.setData(ClipboardData(text: email));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Email copied to clipboard'),
            backgroundColor: Colors.green[600],
          ),
        );
      }
    }
  }
}