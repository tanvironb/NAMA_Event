import 'package:cloud_functions/cloud_functions.dart';

class AdminUserDeleteService {
  static Future<void> permanentlyDeleteUser({
    required String userId,
  }) async {
    if (userId.trim().isEmpty) {
      throw ArgumentError('A user ID is required.');
    }

    await FirebaseFunctions.instanceFor(
      region: 'asia-southeast1',
    )
        .httpsCallable(
          'adminDeleteUser',
          options: HttpsCallableOptions(
            timeout: const Duration(minutes: 9),
          ),
        )
        .call({
          'userId': userId.trim(),
        });
  }
}