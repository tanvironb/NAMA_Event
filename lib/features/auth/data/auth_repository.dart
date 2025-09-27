import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/services/firestore_service.dart';
import 'package:events_app_trueattempt/core/models/app_user.dart'; // Import the AppUser model
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:events_app_trueattempt/core/providers.dart';

class AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirestoreService _firestoreService;

  AuthRepository(this._firebaseAuth, this._firestoreService);

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// SECURITY: Sign-in only works for users who already have authorized profiles
  /// To add new users:
  /// 1. Admin creates Firebase Auth account (via console or admin API)
  /// 2. Admin creates corresponding Firestore user document with proper role
  /// 3. User can then sign in successfully
  /// This prevents unauthorized access to the application

  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    final userCredential = await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
    
    // SECURITY: Only allow sign-in if user already has a valid profile
    // This prevents unauthorized users from gaining access
    final userId = userCredential.user!.uid;
    final userDoc = await _firestoreService.getUserDocument(userId);
    
    if (!userDoc.exists) {
      // User exists in Firebase Auth but NOT authorized for this app
      // Sign them out immediately and throw error
      await _firebaseAuth.signOut();
      throw FirebaseAuthException(
        code: 'user-not-authorized',
        message: 'This account is not authorized to access this application. Please contact an administrator.',
      );
    }
    
    return userCredential;
  }

  Future<UserCredential> createUserWithEmailAndPassword(String email, String password) async {
    final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(email: email, password: password);
    
    // Create a new AppUser model with default values
    final newAppUser = AppUser(uid: userCredential.user!.uid, email: email);
    
    // Convert the AppUser model to a Firestore-compatible map and save
    await _firestoreService.createUserDocument(
      uid: userCredential.user!.uid, 
      userData: newAppUser.toFirestore(),
    );
    return userCredential;
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }
}

// Riverpod provider for AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreServiceProvider),
  );
});