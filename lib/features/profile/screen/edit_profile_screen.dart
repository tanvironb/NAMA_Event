// lib/features/profile/screen/edit_profile_screen.dart

import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/constants/data_validator.dart';
import 'package:events_app_trueattempt/core/models/app_user.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/features/profile/screen/widgets/profile_image_picker.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  final AppUser user;

  const EditProfileScreen({
    super.key,
    required this.user,
  });

  @override
  ConsumerState<EditProfileScreen> createState() =>
      _EditProfileScreenState();
}

class _EditProfileScreenState
    extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _titleController;
  late final TextEditingController _companyController;
  late final TextEditingController _bioController;
  late final TextEditingController _personalEmailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _linkedinController;
  late final TextEditingController _twitterController;
  late final TextEditingController _websiteController;
  late final TextEditingController _githubController;
  late final TextEditingController _mediumController;
  late final TextEditingController _instagramController;

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isUploadingImage = false;

  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;

  bool _shouldRemoveImage = false;

  @override
  void initState() {
    super.initState();

    _nameController =
        TextEditingController(text: widget.user.name);

    _titleController =
        TextEditingController(text: widget.user.title);

    _companyController =
        TextEditingController(text: widget.user.company);

    _bioController =
        TextEditingController(text: widget.user.bio);

    _personalEmailController =
        TextEditingController(
      text: widget.user.personalEmail,
    );

    _phoneController =
        TextEditingController(text: widget.user.phone);

    _linkedinController =
        TextEditingController(text: widget.user.linkedin);

    _twitterController =
        TextEditingController(text: widget.user.twitter);

    _websiteController =
        TextEditingController(text: widget.user.website);

    _githubController =
        TextEditingController(text: widget.user.github);

    _mediumController =
        TextEditingController(text: widget.user.medium);

    _instagramController =
        TextEditingController(text: widget.user.instagram);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final currentFirebaseUser =
        FirebaseAuth.instance.currentUser;

    if (currentFirebaseUser == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your login session has expired. Please log in again.',
          ),
          backgroundColor: AppColors.errorRed,
        ),
      );

      return;
    }

    final String authenticatedUserId =
        currentFirebaseUser.uid;

    debugPrint(
      'Authenticated Firebase UID: $authenticatedUserId',
    );

    debugPrint(
      'Widget profile UID: ${widget.user.uid}',
    );

    setState(() {
      _isLoading = true;
      _isUploadingImage =
          _selectedImage != null || _shouldRemoveImage;
    });

    try {
      final repository =
          ref.read(userProfileRepositoryProvider);

      /*
       * Always use the currently authenticated Firebase UID
       * for the user's own profile image.
       *
       * Firebase Storage path:
       * profile/{authenticatedUserId}.jpg
       */
      if (_shouldRemoveImage) {
        await repository.removeProfileImage(
          authenticatedUserId,
        );
      } else if (_selectedImage != null) {
        await repository.uploadProfileImage(
          authenticatedUserId,
          _selectedImage!,
        );
      }

      final Map<String, dynamic> updatedData = {
        'name': _nameController.text.trim(),
        'title': _titleController.text.trim(),
        'company': _companyController.text.trim(),
        'bio': _bioController.text.trim(),
        'personalEmail':
            _personalEmailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'linkedin': DataValidator.normalizeUrl(
              _linkedinController.text.trim(),
            ) ??
            '',
        'twitter': DataValidator.normalizeUrl(
              _twitterController.text.trim(),
            ) ??
            '',
        'website': DataValidator.normalizeUrl(
              _websiteController.text.trim(),
            ) ??
            '',
        'github': DataValidator.normalizeUrl(
              _githubController.text.trim(),
            ) ??
            '',
        'medium': DataValidator.normalizeUrl(
              _mediumController.text.trim(),
            ) ??
            '',
        'instagram': DataValidator.normalizeUrl(
              _instagramController.text.trim(),
            ) ??
            '',
      };

      await repository.updateUserProfile(
        authenticatedUserId,
        updatedData,
      );

      ref.invalidate(userAppProfileStreamProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Profile updated successfully!',
          ),
          backgroundColor: AppColors.successGreen,
        ),
      );

      Navigator.of(context).pop();
    } on FirebaseException catch (error) {
      debugPrint(
        'Firebase profile update error: '
        '${error.code} - ${error.message}',
      );

      if (!mounted) return;

      String errorMessage =
          'Failed to update profile.';

      if (error.code == 'unauthorized') {
        errorMessage =
            'Profile image permission was denied. '
            'Please log out, log in again, and retry.';
      } else if (error.code == 'canceled') {
        errorMessage =
            'The profile image upload was cancelled.';
      } else if (error.code ==
          'retry-limit-exceeded') {
        errorMessage =
            'The upload took too long. Please check your internet connection.';
      } else if (error.code == 'object-not-found') {
        errorMessage =
            'The profile image could not be found.';
      } else if (error.message != null &&
          error.message!.trim().isNotEmpty) {
        errorMessage = error.message!;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: AppColors.errorRed,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Failed to update profile: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to update profile: $error',
          ),
          backgroundColor: AppColors.errorRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isUploadingImage = false;
        });
      }
    }
  }

  Future<void> _handleImageSelection() async {
    if (_isLoading || _isUploadingImage) {
      return;
    }

    final bool hasExistingImage =
        widget.user.profileImageUrl.trim().isNotEmpty ||
            _selectedImage != null;

    try {
      final XFile? result =
          await ProfileImagePicker.pickAndCropImage(
        context,
        hasExistingImage: hasExistingImage,
      );

      /*
       * When the user cancels the picker, do nothing.
       * Do not remove the current profile picture.
       */
      if (result == null) {
        return;
      }

      final Uint8List bytes =
          await result.readAsBytes();

      if (bytes.isEmpty) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The selected image is empty.',
            ),
            backgroundColor: AppColors.errorRed,
          ),
        );

        return;
      }

      const int maximumImageSize =
          10 * 1024 * 1024;

      if (bytes.length > maximumImageSize) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please select an image smaller than 10 MB.',
            ),
            backgroundColor: AppColors.errorRed,
          ),
        );

        return;
      }

      if (!mounted) return;

      setState(() {
        _selectedImage = result;
        _selectedImageBytes = bytes;
        _shouldRemoveImage = false;
      });
    } catch (error) {
      debugPrint(
        'Failed to select profile image: $error',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to select image: $error',
          ),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  ImageProvider<Object>? _getProfileImage() {
    if (_shouldRemoveImage) {
      return null;
    }

    if (_selectedImageBytes != null) {
      return MemoryImage(
        _selectedImageBytes!,
      );
    }

    final String profileImageUrl =
        widget.user.profileImageUrl.trim();

    if (profileImageUrl.isNotEmpty) {
      return NetworkImage(profileImageUrl);
    }

    return null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _titleController.dispose();
    _companyController.dispose();
    _bioController.dispose();
    _personalEmailController.dispose();
    _phoneController.dispose();
    _linkedinController.dispose();
    _twitterController.dispose();
    _websiteController.dispose();
    _githubController.dispose();
    _mediumController.dispose();
    _instagramController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final OutlineInputBorder inputBorder =
        OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(
        color: Colors.black.withOpacity(0.35),
        width: 0.8,
      ),
    );

    final bool hasProfileImage =
        _getProfileImage() != null;

    return Scaffold(
      backgroundColor:
          Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                18,
                16,
                18,
                12,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Row(
                    children: [
                      InkWell(
                        onTap: _isLoading
                            ? null
                            : () =>
                                Navigator.pop(context),
                        borderRadius:
                            BorderRadius.circular(30),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.arrow_back,
                            size: 22,
                            color:
                                AppColors.namaNavyBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Edit Profile',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                          fontSize: 19,
                          fontWeight:
                              FontWeight.w700,
                          color: AppColors
                              .namaNavyBlue,
                        ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.fromLTRB(
                    18,
                    8,
                    18,
                    24,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                Container(
                                  decoration:
                                      BoxDecoration(
                                    shape:
                                        BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors
                                          .namaGoldenYellow,
                                      width: 2.5,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 50,
                                    backgroundImage:
                                        _getProfileImage(),
                                    backgroundColor:
                                        AppColors
                                            .avatarPlaceholder,
                                    child:
                                        !hasProfileImage
                                            ? Icon(
                                                Icons
                                                    .person,
                                                size:
                                                    50,
                                                color: AppColors
                                                    .avatarPlaceholderText,
                                              )
                                            : null,
                                  ),
                                ),
                                if (_isUploadingImage)
                                  Positioned.fill(
                                    child: Container(
                                      decoration:
                                          const BoxDecoration(
                                        shape: BoxShape
                                            .circle,
                                        color: Colors
                                            .black54,
                                      ),
                                      child:
                                          const Center(
                                        child:
                                            CircularProgressIndicator(
                                          color: AppColors
                                              .namaGoldenYellow,
                                        ),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: CircleAvatar(
                                    radius: 17,
                                    backgroundColor:
                                        AppColors
                                            .namaNavyBlue,
                                    child: IconButton(
                                      icon:
                                          const Icon(
                                        Icons.camera_alt,
                                        size: 16,
                                        color:
                                            Colors.white,
                                      ),
                                      onPressed:
                                          _isLoading ||
                                                  _isUploadingImage
                                              ? null
                                              : _handleImageSelection,
                                      padding:
                                          EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed:
                                  _isLoading ||
                                          _isUploadingImage
                                      ? null
                                      : _handleImageSelection,
                              icon: const Icon(
                                Icons.photo_camera,
                                size: 16,
                              ),
                              label: Text(
                                _selectedImage != null
                                    ? 'Photo selected - tap to change'
                                    : 'Change Profile Photo',
                                style:
                                    const TextStyle(
                                  fontSize: 13,
                                ),
                              ),
                              style:
                                  TextButton.styleFrom(
                                foregroundColor:
                                    AppColors
                                        .namaNavyBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildSectionHeader(
                        'Basic Information',
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _nameController,
                        label: 'Full Name *',
                        icon: Icons.person,
                        border: inputBorder,
                        validator: (value) =>
                            DataValidator
                                .validateName(
                          value ?? '',
                        ),
                      ),
                      _buildTextField(
                        controller:
                            _titleController,
                        label: 'Job Title',
                        icon: Icons.work,
                        border: inputBorder,
                      ),
                      _buildTextField(
                        controller:
                            _companyController,
                        label: 'Company',
                        icon: Icons.business,
                        border: inputBorder,
                      ),
                      _buildTextField(
                        controller:
                            _bioController,
                        label: 'Bio',
                        icon: Icons.info,
                        border: inputBorder,
                        maxLines: 3,
                        validator: (value) =>
                            DataValidator
                                .validateLength(
                          value,
                          'Bio',
                          maxLength: 500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSectionHeader(
                        'Contact Information',
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller:
                            _personalEmailController,
                        label: 'Personal Email',
                        icon: Icons.email,
                        hintText:
                            'your.personal@email.com',
                        keyboardType:
                            TextInputType
                                .emailAddress,
                        border: inputBorder,
                        validator: (value) {
                          if (value?.isNotEmpty ==
                              true) {
                            return DataValidator
                                .validateEmail(
                              value!,
                            );
                          }

                          return null;
                        },
                      ),
                      _buildTextField(
                        controller:
                            _phoneController,
                        label: 'Phone Number',
                        icon: Icons.phone,
                        hintText:
                            '+1 (555) 123-4567',
                        keyboardType:
                            TextInputType.phone,
                        border: inputBorder,
                        validator: (value) {
                          if (value?.isNotEmpty ==
                              true) {
                            return DataValidator
                                .validatePhone(
                              value!,
                            );
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildSectionHeader(
                        'Social Media',
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller:
                            _linkedinController,
                        label: 'LinkedIn Profile',
                        icon: Icons.work,
                        hintText:
                            'https://linkedin.com/in/username',
                        border: inputBorder,
                        validator: (value) {
                          if (value?.isNotEmpty ==
                              true) {
                            return DataValidator
                                .validateLinkedInLenient(
                              value!,
                            );
                          }

                          return null;
                        },
                      ),
                      _buildTextField(
                        controller:
                            _twitterController,
                        label: 'Twitter Profile',
                        icon:
                            Icons.alternate_email,
                        hintText:
                            'https://twitter.com/username',
                        border: inputBorder,
                        validator: (value) {
                          if (value?.isNotEmpty ==
                              true) {
                            return DataValidator
                                .validateTwitterLenient(
                              value!,
                            );
                          }

                          return null;
                        },
                      ),
                      _buildTextField(
                        controller:
                            _websiteController,
                        label: 'Website',
                        icon: Icons.language,
                        hintText:
                            'https://yourwebsite.com',
                        border: inputBorder,
                        validator: (value) {
                          if (value?.isNotEmpty ==
                              true) {
                            return DataValidator
                                .validateWebsiteLenient(
                              value!,
                            );
                          }

                          return null;
                        },
                      ),
                      _buildTextField(
                        controller:
                            _githubController,
                        label: 'GitHub Profile',
                        icon: Icons.code,
                        hintText:
                            'https://github.com/username',
                        border: inputBorder,
                        validator: (value) {
                          if (value?.isNotEmpty ==
                              true) {
                            return DataValidator
                                .validateGitHubLenient(
                              value!,
                            );
                          }

                          return null;
                        },
                      ),
                      _buildTextField(
                        controller:
                            _mediumController,
                        label: 'Medium Profile',
                        icon: Icons.article,
                        hintText:
                            'https://medium.com/@username',
                        border: inputBorder,
                        validator: (value) {
                          if (value?.isNotEmpty ==
                              true) {
                            return DataValidator
                                .validateMediumLenient(
                              value!,
                            );
                          }

                          return null;
                        },
                      ),
                      _buildTextField(
                        controller:
                            _instagramController,
                        label:
                            'Instagram Profile',
                        icon: Icons.camera_alt,
                        hintText:
                            'https://instagram.com/username',
                        border: inputBorder,
                        validator: (value) {
                          if (value?.isNotEmpty ==
                              true) {
                            return DataValidator
                                .validateInstagramLenient(
                              value!,
                            );
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: SizedBox(
                          width: 180,
                          height: 44,
                          child: _isLoading
                              ? const LoadingIndicator()
                              : ElevatedButton(
                                  onPressed:
                                      _saveProfile,
                                  style:
                                      ElevatedButton
                                          .styleFrom(
                                    backgroundColor:
                                        AppColors
                                            .namaNavyBlue,
                                    foregroundColor:
                                        AppColors
                                            .namaWhite,
                                    shape:
                                        RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                        20,
                                      ),
                                    ),
                                  ),
                                  child:
                                      const Text(
                                    'Save Changes',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight:
                                          FontWeight
                                              .w700,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required OutlineInputBorder border,
    String? hintText,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 12,
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        enabled: !_isLoading,
        style: const TextStyle(
          fontSize: 13.5,
          color: Colors.black87,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          alignLabelWithHint: maxLines > 1,
          filled: true,
          fillColor:
              Colors.grey.withOpacity(0.035),
          contentPadding:
              const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          prefixIcon: Icon(
            icon,
            size: 19,
            color: Colors.black.withOpacity(0.6),
          ),
          labelStyle: TextStyle(
            fontSize: 12,
            color:
                Colors.black.withOpacity(0.58),
          ),
          hintStyle: TextStyle(
            fontSize: 12.5,
            color:
                Colors.black.withOpacity(0.35),
          ),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: const BorderSide(
              color:
                  AppColors.namaNavyBlue,
              width: 1,
            ),
          ),
          errorBorder: border.copyWith(
            borderSide: const BorderSide(
              color: AppColors.errorRed,
              width: 1,
            ),
          ),
          focusedErrorBorder:
              border.copyWith(
            borderSide: const BorderSide(
              color: AppColors.errorRed,
              width: 1,
            ),
          ),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
  ) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15.5,
        fontWeight: FontWeight.w700,
        color: AppColors.namaNavyBlue,
      ),
    );
  }
}