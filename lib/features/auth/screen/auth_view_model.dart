import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:events_app_trueattempt/features/auth/data/auth_repository.dart';

// Enum to represent the current authentication form state
enum AuthFormType { login, signup }

// StateNotifier for AuthViewModel to manage authentication logic and state.
class AuthViewModel extends StateNotifier<AsyncValue<void>> {
  final AuthRepository _authRepository;

  AuthViewModel(this._authRepository) : super(const AsyncValue.data(null));

  // Handles user sign-in.
  Future<void> signIn(String email, String password) async {
    if (!mounted) return;
    
    state = const AsyncValue.loading();
    try {
      await _authRepository.signInWithEmailAndPassword(email, password);
      if (mounted) {
        state = const AsyncValue.data(null);
      }
    } on FirebaseAuthException catch (e, stack) {
      if (mounted) {
        // Pass full exception so we can check error code
        state = AsyncValue.error(e, stack);
      }
    }
  }

  // Handles user sign-up.
  Future<void> signUp(String email, String password, {String? name}) async {
    if (!mounted) return;
    
    state = const AsyncValue.loading();
    try {
      await _authRepository.createUserWithEmailAndPassword(email, password, name: name);
      // DON'T send verification email automatically - user will do it manually
      if (mounted) {
        state = const AsyncValue.data(null);
      }
    } on FirebaseAuthException catch (e, stack) {
      if (mounted) {
        state = AsyncValue.error(e.message ?? 'Registration failed.', stack);
      }
    }
  }

  // Handles user sign-out.
  Future<void> signOut() async {
    if (!mounted) return; // Check if still mounted before proceeding
    
    state = const AsyncValue.loading();
    try {
      await _authRepository.signOut();
      if (mounted) {
        state = const AsyncValue.data(null);
      }
    } on Exception catch (e, stack) {
      if (mounted) {
        state = AsyncValue.error(e.toString(), stack);
      }
    }
  }
}

// Riverpod provider for AuthViewModel
final authViewModelProvider = StateNotifierProvider<AuthViewModel, AsyncValue<void>>((ref) {
  return AuthViewModel(ref.watch(authRepositoryProvider));
});