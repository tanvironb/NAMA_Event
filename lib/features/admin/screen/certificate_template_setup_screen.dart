import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class CertificateTemplateSetupScreen extends StatefulWidget {
  final String eventId;
  final String eventName;

  const CertificateTemplateSetupScreen({
    super.key,
    required this.eventId,
    required this.eventName,
  });

  @override
  State<CertificateTemplateSetupScreen> createState() =>
      _CertificateTemplateSetupScreenState();
}

class _CertificateTemplateSetupScreenState
    extends State<CertificateTemplateSetupScreen> {
  final ImagePicker _picker = ImagePicker();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;

  String _selectedRole = 'attendee';
  String _templateUrl = '';
  String _storagePath = '';
  String _orientation = 'landscape';
  bool _isLoading = true;
  bool _isSaving = false;

  double _nameX = 0.50;
  double _nameY = 0.48;
  double _eventX = 0.50;
  double _eventY = 0.60;
  double _dateX = 0.50;
  double _dateY = 0.68;
  double _certificateIdX = 0.50;
  double _certificateIdY = 0.88;

  double _nameFontSize = 34;
  double _eventFontSize = 16;
  double _dateFontSize = 16;
  double _certificateIdFontSize = 16;
  String _textColor = '#111827';

  static const List<String> _supportedRoles = <String>[
    'attendee',
    'speaker',
    'moderator',
    'staff',
  ];

  DocumentReference<Map<String, dynamic>> get _templateRef {
    return _firestore
        .collection('events')
        .doc(widget.eventId)
        .collection('certificateTemplates')
        .doc(_selectedRole);
  }

  String get _selectedRoleLabel {
    switch (_selectedRole) {
      case 'speaker':
        return 'Speaker';
      case 'moderator':
        return 'Moderator';
      case 'staff':
        return 'Staff / Volunteer';
      case 'attendee':
      default:
        return 'Attendee';
    }
  }

  String get _previewPersonName {
    switch (_selectedRole) {
      case 'speaker':
        return 'Speaker Name';
      case 'moderator':
        return 'Moderator Name';
      case 'staff':
        return 'Volunteer Name';
      case 'attendee':
      default:
        return 'Participant Name';
    }
  }

  String get _previewCertificateId {
    switch (_selectedRole) {
      case 'speaker':
        return 'NAMA-SPK-2026-0001';
      case 'moderator':
        return 'NAMA-MOD-2026-0001';
      case 'staff':
        return 'NAMA-STF-2026-0001';
      case 'attendee':
      default:
        return 'NAMA-PART-2026-0001';
    }
  }

  void _resetTemplateValues() {
    _selectedImage = null;
    _selectedImageBytes = null;
    _templateUrl = '';
    _storagePath = '';
    _orientation = 'landscape';

    _nameX = 0.50;
    _nameY = 0.48;
    _eventX = 0.50;
    _eventY = 0.60;
    _dateX = 0.50;
    _dateY = 0.68;
    _certificateIdX = 0.50;
    _certificateIdY = 0.88;

    _nameFontSize = 34;
    _eventFontSize = 16;
    _dateFontSize = 16;
    _certificateIdFontSize = 16;
    _textColor = '#111827';
  }

  Future<void> _changeRole(String role) async {
    if (_isSaving || role == _selectedRole) return;

    setState(() {
      _selectedRole = role;
      _isLoading = true;
      _resetTemplateValues();
    });

    await _loadTemplate();
  }

  @override
  void initState() {
    super.initState();
    _loadTemplate();
  }

  Future<void> _loadTemplate() async {
    try {
      final doc = await _templateRef.get();
      final data = doc.data();

      if (!mounted) return;

      setState(() {
        if (data != null) {
          _templateUrl = (data['templateUrl'] ?? '').toString();
          _storagePath = (data['storagePath'] ?? '').toString();
          _orientation = (data['orientation'] ?? 'landscape').toString();
          _nameX = _readDouble(data['nameX'], _nameX);
          _nameY = _readDouble(data['nameY'], _nameY);
          _eventX = _readDouble(data['eventX'], _eventX);
          _eventY = _readDouble(data['eventY'], _eventY);
          _dateX = _readDouble(data['dateX'], _dateX);
          _dateY = _readDouble(data['dateY'], _dateY);
          _certificateIdX =
              _readDouble(data['certificateIdX'], _certificateIdX);
          _certificateIdY =
              _readDouble(data['certificateIdY'], _certificateIdY);
          final legacyNormalFontSize =
              _readDouble(data['normalFontSize'], 16);
          _nameFontSize =
              _readDouble(data['nameFontSize'], _nameFontSize);
          _eventFontSize =
              _readDouble(data['eventFontSize'], legacyNormalFontSize);
          _dateFontSize =
              _readDouble(data['dateFontSize'], legacyNormalFontSize);
          _certificateIdFontSize = _readDouble(
            data['certificateIdFontSize'],
            legacyNormalFontSize,
          );
          _textColor = (data['textColor'] ?? _textColor).toString();
        }

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to load the $_selectedRoleLabel certificate template.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  double _readDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );

    if (image == null) return;

    final bytes = await image.readAsBytes();

    setState(() {
      _selectedImage = image;
      _selectedImageBytes = bytes;
    });
  }

  Future<String> _uploadSelectedImage() async {
    if (_selectedImage == null || _selectedImageBytes == null) {
      return _templateUrl;
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = _selectedImage!.name.split('.').last.toLowerCase();
    final safeExtension =
        extension == 'png' || extension == 'jpg' || extension == 'jpeg'
            ? extension
            : 'jpg';

    final path =
        'certificate_templates/${widget.eventId}/$_selectedRole/'
        'template_$timestamp.$safeExtension';

    final ref = _storage.ref(path);
    final metadata = SettableMetadata(
      contentType: safeExtension == 'png' ? 'image/png' : 'image/jpeg',
    );

    await ref.putData(_selectedImageBytes!, metadata);
    final downloadUrl = await ref.getDownloadURL();

    _storagePath = path;
    return downloadUrl;
  }

  Future<void> _saveTemplate() async {
    if (_isSaving) return;

    try {
      setState(() => _isSaving = true);

      final downloadUrl = await _uploadSelectedImage();

      if (downloadUrl.trim().isEmpty) {
        throw Exception('Please upload a certificate template image first.');
      }

      await _templateRef.set(
        {
          'templateUrl': downloadUrl,
          'storagePath': _storagePath,
          'role': _selectedRole,
          'roleLabel': _selectedRoleLabel,
          'orientation': _orientation,
          'nameX': _nameX,
          'nameY': _nameY,
          'eventX': _eventX,
          'eventY': _eventY,
          'dateX': _dateX,
          'dateY': _dateY,
          'certificateIdX': _certificateIdX,
          'certificateIdY': _certificateIdY,
          'nameFontSize': _nameFontSize,
          'eventFontSize': _eventFontSize,
          'dateFontSize': _dateFontSize,
          'certificateIdFontSize': _certificateIdFontSize,
          // Kept for compatibility with older certificate rendering code.
          'normalFontSize': _eventFontSize,
          'textColor': _textColor,
          'isConfigured': true,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      setState(() {
        _templateUrl = downloadUrl;
        _selectedImage = null;
        _selectedImageBytes = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$_selectedRoleLabel certificate template saved successfully.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Color _parseColor(String hex) {
    var value = hex.replaceAll('#', '').trim();
    if (value.length == 6) value = 'FF$value';
    return Color(int.tryParse(value, radix: 16) ?? 0xFF111827);
  }

Widget _header() {
  return Row(
    children: [
      InkWell(
        onTap: () => Navigator.of(context).pop(),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.namaGoldenYellow.withOpacity(0.7),
            ),
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
          'Certificate Template',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.namaNavyBlue,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ],
  );
}

  Widget _infoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.namaNavyBlue,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Upload the final $_selectedRoleLabel certificate design as PNG/JPG. '
        'The app will place the recipient name, event name, date, and '
        'certificate ID on top of this template.',
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11.5,
          height: 1.35,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _roleSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Certificate User Type',
            style: TextStyle(
              color: AppColors.namaNavyBlue,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Each user type has its own independent certificate template.',
            style: TextStyle(
              color: AppColors.namaMediumGray,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _supportedRoles.map((role) {
              final selected = role == _selectedRole;

              String label;
              IconData icon;

              switch (role) {
                case 'speaker':
                  label = 'Speaker';
                  icon = Icons.record_voice_over_rounded;
                  break;
                case 'moderator':
                  label = 'Moderator';
                  icon = Icons.forum_rounded;
                  break;
                case 'staff':
                  label = 'Staff / Volunteer';
                  icon = Icons.groups_rounded;
                  break;
                case 'attendee':
                default:
                  label = 'Attendee';
                  icon = Icons.person_rounded;
                  break;
              }

              return ChoiceChip(
                selected: selected,
                onSelected: _isSaving ? null : (_) => _changeRole(role),
                avatar: Icon(
                  icon,
                  size: 17,
                  color: selected ? Colors.white : AppColors.namaNavyBlue,
                ),
                label: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.namaNavyBlue,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                selectedColor: AppColors.namaNavyBlue,
                backgroundColor: const Color(0xFFF4F2FB),
                side: BorderSide(
                  color: selected
                      ? AppColors.namaNavyBlue
                      : const Color(0xFFE4E0F2),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                showCheckmark: false,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

Widget _previewCard() {
  final textColor = _parseColor(_textColor);
  final hasTemplate =
      _selectedImageBytes != null || _templateUrl.trim().isNotEmpty;

  return Container(
    width: double.infinity,
    height: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: _cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Preview',
          style: TextStyle(
            color: AppColors.namaNavyBlue,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: _orientation == 'portrait' ? 0.707 : 1.414,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F2FB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFE4E0F2),
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_selectedImageBytes != null)
                          Image.memory(
                            _selectedImageBytes!,
                            fit: BoxFit.cover,
                          )
                        else if (_templateUrl.trim().isNotEmpty)
                          Image.network(
                            _templateUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) {
                              return const Center(
                                child: Text(
                                  'Template image could not load',
                                  style: TextStyle(
                                    color: AppColors.namaMediumGray,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              );
                            },
                          )
                        else
                          const Center(
                            child: Text(
                              'No template uploaded yet',
                              style: TextStyle(
                                color: AppColors.namaMediumGray,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),

                        if (hasTemplate) ...[
                          _PreviewText(
                            x: _nameX,
                            y: _nameY,
                            width: constraints.maxWidth,
                            text: _previewPersonName,
                            color: textColor,
                            fontSize: _nameFontSize * 0.28,
                            fontWeight: FontWeight.w900,
                          ),
                          _PreviewText(
                            x: _eventX,
                            y: _eventY,
                            width: constraints.maxWidth,
                            text: widget.eventName,
                            color: textColor,
                            fontSize: _eventFontSize * 0.28,
                            fontWeight: FontWeight.w800,
                          ),
                          _PreviewText(
                            x: _dateX,
                            y: _dateY,
                            width: constraints.maxWidth,
                            text: '11 Jun 2026',
                            color: textColor,
                            fontSize: _dateFontSize * 0.26,
                            fontWeight: FontWeight.w700,
                          ),
                          _PreviewText(
                            x: _certificateIdX,
                            y: _certificateIdY,
                            width: constraints.maxWidth,
                            text: _previewCertificateId,
                            color: textColor,
                            fontSize: _certificateIdFontSize * 0.24,
                            fontWeight: FontWeight.w700,
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
  Widget _uploadButton() {
    return SizedBox(
      height: 44,
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isSaving ? null : _pickImage,
        icon: const Icon(Icons.upload_file_rounded, size: 18),
        label: Text(
          _selectedImage == null
              ? 'Upload $_selectedRoleLabel Template'
              : 'Change Selected Image',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.namaNavyBlue,
          side: const BorderSide(color: Color(0xFFE4E0F2)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  Widget _orientationSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1EEF9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentButton(
              label: 'Landscape',
              selected: _orientation == 'landscape',
              onTap: () => setState(() => _orientation = 'landscape'),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _SegmentButton(
              label: 'Portrait',
              selected: _orientation == 'portrait',
              onTap: () => setState(() => _orientation = 'portrait'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _positionControls() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Text Position Settings',
            style: TextStyle(
              color: AppColors.namaNavyBlue,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Drag each slider or type an exact number in the box.',
            style: TextStyle(
              color: AppColors.namaMediumGray,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          _PositionEditorCard(
            title: 'Recipient Name',
            x: _nameX,
            y: _nameY,
            fontSize: _nameFontSize,
            fontMin: 18,
            fontMax: 72,
            onXChanged: (value) => setState(() => _nameX = value),
            onYChanged: (value) => setState(() => _nameY = value),
            onFontSizeChanged: (value) =>
                setState(() => _nameFontSize = value),
          ),
          _PositionEditorCard(
            title: 'Event Name',
            x: _eventX,
            y: _eventY,
            fontSize: _eventFontSize,
            fontMin: 8,
            fontMax: 48,
            onXChanged: (value) => setState(() => _eventX = value),
            onYChanged: (value) => setState(() => _eventY = value),
            onFontSizeChanged: (value) =>
                setState(() => _eventFontSize = value),
          ),
          _PositionEditorCard(
            title: 'Event Date',
            x: _dateX,
            y: _dateY,
            fontSize: _dateFontSize,
            fontMin: 8,
            fontMax: 48,
            onXChanged: (value) => setState(() => _dateX = value),
            onYChanged: (value) => setState(() => _dateY = value),
            onFontSizeChanged: (value) =>
                setState(() => _dateFontSize = value),
          ),
          _PositionEditorCard(
            title: 'Certificate ID',
            x: _certificateIdX,
            y: _certificateIdY,
            fontSize: _certificateIdFontSize,
            fontMin: 8,
            fontMax: 48,
            onXChanged: (value) =>
                setState(() => _certificateIdX = value),
            onYChanged: (value) =>
                setState(() => _certificateIdY = value),
            onFontSizeChanged: (value) =>
                setState(() => _certificateIdFontSize = value),
          ),
        ],
      ),
    );
  }

  Widget _saveButton() {
    return SizedBox(
      height: 44,
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _saveTemplate,
        icon: _isSaving
            ? const SizedBox(
                height: 17,
                width: 17,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.save_rounded, size: 18),
        label: Text(
          _isSaving
              ? 'Saving Template...'
              : 'Save $_selectedRoleLabel Template',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.namaNavyBlue,
          disabledBackgroundColor: AppColors.namaNavyBlue.withOpacity(0.55),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

// Page horizontal padding: 16 + 16
// Preview card internal padding: 12 + 12
final previewImageWidth = screenWidth - 56;

final previewAspectRatio =
    _orientation == 'portrait' ? 0.707 : 1.414;

final previewImageHeight =
    previewImageWidth / previewAspectRatio;

// Includes:
// preview title
// title spacing
// card padding
// bottom spacing around pinned header
final previewHeight = previewImageHeight + 72;

    return Scaffold(
      backgroundColor: AppColors.namaLightGray,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.namaNavyBlue,
                ),
              )
            : CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate(
                        [
                          _header(),
                          const SizedBox(height: 18),
                          _infoCard(),
                          const SizedBox(height: 14),
                          _roleSelector(),
                          const SizedBox(height: 14),
                          _uploadButton(),
                          const SizedBox(height: 12),
                          _orientationSelector(),
                          const SizedBox(height: 14),
                        ],
                      ),
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _PinnedPreviewDelegate(
                      height: previewHeight,
                      backgroundColor: AppColors.namaLightGray,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: _previewCard(),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate(
                        [
                          _positionControls(),
                          const SizedBox(height: 16),
                          _saveButton(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

}

class _PinnedPreviewDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Color backgroundColor;
  final Widget child;

  const _PinnedPreviewDelegate({
    required this.height,
    required this.backgroundColor,
    required this.child,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(
      child: Material(
        color: backgroundColor,
        elevation: overlapsContent ? 3 : 0,
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedPreviewDelegate oldDelegate) {
    return oldDelegate.height != height ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

class _PreviewText extends StatelessWidget {
  final double x;
  final double y;
  final double width;
  final String text;
  final Color color;
  final double fontSize;
  final FontWeight fontWeight;

  const _PreviewText({
    required this.x,
    required this.y,
    required this.width,
    required this.text,
    required this.color,
    required this.fontSize,
    required this.fontWeight,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: FractionalTranslation(
        translation: Offset(x - 0.5, y - 0.5),
        child: Center(
          child: SizedBox(
            width: width * 0.82,
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: fontSize,
                fontWeight: fontWeight,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.namaNavyBlue : AppColors.namaMediumGray,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _PositionEditorCard extends StatelessWidget {
  final String title;
  final double x;
  final double y;
  final double fontSize;
  final double fontMin;
  final double fontMax;
  final ValueChanged<double> onXChanged;
  final ValueChanged<double> onYChanged;
  final ValueChanged<double> onFontSizeChanged;

  const _PositionEditorCard({
    required this.title,
    required this.x,
    required this.y,
    required this.fontSize,
    required this.fontMin,
    required this.fontMax,
    required this.onXChanged,
    required this.onYChanged,
    required this.onFontSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF9FD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7E2F1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.namaDarkGray,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          _EditableSlider(
            title: 'Horizontal',
            value: x,
            min: 0,
            max: 1,
            decimals: 3,
            onChanged: onXChanged,
          ),
          _EditableSlider(
            title: 'Vertical',
            value: y,
            min: 0,
            max: 1,
            decimals: 3,
            onChanged: onYChanged,
          ),
          _EditableSlider(
            title: 'Font size',
            value: fontSize,
            min: fontMin,
            max: fontMax,
            decimals: 0,
            onChanged: onFontSizeChanged,
          ),
        ],
      ),
    );
  }
}

class _EditableSlider extends StatefulWidget {
  final String title;
  final double value;
  final double min;
  final double max;
  final int decimals;
  final ValueChanged<double> onChanged;

  const _EditableSlider({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.decimals,
    required this.onChanged,
  });

  @override
  State<_EditableSlider> createState() => _EditableSliderState();
}

class _EditableSliderState extends State<_EditableSlider> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  String _formatted(double value) => value.toStringAsFixed(widget.decimals);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatted(widget.value));
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant _EditableSlider oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_focusNode.hasFocus && oldWidget.value != widget.value) {
      _controller.text = _formatted(widget.value);
    }
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) {
      _commitText();
    }
  }

  void _commitText() {
    final parsed = double.tryParse(_controller.text.trim());

    if (parsed == null) {
      _controller.text = _formatted(widget.value);
      return;
    }

    final safeValue = parsed.clamp(widget.min, widget.max).toDouble();
    _controller.text = _formatted(safeValue);
    widget.onChanged(safeValue);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sliderValue =
        widget.value.clamp(widget.min, widget.max).toDouble();

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(
              widget.title,
              style: const TextStyle(
                color: AppColors.namaMediumGray,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.namaNavyBlue,
                inactiveTrackColor:
                    AppColors.namaGoldenYellow.withOpacity(0.65),
                thumbColor: AppColors.namaNavyBlue,
                overlayColor:
                    AppColors.namaGoldenYellow.withOpacity(0.20),
                trackHeight: 6,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 9,
                ),
              ),
              child: Slider(
                value: sliderValue,
                min: widget.min,
                max: widget.max,
                onChanged: (value) {
                  _controller.text = _formatted(value);
                  widget.onChanged(value);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 68,
            height: 36,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: false,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'^\d*\.?\d{0,3}'),
                ),
              ],
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.namaDarkGray,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
              decoration: InputDecoration(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
                filled: true,
                fillColor: Colors.white,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: const BorderSide(
                    color: Color(0xFFDCD6EA),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: const BorderSide(
                    color: AppColors.namaNavyBlue,
                    width: 1.4,
                  ),
                ),
              ),
              onSubmitted: (_) => _commitText(),
              onEditingComplete: () {
                _commitText();
                FocusScope.of(context).unfocus();
              },
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.045),
        blurRadius: 12,
        offset: const Offset(0, 5),
      ),
    ],
  );
}