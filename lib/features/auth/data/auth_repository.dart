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
    
    // Update lastSeen timestamp and set user online
    try {
      await _firestoreService.updateUserDocument(
        user.uid,
        {
          'lastSeen': FieldValue.serverTimestamp(),
          'isOnline': true,
        },
      );
    } catch (e) {
      // Don't fail login if timestamp update fails
      print('Warning: Failed to update lastSeen on login: $e');
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
        'profileVisibility': 'minimal', // Default privacy level (user will be forced to confirm/change on first login)
        // privacySelectedAt is intentionally null - user must make explicit choice on first login
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
    final user = _firebaseAuth.currentUser;
    
    if (user != null) {
      try {
        // Clean up user session data before signing out
        // Use timeout to prevent hanging on poor network
        await _firestoreService.updateUserDocument(
          user.uid,
          {
            'fcmToken': FieldValue.delete(), // Remove FCM token to stop notifications
            'isOnline': false, // Set user offline
            'lastSeen': FieldValue.serverTimestamp(), // Record sign-out time
          },
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            print('Warning: Firestore update timed out during sign-out');
          },
        );
      } catch (e) {
        // If Firestore update fails (e.g., no network), continue with sign-out
        // This ensures user can still sign out locally
        print('Warning: Failed to update user session data on sign-out: $e');
      }
    }
    
    // Always sign out from Firebase Auth, even if Firestore update failed
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