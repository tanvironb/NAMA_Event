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

  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    return await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
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