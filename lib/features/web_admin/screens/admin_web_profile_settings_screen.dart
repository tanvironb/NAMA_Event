// lib/features/web_admin/screens/admin_web_profile_settings_screen.dart

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../admin_web_theme.dart';

class AdminWebProfileSettingsScreen extends StatefulWidget {
  final String adminUserId;
  final String adminName;
  final String adminEmail;
  final String profileImageUrl;

  const AdminWebProfileSettingsScreen({
    super.key,
    required this.adminUserId,
    required this.adminName,
    required this.adminEmail,
    required this.profileImageUrl,
  });

  @override
  State<AdminWebProfileSettingsScreen> createState() =>
      _AdminWebProfileSettingsScreenState();
}

enum _ProfileSettingsSection {
  profile,
  settings,
}

class _AdminWebProfileSettingsScreenState
    extends State<AdminWebProfileSettingsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  _ProfileSettingsSection _selectedSection =
      _ProfileSettingsSection.profile;

  Uint8List? _selectedProfileImageBytes;
  XFile? _selectedProfileImage;

  String _profileImageUrl = '';
  String _role = 'admin';
  String _status = 'approved';

  bool _isLoading = true;
  bool _isSavingProfile = false;
  bool _isLoggingOut = false;

  DocumentReference<Map<String, dynamic>> get _userReference {
    return _firestore.collection('users').doc(widget.adminUserId);
  }

  @override
  void initState() {
    super.initState();

    _nameController.text = widget.adminName;
    _profileImageUrl = widget.profileImageUrl;

    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final document = await _userReference.get();
      final data = document.data() ?? <String, dynamic>{};

      if (!mounted) return;

      setState(() {
        _nameController.text =
            (data['name'] ?? widget.adminName).toString();
        _phoneController.text =
            (data['phoneNumber'] ?? data['phone'] ?? '').toString();
        _bioController.text = (data['bio'] ?? '').toString();

        _profileImageUrl =
            (data['profileImageUrl'] ?? widget.profileImageUrl).toString();

        _role = (data['role'] ?? 'admin').toString();
        _status = (data['status'] ?? 'approved').toString();

        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      _showMessage(
        'Unable to load administrator profile: $error',
        error: true,
      );
    }
  }

  Future<void> _pickProfileImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 1200,
      maxHeight: 1200,
    );

    if (image == null) return;

    final bytes = await image.readAsBytes();

    if (!mounted) return;

    setState(() {
      _selectedProfileImage = image;
      _selectedProfileImageBytes = bytes;
    });
  }

  Future<String> _uploadProfileImage() async {
    if (_selectedProfileImage == null ||
        _selectedProfileImageBytes == null) {
      return _profileImageUrl;
    }

    final extension =
        _selectedProfileImage!.name.split('.').last.toLowerCase();

    final safeExtension =
        const ['png', 'jpg', 'jpeg', 'webp'].contains(extension)
            ? extension
            : 'jpg';

    final storagePath =
        'profile_images/${widget.adminUserId}/admin_profile.$safeExtension';

    final reference = _storage.ref(storagePath);

    await reference.putData(
      _selectedProfileImageBytes!,
      SettableMetadata(
        contentType: safeExtension == 'png'
            ? 'image/png'
            : safeExtension == 'webp'
                ? 'image/webp'
                : 'image/jpeg',
      ),
    );

    return reference.getDownloadURL();
  }

  Future<void> _saveProfile() async {
    if (_isSavingProfile) return;

    final name = _nameController.text.trim();

    if (name.isEmpty) {
      _showMessage(
        'Full name cannot be empty.',
        error: true,
      );
      return;
    }

    setState(() => _isSavingProfile = true);

    try {
      final imageUrl = await _uploadProfileImage();

      await _userReference.set(
        {
          'name': name,
          'phoneNumber': _phoneController.text.trim(),
          'bio': _bioController.text.trim(),
          'profileImageUrl': imageUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      setState(() {
        _profileImageUrl = imageUrl;
        _selectedProfileImage = null;
        _selectedProfileImageBytes = null;
      });

      _showMessage('Profile information saved successfully.');
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Failed to save profile: $error',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingProfile = false);
      }
    }
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.logout_rounded,
                color: Colors.redAccent,
              ),
              SizedBox(width: 10),
              Text('Log Out'),
            ],
          ),
          content: const Text(
            'Are you sure you want to log out from the admin panel?',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoggingOut = true);

    try {
      await FirebaseAuth.instance.signOut();
    } catch (error) {
      if (!mounted) return;

      setState(() => _isLoggingOut = false);

      _showMessage(
        'Logout failed: $error',
        error: true,
      );
    }
  }

  Future<void> _openAboutEventDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _AboutEventEditorDialog(),
    );

    if (result == true && mounted) {
      _showMessage('About Event information saved.');
    }
  }

  Future<void> _openPrivacyDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _PrivacyPolicyEditorDialog(),
    );

    if (result == true && mounted) {
      _showMessage('Privacy information saved.');
    }
  }

  void _showMessage(
    String message, {
    bool error = false,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              error ? Colors.redAccent : AdminWebTheme.primary,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AdminWebTheme.primary,
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profile & Settings',
            style: TextStyle(
              color: AdminWebTheme.textPrimary,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Manage your administrator profile and application information.',
            style: TextStyle(
              color: AdminWebTheme.textSecondary,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 1050;

              final sidePanel = _ProfileSidePanel(
                name: _nameController.text.trim().isEmpty
                    ? widget.adminName
                    : _nameController.text.trim(),
                email: widget.adminEmail,
                role: _role,
                status: _status,
                imageUrl: _profileImageUrl,
                selectedImageBytes: _selectedProfileImageBytes,
                selectedSection: _selectedSection,
                isLoggingOut: _isLoggingOut,
                onSectionChanged: (section) {
                  setState(() => _selectedSection = section);
                },
                onLogout: _logout,
              );

              final content = _buildSelectedContent();

              if (!isWide) {
                return Column(
                  children: [
                    sidePanel,
                    const SizedBox(height: 18),
                    content,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 305,
                    child: sidePanel,
                  ),
                  const SizedBox(width: 20),
                  Expanded(child: content),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedContent() {
    switch (_selectedSection) {
      case _ProfileSettingsSection.settings:
        return _SettingsOverviewPanel(
          onOpenAboutEvent: _openAboutEventDialog,
          onOpenPrivacy: _openPrivacyDialog,
        );

      case _ProfileSettingsSection.profile:
        return _ProfileInformationCard(
          nameController: _nameController,
          phoneController: _phoneController,
          bioController: _bioController,
          email: widget.adminEmail,
          role: _role,
          isSaving: _isSavingProfile,
          onPickImage: _pickProfileImage,
          onSave: _saveProfile,
          onNameChanged: (_) => setState(() {}),
        );
    }
  }
}

class _ProfileSidePanel extends StatelessWidget {
  final String name;
  final String email;
  final String role;
  final String status;
  final String imageUrl;
  final Uint8List? selectedImageBytes;
  final _ProfileSettingsSection selectedSection;
  final bool isLoggingOut;
  final ValueChanged<_ProfileSettingsSection> onSectionChanged;
  final VoidCallback onLogout;

  const _ProfileSidePanel({
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    required this.imageUrl,
    required this.selectedImageBytes,
    required this.selectedSection,
    required this.isLoggingOut,
    required this.onSectionChanged,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedStatus = status.trim().toLowerCase();

    final isActive = normalizedStatus != 'rejected' &&
        normalizedStatus != 'disabled';

    return Container(
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: 112,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF17178C),
                  Color(0xFF0B0B5D),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -45),
            child: Column(
              children: [
                Container(
                  width: 92,
                  height: 92,
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: _ProfileImage(
                      imageUrl: imageUrl,
                      selectedImageBytes: selectedImageBytes,
                      fallbackName: name,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AdminWebTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _displayRole(role),
                  style: const TextStyle(
                    color: AdminWebTheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.email_outlined,
                        size: 15,
                        color: AdminWebTheme.textSecondary,
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          email,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AdminWebTheme.textSecondary,
                            fontSize: 9.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFFDCF7E8)
                        : const Color(0xFFFFE4E8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isActive ? 'Active' : 'Disabled',
                    style: TextStyle(
                      color: isActive
                          ? const Color(0xFF14834F)
                          : Colors.redAccent,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -22),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              child: Column(
                children: [
                  _SideMenuItem(
                    label: 'Profile Information',
                    icon: Icons.person_outline_rounded,
                    selected: selectedSection ==
                        _ProfileSettingsSection.profile,
                    onTap: () => onSectionChanged(
                      _ProfileSettingsSection.profile,
                    ),
                  ),
                  _SideMenuItem(
                    label: 'Settings',
                    icon: Icons.settings_outlined,
                    selected: selectedSection ==
                        _ProfileSettingsSection.settings,
                    onTap: () => onSectionChanged(
                      _ProfileSettingsSection.settings,
                    ),
                  ),
                  const Divider(height: 26),
                  _SideMenuItem(
                    label:
                        isLoggingOut ? 'Logging out...' : 'Logout',
                    icon: Icons.logout_rounded,
                    color: Colors.redAccent,
                    selected: false,
                    onTap: isLoggingOut ? null : onLogout,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileInformationCard extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController bioController;
  final String email;
  final String role;
  final bool isSaving;
  final VoidCallback onPickImage;
  final VoidCallback onSave;
  final ValueChanged<String> onNameChanged;

  const _ProfileInformationCard({
    required this.nameController,
    required this.phoneController,
    required this.bioController,
    required this.email,
    required this.role,
    required this.isSaving,
    required this.onPickImage,
    required this.onSave,
    required this.onNameChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.person_outline_rounded,
      title: 'Profile Information',
      subtitle: 'Update your personal information and profile picture.',
      action: OutlinedButton.icon(
        onPressed: isSaving ? null : onPickImage,
        icon: const Icon(
          Icons.photo_camera_outlined,
          size: 16,
        ),
        label: const Text('Change Photo'),
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stackFields = constraints.maxWidth < 700;

              final nameField = TextField(
                controller: nameController,
                onChanged: onNameChanged,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                ),
              );

              final emailField = TextField(
                controller: TextEditingController(text: email),
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                ),
              );

              if (stackFields) {
                return Column(
                  children: [
                    nameField,
                    const SizedBox(height: 14),
                    emailField,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: nameField),
                  const SizedBox(width: 14),
                  Expanded(child: emailField),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final stackFields = constraints.maxWidth < 700;

              final phoneField = TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                ),
              );

              final roleField = TextField(
                controller: TextEditingController(
                  text: _displayRole(role),
                ),
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'Role',
                ),
              );

              if (stackFields) {
                return Column(
                  children: [
                    phoneField,
                    const SizedBox(height: 14),
                    roleField,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: phoneField),
                  const SizedBox(width: 14),
                  Expanded(child: roleField),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: bioController,
            minLines: 5,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Bio',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: isSaving ? null : onSave,
              icon: isSaving
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.save_outlined,
                      size: 17,
                    ),
              label: Text(
                isSaving ? 'Saving...' : 'Save Changes',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AdminWebTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsOverviewPanel extends StatelessWidget {
  final VoidCallback onOpenAboutEvent;
  final VoidCallback onOpenPrivacy;

  const _SettingsOverviewPanel({
    required this.onOpenAboutEvent,
    required this.onOpenPrivacy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            icon: Icons.settings_outlined,
            title: 'Settings',
            subtitle: 'Manage application settings and information.',
          ),
          const SizedBox(height: 18),
          _SettingsFeatureCard(
            icon: Icons.info_outline_rounded,
            title: 'About Event',
            subtitle: 'Information about the current active event.',
            description:
                'This information will be visible to all users in the mobile app under “About Event”.',
            actionLabel: 'View / Edit About Event',
            illustration: const _AboutIllustration(),
            onTap: onOpenAboutEvent,
          ),
          const SizedBox(height: 14),
          _SettingsFeatureCard(
            icon: Icons.shield_outlined,
            title: 'Privacy',
            subtitle: 'Manage application privacy and policies.',
            description:
                'View or update the privacy policy and account deletion information.',
            actionLabel: 'View Privacy Policy',
            illustration: const _PrivacyIllustration(),
            onTap: onOpenPrivacy,
          ),
        ],
      ),
    );
  }
}

class _SettingsFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final String actionLabel;
  final Widget illustration;
  final VoidCallback onTap;

  const _SettingsFeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.actionLabel,
    required this.illustration,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFCFE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AdminWebTheme.border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeading(
                  icon: icon,
                  title: title,
                  subtitle: subtitle,
                  compact: true,
                ),
                const SizedBox(height: 18),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 470),
                  child: Text(
                    description,
                    style: const TextStyle(
                      color: AdminWebTheme.textSecondary,
                      fontSize: 10.5,
                      height: 1.55,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: onTap,
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(
                    Icons.chevron_right_rounded,
                    size: 17,
                  ),
                  label: Text(actionLabel),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AdminWebTheme.primary,
                    side: const BorderSide(
                      color: AdminWebTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          SizedBox(
            width: 130,
            height: 130,
            child: illustration,
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool compact;

  const _SectionHeading({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: compact ? 38 : 42,
          height: compact ? 38 : 42,
          decoration: BoxDecoration(
            color: AdminWebTheme.primary.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: AdminWebTheme.primary,
            size: compact ? 18 : 21,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AdminWebTheme.textPrimary,
                  fontSize: compact ? 12.5 : 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AdminWebTheme.textSecondary,
                  fontSize: 9.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AboutIllustration extends StatelessWidget {
  const _AboutIllustration();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 76,
          height: 92,
          decoration: BoxDecoration(
            color: const Color(0xFFE8E8FF),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        Positioned(
          top: 25,
          child: Container(
            width: 52,
            height: 8,
            decoration: BoxDecoration(
              color: AdminWebTheme.primary.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        Positioned(
          top: 42,
          child: Container(
            width: 42,
            height: 7,
            decoration: BoxDecoration(
              color: AdminWebTheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        Positioned(
          right: 13,
          bottom: 18,
          child: Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: AdminWebTheme.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: Colors.white,
              size: 21,
            ),
          ),
        ),
      ],
    );
  }
}

class _PrivacyIllustration extends StatelessWidget {
  const _PrivacyIllustration();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          left: 10,
          bottom: 16,
          child: Container(
            width: 54,
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFFEDEEFF),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        Container(
          width: 78,
          height: 86,
          decoration: BoxDecoration(
            color: const Color(0xFF7A78F2),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.lock_outline_rounded,
            color: Colors.white,
            size: 35,
          ),
        ),
      ],
    );
  }
}

class _AboutEventEditorDialog extends StatefulWidget {
  const _AboutEventEditorDialog();

  @override
  State<_AboutEventEditorDialog> createState() =>
      _AboutEventEditorDialogState();
}

class _AboutEventEditorDialogState
    extends State<_AboutEventEditorDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _eventNameController =
      TextEditingController();
  final TextEditingController _descriptionController =
      TextEditingController();
  final TextEditingController _aboutController =
      TextEditingController();

  String? _eventId;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadActiveEvent();
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    _descriptionController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  Future<void> _loadActiveEvent() async {
    try {
      final snapshot = await _firestore
          .collection('events')
          .where('isActive', isEqualTo: true)
          .get();

      final activeDocuments = snapshot.docs.where((document) {
        final status = (document.data()['status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        return status != 'archived';
      }).toList();

      if (activeDocuments.isEmpty) {
        throw Exception('No active event was found.');
      }

      final document = activeDocuments.first;
      final data = document.data();

      if (!mounted) return;

      setState(() {
        _eventId = document.id;
        _eventNameController.text =
            (data['name'] ?? data['eventName'] ?? 'Current Event')
                .toString();
        _descriptionController.text =
            (data['description'] ?? '').toString();
        _aboutController.text =
            (data['aboutEvent'] ?? '').toString();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Exception: ', ''),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _save() async {
    if (_eventId == null || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      await _firestore.collection('events').doc(_eventId).set(
        {
          'description': _descriptionController.text.trim(),
          'aboutEvent': _aboutController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save About Event: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 780,
          maxHeight: 760,
        ),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AdminWebTheme.primary,
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'About Event',
                            style: TextStyle(
                              color: AdminWebTheme.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _isSaving
                              ? null
                              : () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Edit the content shown in the mobile app About Event page.',
                      style: TextStyle(
                        color: AdminWebTheme.textSecondary,
                        fontSize: 10.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _eventNameController,
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: 'Active Event',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _descriptionController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Short Description',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: TextField(
                        controller: _aboutController,
                        expands: true,
                        minLines: null,
                        maxLines: null,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: const InputDecoration(
                          labelText: 'About Event Content',
                          alignLabelWithHint: true,
                          hintText:
                              'Write the complete event introduction and information.',
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _isSaving ? null : _save,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.save_outlined,
                                size: 17,
                              ),
                        label: Text(
                          _isSaving ? 'Saving...' : 'Save About Event',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AdminWebTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _PrivacyPolicyEditorDialog extends StatefulWidget {
  const _PrivacyPolicyEditorDialog();

  @override
  State<_PrivacyPolicyEditorDialog> createState() =>
      _PrivacyPolicyEditorDialogState();
}

class _PrivacyPolicyEditorDialogState
    extends State<_PrivacyPolicyEditorDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _titleController =
      TextEditingController();
  final TextEditingController _privacyUrlController =
      TextEditingController();
  final TextEditingController _policyController =
      TextEditingController();
  final TextEditingController _deletionTitleController =
      TextEditingController();
  final TextEditingController _deletionInstructionsController =
      TextEditingController();
  final TextEditingController _contactEmailController =
      TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  DocumentReference<Map<String, dynamic>> get _privacyReference {
    return _firestore
        .collection('appSettings')
        .doc('privacyPolicy');
  }

  @override
  void initState() {
    super.initState();
    _loadPrivacy();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _privacyUrlController.dispose();
    _policyController.dispose();
    _deletionTitleController.dispose();
    _deletionInstructionsController.dispose();
    _contactEmailController.dispose();
    super.dispose();
  }

  Future<void> _loadPrivacy() async {
    try {
      final document = await _privacyReference.get();
      final data = document.data() ?? <String, dynamic>{};

      if (!mounted) return;

      setState(() {
        _titleController.text =
            (data['title'] ?? 'Privacy Policy').toString();
        _privacyUrlController.text =
            (data['privacyPolicyUrl'] ?? '').toString();
        _policyController.text =
            (data['privacyPolicyContent'] ?? '').toString();
        _deletionTitleController.text =
            (data['accountDeletionTitle'] ?? 'Account Deletion')
                .toString();
        _deletionInstructionsController.text =
            (data['accountDeletionInstructions'] ?? '').toString();
        _contactEmailController.text =
            (data['contactEmail'] ?? '').toString();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to load privacy information: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      await _privacyReference.set(
        {
          'title': _titleController.text.trim(),
          'privacyPolicyUrl': _privacyUrlController.text.trim(),
          'privacyPolicyContent': _policyController.text.trim(),
          'accountDeletionTitle':
              _deletionTitleController.text.trim(),
          'accountDeletionInstructions':
              _deletionInstructionsController.text.trim(),
          'contactEmail': _contactEmailController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save privacy information: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 860,
          maxHeight: 800,
        ),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AdminWebTheme.primary,
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Privacy Policy',
                            style: TextStyle(
                              color: AdminWebTheme.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _isSaving
                              ? null
                              : () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Manage the app privacy policy and account deletion information.',
                      style: TextStyle(
                        color: AdminWebTheme.textSecondary,
                        fontSize: 10.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            TextField(
                              controller: _titleController,
                              decoration: const InputDecoration(
                                labelText: 'Page Title',
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _privacyUrlController,
                              keyboardType: TextInputType.url,
                              decoration: const InputDecoration(
                                labelText: 'Privacy Policy URL',
                                hintText:
                                    'https://example.com/privacy-policy',
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _policyController,
                              minLines: 8,
                              maxLines: 16,
                              decoration: const InputDecoration(
                                labelText: 'Privacy Policy Content',
                                alignLabelWithHint: true,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _deletionTitleController,
                              decoration: const InputDecoration(
                                labelText: 'Account Deletion Title',
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller:
                                  _deletionInstructionsController,
                              minLines: 5,
                              maxLines: 10,
                              decoration: const InputDecoration(
                                labelText:
                                    'Account Deletion Instructions',
                                alignLabelWithHint: true,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _contactEmailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Privacy Contact Email',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _isSaving ? null : _save,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.save_outlined,
                                size: 17,
                              ),
                        label: Text(
                          _isSaving
                              ? 'Saving...'
                              : 'Save Privacy Information',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AdminWebTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AdminWebTheme.primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: AdminWebTheme.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AdminWebTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AdminWebTheme.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _SideMenuItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;
  final Color? color;

  const _SideMenuItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final foregroundColor = color ??
        (selected
            ? AdminWebTheme.primary
            : AdminWebTheme.textPrimary);

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Material(
        color: selected
            ? AdminWebTheme.primary.withOpacity(0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 11,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: foregroundColor,
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: 10.5,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileImage extends StatelessWidget {
  final String imageUrl;
  final Uint8List? selectedImageBytes;
  final String fallbackName;

  const _ProfileImage({
    required this.imageUrl,
    required this.selectedImageBytes,
    required this.fallbackName,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedImageBytes != null) {
      return Image.memory(
        selectedImageBytes!,
        fit: BoxFit.cover,
      );
    }

    if (imageUrl.trim().isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return _InitialAvatar(name: fallbackName);
        },
      );
    }

    return _InitialAvatar(name: fallbackName);
  }
}

class _InitialAvatar extends StatelessWidget {
  final String name;

  const _InitialAvatar({
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty
        ? 'A'
        : name.trim().substring(0, 1).toUpperCase();

    return Container(
      color: AdminWebTheme.primary.withOpacity(0.08),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: AdminWebTheme.primary,
          fontSize: 28,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(15),
    border: Border.all(
      color: AdminWebTheme.border,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.025),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ],
  );
}

String _displayRole(String role) {
  final normalized = role.trim().toLowerCase();

  switch (normalized) {
    case 'admin':
    case 'administrator':
      return 'Administrator';
    case 'staff':
      return 'Staff';
    default:
      if (normalized.isEmpty) return 'Administrator';
      return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
  }
}
