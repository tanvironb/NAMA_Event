// lib/features/web_admin/event_workspace/Screens/admin_web_certificate_template_screen.dart

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../admin_web_theme.dart';

class AdminWebCertificateTemplateScreen extends StatefulWidget {
  final String eventId;
  final String eventName;

  const AdminWebCertificateTemplateScreen({
    super.key,
    required this.eventId,
    required this.eventName,
  });

  @override
  State<AdminWebCertificateTemplateScreen> createState() =>
      _AdminWebCertificateTemplateScreenState();
}

class _AdminWebCertificateTemplateScreenState
    extends State<AdminWebCertificateTemplateScreen> {
  final _picker = ImagePicker();
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;

  String _selectedRole = 'attendee';
  String _templateUrl = '';
  String _storagePath = '';
  String _orientation = 'landscape';
  String _textColor = '#111827';

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDeleting = false;

  double _nameX = .50;
  double _nameY = .48;
  double _eventX = .50;
  double _eventY = .60;
  double _dateX = .50;
  double _dateY = .68;
  double _certificateIdX = .50;
  double _certificateIdY = .88;

  double _nameFontSize = 34;
  double _eventFontSize = 16;
  double _dateFontSize = 16;
  double _certificateIdFontSize = 16;

  static const _roles = ['attendee', 'speaker', 'moderator', 'staff'];

  DocumentReference<Map<String, dynamic>> get _templateRef => _firestore
      .collection('events')
      .doc(widget.eventId)
      .collection('certificateTemplates')
      .doc(_selectedRole);

  String get _roleLabel => _labelForRole(_selectedRole);

  String get _previewPersonName {
    switch (_selectedRole) {
      case 'speaker':
        return 'Speaker Name';
      case 'moderator':
        return 'Moderator Name';
      case 'staff':
        return 'Volunteer Name';
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
      default:
        return 'NAMA-PART-2026-0001';
    }
  }

  bool get _hasTemplate =>
      _selectedImageBytes != null || _templateUrl.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadTemplate();
  }

  double _readDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  void _resetValues() {
    _selectedImage = null;
    _selectedImageBytes = null;
    _templateUrl = '';
    _storagePath = '';
    _orientation = 'landscape';
    _textColor = '#111827';
    _nameX = .50;
    _nameY = .48;
    _eventX = .50;
    _eventY = .60;
    _dateX = .50;
    _dateY = .68;
    _certificateIdX = .50;
    _certificateIdY = .88;
    _nameFontSize = 34;
    _eventFontSize = 16;
    _dateFontSize = 16;
    _certificateIdFontSize = 16;
  }

  Future<void> _changeRole(String role) async {
    if (_isSaving || role == _selectedRole) return;

    setState(() {
      _selectedRole = role;
      _isLoading = true;
      _resetValues();
    });

    await _loadTemplate();
  }

  Future<void> _loadTemplate() async {
    try {
      final document = await _templateRef.get();
      final data = document.data();

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

          final legacy = _readDouble(data['normalFontSize'], 16);
          _nameFontSize =
              _readDouble(data['nameFontSize'], _nameFontSize);
          _eventFontSize = _readDouble(data['eventFontSize'], legacy);
          _dateFontSize = _readDouble(data['dateFontSize'], legacy);
          _certificateIdFontSize =
              _readDouble(data['certificateIdFontSize'], legacy);
          _textColor = (data['textColor'] ?? _textColor).toString();
        }

        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('Unable to load the $_roleLabel template: $error', true);
    }
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );

    if (image == null) return;
    final bytes = await image.readAsBytes();

    if (!mounted) return;
    setState(() {
      _selectedImage = image;
      _selectedImageBytes = bytes;
    });
  }

  Future<String> _uploadSelectedImage() async {
    if (_selectedImage == null || _selectedImageBytes == null) {
      return _templateUrl;
    }

    final extension = _selectedImage!.name.split('.').last.toLowerCase();
    final safeExtension = const ['png', 'jpg', 'jpeg'].contains(extension)
        ? extension
        : 'jpg';

    final path =
        'certificate_templates/${widget.eventId}/$_selectedRole/'
        'template_${DateTime.now().millisecondsSinceEpoch}.$safeExtension';

    final reference = _storage.ref(path);
    await reference.putData(
      _selectedImageBytes!,
      SettableMetadata(
        contentType:
            safeExtension == 'png' ? 'image/png' : 'image/jpeg',
      ),
    );

    _storagePath = path;
    return reference.getDownloadURL();
  }

  Future<void> _saveTemplate() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final downloadUrl = await _uploadSelectedImage();
      if (downloadUrl.trim().isEmpty) {
        throw Exception('Upload a certificate template image first.');
      }

      await _templateRef.set(
        {
          'templateUrl': downloadUrl,
          'storagePath': _storagePath,
          'role': _selectedRole,
          'roleLabel': _roleLabel,
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

      _showMessage('$_roleLabel certificate template saved successfully.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        error.toString().replaceFirst('Exception: ', ''),
        true,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteTemplate() async {
    if (_isDeleting || !_hasTemplate) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Certificate Template'),
        content: Text(
          'Delete the $_roleLabel certificate template? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => _isDeleting = true);

    try {
      await _templateRef.delete();
      if (_storagePath.trim().isNotEmpty) {
        try {
          await _storage.ref(_storagePath).delete();
        } catch (_) {}
      }

      if (!mounted) return;
      setState(_resetValues);
      _showMessage('$_roleLabel template deleted.');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Failed to delete template: $error', true);
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  void _resetPositions() {
    setState(() {
      _nameX = .50;
      _nameY = .48;
      _eventX = .50;
      _eventY = .60;
      _dateX = .50;
      _dateY = .68;
      _certificateIdX = .50;
      _certificateIdY = .88;
      _nameFontSize = 34;
      _eventFontSize = 16;
      _dateFontSize = 16;
      _certificateIdFontSize = 16;
      _textColor = '#111827';
    });
  }

  Color _parseColor(String hex) {
    var value = hex.replaceAll('#', '').trim();
    if (value.length == 6) value = 'FF$value';
    return Color(int.tryParse(value, radix: 16) ?? 0xFF111827);
  }

  void _showMessage(String message, [bool error = false]) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              error ? Colors.redAccent : AdminWebTheme.primary,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AdminWebTheme.primary,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, pageConstraints) {
        final isWide = pageConstraints.maxWidth >= 1050;

        final preview = _PreviewPanel(
          selectedImageBytes: _selectedImageBytes,
          templateUrl: _templateUrl,
          orientation: _orientation,
          textColor: _parseColor(_textColor),
          personName: _previewPersonName,
          eventName: widget.eventName,
          certificateId: _previewCertificateId,
          nameX: _nameX,
          nameY: _nameY,
          eventX: _eventX,
          eventY: _eventY,
          dateX: _dateX,
          dateY: _dateY,
          certificateIdX: _certificateIdX,
          certificateIdY: _certificateIdY,
          nameFontSize: _nameFontSize,
          eventFontSize: _eventFontSize,
          dateFontSize: _dateFontSize,
          certificateIdFontSize: _certificateIdFontSize,
        );

        final controls = _ControlsPanel(
          roleLabel: _roleLabel,
          selectedImageName: _selectedImage?.name,
          orientation: _orientation,
          textColor: _textColor,
          isBusy: _isSaving || _isDeleting,
          hasTemplate: _hasTemplate,
          nameX: _nameX,
          nameY: _nameY,
          eventX: _eventX,
          eventY: _eventY,
          dateX: _dateX,
          dateY: _dateY,
          certificateIdX: _certificateIdX,
          certificateIdY: _certificateIdY,
          nameFontSize: _nameFontSize,
          eventFontSize: _eventFontSize,
          dateFontSize: _dateFontSize,
          certificateIdFontSize: _certificateIdFontSize,
          onPickImage: _pickImage,
          onOrientationChanged: (value) {
            setState(() => _orientation = value);
          },
          onTextColorChanged: (value) {
            setState(() => _textColor = value);
          },
          onReset: _resetPositions,
          onDelete: _deleteTemplate,
          onNameXChanged: (value) {
            setState(() => _nameX = value);
          },
          onNameYChanged: (value) {
            setState(() => _nameY = value);
          },
          onEventXChanged: (value) {
            setState(() => _eventX = value);
          },
          onEventYChanged: (value) {
            setState(() => _eventY = value);
          },
          onDateXChanged: (value) {
            setState(() => _dateX = value);
          },
          onDateYChanged: (value) {
            setState(() => _dateY = value);
          },
          onCertificateIdXChanged: (value) {
            setState(() => _certificateIdX = value);
          },
          onCertificateIdYChanged: (value) {
            setState(() => _certificateIdY = value);
          },
          onNameFontSizeChanged: (value) {
            setState(() => _nameFontSize = value);
          },
          onEventFontSizeChanged: (value) {
            setState(() => _eventFontSize = value);
          },
          onDateFontSizeChanged: (value) {
            setState(() => _dateFontSize = value);
          },
          onCertificateIdFontSizeChanged: (value) {
            setState(() => _certificateIdFontSize = value);
          },
        );

        final header = _PageHeader(
          eventName: widget.eventName,
          roleLabel: _roleLabel,
          isSaving: _isSaving,
          onSave: _saveTemplate,
        );

        final roleSelector = _RoleSelector(
          selectedRole: _selectedRole,
          enabled: !_isSaving,
          onChanged: _changeRole,
        );

        // On smaller screens, keep the original normal page scrolling.
        if (!isWide) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                const SizedBox(height: 18),
                roleSelector,
                const SizedBox(height: 18),
                preview,
                const SizedBox(height: 18),
                controls,
                const SizedBox(height: 18),
                _BottomActions(
                  isSaving: _isSaving,
                  roleLabel: _roleLabel,
                  onSave: _saveTemplate,
                ),
              ],
            ),
          );
        }

        // Desktop layout:
        // - Header and role selector remain fixed.
        // - The certificate preview remains visible on the left.
        // - Only the settings column on the right scrolls.
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              const SizedBox(height: 18),
              roleSelector,
              const SizedBox(height: 18),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: preview,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      flex: 4,
                      child: Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          primary: true,
                          padding: const EdgeInsets.only(
                            right: 8,
                            bottom: 24,
                          ),
                          child: Column(
                            children: [
                              controls,
                              const SizedBox(height: 18),
                              _BottomActions(
                                isSaving: _isSaving,
                                roleLabel: _roleLabel,
                                onSave: _saveTemplate,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

}

class _PageHeader extends StatelessWidget {
  final String eventName;
  final String roleLabel;
  final bool isSaving;
  final VoidCallback onSave;

  const _PageHeader({
    required this.eventName,
    required this.roleLabel,
    required this.isSaving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eventName.toUpperCase(),
                style: const TextStyle(
                  color: AdminWebTheme.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Certificate Templates',
                style: TextStyle(
                  color: AdminWebTheme.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Design and configure the $roleLabel certificate template.',
                style: const TextStyle(
                  color: AdminWebTheme.textSecondary,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: isSaving ? null : onSave,
          icon: isSaving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_outlined, size: 17),
          label: Text(isSaving ? 'Saving...' : 'Save Template'),
          style: FilledButton.styleFrom(
            backgroundColor: AdminWebTheme.primary,
          ),
        ),
      ],
    );
  }
}

class _RoleSelector extends StatelessWidget {
  final String selectedRole;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _RoleSelector({
    required this.selectedRole,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Certificate User Type',
            style: TextStyle(
              color: AdminWebTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Each role has an independent image and text layout.',
            style: TextStyle(
              color: AdminWebTheme.textSecondary,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: _AdminWebCertificateTemplateScreenState._roles
                .map((role) {
              final selected = role == selectedRole;

              return ChoiceChip(
                selected: selected,
                showCheckmark: false,
                onSelected: enabled ? (_) => onChanged(role) : null,
                avatar: Icon(
                  _iconForRole(role),
                  size: 17,
                  color: selected
                      ? Colors.white
                      : AdminWebTheme.primary,
                ),
                label: Text(_labelForRole(role)),
                labelStyle: TextStyle(
                  color: selected
                      ? Colors.white
                      : AdminWebTheme.primary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
                selectedColor: AdminWebTheme.primary,
                backgroundColor: const Color(0xFFF7F8FB),
                side: BorderSide(
                  color: selected
                      ? AdminWebTheme.primary
                      : AdminWebTheme.border,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  final Uint8List? selectedImageBytes;
  final String templateUrl;
  final String orientation;
  final Color textColor;
  final String personName;
  final String eventName;
  final String certificateId;
  final double nameX;
  final double nameY;
  final double eventX;
  final double eventY;
  final double dateX;
  final double dateY;
  final double certificateIdX;
  final double certificateIdY;
  final double nameFontSize;
  final double eventFontSize;
  final double dateFontSize;
  final double certificateIdFontSize;

  const _PreviewPanel({
    required this.selectedImageBytes,
    required this.templateUrl,
    required this.orientation,
    required this.textColor,
    required this.personName,
    required this.eventName,
    required this.certificateId,
    required this.nameX,
    required this.nameY,
    required this.eventX,
    required this.eventY,
    required this.dateX,
    required this.dateY,
    required this.certificateIdX,
    required this.certificateIdY,
    required this.nameFontSize,
    required this.eventFontSize,
    required this.dateFontSize,
    required this.certificateIdFontSize,
  });

  @override
  Widget build(BuildContext context) {
    final hasTemplate =
        selectedImageBytes != null || templateUrl.trim().isNotEmpty;

    final logicalWidth = orientation == 'portrait' ? 707.0 : 1000.0;
    final logicalHeight = orientation == 'portrait' ? 1000.0 : 707.0;

    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Live Preview',
            style: TextStyle(
              color: AdminWebTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Changes appear instantly. Positions are saved as relative values.',
            style: TextStyle(
              color: AdminWebTheme.textSecondary,
              fontSize: 9.5,
            ),
          ),
          const SizedBox(height: 16),

          // This area now fits the entire certificate inside the available
          // desktop height instead of overflowing below the page.
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.contain,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: logicalWidth,
                  height: logicalHeight,
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F5FA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AdminWebTheme.border,
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (selectedImageBytes != null)
                          Image.memory(
                            selectedImageBytes!,
                            fit: BoxFit.cover,
                          )
                        else if (templateUrl.trim().isNotEmpty)
                          Image.network(
                            templateUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) {
                              return const _TemplatePlaceholder(
                                message:
                                    'Template image could not load',
                              );
                            },
                          )
                        else
                          const _TemplatePlaceholder(
                            message: 'No template uploaded yet',
                          ),
                        if (hasTemplate) ...[
                          _PreviewText(
                            x: nameX,
                            y: nameY,
                            width: logicalWidth,
                            text: personName,
                            color: textColor,
                            fontSize: nameFontSize,
                            fontWeight: FontWeight.w900,
                          ),
                          _PreviewText(
                            x: eventX,
                            y: eventY,
                            width: logicalWidth,
                            text: eventName,
                            color: textColor,
                            fontSize: eventFontSize,
                            fontWeight: FontWeight.w700,
                          ),
                          _PreviewText(
                            x: dateX,
                            y: dateY,
                            width: logicalWidth,
                            text: '11 Jun 2026',
                            color: textColor,
                            fontSize: dateFontSize,
                            fontWeight: FontWeight.w600,
                          ),
                          _PreviewText(
                            x: certificateIdX,
                            y: certificateIdY,
                            width: logicalWidth,
                            text: certificateId,
                            color: textColor,
                            fontSize: certificateIdFontSize,
                            fontWeight: FontWeight.w600,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplatePlaceholder extends StatelessWidget {
  final String message;

  const _TemplatePlaceholder({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.image_outlined,
            color: AdminWebTheme.textSecondary,
            size: 44,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(
              color: AdminWebTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlsPanel extends StatelessWidget {
  final String roleLabel;
  final String? selectedImageName;
  final String orientation;
  final String textColor;
  final bool isBusy;
  final bool hasTemplate;
  final double nameX;
  final double nameY;
  final double eventX;
  final double eventY;
  final double dateX;
  final double dateY;
  final double certificateIdX;
  final double certificateIdY;
  final double nameFontSize;
  final double eventFontSize;
  final double dateFontSize;
  final double certificateIdFontSize;
  final VoidCallback onPickImage;
  final ValueChanged<String> onOrientationChanged;
  final ValueChanged<String> onTextColorChanged;
  final VoidCallback onReset;
  final VoidCallback onDelete;
  final ValueChanged<double> onNameXChanged;
  final ValueChanged<double> onNameYChanged;
  final ValueChanged<double> onEventXChanged;
  final ValueChanged<double> onEventYChanged;
  final ValueChanged<double> onDateXChanged;
  final ValueChanged<double> onDateYChanged;
  final ValueChanged<double> onCertificateIdXChanged;
  final ValueChanged<double> onCertificateIdYChanged;
  final ValueChanged<double> onNameFontSizeChanged;
  final ValueChanged<double> onEventFontSizeChanged;
  final ValueChanged<double> onDateFontSizeChanged;
  final ValueChanged<double> onCertificateIdFontSizeChanged;

  const _ControlsPanel({
    required this.roleLabel,
    required this.selectedImageName,
    required this.orientation,
    required this.textColor,
    required this.isBusy,
    required this.hasTemplate,
    required this.nameX,
    required this.nameY,
    required this.eventX,
    required this.eventY,
    required this.dateX,
    required this.dateY,
    required this.certificateIdX,
    required this.certificateIdY,
    required this.nameFontSize,
    required this.eventFontSize,
    required this.dateFontSize,
    required this.certificateIdFontSize,
    required this.onPickImage,
    required this.onOrientationChanged,
    required this.onTextColorChanged,
    required this.onReset,
    required this.onDelete,
    required this.onNameXChanged,
    required this.onNameYChanged,
    required this.onEventXChanged,
    required this.onEventYChanged,
    required this.onDateXChanged,
    required this.onDateYChanged,
    required this.onCertificateIdXChanged,
    required this.onCertificateIdYChanged,
    required this.onNameFontSizeChanged,
    required this.onEventFontSizeChanged,
    required this.onDateFontSizeChanged,
    required this.onCertificateIdFontSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SettingsCard(
          title: 'Template Image',
          subtitle: 'Upload the finished certificate background.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OutlinedButton.icon(
                onPressed: isBusy ? null : onPickImage,
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: Text(
                  selectedImageName == null
                      ? 'Upload $roleLabel Template'
                      : 'Change Selected Image',
                ),
              ),
              if (selectedImageName != null) ...[
                const SizedBox(height: 8),
                Text(
                  selectedImageName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AdminWebTheme.textSecondary,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SettingsCard(
          title: 'Page & Text',
          subtitle: 'Choose orientation and text color.',
          child: Column(
            children: [
              _SegmentedControl(
                value: orientation,
                onChanged: onOrientationChanged,
              ),
              const SizedBox(height: 14),
              _ColorField(
                value: textColor,
                onChanged: onTextColorChanged,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SettingsCard(
          title: 'Text Positioning',
          subtitle: 'Use sliders or enter exact values.',
          action: TextButton.icon(
            onPressed: isBusy ? null : onReset,
            icon: const Icon(Icons.restart_alt_rounded, size: 16),
            label: const Text('Reset'),
          ),
          child: Column(
            children: [
              _PositionEditorCard(
                title: 'Recipient Name',
                x: nameX,
                y: nameY,
                fontSize: nameFontSize,
                fontMin: 18,
                fontMax: 72,
                onXChanged: onNameXChanged,
                onYChanged: onNameYChanged,
                onFontSizeChanged: onNameFontSizeChanged,
              ),
              _PositionEditorCard(
                title: 'Event Name',
                x: eventX,
                y: eventY,
                fontSize: eventFontSize,
                fontMin: 8,
                fontMax: 48,
                onXChanged: onEventXChanged,
                onYChanged: onEventYChanged,
                onFontSizeChanged: onEventFontSizeChanged,
              ),
              _PositionEditorCard(
                title: 'Event Date',
                x: dateX,
                y: dateY,
                fontSize: dateFontSize,
                fontMin: 8,
                fontMax: 48,
                onXChanged: onDateXChanged,
                onYChanged: onDateYChanged,
                onFontSizeChanged: onDateFontSizeChanged,
              ),
              _PositionEditorCard(
                title: 'Certificate ID',
                x: certificateIdX,
                y: certificateIdY,
                fontSize: certificateIdFontSize,
                fontMin: 8,
                fontMax: 48,
                onXChanged: onCertificateIdXChanged,
                onYChanged: onCertificateIdYChanged,
                onFontSizeChanged: onCertificateIdFontSizeChanged,
              ),
            ],
          ),
        ),
        if (hasTemplate) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isBusy ? null : onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 17),
              label: const Text('Delete This Template'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  const _SettingsCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AdminWebTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: AdminWebTheme.textSecondary,
              fontSize: 9.5,
            ),
          ),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }
}

class _SegmentedControl extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _SegmentedControl({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminWebTheme.border),
      ),
      child: Row(
        children: ['landscape', 'portrait'].map((item) {
          final selected = value == item;
          return Expanded(
            child: Material(
              color: selected
                  ? AdminWebTheme.primary
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: () => onChanged(item),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Text(
                    item == 'landscape' ? 'Landscape' : 'Portrait',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : AdminWebTheme.textSecondary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ColorField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _ColorField({
    required this.value,
    required this.onChanged,
  });

  @override
  State<_ColorField> createState() => _ColorFieldState();
}

class _ColorFieldState extends State<_ColorField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _ColorField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value &&
        _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _parse(String value) {
    var clean = value.replaceAll('#', '').trim();
    if (clean.length == 6) clean = 'FF$clean';
    return Color(int.tryParse(clean, radix: 16) ?? 0xFF111827);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _parse(widget.value),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AdminWebTheme.border),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: _controller,
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(r'[0-9a-fA-F#]'),
              ),
              LengthLimitingTextInputFormatter(7),
            ],
            decoration: const InputDecoration(
              labelText: 'Text color',
              hintText: '#111827',
              isDense: true,
            ),
            onChanged: (value) {
              if (RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) {
                widget.onChanged(value.toUpperCase());
              }
            },
          ),
        ),
      ],
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
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminWebTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AdminWebTheme.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
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

  String _formatted(double value) =>
      value.toStringAsFixed(widget.decimals);

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: _formatted(widget.value));
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant _EditableSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && oldWidget.value != widget.value) {
      _controller.text = _formatted(widget.value);
    }
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) _commitText();
  }

  void _commitText() {
    final parsed = double.tryParse(_controller.text.trim());
    if (parsed == null) {
      _controller.text = _formatted(widget.value);
      return;
    }

    final safe = parsed.clamp(widget.min, widget.max).toDouble();
    _controller.text = _formatted(safe);
    widget.onChanged(safe);
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
    final value = widget.value.clamp(widget.min, widget.max).toDouble();

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              widget.title,
              style: const TextStyle(
                color: AdminWebTheme.textSecondary,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Slider(
              value: value,
              min: widget.min,
              max: widget.max,
              activeColor: AdminWebTheme.primary,
              onChanged: (newValue) {
                _controller.text = _formatted(newValue);
                widget.onChanged(newValue);
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            height: 34,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'^\d*\.?\d{0,3}'),
                ),
              ],
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 9,
                ),
              ),
              onSubmitted: (_) => _commitText(),
            ),
          ),
        ],
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
        translation: Offset(x - .5, y - .5),
        child: Center(
          child: SizedBox(
            width: width * .84,
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

class _BottomActions extends StatelessWidget {
  final bool isSaving;
  final String roleLabel;
  final VoidCallback onSave;

  const _BottomActions({
    required this.isSaving,
    required this.roleLabel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Save the current image, positions, font sizes, and color.',
              style: TextStyle(
                color: AdminWebTheme.textSecondary,
                fontSize: 10,
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: isSaving ? null : onSave,
            icon: isSaving
                ? const SizedBox(
                    height: 15,
                    width: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined, size: 17),
            label: Text(
              isSaving ? 'Saving...' : 'Save $roleLabel Template',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AdminWebTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

String _labelForRole(String role) {
  switch (role) {
    case 'speaker':
      return 'Speaker';
    case 'moderator':
      return 'Moderator';
    case 'staff':
      return 'Staff / Volunteer';
    default:
      return 'Attendee';
  }
}

IconData _iconForRole(String role) {
  switch (role) {
    case 'speaker':
      return Icons.record_voice_over_rounded;
    case 'moderator':
      return Icons.forum_rounded;
    case 'staff':
      return Icons.groups_rounded;
    default:
      return Icons.person_rounded;
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: AdminWebTheme.border),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(.025),
        blurRadius: 14,
        offset: const Offset(0, 5),
      ),
    ],
  );
}
