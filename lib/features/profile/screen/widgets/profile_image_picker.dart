// lib/features/profile/screen/widgets/profile_image_picker.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';

class ProfileImagePicker {
  static const int maxFileSizeBytes = 5 * 1024 * 1024; // 5MB

  /// Show bottom sheet with image source options
  static Future<File?> pickAndCropImage(BuildContext context, {bool hasExistingImage = false}) async {
    final source = await _showImageSourceBottomSheet(context, hasExistingImage);
    
    if (source == null) return null;
    
    // Handle remove photo option
    if (source == ImageSource.gallery && hasExistingImage) {
      // This is a signal to remove (we'll handle in the calling screen)
      return null;
    }

    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null) return null;

      // Check file size
      final fileSize = await File(pickedFile.path).length();
      if (fileSize > maxFileSizeBytes) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image is too large. Please select an image smaller than 5MB.'),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
        return null;
      }

      // Crop the image
      final croppedFile = await _cropImage(pickedFile.path);
      
      return croppedFile;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to select image: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
      return null;
    }
  }

  /// Show bottom sheet with image source options
  static Future<ImageSource?> _showImageSourceBottomSheet(BuildContext context, bool hasExistingImage) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'Profile Photo',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(),
                
                // Take Photo
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.navyBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.camera_alt, color: AppColors.navyBlue),
                  ),
                  title: const Text('Take Photo'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                
                // Choose from Gallery
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.navyBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.photo_library, color: AppColors.navyBlue),
                  ),
                  title: const Text('Choose from Gallery'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                
                // Remove Photo (only if user has existing image)
                if (hasExistingImage)
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.errorRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.delete_outline, color: AppColors.errorRed),
                    ),
                    title: const Text('Remove Photo', style: TextStyle(color: AppColors.errorRed)),
                    onTap: () => Navigator.pop(context, null), // Signal to remove
                  ),
                
                const SizedBox(height: 8),
                
                // Cancel
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Crop the selected image
  static Future<File?> _cropImage(String imagePath) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imagePath,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressQuality: 80,
      maxWidth: 512,
      maxHeight: 512,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Profile Photo',
          toolbarColor: AppColors.namaNavyBlue,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: AppColors.namaGoldenYellow,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          cropStyle: CropStyle.circle,
        ),
        IOSUiSettings(
          title: 'Crop Profile Photo',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );

    if (croppedFile == null) return null;
    
    return File(croppedFile.path);
  }
}
