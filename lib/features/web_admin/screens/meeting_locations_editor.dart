import 'package:flutter/material.dart';

class MeetingLocationsEditor extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;

  const MeetingLocationsEditor({
    super.key,
    required this.controller,
    this.enabled = true,
  });

  /// Accepts Firestore lists or the editor's multiline text.
  /// Removes blank entries and duplicate locations.
  static List<String> readLocations(dynamic value) {
    final Iterable<dynamic> entries;

    if (value is String) {
      entries = value.split(RegExp(r'\r?\n'));
    } else if (value is List) {
      entries = value;
    } else {
      return [];
    }

    final locations = <String>[];
    final seen = <String>{};

    for (final entry in entries) {
      if (entry is! String) continue;

      final location = entry.trim();

      if (location.isEmpty) continue;

      if (seen.add(location.toLowerCase())) {
        locations.add(location);
      }
    }

    return locations;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          enabled: enabled,
          minLines: 4,
          maxLines: 8,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            labelText: 'Suggested meeting locations',
            alignLabelWithHint: true,
            hintText: 'Coffee Lounge\n'
                'Main Lobby\n'
                'Networking Area\n'
                'Meeting Room 1',
            helperText: 'Enter one location per line. '
                'Users can also enter their own location.',
            helperMaxLines: 3,
            contentPadding: const EdgeInsets.all(16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(height: 10),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, child) {
            final count = readLocations(value.text).length;

            return Text(
              '$count meeting location${count == 1 ? '' : 's'} configured',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            );
          },
        ),
      ],
    );
  }
}