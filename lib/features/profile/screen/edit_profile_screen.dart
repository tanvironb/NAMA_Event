// lib/features/profile/screen/edit_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/models/app_user.dart';
import 'package:events_app_trueattempt/core/providers.dart';
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
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _titleController = TextEditingController(text: widget.user.title);
    _companyController = TextEditingController(text: widget.user.company);
    _bioController = TextEditingController(text: widget.user.bio);
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(userProfileRepositoryProvider);
      final updatedData = {
        'name': _nameController.text.trim(),
        'title': _titleController.text.trim(),
        'company': _companyController.text.trim(),
        'bio': _bioController.text.trim(),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Full Name')),
            const SizedBox(height: 16),
            TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Job Title')),
            const SizedBox(height: 16),
            TextField(controller: _companyController, decoration: const InputDecoration(labelText: 'Company')),
            const SizedBox(height: 16),
            TextField(
              controller: _bioController,
              decoration: const InputDecoration(labelText: 'Bio', alignLabelWithHint: true),
              maxLines: 4,
            ),
            const SizedBox(height: 32),
            _isLoading
                ? const LoadingIndicator()
                : ElevatedButton(
                    onPressed: _saveProfile,
                    child: const Text('Save Changes'),
                  ),
          ],
        ),
      ),
    );
  }
}