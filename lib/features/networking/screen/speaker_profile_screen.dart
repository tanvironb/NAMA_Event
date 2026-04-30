import 'package:flutter/material.dart';

class SpeakerProfileScreen extends StatelessWidget {
  final String name;
  final String role;
  final String company;
  final String imageUrl;
  final String bio;
  final String email;

  const SpeakerProfileScreen({
    super.key,
    required this.name,
    required this.role,
    required this.company,
    required this.imageUrl,
    required this.bio,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 25),
          child: Column(
            children: [

              // 🔹 TOP BAR
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
                        icon: const Icon(Icons.arrow_back, size: 18),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                  const Text(
                    'Profile',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF24158A),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 25),

              // 🔹 IMAGE
              CircleAvatar(
                radius: 45,
                backgroundColor: const Color(0xFFEFEFEF),
                backgroundImage:
                    imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                child: imageUrl.isEmpty
                    ? const Icon(Icons.person, size: 40)
                    : null,
              ),

              const SizedBox(height: 16),

              // 🔹 NAME
              Text(
                name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 8),

              // 🔹 TAGS
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _tag(role.isEmpty ? 'Speaker' : role),
                  const SizedBox(width: 8),
                  if (company.isNotEmpty) _tag(company),
                ],
              ),

              const SizedBox(height: 18),

              // 🔹 BUTTONS (SMALLER)
              _button('Say Hi', const Color(0xFF24158A), Colors.white),
              const SizedBox(height: 8),

              _buttonOutline('Request Meeting'),
              const SizedBox(height: 8),

              _button('Book 3 Sessions', const Color(0xFFE2B23C), Colors.white),

              const SizedBox(height: 20),

              // 🔹 ABOUT
              _card(
                title: 'About',
                child: Text(
                  bio.isEmpty ? 'No information available.' : bio,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
              ),

              const SizedBox(height: 16),

              // 🔹 CONTACT
              _card(
                title: 'Contact',
                child: Row(
                  children: [
                    const Icon(Icons.email, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        email.isEmpty ? '-' : email,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEDECF7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _button(String text, Color bg, Color textColor) {
    return SizedBox(
      width: 240,
      height: 40,
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          elevation: 2,
          backgroundColor: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buttonOutline(String text) {
    return SizedBox(
      width: 240,
      height: 40,
      child: OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF24158A)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Request Meeting',
          style: TextStyle(
            color: Color(0xFF24158A),
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}