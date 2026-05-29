// lib/features/admin/screen/manage_user_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/models/app_user.dart';
import 'package:events_app_trueattempt/core/providers.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';

class ManageUserProfileScreen extends ConsumerStatefulWidget {
  final AppUser user;

  const ManageUserProfileScreen({
    super.key,
    required this.user,
  });

  @override
  ConsumerState<ManageUserProfileScreen> createState() =>
      _ManageUserProfileScreenState();
}

class _ManageUserProfileScreenState
    extends ConsumerState<ManageUserProfileScreen> {
  final Set<String> _fieldsToRemove = {};
  final Map<String, String> _fieldValues = {};

  bool _isUpdating = false;
  bool _isLoadingDialogOpen = false;

  final Map<String, String> _editableFields = {
    'name': 'Name',
    'company': 'Company',
    'title': 'Job Title',
    'bio': 'Bio',
    'phone': 'Phone Number',
    'linkedin': 'LinkedIn',
    'twitter': 'Twitter',
    'website': 'Website',
    'github': 'GitHub',
    'medium': 'Medium',
    'instagram': 'Instagram',
    'profileImageUrl': 'Profile Image',
  };

  @override
  void initState() {
    super.initState();

    _fieldValues.addAll({
      'name': widget.user.name,
      'company': widget.user.company,
      'title': widget.user.title,
      'bio': widget.user.bio,
      'phone': widget.user.phone,
      'linkedin': widget.user.linkedin,
      'twitter': widget.user.twitter,
      'website': widget.user.website,
      'github': widget.user.github,
      'medium': widget.user.medium,
      'instagram': widget.user.instagram,
      'profileImageUrl': widget.user.profileImageUrl,
    });
  }

  void _showLoadingDialog() {
    if (_isLoadingDialogOpen || !mounted) return;

    _isLoadingDialogOpen = true;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) {
        return const Center(
          child: CircularProgressIndicator(
            color: AppColors.namaNavyBlue,
          ),
        );
      },
    );
  }

  void _hideLoadingDialog() {
    if (!_isLoadingDialogOpen || !mounted) return;

    final navigator = Navigator.of(context, rootNavigator: true);

    if (navigator.canPop()) {
      navigator.pop();
    }

    _isLoadingDialogOpen = false;
  }

  void _showMessage(
      String message, {
        bool isError = false,
      }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.errorRed : AppColors.successGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _getFieldValue(String fieldKey) {
    return _fieldValues[fieldKey] ?? '';
  }

  String _getFieldLabel(String fieldKey) {
    return _editableFields[fieldKey] ?? 'Field';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            _buildUserHeader(context),
            _buildInfoBanner(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: _editableFields.entries.map((entry) {
                  final fieldKey = entry.key;
                  final fieldLabel = entry.value;
                  final fieldValue = _getFieldValue(fieldKey);
                  final hasValue = fieldValue.trim().isNotEmpty;

                  return _ProfileFieldCard(
                    fieldKey: fieldKey,
                    fieldLabel: fieldLabel,
                    fieldValue: fieldValue,
                    hasValue: hasValue,
                    isMarkedForRemoval: _fieldsToRemove.contains(fieldKey),
                    isUpdating: _isUpdating,
                    onEdit: () {
                      if (_isUpdating) return;
                      _showEditDialog(fieldKey, fieldLabel);
                    },
                    onToggleRemoval: (marked) {
                      if (_isUpdating) return;

                      setState(() {
                        if (marked) {
                          _fieldsToRemove.add(fieldKey);
                        } else {
                          _fieldsToRemove.remove(fieldKey);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            _buildBottomActionButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserHeader(BuildContext context) {
    final profileImageUrl = _getFieldValue('profileImageUrl').trim();
    final name = _getFieldValue('name').trim().isEmpty
        ? 'User'
        : _getFieldValue('name').trim();

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
      child: Row(
        children: [
          InkWell(
            onTap: _isUpdating ? null : () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(50),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(
                Icons.arrow_back,
                size: 22,
                color: AppColors.namaNavyBlue,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.namaNavyBlue.withOpacity(0.1),
                    backgroundImage: profileImageUrl.isNotEmpty
                        ? NetworkImage(profileImageUrl)
                        : null,
                    child: profileImageUrl.isEmpty
                        ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.namaNavyBlue,
                      ),
                    )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF222222),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.user.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 34),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.warningAmber.withOpacity(0.09),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.warningAmber.withOpacity(0.8),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.warningAmber,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Admin & Staff can edit or remove user profile fields. Removed fields will be cleared from the user\'s profile.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionButton() {
    if (_fieldsToRemove.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${_fieldsToRemove.length} field${_fieldsToRemove.length != 1 ? 's' : ''} marked for removal',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: 220,
            height: 42,
            child: ElevatedButton(
              onPressed: _isUpdating ? null : _showRemoveConfirmationDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorRed,
                disabledBackgroundColor: AppColors.errorRed.withOpacity(0.5),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                _isUpdating ? 'Updating...' : 'Update Profile',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(String fieldKey, String fieldLabel) {
    String editedValue = _getFieldValue(fieldKey);

    showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Edit $fieldLabel',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: TextFormField(
            initialValue: editedValue,
            maxLines: fieldKey == 'bio' ? 4 : 1,
            onChanged: (value) {
              editedValue = value;
            },
            decoration: InputDecoration(
              labelText: fieldLabel,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(
                  color: Colors.grey.shade300,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(
                  color: AppColors.namaNavyBlue,
                  width: 1.3,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext, rootNavigator: true).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final newValue = editedValue.trim();

                Navigator.of(dialogContext, rootNavigator: true).pop();

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _updateSingleField(fieldKey, newValue);
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.namaNavyBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateSingleField(String fieldKey, String newValue) async {
    if (_isUpdating) return;

    if (fieldKey == 'name' && newValue.trim().isEmpty) {
      _showMessage(
        'Name cannot be empty',
        isError: true,
      );
      return;
    }

    final currentValue = _getFieldValue(fieldKey);

    if (newValue == currentValue) {
      return;
    }

    if (!mounted) return;

    setState(() => _isUpdating = true);
    _showLoadingDialog();

    try {
      await ref.read(userProfileRepositoryProvider).updateUserProfile(
        widget.user.uid,
        {
          fieldKey: newValue,
        },
      );

      if (!mounted) return;

      _hideLoadingDialog();

      setState(() {
        _fieldValues[fieldKey] = newValue;
        _fieldsToRemove.remove(fieldKey);
        _isUpdating = false;
      });

      _showMessage('${_getFieldLabel(fieldKey)} updated successfully');
    } catch (e) {
      if (!mounted) return;

      _hideLoadingDialog();

      setState(() => _isUpdating = false);

      _showMessage(
        'Failed to update profile: $e',
        isError: true,
      );
    }
  }

  void _showRemoveConfirmationDialog() {
    if (_isUpdating) return;

    final fieldNames = _fieldsToRemove
        .map((key) => _editableFields[key])
        .whereType<String>()
        .join(', ');

    showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.warning_rounded,
                color: AppColors.errorRed,
                size: 22,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Confirm Update',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you sure you want to remove these fields?',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  fieldNames,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'This will clear the selected fields from the user profile.',
                style: TextStyle(
                  color: AppColors.errorRed,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext, rootNavigator: true).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext, rootNavigator: true).pop();

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _performRemoveUpdate();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorRed,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performRemoveUpdate() async {
    if (_isUpdating) return;

    if (_fieldsToRemove.isEmpty) return;

    setState(() => _isUpdating = true);
    _showLoadingDialog();

    try {
      final Map<String, dynamic> updates = {};

      for (final fieldKey in _fieldsToRemove) {
        if (fieldKey == 'name') {
          updates[fieldKey] = 'User';
        } else {
          updates[fieldKey] = '';
        }
      }

      await ref.read(userProfileRepositoryProvider).updateUserProfile(
        widget.user.uid,
        updates,
      );

      if (!mounted) return;

      _hideLoadingDialog();

      setState(() {
        for (final fieldKey in _fieldsToRemove) {
          _fieldValues[fieldKey] = fieldKey == 'name' ? 'User' : '';
        }

        _fieldsToRemove.clear();
        _isUpdating = false;
      });

      _showMessage('User profile updated successfully');
    } catch (e) {
      if (!mounted) return;

      _hideLoadingDialog();

      setState(() => _isUpdating = false);

      _showMessage(
        'Failed to update profile: $e',
        isError: true,
      );
    }
  }
}

class _ProfileFieldCard extends StatelessWidget {
  final String fieldKey;
  final String fieldLabel;
  final String fieldValue;
  final bool hasValue;
  final bool isMarkedForRemoval;
  final bool isUpdating;
  final VoidCallback onEdit;
  final Function(bool) onToggleRemoval;

  const _ProfileFieldCard({
    required this.fieldKey,
    required this.fieldLabel,
    required this.fieldValue,
    required this.hasValue,
    required this.isMarkedForRemoval,
    required this.isUpdating,
    required this.onEdit,
    required this.onToggleRemoval,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.fromLTRB(15, 13, 8, 13),
      decoration: BoxDecoration(
        color: isMarkedForRemoval
            ? AppColors.errorRed.withOpacity(0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMarkedForRemoval
              ? AppColors.errorRed
              : hasValue
              ? Colors.grey.shade300
              : Colors.grey.shade200,
          width: isMarkedForRemoval ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Opacity(
              opacity: isMarkedForRemoval ? 0.55 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fieldLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: Color(0xFF2A2A2A),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    hasValue ? fieldValue : 'Not provided',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.3,
                      color: hasValue
                          ? Colors.grey.shade700
                          : Colors.grey.shade400,
                      fontStyle: hasValue ? FontStyle.normal : FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: isUpdating ? null : onEdit,
            icon: Icon(
              Icons.edit_rounded,
              size: 20,
              color: isUpdating
                  ? Colors.grey.shade300
                  : AppColors.namaNavyBlue,
            ),
            tooltip: 'Edit',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: isUpdating || !hasValue
                ? null
                : () => onToggleRemoval(!isMarkedForRemoval),
            icon: Icon(
              isMarkedForRemoval ? Icons.undo_rounded : Icons.delete_rounded,
              size: 20,
              color: isUpdating
                  ? Colors.grey.shade300
                  : isMarkedForRemoval
                  ? AppColors.warningAmber
                  : hasValue
                  ? AppColors.errorRed
                  : Colors.grey.shade300,
            ),
            tooltip: isMarkedForRemoval ? 'Undo' : 'Remove',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}