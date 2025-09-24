import 'package:flutter/material.dart';

// A simple reusable loading indicator widget.
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        color: Theme.of(context).colorScheme.secondary, // Use accent color for loading
      ),
    );
  }
}