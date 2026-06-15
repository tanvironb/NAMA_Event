import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
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
  double _normalFontSize = 16;
  String _textColor = '#111827';

  DocumentReference<Map<String, dynamic>> get _templateRef {
    return _firestore
        .collection('events')
        .doc(widget.eventId)
        .collection('certificateTemplate')
        .doc('main');
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
        _certificateIdX = _readDouble(data['certificateIdX'], _certificateIdX);
        _certificateIdY = _readDouble(data['certificateIdY'], _certificateIdY);
        _nameFontSize = _readDouble(data['nameFontSize'], _nameFontSize);
        _normalFontSize = _readDouble(data['normalFontSize'], _normalFontSize);
        _textColor = (data['textColor'] ?? _textColor).toString();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        'certificate_templates/${widget.eventId}/template_$timestamp.$safeExtension';

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
          'normalFontSize': _normalFontSize,
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
        const SnackBar(
          content: Text('Certificate template saved successfully.'),
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
      child: const Text(
        'Upload the final certificate design as PNG/JPG. The app will place participant name, event name, date, and certificate ID on top of this template.',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 11.5,
          height: 1.35,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _previewCard() {
  final textColor = _parseColor(_textColor);
  final aspectRatio = _orientation == 'portrait' ? 0.707 : 1.414;
  final hasTemplate =
      _selectedImageBytes != null || _templateUrl.trim().isNotEmpty;

  return Container(
    width: double.infinity,
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
        AspectRatio(
          aspectRatio: aspectRatio,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F2FB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE4E0F2)),
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
                        text: 'Participant Name',
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
                        fontSize: _normalFontSize * 0.28,
                        fontWeight: FontWeight.w800,
                      ),
                      _PreviewText(
                        x: _dateX,
                        y: _dateY,
                        width: constraints.maxWidth,
                        text: '11 Jun 2026',
                        color: textColor,
                        fontSize: _normalFontSize * 0.26,
                        fontWeight: FontWeight.w700,
                      ),
                      _PreviewText(
                        x: _certificateIdX,
                        y: _certificateIdY,
                        width: constraints.maxWidth,
                        text: 'NAMA-PART-2026-0001',
                        color: textColor,
                        fontSize: _normalFontSize * 0.24,
                        fontWeight: FontWeight.w700,
                      ),
                    ],
                  ],
                );
              },
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
              ? 'Upload Template Image'
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
          const SizedBox(height: 12),
          _SliderPair(
            title: 'Participant Name',
            x: _nameX,
            y: _nameY,
            onXChanged: (value) => setState(() => _nameX = value),
            onYChanged: (value) => setState(() => _nameY = value),
          ),
          _SliderPair(
            title: 'Event Name',
            x: _eventX,
            y: _eventY,
            onXChanged: (value) => setState(() => _eventX = value),
            onYChanged: (value) => setState(() => _eventY = value),
          ),
          _SliderPair(
            title: 'Event Date',
            x: _dateX,
            y: _dateY,
            onXChanged: (value) => setState(() => _dateX = value),
            onYChanged: (value) => setState(() => _dateY = value),
          ),
          _SliderPair(
            title: 'Certificate ID',
            x: _certificateIdX,
            y: _certificateIdY,
            onXChanged: (value) => setState(() => _certificateIdX = value),
            onYChanged: (value) => setState(() => _certificateIdY = value),
          ),
          const SizedBox(height: 8),
          _SingleSlider(
            title: 'Name font size',
            value: _nameFontSize,
            min: 18,
            max: 56,
            onChanged: (value) => setState(() => _nameFontSize = value),
          ),
          _SingleSlider(
            title: 'Normal font size',
            value: _normalFontSize,
            min: 10,
            max: 28,
            onChanged: (value) => setState(() => _normalFontSize = value),
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
          _isSaving ? 'Saving Template...' : 'Save Certificate Template',
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
    return Scaffold(
      backgroundColor: AppColors.namaLightGray,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.namaNavyBlue),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                children: [
                  _header(),
                  const SizedBox(height: 18),
                  _infoCard(),
                  const SizedBox(height: 14),
                  _uploadButton(),
                  const SizedBox(height: 12),
                  _orientationSelector(),
                  const SizedBox(height: 14),
                  _previewCard(),
                  const SizedBox(height: 14),
                  _positionControls(),
                  const SizedBox(height: 16),
                  _saveButton(),
                ],
              ),
      ),
    );
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

class _SliderPair extends StatelessWidget {
  final String title;
  final double x;
  final double y;
  final ValueChanged<double> onXChanged;
  final ValueChanged<double> onYChanged;

  const _SliderPair({
    required this.title,
    required this.x,
    required this.y,
    required this.onXChanged,
    required this.onYChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.namaDarkGray,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          _SingleSlider(title: 'Horizontal', value: x, onChanged: onXChanged),
          _SingleSlider(title: 'Vertical', value: y, onChanged: onYChanged),
        ],
      ),
    );
  }
}

class _SingleSlider extends StatelessWidget {
  final String title;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _SingleSlider({
    required this.title,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 86,
          child: Text(
            title,
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
              inactiveTrackColor: AppColors.namaGoldenYellow.withOpacity(0.65),
              thumbColor: AppColors.namaNavyBlue,
              overlayColor: AppColors.namaGoldenYellow.withOpacity(0.20),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 10,
              ),
            ),
            child: Slider(
              value: value.clamp(min, max).toDouble(),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 38,
          child: Text(
            value.toStringAsFixed(min == 0 && max == 1 ? 2 : 0),
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.namaDarkGray,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
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