import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:events_app_trueattempt/core/models/session_model.dart';
import 'package:events_app_trueattempt/features/agenda/screen/widgets/session_bookmark_button.dart';
import 'package:events_app_trueattempt/features/networking/screen/speaker_profile_screen.dart';

class SessionDetailScreen extends StatelessWidget {
  final Session session;

  const SessionDetailScreen({super.key, required this.session});

  Future<List<Map<String, dynamic>>> _loadSpeakers() async {
    if (session.speakerIds.isEmpty) return [];

    final firestore = FirebaseFirestore.instance;
    final speakers = <Map<String, dynamic>>[];

    for (final speakerId in session.speakerIds) {
      DocumentSnapshot<Map<String, dynamic>> doc =
          await firestore.collection('speakers').doc(speakerId).get();

      if (!doc.exists) {
        doc = await firestore.collection('users').doc(speakerId).get();
      }

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        data['id'] = doc.id;
        speakers.add(data);
      }
    }

    return speakers;
  }

  @override
  Widget build(BuildContext context) {
    final time =
        '${DateFormat('h:mm a').format(session.startTime)} - ${DateFormat('h:mm a').format(session.endTime)}';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // 🔹 TOP BAR (CENTER TITLE)
              Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.grey.shade300,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.arrow_back, color: Colors.black),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                  const Text(
                    'Event Details',
                    style: TextStyle(
                      color: Color(0xFF24158A),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              Center(
                child: Text(
                  session.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const SizedBox(height: 25),

              // 🔹 IMAGE + BOOKMARK
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 130,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFEFEF),
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  Positioned(
                    right: 14,
                    bottom: -22,
                    child: Container(
                      height: 55,
                      width: 55,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3D3D9E),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: SessionBookmarkButton(
                        sessionId: session.id,
                        iconSize: 30,
                        bookmarkedColor: Colors.white,
                        unbookmarkedColor: Colors.white,
                        padding: EdgeInsets.zero,
                        alignment: Alignment.center,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 🔹 TIME
              Row(
                children: [
                  const Icon(Icons.access_time,
                      color: Color(0xFFE2BF3C), size: 18),
                  const SizedBox(width: 12),
                  Text(time),
                ],
              ),

              const SizedBox(height: 12),

              // 🔹 LOCATION
              Row(
                children: [
                  const Icon(Icons.location_on,
                      color: Color(0xFFE2BF3C), size: 18),
                  const SizedBox(width: 12),
                  Expanded(child: Text(session.location)),
                ],
              ),

              const SizedBox(height: 22),

              // 🔹 ABOUT
              const Text(
                'About',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),

              const SizedBox(height: 10),

              Text(session.description),

              const SizedBox(height: 22),

              // 🔹 SPEAKERS TITLE
              const Text(
                'Speakers',
                style: TextStyle(
                  fontSize: 20,
                  color: Color(0xFF3D3D9E),
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 14),

              // 🔹 SPEAKERS LIST
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _loadSpeakers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final speakers = snapshot.data ?? [];

                  if (speakers.isEmpty) {
                    return _speakerCard(context: context, speaker: {});
                  }

                  return Column(
                    children: speakers.map((speaker) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _speakerCard(
                          context: context,
                          speaker: speaker,
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

              const SizedBox(height: 65),

              // 🔹 JOIN BUTTON
              Center(
                child: SizedBox(
                  width: 170,
                  height: 36,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3D3D9E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    child: const Text(
                      'JOIN EVENT',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🔹 SPEAKER CARD WITH ROUTING
  Widget _speakerCard({
  required BuildContext context,
  required Map<String, dynamic> speaker,
}) {
  final name = speaker['name'] ??
      speaker['fullName'] ??
      speaker['displayName'] ??
      'Speaker';

  final role = speaker['role'] ?? speaker['title'] ?? 'Speaker';

  final company = speaker['company'] ?? '';

  final imageUrl = speaker['profileImageUrl'] ?? '';

  final bio = speaker['bio'] ?? '';
  final email = speaker['email'] ?? '';

  return InkWell(
    borderRadius: BorderRadius.circular(18),
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SpeakerProfileScreen(
            name: name,
            role: role,
            company: company,
            imageUrl: imageUrl,
            bio: bio,
            email: email,
          ),
        ),
      );
    },
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundImage:
                imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
            child: imageUrl.isEmpty ? const Icon(Icons.person) : null,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(name)),
          const Icon(Icons.chevron_right),
        ],
      ),
    ),
  );
}
}