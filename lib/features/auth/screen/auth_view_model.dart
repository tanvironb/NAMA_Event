// lib/features/auth/screen/auth_view_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/features/auth/data/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AuthFormType { login, signup }

class AuthViewModel extends StateNotifier<AsyncValue<void>> {
  final AuthRepository _authRepository;

  AuthViewModel(this._authRepository) : super(const AsyncValue.data(null));

  Future<void> _markUserLoggedIn(User user) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'lastSeen': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
          'isOnline': true,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('AuthViewModel: failed to update login status: $e');
    }
  }

  Future<void> _markUserLoggedOut(User user) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'lastSeen': FieldValue.serverTimestamp(),
          'isOnline': false,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('AuthViewModel: failed to update logout status: $e');
    }
  }

  Future<void> signIn(String email, String password) async {
    if (!mounted) return;

    state = const AsyncValue.loading();

    try {
      await _authRepository.signInWithEmailAndPassword(
        email.trim(),
        password,
      );

      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        await _markUserLoggedIn(user);
      }

      if (mounted) {
        state = const AsyncValue.data(null);
      }
    } catch (e, stack) {
      if (mounted) {
        state = AsyncValue.error(e, stack);
      }
      rethrow;
    }
  }

  Future<void> signUp(
    String email,
    String password, {
    String? name,
  }) async {
    if (!mounted) return;

    state = const AsyncValue.loading();

    try {
      await _authRepository.createUserWithEmailAndPassword(
        email.trim(),
        password,
        name: name,
      );

      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        await _markUserLoggedIn(user);
      }

      if (mounted) {
        state = const AsyncValue.data(null);
      }
    } catch (e, stack) {
      if (mounted) {
        state = AsyncValue.error(e, stack);
      }
      rethrow;
    }
  }

  Future<void> deleteAccount({
    required String password,
  }) async {
    if (!mounted) return;

    state = const AsyncValue.loading();

    try {
      await _authRepository.deleteCurrentAccount(
        password: password,
      );

      if (mounted) {
        state = const AsyncValue.data(null);
      }
    } catch (e, stack) {
      if (mounted) {
        state = AsyncValue.error(e, stack);
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    if (!mounted) return;

    state = const AsyncValue.data(null);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        await _markUserLoggedOut(user);
      }

      await _authRepository.signOut();
    } on Exception catch (e) {
      debugPrint('AuthViewModel: signOut error: $e');
    } finally {
      if (mounted) {
        state = const AsyncValue.data(null);
      }
    }
  }

  void resetState() {
    if (!mounted) return;
    state = const AsyncValue.data(null);
  }
}

final authViewModelProvider =
    StateNotifierProvider<AuthViewModel, AsyncValue<void>>((ref) {
  return AuthViewModel(ref.watch(authRepositoryProvider));
});
