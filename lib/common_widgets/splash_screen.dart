import 'package:flutter/material.dart';
import 'package:events_app_trueattempt/core/constants/app_constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _showLogo = false;

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _showLogo = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedOpacity(
          opacity: _showLogo ? 1 : 0,
          duration: const Duration(milliseconds: 500),
          child: AnimatedScale(
            scale: _showLogo ? 1 : 0.85,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutBack,
            child: Image.asset(
              AppConstants.logoCombinationPath,
              width: 170,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}