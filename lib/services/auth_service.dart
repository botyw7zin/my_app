import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:my_app/services/subject_service.dart';
import 'package:my_app/screens/Splash.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SubjectService _subjectService = SubjectService();

  bool _isGoogleSignInInitialized = false;

  Future<void> _ensureGoogleSignInInitialized() async {
    if (!_isGoogleSignInInitialized) {
      await _googleSignIn.initialize();
      _isGoogleSignInInitialized = true;
    }
  }

  User? getCurrentUser() => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Initialize services after successful authentication
  Future<void> _initializePostAuthServices(String userId) async {
    print('🔵 [_initializePostAuthServices] Initializing for user: $userId');

    // Load user's subjects from Firebase
    await _subjectService.loadFromFirebase(userId);

    // Start connectivity listener for foreground sync
    _subjectService.listenForConnectivityChanges();

    print('✅ [_initializePostAuthServices] Services initialized');
  }

  Future<User?> registerWithEmail(
    String email,
    String password,
    String username,
  ) async {
    try {
      print('🔵 [registerWithEmail] Registering user: $email');
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      if (user != null) {
        final String defaultPhotoUrl = 'assets/data:image/jpeg;base64,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';

        // Create user document in Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'email': email,
          'displayName': username,
          'lowercaseDisplayName': username.toLowerCase(), // for search
          'photoURL': defaultPhotoUrl,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Save to local Hive storage
        final userBox = Hive.box('userBox');
        await userBox.put('userId', user.uid);
        await userBox.put('email', email);
        await userBox.put('displayName', username);
        await userBox.put('photoURL', defaultPhotoUrl);

        print('✅ [registerWithEmail] Registration successful for ${user.uid}');

        // Initialize post-auth services
        await _initializePostAuthServices(user.uid);
      }
      return user;
    } on FirebaseAuthException catch (e) {
      print('🔴 [registerWithEmail] Registration error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('🔴 [registerWithEmail] Error: $e');
      return null;
    }
  }

  Future<User?> signInWithEmail(String email, String password) async {
    try {
      print('🔵 [signInWithEmail] Signing in: $email');
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      if (user != null) {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        final data = userDoc.data();
        final userBox = Hive.box('userBox');

        // Ensure user document has required fields
        if (!userDoc.exists || data == null || !data.containsKey('photoURL')) {
          final displayName = user.displayName ?? 'User';
          await _firestore.collection('users').doc(user.uid).set({
            'email': user.email,
            'displayName': displayName,
            'lowercaseDisplayName': displayName.toLowerCase(),
            'photoURL': 'assets/data:image/jpeg;base64,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',
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          await userBox.put('photoURL', 'assets/data:image/jpeg;base64,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');
        } else if (!data.containsKey('lowercaseDisplayName')) {
          // Backfill lowercaseDisplayName for old accounts
          final displayName =
              (data['displayName'] ?? user.displayName ?? 'User') as String;
          await _firestore.collection('users').doc(user.uid).set({
            'lowercaseDisplayName': displayName.toLowerCase(),
          }, SetOptions(merge: true));
        }

        final effectiveDisplayName =
            data?['displayName'] ?? user.displayName ?? '';

        // Save to local Hive storage
        await userBox.put('userId', user.uid);
        await userBox.put('email', user.email);
        await userBox.put('displayName', effectiveDisplayName);
        await userBox.put(
          'photoURL',
          data?['photoURL'] ?? 'assets/data:image/jpeg;base64,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',
        );

        print('✅ [signInWithEmail] Signed in user: ${user.uid}');
        print(
            '>>> [signInWithEmail] current auth uid for friends: ${FirebaseAuth.instance.currentUser?.uid}');

        // Initialize post-auth services (includes loadFromFirebase)
        await _initializePostAuthServices(user.uid);
      }
      return user;
    } on FirebaseAuthException catch (e) {
      print('🔴 [signInWithEmail] Sign in error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('🔴 [signInWithEmail] Error: $e');
      return null;
    }
  }

  Future<User?> signInWithGoogle() async {
    try {
      print('🔵 [signInWithGoogle] Starting Google Sign-In');
      await _ensureGoogleSignInInitialized();

      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        print('🔴 [signInWithGoogle] Failed to get ID token');
        return null;
      }

      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: null,
      );

      UserCredential result =
          await _auth.signInWithCredential(credential);
      User? user = result.user;

      if (user != null) {
        final String displayName =
            user.displayName ?? googleUser.displayName ?? 'Google User';
        final String googlePhotoUrl =
            user.photoURL ?? googleUser.photoUrl ?? 'assets/data:image/jpeg;base64,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';

        // Save/update user document in Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'email': user.email,
          'displayName': displayName,
          'lowercaseDisplayName': displayName.toLowerCase(),
          'photoURL': googlePhotoUrl,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Save to local Hive storage
        final userBox = Hive.box('userBox');
        await userBox.put('userId', user.uid);
        await userBox.put('email', user.email);
        await userBox.put('displayName', displayName);
        await userBox.put('photoURL', googlePhotoUrl);

        print('✅ [signInWithGoogle] Signed in user: ${user.uid}');
        print(
            '>>> [signInWithGoogle] current auth uid for friends: ${FirebaseAuth.instance.currentUser?.uid}');

        // Initialize post-auth services (includes loadFromFirebase)
        await _initializePostAuthServices(user.uid);
      }

      return user;
    } on GoogleSignInException catch (e) {
      print(
          '🔴 [signInWithGoogle] Google Sign-In error: ${e.code} - ${e.description}');
      return null;
    } on FirebaseAuthException catch (e) {
      print(
          '🔴 [signInWithGoogle] Firebase auth error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('🔴 [signInWithGoogle] Unexpected error: $e');
      return null;
    }
  }

  Future<void> signOut(BuildContext context) async {
    try {
      print('🔵 [signOut] Starting sign out process');

      // Cancel all background sync tasks
      await _subjectService.cancelBackgroundSync();
      print('✅ [signOut] Background sync tasks cancelled');

      // Sign out from Google and Firebase
      await _googleSignIn.signOut();
      await _auth.signOut();

      // Clear local storage
      final userBox = Hive.box('userBox');
      await userBox.clear();
      await _subjectService.clearLocalData();

      print('✅ [signOut] Signed out, cache cleared.');

      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const SplashPage()),
          (route) => false,
        );
      }
    } catch (e) {
      print('❌ [signOut] Sign out error: $e');
      rethrow;
    }
  }

  /// Send password reset email to user
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      print('🔵 [sendPasswordResetEmail] Sending reset email to: $email');
      await _auth.sendPasswordResetEmail(email: email);
      print('✅ [sendPasswordResetEmail] Password reset email sent');
    } on FirebaseAuthException catch (e) {
      print(
          '🔴 [sendPasswordResetEmail] Error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('🔴 [sendPasswordResetEmail] Unexpected error: $e');
      rethrow;
    }
  }

  /// Change password for currently authenticated user
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      print('🔵 [changePassword] Attempting to change password');
      final user = _auth.currentUser;

      if (user == null) {
        print('🔴 [changePassword] No user logged in');
        throw FirebaseAuthException(
          code: 'no-user',
          message: 'No user is currently logged in',
        );
      }

      // Re-authenticate user with current password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);
      print('✅ [changePassword] User re-authenticated successfully');

      // Update password
      await user.updatePassword(newPassword);
      print('✅ [changePassword] Password changed successfully');
    } on FirebaseAuthException catch (e) {
      print(
          '🔴 [changePassword] Auth error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('🔴 [changePassword] Unexpected error: $e');
      rethrow;
    }
  }
}
