import 'package:cloud_functions/cloud_functions.dart';

/// Quick tool to manually verify emails
/// Run this from your main.dart or create a test button in admin panel
Future<void> manuallyVerifyTestEmails() async {
  final functions = FirebaseFunctions.instanceFor(region: 'asia-southeast1');
  
  final emails = [
    'adminuser@gmail.com',
    'speaker1@gmail.com',
    // Add more emails here
  ];
  
  try {
    final result = await functions
        .httpsCallable('manuallyVerifyEmails')
        .call({'emails': emails});
    
    print('✅ Result: ${result.data}');
    print('Verified: ${result.data['verified']}');
    print('Failed: ${result.data['failed']}');
    
    for (var item in result.data['results']) {
      if (item['success']) {
        print('✓ ${item['email']} - ${item['error'] ?? 'Verified'}');
      } else {
        print('✗ ${item['email']} - ${item['error']}');
      }
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}
