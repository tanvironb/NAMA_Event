import 'package:flutter/material.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/enums/profile_visibility.dart';

/// Modal dialog for privacy level selection
/// Shown to users after approval or when changing privacy settings
class PrivacySelectionDialog extends StatefulWidget {
  final ProfileVisibility initialSelection;
  final Function(ProfileVisibility) onConfirm;
  final bool canDismiss; // false for first-time selection

  const PrivacySelectionDialog({
    super.key,
    this.initialSelection = ProfileVisibility.full,
    required this.onConfirm,
    this.canDismiss = false,
  });

  @override
  State<PrivacySelectionDialog> createState() => _PrivacySelectionDialogState();
}

class _PrivacySelectionDialogState extends State<PrivacySelectionDialog> {
  late ProfileVisibility _selectedLevel;
  ProfileVisibility? _expandedLevel;

  @override
  void initState() {
    super.initState();
    _selectedLevel = widget.initialSelection;
    _expandedLevel = widget.initialSelection; // Default expand the selected one
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.canDismiss,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              Text(
                'Choose Your Privacy Level',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.namaNavyBlue,
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              
              // Subtitle
              Text(
                widget.canDismiss
                    ? 'Update how others see your profile'
                    : 'Select how you want to appear to other attendees',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Icons row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildIconButton(ProfileVisibility.full),
                  _buildIconButton(ProfileVisibility.minimal),
                  _buildIconButton(ProfileVisibility.anonymous),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Detail box below icons
              if (_expandedLevel != null) _buildDetailBox(_expandedLevel!),
              
              const SizedBox(height: 24),
              
              // Confirm Button
              ElevatedButton(
                onPressed: () => widget.onConfirm(_selectedLevel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.namaNavyBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Confirm',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton(ProfileVisibility level) {
    final isSelected = _selectedLevel == level;
    final isExpanded = _expandedLevel == level;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedLevel = level;
          _expandedLevel = level;
        });
      },
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: isExpanded ? AppColors.namaNavyBlue.withOpacity(0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isExpanded
              ? Border.all(color: AppColors.namaNavyBlue, width: 2)
              : null,
        ),
        child: Center(
          child: Text(
            level.icon,
            style: TextStyle(
              fontSize: 40,
              shadows: isSelected
                  ? [
                      Shadow(
                        color: AppColors.namaNavyBlue.withOpacity(0.3),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailBox(ProfileVisibility level) {
    final isRecommended = level == ProfileVisibility.full;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.namaNavyBlue.withOpacity(0.05),
        border: Border.all(
          color: AppColors.namaNavyBlue,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            level.displayName,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.namaNavyBlue,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            level.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
          ),
          if (isRecommended) ...[
            const SizedBox(height: 12),
            Text(
              'Recommended for networking',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.namaGoldenYellow.withOpacity(0.8),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
