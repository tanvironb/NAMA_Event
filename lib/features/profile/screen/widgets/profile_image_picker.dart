// lib/features/profile/screen/widgets/profile_image_picker.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';

class ProfileImagePicker {
  static const int maxFileSizeBytes = 5 * 1024 * 1024; // 5MB

  static Future<XFile?> pickAndCropImage(
    BuildContext context, {
    bool hasExistingImage = false,
  }) async {
    final source = await _showImageSourceBottomSheet(
      context,
      hasExistingImage,
    );

    if (source == null) return null;

    try {
      final picker = ImagePicker();

      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null) return null;

      final fileSize = await pickedFile.length();

      if (fileSize > maxFileSizeBytes) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Image is too large. Please select an image smaller than 5MB.',
              ),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
        return null;
      }

      // Web fix: skip cropper on Chrome/Web to avoid overflow and cropper JS issues.
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();

        return XFile.fromData(
          bytes,
          name: 'profile_photo.jpg',
          mimeType: 'image/jpeg',
        );
      }

      // Mobile only: crop image
      final croppedFile = await _cropImage(pickedFile.path);

      if (croppedFile == null) return null;

      final bytes = await croppedFile.readAsBytes();

      return XFile.fromData(
        bytes,
        name: 'profile_photo.jpg',
        mimeType: 'image/jpeg',
      );
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

  static Future<ImageSource?> _showImageSourceBottomSheet(
    BuildContext context,
    bool hasExistingImage,
  ) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Profile Photo',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                ),

                const SizedBox(height: 10),

                Divider(
                  height: 1,
                  color: Colors.grey.withOpacity(0.4),
                ),

                const SizedBox(height: 6),

                _buildOption(
                  icon: Icons.camera_alt,
                  text: 'Take Photo',
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),

                _buildOption(
                  icon: Icons.photo_library,
                  text: 'Choose from Gallery',
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),

                const SizedBox(height: 6),

                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _buildOption({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.namaNavyBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: AppColors.namaNavyBlue,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<CroppedFile?> _cropImage(String imagePath) async {
    return await ImageCropper().cropImage(
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
  }
}