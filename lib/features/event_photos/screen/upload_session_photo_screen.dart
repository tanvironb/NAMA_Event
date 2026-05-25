import 'dart:io' show File;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class UploadSessionPhotoScreen extends StatefulWidget {
  final Session session;

  const UploadSessionPhotoScreen({
    super.key,
    required this.session,
  });

  @override
  State<UploadSessionPhotoScreen> createState() =>
      _UploadSessionPhotoScreenState();
}

class _UploadSessionPhotoScreenState extends State<UploadSessionPhotoScreen> {
  final TextEditingController _captionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  XFile? _pickedImage;
  Uint8List? _webImageBytes;
  File? _mobileImageFile;

  bool _isUploading = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_isUploading) return;

    final pickedImage = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1600,
    );

    if (pickedImage == null) return;

    if (kIsWeb) {
      final bytes = await pickedImage.readAsBytes();

      if (!mounted) return;

      setState(() {
        _pickedImage = pickedImage;
        _webImageBytes = bytes;
        _mobileImageFile = null;
      });
    } else {
      setState(() {
        _pickedImage = pickedImage;
        _mobileImageFile = File(pickedImage.path);
        _webImageBytes = null;
      });
    }
  }

  Future<void> _uploadPhoto() async {
    if (_isUploading) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showSnackBar('Please login first to upload a photo.');
      return;
    }

    if (_pickedImage == null) {
      _showSnackBar('Please select a photo first.');
      return;
    }

    try {
      setState(() => _isUploading = true);

      final firestore = FirebaseFirestore.instance;

      final userDoc = await firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      final userName = (userData['name'] ??
              userData['fullName'] ??
              userData['displayName'] ??
              user.displayName ??
              'Attendee')
          .toString();

      final userEmail = (userData['email'] ?? user.email ?? '').toString();

      final now = DateTime.now().millisecondsSinceEpoch;

      final storagePath =
          'event_photos/${widget.session.eventId}/${widget.session.id}/${user.uid}_$now.jpg';

      final storageRef = FirebaseStorage.instance.ref().child(storagePath);

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'eventId': widget.session.eventId,
          'sessionId': widget.session.id,
          'userId': user.uid,
        },
      );

      if (kIsWeb) {
        if (_webImageBytes == null) {
          throw Exception('Image data not found.');
        }

        await storageRef.putData(_webImageBytes!, metadata);
      } else {
        if (_mobileImageFile == null) {
          throw Exception('Image file not found.');
        }

        await storageRef.putFile(_mobileImageFile!, metadata);
      }

      final photoUrl = await storageRef.getDownloadURL();

      final photoDoc = firestore
          .collection('events')
          .doc(widget.session.eventId)
          .collection('eventPhotos')
          .doc();

      await photoDoc.set({
        'id': photoDoc.id,
        'eventId': widget.session.eventId,
        'sessionId': widget.session.id,
        'sessionTitle': widget.session.title,
        'userId': user.uid,
        'userName': userName,
        'userEmail': userEmail,
        'photoUrl': photoUrl,
        'storagePath': storagePath,
        'caption': _captionController.text.trim(),
        'status': 'pending',
        'uploadedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() => _isUploading = false);

      _showSuccessDialog();
    } catch (e) {
      if (!mounted) return;

      setState(() => _isUploading = false);

      _showSnackBar('Failed to upload photo: $e');
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Photo Uploaded',
            style: TextStyle(
              color: AppColors.namaNavyBlue,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const Text(
            'Your photo has been uploaded successfully and is pending admin review.',
            style: TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text(
                'OK',
                style: TextStyle(
                  color: AppColors.namaNavyBlue,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _selectedImagePreview() {
    if (kIsWeb && _webImageBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Image.memory(
          _webImageBytes!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      );
    }

    if (!kIsWeb && _mobileImageFile != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Image.file(
          _mobileImageFile!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      );
    }

    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          color: AppColors.namaNavyBlue,
          size: 42,
        ),
        SizedBox(height: 10),
        Text(
          'Select Session Photo',
          style: TextStyle(
            color: AppColors.namaNavyBlue,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Choose one photo from your gallery',
          style: TextStyle(
            color: AppColors.namaMediumGray,
            fontSize: 11.5,
          ),
        ),
      ],
    );
  }

  Widget _imagePickerBox() {
    return InkWell(
      onTap: _pickImage,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 230,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFFE4E0F2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.045),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: _selectedImagePreview(),
      ),
    );
  }

  Widget _captionField() {
    return TextField(
      controller: _captionController,
      enabled: !_isUploading,
      maxLines: 4,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: 'Caption (optional)',
        hintText: 'Example: Group discussion during the workshop...',
        labelStyle: const TextStyle(
          color: AppColors.namaNavyBlue,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: TextStyle(
          color: Colors.grey.shade500,
          fontSize: 12,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xFFE4E0F2),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xFFE4E0F2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: AppColors.namaNavyBlue,
            width: 1.2,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.namaLightGray,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: _isUploading ? null : () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 32,
                      width: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F2FB),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: AppColors.namaNavyBlue,
                        size: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Upload Session Photo',
                      style: TextStyle(
                        color: AppColors.namaNavyBlue,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: AppColors.namaNavyBlue,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.session.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      widget.session.location,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _imagePickerBox(),
              const SizedBox(height: 16),
              _captionField(),
              const SizedBox(height: 18),
              SizedBox(
                height: 46,
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isUploading ? null : _uploadPhoto,
                  icon: _isUploading
                      ? const SizedBox(
                          height: 17,
                          width: 17,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.cloud_upload_outlined, size: 19),
                  label: Text(
                    _isUploading ? 'Uploading...' : 'Upload Photo',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.namaNavyBlue,
                    disabledBackgroundColor:
                        AppColors.namaNavyBlue.withOpacity(0.55),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Note: Uploaded photos will be reviewed by admin before being used in the event report.',
                style: TextStyle(
                  color: AppColors.namaMediumGray,
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}