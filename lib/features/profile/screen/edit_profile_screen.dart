// lib/features/profile/screen/edit_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/models/app_user.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/core/constants/data_validator.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/common_widgets/loading_indicator.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  final AppUser user;
  const EditProfileScreen({super.key, required this.user});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
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
  
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _titleController = TextEditingController(text: widget.user.title);
    _companyController = TextEditingController(text: widget.user.company);
    _bioController = TextEditingController(text: widget.user.bio);
    _personalEmailController = TextEditingController(text: widget.user.personalEmail);
    _phoneController = TextEditingController(text: widget.user.phone);
    _linkedinController = TextEditingController(text: widget.user.linkedin);
    _twitterController = TextEditingController(text: widget.user.twitter);
    _websiteController = TextEditingController(text: widget.user.website);
    _githubController = TextEditingController(text: widget.user.github);
    _mediumController = TextEditingController(text: widget.user.medium);
    _instagramController = TextEditingController(text: widget.user.instagram);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(userProfileRepositoryProvider);
      final updatedData = {
        'name': _nameController.text.trim(),
        'title': _titleController.text.trim(),
        'company': _companyController.text.trim(),
        'bio': _bioController.text.trim(),
        'personalEmail': _personalEmailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'linkedin': DataValidator.normalizeUrl(_linkedinController.text.trim()) ?? '',
        'twitter': DataValidator.normalizeUrl(_twitterController.text.trim()) ?? '',
        'website': DataValidator.normalizeUrl(_websiteController.text.trim()) ?? '',
        'github': DataValidator.normalizeUrl(_githubController.text.trim()) ?? '',
        'medium': DataValidator.normalizeUrl(_mediumController.text.trim()) ?? '',
        'instagram': DataValidator.normalizeUrl(_instagramController.text.trim()) ?? '',
      };
      await repo.updateUserProfile(widget.user.uid, updatedData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: AppColors.navyBlue,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic Information Section
              _buildSectionHeader('Basic Information'),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) => DataValidator.validateName(value ?? ''),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Job Title',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.work),
                ),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _companyController,
                decoration: const InputDecoration(
                  labelText: 'Company',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(
                  labelText: 'Bio',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.info),
                ),
                maxLines: 4,
                validator: (value) => DataValidator.validateLength(value, 'Bio', maxLength: 500),
              ),
              const SizedBox(height: 24),

              // Contact Information Section
              _buildSectionHeader('Contact Information'),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _personalEmailController,
                decoration: const InputDecoration(
                  labelText: 'Personal Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                  hintText: 'your.personal@email.com',
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value?.isNotEmpty == true) {
                    return DataValidator.validateEmail(value!);
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                  hintText: '+1 (555) 123-4567',
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value?.isNotEmpty == true) {
                    return DataValidator.validatePhone(value!);
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Social Media Section
              _buildSectionHeader('Social Media'),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _linkedinController,
                decoration: const InputDecoration(
                  labelText: 'LinkedIn Profile',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.work),
                  hintText: 'https://linkedin.com/in/username',
                ),
                validator: (value) {
                  if (value?.isNotEmpty == true) {
                    return DataValidator.validateLinkedInLenient(value!);
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _twitterController,
                decoration: const InputDecoration(
                  labelText: 'Twitter Profile',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.alternate_email),
                  hintText: 'https://twitter.com/username',
                ),
                validator: (value) {
                  if (value?.isNotEmpty == true) {
                    return DataValidator.validateTwitterLenient(value!);
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _websiteController,
                decoration: const InputDecoration(
                  labelText: 'Website',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.language),
                  hintText: 'https://yourwebsite.com',
                ),
                validator: (value) {
                  if (value?.isNotEmpty == true) {
                    return DataValidator.validateWebsiteLenient(value!);
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _githubController,
                decoration: const InputDecoration(
                  labelText: 'GitHub Profile',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.code),
                  hintText: 'https://github.com/username',
                ),
                validator: (value) {
                  if (value?.isNotEmpty == true) {
                    return DataValidator.validateGitHubLenient(value!);
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _mediumController,
                decoration: const InputDecoration(
                  labelText: 'Medium Profile',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.article),
                  hintText: 'https://medium.com/@username',
                ),
                validator: (value) {
                  if (value?.isNotEmpty == true) {
                    return DataValidator.validateMediumLenient(value!);
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _instagramController,
                decoration: const InputDecoration(
                  labelText: 'Instagram Profile',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.camera_alt),
                  hintText: 'https://instagram.com/username',
                ),
                validator: (value) {
                  if (value?.isNotEmpty == true) {
                    return DataValidator.validateInstagramLenient(value!);
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              
              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: _isLoading
                    ? const LoadingIndicator()
                    : ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.navyBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Save Changes',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.navyBlue,
      ),
    );
  }
}