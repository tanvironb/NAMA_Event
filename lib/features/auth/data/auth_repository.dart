import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:events_app_trueattempt/core/services/firestore_service.dart';
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
    // First try to sign in - this validates BOTH email AND password
    final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email, 
      password: password
    );
    
    final user = userCredential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No user found.',
      );
    }
    
    // Check if email is verified
    if (!user.emailVerified) {
      // Keep user signed in for verification dialog flow
      throw FirebaseAuthException(
        code: 'email-not-verified',
        message: 'Your email is pending verification.',
      );
    }
    
    // Check if user document exists in Firestore
    final userDoc = await _firestoreService.getUserDocument(user.uid);
    
    if (!userDoc.exists) {
      await _firebaseAuth.signOut();
      throw FirebaseAuthException(
        code: 'user-not-authorized',
        message: 'Account not found. Please register.',
      );
    }
    
    return userCredential;
  }

  Future<UserCredential> createUserWithEmailAndPassword(String email, String password, {String? name}) async {
    try {
      // Try to create the user
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(email: email, password: password);
      
      // Create Firestore profile
      final userData = {
        'email': email,
        'name': name ?? email.split('@')[0],
        'role': 'attendee',
        'status': 'approved',
        'qrCodePayload': '',
        'profileImageUrl': '',
        'title': '',
        'company': '',
        'bio': '',
        'phone': '',
        'linkedin': '',
        'twitter': '',
        'website': '',
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      await _firestoreService.createUserDocument(
        uid: userCredential.user!.uid, 
        userData: userData,
      );
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw FirebaseAuthException(
          code: 'email-already-in-use',
          message: 'This email is already registered. Please sign in or use password reset if you forgot your password.',
        );
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  Future<void> sendEmailVerification() async {
    final user = _firebaseAuth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  User? get currentUser => _firebaseAuth.currentUser;
}

// Riverpod provider for AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreServiceProvider),
  );
});