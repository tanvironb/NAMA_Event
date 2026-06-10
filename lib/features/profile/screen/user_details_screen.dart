import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/core/models/app_user.dart';
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

            final hasContactInfo = appUser.email.isNotEmpty ||
                (canViewFullData &&
                    (appUser.personalEmail.isNotEmpty ||
                        appUser.phone.isNotEmpty));

            final hasSocialMedia = canViewFullData &&
                (appUser.linkedin.isNotEmpty ||
                    appUser.twitter.isNotEmpty ||
                    appUser.website.isNotEmpty ||
                    appUser.github.isNotEmpty ||
                    appUser.medium.isNotEmpty ||
                    appUser.instagram.isNotEmpty);

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
                      if (hasContactInfo) ...[
                        const SizedBox(height: 16),
                        _contactCard(context, appUser, canViewFullData),
                      ],
                      if (hasSocialMedia) ...[
                        const SizedBox(height: 16),
                        _socialMediaCard(context, appUser),
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
              icon: const Icon(
                Icons.arrow_back,
                size: 18,
                color: Colors.black87,
              ),
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
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 17,
                  color: Colors.black87,
                ),
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
    final imageUrl = appUser.profileImageUrl.trim();

    return CircleAvatar(
      radius: 45,
      backgroundColor: const Color(0xFFEFEFEF),
      backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
      child: imageUrl.isEmpty
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
            onPressed: () async {
              await _openDirectMessageFromNetworking(
                context: context,
                ref: ref,
                currentUserId: currentUserId,
                otherUser: appUser,
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
        const SizedBox(height: 8),
        SizedBox(
          width: 240,
          height: 40,
          child: OutlinedButton.icon(
            onPressed: () => _saveContact(context, appUser),
            icon: const Icon(Icons.person_add_alt_1_outlined, size: 15),
            label: const Text(
              'Save Contact',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green,
              side: const BorderSide(color: Colors.green, width: 1.5),
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

 Future<void> _saveContact(
  BuildContext context,
  AppUser appUser,
) async {
  final phone = appUser.phone.trim();

  if (phone.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No phone number available to save.'),
      ),
    );
    return;
  }

  final uri = Uri.parse('tel:$phone');

  await _launchUriWithFallback(context, uri);
}
  Future<void> _openDirectMessageFromNetworking({
    required BuildContext context,
    required WidgetRef ref,
    required String currentUserId,
    required AppUser otherUser,
  }) async {
    try {
      final activeEvent = await ref.read(activeEventFutureProvider.future);

      final conversationId =
          await ref.read(messagingRepositoryProvider).createOrGetConversation(
                currentUserId: currentUserId,
                otherUserId: otherUser.uid,
                eventId: activeEvent.id,
              );

      if (!context.mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => DirectMessageScreen(
            conversationId: conversationId,
            otherUserId: otherUser.uid,
            otherUserName: otherUser.name,
            otherUserProfileImage: otherUser.profileImageUrl,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to open conversation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _contactCard(
    BuildContext context,
    AppUser appUser,
    bool canViewFullData,
  ) {
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

  Widget _socialMediaCard(BuildContext context, AppUser appUser) {
    final items = <Widget>[];

    void addItem({
      required String label,
      required IconData icon,
      required String url,
    }) {
      if (url.trim().isEmpty) return;

      items.add(
        _socialGridItem(
          context,
          label: label,
          icon: icon,
          url: url,
        ),
      );
    }

    addItem(
      label: 'LinkedIn',
      icon: Icons.business_center_outlined,
      url: appUser.linkedin,
    );
    addItem(
      label: 'Twitter',
      icon: Icons.alternate_email,
      url: appUser.twitter,
    );
    addItem(
      label: 'Website',
      icon: Icons.language,
      url: appUser.website,
    );
    addItem(
      label: 'GitHub',
      icon: Icons.code,
      url: appUser.github,
    );
    addItem(
      label: 'Medium',
      icon: Icons.article_outlined,
      url: appUser.medium,
    );
    addItem(
      label: 'Instagram',
      icon: Icons.camera_alt_outlined,
      url: appUser.instagram,
    );

    return _card(
      title: 'Social Media',
      icon: Icons.public,
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 3.4,
        children: items,
      ),
    );
  }

  Widget _socialGridItem(
    BuildContext context, {
    required String label,
    required IconData icon,
    required String url,
  }) {
    return InkWell(
      onTap: () => _launchUrl(context, url),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFEDECF7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _mainColor.withOpacity(0.08),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: _mainColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _mainColor,
                ),
              ),
            ),
          ],
        ),
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
                overflow: TextOverflow.ellipsis,
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
                icon: const Icon(
                  Icons.arrow_back,
                  size: 18,
                  color: Colors.black87,
                ),
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
            const Expanded(
              child: Center(
                child: Text(
                  'This profile is private.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
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

  String _getRoleDisplayName(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'Admin';
      case 'staff':
        return 'Staff';
      case 'speaker':
        return 'Speaker';
      case 'attendee':
        return 'Attendee';
      default:
        return role;
    }
  }

  Future<void> _launchEmail(BuildContext context, String email) async {
    final Uri uri = Uri(
      scheme: 'mailto',
      path: email,
    );

    await _launchUriWithFallback(context, uri);
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    final fixedUrl = url.startsWith('http') ? url : 'https://$url';
    final uri = Uri.parse(fixedUrl);

    await _launchUriWithFallback(context, uri);
  }

  Future<void> _launchUriWithFallback(BuildContext context, Uri uri) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && context.mounted) {
        await Clipboard.setData(ClipboardData(text: uri.toString()));

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open link. Copied to clipboard.'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        await Clipboard.setData(ClipboardData(text: uri.toString()));

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open link. Copied to clipboard.'),
          ),
        );
      }
    }
  }
}