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

  @override
  void initState() {
    super.initState();
    _selectedLevel = widget.initialSelection;
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
              const SizedBox(height: 24),
              
              // Privacy Level Cards
              _buildPrivacyCard(ProfileVisibility.full),
              const SizedBox(height: 12),
              _buildPrivacyCard(ProfileVisibility.minimal),
              const SizedBox(height: 12),
              _buildPrivacyCard(ProfileVisibility.anonymous),
              const SizedBox(height: 24),
              
              // Description of selected level
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.namaNavyBlue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedLevel.icon,
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedLevel.displayName,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.namaNavyBlue,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedLevel.description,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey.shade700,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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

  Widget _buildPrivacyCard(ProfileVisibility level) {
    final isSelected = _selectedLevel == level;
    final isRecommended = level == ProfileVisibility.full;

    return InkWell(
      onTap: () => setState(() => _selectedLevel = level),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.namaNavyBlue.withOpacity(0.1)
              : Colors.grey.shade50,
          border: Border.all(
            color: isSelected ? AppColors.namaNavyBlue : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.namaNavyBlue
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  level.icon,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Title
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        level.displayName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? AppColors.namaNavyBlue : Colors.black87,
                            ),
                      ),
                      if (isRecommended) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.namaGoldenYellow.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Recommended for networking',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.namaGoldenYellow,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            
            // Radio indicator
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.namaNavyBlue : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.namaNavyBlue,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
