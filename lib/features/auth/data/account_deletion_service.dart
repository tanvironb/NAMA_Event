// lib/features/auth/data/account_deletion_service.dart

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AccountDeletionService {
  AccountDeletionService({
    FirebaseAuth? firebaseAuth,
    FirebaseFunctions? functions,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  final FirebaseAuth _firebaseAuth;
  final FirebaseFunctions _functions;

  Future<void> deleteCurrentAccount({
    required String password,
  }) async {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No signed-in account was found.',
      );
    }

    final email = user.email?.trim() ?? '';

    if (email.isEmpty) {
      throw FirebaseAuthException(
        code: 'email-not-found',
        message: 'This account does not have an email address.',
      );
    }

    final cleanPassword = password.trim();

    if (cleanPassword.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-password',
        message: 'Please enter your password.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: cleanPassword,
    );

    await user.reauthenticateWithCredential(credential);
    await user.getIdToken(true);

    final callable = _functions.httpsCallable(
      'deleteMyAccount',
      options: HttpsCallableOptions(
        timeout: const Duration(minutes: 5),
      ),
    );

    final result = await callable.call<Map<String, dynamic>>();

    if (result.data['success'] != true) {
      throw FirebaseException(
        plugin: 'cloud_functions',
        code: 'account-deletion-failed',
        message: (result.data['message'] ??
                'Account deletion failed.')
            .toString(),
      );
    }

    await _firebaseAuth.signOut();
  }
}
