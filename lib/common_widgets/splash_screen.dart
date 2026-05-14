import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:events_app_trueattempt/core/constants/app_constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _showLogo = false;
  String? _activeEventTitle;

  static const Color _primaryColor = Color(0xFF1B0F72);
  static const Color _goldColor = Color(0xFFF5B51B);

  @override
  void initState() {
    super.initState();

    _loadActiveEventTitle();

    // Logo appears after 1 second, then stays longer on screen.
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _showLogo = true);
    });
  }

  Future<void> _loadActiveEventTitle() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (!mounted) return;

      if (snapshot.docs.isEmpty) {
        setState(() => _activeEventTitle = null);
        return;
      }

      final data = snapshot.docs.first.data();
      final eventName = (data['name'] ?? '').toString().trim();

      setState(() {
        _activeEventTitle = eventName.isEmpty ? null : eventName;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _activeEventTitle = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedOpacity(
          opacity: _showLogo ? 1 : 0,
          duration: const Duration(milliseconds: 700),
          child: AnimatedScale(
            scale: _showLogo ? 1 : 0.85,
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutBack,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  AppConstants.logoCombinationPath,
                  width: 170,
                  fit: BoxFit.contain,
                ),

                if (_activeEventTitle != null) ...[
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _activeEventTitle!,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _primaryColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        height: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 4,
                    width: 38,
                    decoration: BoxDecoration(
                      color: _goldColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}