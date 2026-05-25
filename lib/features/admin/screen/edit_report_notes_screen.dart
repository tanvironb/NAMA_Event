import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EditReportNotesScreen extends StatefulWidget {
  final String eventId;
  final String eventName;

  const EditReportNotesScreen({
    super.key,
    required this.eventId,
    required this.eventName,
  });

  @override
  State<EditReportNotesScreen> createState() => _EditReportNotesScreenState();
}

class _EditReportNotesScreenState extends State<EditReportNotesScreen> {
  final TextEditingController _objectivesController = TextEditingController();
  final TextEditingController _highlightsController = TextEditingController();
  final TextEditingController _outcomesController = TextEditingController();
  final TextEditingController _challengesController = TextEditingController();
  final TextEditingController _recommendationsController =
      TextEditingController();
  final TextEditingController _conclusionController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  DocumentReference<Map<String, dynamic>> get _notesRef {
    return FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .collection('reportNotes')
        .doc('main');
  }

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void dispose() {
    _objectivesController.dispose();
    _highlightsController.dispose();
    _outcomesController.dispose();
    _challengesController.dispose();
    _recommendationsController.dispose();
    _conclusionController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    try {
      final doc = await _notesRef.get();

      if (!mounted) return;

      if (doc.exists) {
        final data = doc.data() ?? {};

        _objectivesController.text =
            (data['eventObjectives'] ?? '').toString();
        _highlightsController.text = (data['keyHighlights'] ?? '').toString();
        _outcomesController.text = (data['mainOutcomes'] ?? '').toString();
        _challengesController.text = (data['challenges'] ?? '').toString();
        _recommendationsController.text =
            (data['recommendations'] ?? '').toString();
        _conclusionController.text = (data['conclusion'] ?? '').toString();
      }

      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load report notes: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _saveNotes() async {
    if (_isSaving) return;

    try {
      setState(() => _isSaving = true);

      final user = FirebaseAuth.instance.currentUser;

      await _notesRef.set({
        'eventId': widget.eventId,
        'eventName': widget.eventName,
        'eventObjectives': _objectivesController.text.trim(),
        'keyHighlights': _highlightsController.text.trim(),
        'mainOutcomes': _outcomesController.text.trim(),
        'challenges': _challengesController.text.trim(),
        'recommendations': _recommendationsController.text.trim(),
        'conclusion': _conclusionController.text.trim(),
        'updatedBy': user?.uid ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report notes saved successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save report notes: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildTextArea({
    required String title,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        enabled: !_isSaving,
        maxLines: 5,
        style: const TextStyle(
          color: AppColors.namaDarkGray,
          fontSize: 13,
          height: 1.4,
        ),
        decoration: InputDecoration(
          prefixIcon: Padding(
            padding: const EdgeInsets.only(bottom: 70),
            child: Icon(
              icon,
              color: AppColors.namaNavyBlue,
              size: 20,
            ),
          ),
          labelText: title,
          hintText: hint,
          alignLabelWithHint: true,
          labelStyle: const TextStyle(
            color: AppColors.namaNavyBlue,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
          hintStyle: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 12,
            height: 1.35,
          ),
          filled: true,
          fillColor: const Color(0xFFF8F8FB),
          contentPadding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        InkWell(
          onTap: _isSaving ? null : () => Navigator.of(context).pop(),
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
            'Edit Report Notes',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.namaNavyBlue,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _eventCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.namaNavyBlue,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Final Report Narrative',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.eventName,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'These notes will appear in the Event Report Dashboard and PDF report.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _saveButton() {
    return SizedBox(
      height: 46,
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _saveNotes,
        icon: _isSaving
            ? const SizedBox(
                height: 17,
                width: 17,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.save_outlined, size: 18),
        label: Text(
          _isSaving ? 'Saving...' : 'Save Report Notes',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.namaNavyBlue,
          disabledBackgroundColor: AppColors.namaNavyBlue.withOpacity(0.55),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
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
                child: CircularProgressIndicator(
                  color: AppColors.namaNavyBlue,
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(),
                    const SizedBox(height: 18),
                    _eventCard(),
                    const SizedBox(height: 18),
                    _buildTextArea(
                      title: 'Event Objectives',
                      hint:
                          'Write the main objectives of the event. Example: To bring stakeholders together, share knowledge, and strengthen collaboration.',
                      controller: _objectivesController,
                      icon: Icons.flag_outlined,
                    ),
                    _buildTextArea(
                      title: 'Key Highlights',
                      hint:
                          'Write the key highlights. Example: keynote speeches, panel discussions, networking sessions, workshops, exhibitions.',
                      controller: _highlightsController,
                      icon: Icons.star_outline_rounded,
                    ),
                    _buildTextArea(
                      title: 'Main Outcomes',
                      hint:
                          'Write what the event achieved. Example: stronger partnerships, knowledge sharing, participant engagement, agreements, future actions.',
                      controller: _outcomesController,
                      icon: Icons.check_circle_outline_rounded,
                    ),
                    _buildTextArea(
                      title: 'Challenges Faced',
                      hint:
                          'Write any challenges faced. Example: time limitation, technical issues, attendance gaps, logistics, communication issues.',
                      controller: _challengesController,
                      icon: Icons.warning_amber_rounded,
                    ),
                    _buildTextArea(
                      title: 'Recommendations',
                      hint:
                          'Write recommendations for future improvement. Example: improve registration flow, increase promotion, add more Q&A time.',
                      controller: _recommendationsController,
                      icon: Icons.tips_and_updates_outlined,
                    ),
                    _buildTextArea(
                      title: 'Conclusion',
                      hint:
                          'Write a short closing conclusion for management report.',
                      controller: _conclusionController,
                      icon: Icons.article_outlined,
                    ),
                    const SizedBox(height: 8),
                    _saveButton(),
                  ],
                ),
              ),
      ),
    );
  }
}