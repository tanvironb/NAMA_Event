import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

  // Optimized animation durations for better performance on lower-end devices
  static const int _baseDuration = 400; // Reduced from 600ms
  static const int _staggerDelay = 50;   // Reduced from 100ms

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileByIdProvider(userId));
    final currentUserAsync = ref.watch(userAppProfileStreamProvider);
    final currentUserId = ref.watch(firebaseAuthProvider).currentUser?.uid;

    return userProfileAsync.when(
      data: (appUser) {
        if (appUser == null) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              title: const Text('Profile'),
              backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
              foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
              elevation: 0,
            ),
            body: const Center(
              child: Text(
                'User not found',
                style: TextStyle(fontSize: 16, color: AppColors.namaMediumGray),
              ),
            ),
          );
        }

        // Get current user to check admin status and determine privacy permissions
        return currentUserAsync.when(
          data: (currentUser) {
            final viewerIsAdmin = currentUser?.role == 'admin';
            final canViewProfile = appUser.canBeViewedBy(currentUserId ?? '', viewerIsAdmin);
            
            // If viewer cannot access this profile, show "ANONYMOUS" screen
            if (!canViewProfile) {
              return Scaffold(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                appBar: AppBar(
                  title: const Text('Profile'),
                  backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
                  foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
                  elevation: 0,
                ),
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.namaMediumGray.withOpacity(0.1),
                        ),
                        child: const Icon(
                          Icons.person_off_outlined,
                          size: 60,
                          color: AppColors.namaMediumGray,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Anonymous',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppColors.namaMediumGray,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 48),
                        child: Text(
                          'This user has chosen to remain anonymous.\nScan their QR code to connect.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.namaMediumGray.withOpacity(0.8),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            
            final canViewFullData = appUser.canViewFullDataBy(currentUserId ?? '', viewerIsAdmin);
            
            return Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              appBar: AppBar(
                title: const Text('Profile'),
                backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
                foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
                elevation: 0,
                actions: [
                  if (currentUserId == userId)
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 500),
                      tween: Tween(begin: 0.0, end: 1.0),
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: IconButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (context, animation, secondaryAnimation) =>
                                      EditProfileScreen(user: appUser),
                                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                    return SlideTransition(
                                      position: animation.drive(
                                        Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                                            .chain(CurveTween(curve: Curves.easeInOut)),
                                      ),
                                      child: child,
                                    );
                                  },
                                ),
                              );
                            },
                            icon: const Icon(Icons.edit_outlined),
                            color: AppColors.namaWhite,
                            iconSize: 24,
                            tooltip: 'Edit Profile',
                          ),
                        );
                      },
                    ),
                ],
              ),
              body: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      _buildProfileHeader(context, appUser, currentUserId, ref, viewerIsAdmin, canViewFullData),
                      _buildProfileContent(context, appUser, canViewFullData),
                    ],
                  ),
                ),
              ),
            );
          },
          loading: () => Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              title: const Text('Profile'),
              backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
              foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
              elevation: 0,
            ),
            body: const Center(child: LoadingIndicator()),
          ),
          error: (error, stack) => Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              title: const Text('Profile'),
              backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
              foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
              elevation: 0,
            ),
            body: const Center(
              child: Text(
                'Error loading viewer info',
                style: TextStyle(fontSize: 16, color: AppColors.namaMediumGray),
              ),
            ),
          ),
        );
      },
      loading: () => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
          elevation: 0,
        ),
        body: const Center(child: LoadingIndicator()),
      ),
      error: (error, stack) => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.namaMediumGray),
              const SizedBox(height: 16),
              Text(
                'Error loading profile',
                style: TextStyle(fontSize: 16, color: AppColors.namaMediumGray),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: TextStyle(fontSize: 12, color: AppColors.namaMediumGray),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, AppUser appUser, String? currentUserId, WidgetRef ref, bool viewerIsAdmin, bool canViewFullData) {
    final isConnected = appUser.isConnectedWith(currentUserId ?? '');
    
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 800),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              width: double.infinity,
              color: AppColors.namaWhite,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                children: [
                  Hero(
                    tag: 'profile_image_${appUser.uid}',
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.namaLightGray, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.namaNavyBlue.withOpacity(0.1),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: appUser.profileImageUrl.isNotEmpty
                            ? Image.network(
                                appUser.profileImageUrl,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return _buildLoadingAvatar();
                                },
                                errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
                              )
                            : _buildDefaultAvatar(),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 600),
                    tween: Tween(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: 0.8 + (0.2 * value),
                        child: Opacity(
                          opacity: value,
                          child: Text(
                            appUser.name,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: AppColors.namaNavyBlue,
                              letterSpacing: -0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    },
                  ),
                  
                  // Title
                  if (appUser.title.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 700),
                      tween: Tween(begin: 0.0, end: 1.0),
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 10 * (1 - value)),
                          child: Opacity(
                            opacity: value,
                            child: Text(
                              appUser.title,
                              style: TextStyle(
                              fontSize: 18,
                              color: AppColors.namaMediumGray,
                              fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  
                  // Role and Company Row
                  if (appUser.company.isNotEmpty || appUser.role.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 800),
                      tween: Tween(begin: 0.0, end: 1.0),
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 10 * (1 - value)),
                          child: Opacity(
                            opacity: value,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Role Badge (left side)
                                if (appUser.role.isNotEmpty && appUser.role != 'user') ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getRoleColor(appUser.role).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _getRoleColor(appUser.role).withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      _getRoleDisplayName(appUser.role),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _getRoleColor(appUser.role),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                
                                // Company Badge (right side)
                                if (appUser.company.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.namaNavyBlue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.business,
                                          size: 16,
                                          color: AppColors.namaNavyBlue,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          appUser.company,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: AppColors.namaNavyBlue,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  
                  // Privacy & Connection Indicators
                  if (currentUserId != userId && (viewerIsAdmin || appUser.isAnonymous || isConnected)) ...[
                    const SizedBox(height: 12),
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 850),
                      tween: Tween(begin: 0.0, end: 1.0),
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 10 * (1 - value)),
                          child: Opacity(
                            opacity: value,
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                // Connected Badge
                                if (isConnected)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.green.shade200,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.qr_code_scanner, size: 14, color: Colors.green.shade700),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Connected via QR',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.green.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                
                                // Privacy Level Indicator (Admin or Anonymous users)
                                if (viewerIsAdmin && appUser.isAnonymous)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.namaMediumGray.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.namaMediumGray.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '🕵️',
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Anonymous Mode',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.namaMediumGray,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                
                                // Limited Profile Badge (when not connected to anonymous user)
                                if (appUser.isAnonymous && !isConnected && !viewerIsAdmin)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.namaMediumGray.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.namaMediumGray.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.lock_outline, size: 12, color: AppColors.namaMediumGray),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Limited Profile',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.namaMediumGray,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  
                  // Social Icons Row (only show for Full privacy or Admin)
                  if (canViewFullData && (appUser.linkedin.isNotEmpty || appUser.twitter.isNotEmpty || appUser.website.isNotEmpty)) ...[
                    const SizedBox(height: 16),
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 900),
                      tween: Tween(begin: 0.0, end: 1.0),
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 10 * (1 - value)),
                          child: Opacity(
                            opacity: value,
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 12,
                              children: [
                                if (appUser.linkedin.isNotEmpty) 
                                  _buildSocialIcon('assets/icons/linkedin.svg', appUser.linkedin, 0),
                                if (appUser.twitter.isNotEmpty) 
                                  _buildSocialIcon('assets/icons/twitter.svg', appUser.twitter, 1),
                                if (appUser.github.isNotEmpty) 
                                  _buildSocialIcon('assets/icons/github.svg', appUser.github, 2),
                                if (appUser.medium.isNotEmpty) 
                                  _buildSocialIcon('assets/icons/medium.svg', appUser.medium, 3),
                                if (appUser.instagram.isNotEmpty) 
                                  _buildSocialIcon('assets/icons/instagram.svg', appUser.instagram, 4),
                                if (appUser.website.isNotEmpty) 
                                  _buildSocialIcon('assets/icons/website.svg', appUser.website, 5),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  
                  const SizedBox(height: 32),
                  
                  if (currentUserId != userId) ...[
                    _buildActionButtons(context, appUser, currentUserId!, ref),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            AppColors.namaNavyBlue.withOpacity(0.1),
            AppColors.namaNavyBlue.withOpacity(0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(
        Icons.person_outline,
        size: 50,
        color: AppColors.namaNavyBlue,
      ),
    );
  }

  Widget _buildLoadingAvatar() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.namaLightGray,
      ),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.namaNavyBlue),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, AppUser appUser, String currentUserId, WidgetRef ref) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1000),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Column(
            children: [
              // Say Hi button (always available - messaging is open to all)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Navigate directly to chat without creating conversation
                    // Conversation will be created when first message is sent
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => DirectMessageScreen(
                        conversationId: null, // Don't create conversation yet
                        otherUserId: appUser.uid,
                        otherUserName: appUser.name,
                        otherUserProfileImage: appUser.profileImageUrl,
                      ),
                    ));
                  },
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text(
                    'Say Hi',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.namaNavyBlue,
                    foregroundColor: AppColors.namaWhite,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: AppColors.namaNavyBlue.withOpacity(0.3),
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Request Meeting button (always available)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => RequestMeetingScreen(recipient: appUser),
                      ),
                    );
                  },
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: const Text(
                    'Request Meeting',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.namaNavyBlue,
                    side: const BorderSide(color: AppColors.namaNavyBlue, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              
              // Book All Sessions button (only for speakers)
              if (appUser.role == 'speaker') ...[
                const SizedBox(height: 12),
                SpeakerSessionsBookmarkButton(speakerId: appUser.uid),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileContent(BuildContext context, AppUser appUser, bool canViewFullData) {
    return Container(
      color: AppColors.namaVeryLightGray,
      child: Column(
        children: [
          // Bio section (only show for Full privacy or Admin)
          if (canViewFullData && appUser.bio.isNotEmpty) 
            _buildAnimatedSection('About', appUser.bio, Icons.info_outline, 0),
          
          // Contact section (email always visible, phone only for Full privacy or Admin)
          if (appUser.email.isNotEmpty || (canViewFullData && appUser.phone.isNotEmpty))
            _buildContactSection(context, appUser, canViewFullData),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildAnimatedSection(String title, String content, IconData icon, int delay) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 600 + (delay * 200)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              margin: const EdgeInsets.only(top: 24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 1,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.namaNavyBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: AppColors.namaNavyBlue, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.namaNavyBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    content,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                      height: 1.6,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }



  Widget _buildContactSection(BuildContext context, AppUser appUser, bool canViewFullData) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1000),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              margin: const EdgeInsets.only(top: 24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 1,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.namaNavyBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.contact_phone, color: AppColors.namaNavyBlue, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Contact',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.namaNavyBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (appUser.email.isNotEmpty)
                    _buildEmailTile(context, appUser.email, 0),
                  // Phone is only visible for Full privacy or Admin
                  if (canViewFullData && appUser.phone.isNotEmpty)
                    _buildContactTile(context, Icons.phone_outlined, 'Phone', appUser.phone, 'tel:${appUser.phone}', 1),
                ],
              ),
            ),
          ),
        );
      },
    );
  }



  Widget _buildContactTile(BuildContext context, IconData icon, String label, String value, String url, int delay) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (delay * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, animationValue, child) {
        return Transform.translate(
          offset: Offset(20 * (1 - animationValue), 0),
          child: Opacity(
            opacity: animationValue,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 16),
              child: InkWell(
                onTap: () => _launchUrl(context, url),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[200]!, width: 1.5),
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.namaNavyBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, size: 24, color: AppColors.namaNavyBlue),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.namaNavyBlue,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              value,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.namaNavyBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: AppColors.namaNavyBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    String cleanUrl = url.trim();
    if (!cleanUrl.startsWith('http') && !cleanUrl.startsWith('mailto:') && !cleanUrl.startsWith('tel:')) {
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
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Could not open: $url')),
              ],
            ),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  // Helper method to get role color based on user role
  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'speaker':
        return AppColors.speakerColor;
      case 'staff':
        return AppColors.staffColor;
      case 'admin':
        return AppColors.adminColor;
      case 'attendee':
      default:
        return AppColors.attendeeColor;
    }
  }

  // Helper method to get display name for user role
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
        return role.toUpperCase();
    }
  }

  // Helper method to build social icons
  Widget _buildSocialIcon(String iconPath, String url, int delay) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: _baseDuration + (delay * _staggerDelay)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, animationValue, child) {
        return Transform.scale(
          scale: animationValue,
          child: GestureDetector(
            onTap: () => _launchUrl(context, url),
            child: Container(
              width: 32,
              height: 32,
              padding: const EdgeInsets.all(4), // Reduced padding
              decoration: BoxDecoration(
                color: AppColors.namaNavyBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8), // Squared with rounded edges
                border: Border.all(
                  color: AppColors.namaNavyBlue.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: SvgPicture.asset(
                iconPath,
                width: 24,
                height: 24,
                colorFilter: const ColorFilter.mode(
                  AppColors.namaNavyBlue,
                  BlendMode.srcIn,
                ),
                placeholderBuilder: (context) => 
                  const Icon(Icons.link, size: 20, color: AppColors.namaNavyBlue),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmailTile(BuildContext context, String email, int delay) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (delay * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, animationValue, child) {
        return Transform.translate(
          offset: Offset(20 * (1 - animationValue), 0),
          child: Opacity(
            opacity: animationValue,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 16),
              child: InkWell(
                onTap: () => _launchEmail(context, email),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[200]!, width: 1.5),
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.namaNavyBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.email_outlined, size: 24, color: AppColors.namaNavyBlue),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Email',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.namaNavyBlue,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              email,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.namaNavyBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: AppColors.namaNavyBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _launchEmail(BuildContext context, String email) async {
    try {
      // Simple and direct mailto approach that works on most platforms
      final emailUri = Uri.parse('mailto:$email');
      
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri, mode: LaunchMode.externalApplication);
      } else {
        throw 'No email app available';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                const Expanded(child: Text('Could not open email app')),
              ],
            ),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            action: SnackBarAction(
              label: 'Copy Email',
              textColor: Colors.white,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: email));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Email copied to clipboard'),
                    backgroundColor: Colors.green[600],
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
          ),
        );
      }
    }
  }
}