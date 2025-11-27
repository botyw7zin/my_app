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

    // 1) Sync local changes to Firestore FIRST (preserves hoursCompleted)
    await _subjectService.syncToFirebase();
    print('✅ [_initializePostAuthServices] Local changes synced to Firestore');

    // 2) Load ONLY missing subjects from Firestore (never overwrite existing)
    await _subjectService.loadFromFirebase(userId);
    print('✅ [_initializePostAuthServices] Missing subjects loaded');

    // 3) Start connectivity listener for future changes
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
        const String defaultPhotoUrl = 'assets/images/cat.png';

        await _firestore.collection('users').doc(user.uid).set({
          'email': email,
          'displayName': username,
          'lowercaseDisplayName': username.toLowerCase(),
          'photoURL': defaultPhotoUrl,
          'createdAt': FieldValue.serverTimestamp(),
        });

        final userBox = Hive.box('userBox');
        await userBox.put('userId', user.uid);
        await userBox.put('email', email);
        await userBox.put('displayName', username);
        await userBox.put('photoURL', defaultPhotoUrl);

        print('✅ [registerWithEmail] Registration successful for ${user.uid}');
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

        if (!userDoc.exists || data == null || !data.containsKey('photoURL')) {
          final displayName = user.displayName ?? 'User';
          await _firestore.collection('users').doc(user.uid).set({
            'email': user.email,
            'displayName': displayName,
            'lowercaseDisplayName': displayName.toLowerCase(),
            'photoURL': 'assets/images/cat.png',
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          await userBox.put('photoURL', 'assets/images/cat.png');
        } else if (!data.containsKey('lowercaseDisplayName')) {
          final displayName =
              (data['displayName'] ?? user.displayName ?? 'User') as String;
          await _firestore.collection('users').doc(user.uid).set({
            'lowercaseDisplayName': displayName.toLowerCase(),
          }, SetOptions(merge: true));
        }

        final effectiveDisplayName =
            data?['displayName'] ?? user.displayName ?? '';

        await userBox.put('userId', user.uid);
        await userBox.put('email', user.email);
        await userBox.put('displayName', effectiveDisplayName);
        await userBox.put(
          'photoURL',
          data?['photoURL'] ?? 'assets/images/cat.png',
        );

        print('✅ [signInWithEmail] Signed in user: ${user.uid}');
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

      UserCredential result = await _auth.signInWithCredential(credential);
      User? user = result.user;

      if (user != null) {
        final String displayName =
            user.displayName ?? googleUser.displayName ?? 'Google User';
        final String googlePhotoUrl =
            user.photoURL ?? googleUser.photoUrl ?? 'assets/images/cat.png';

        await _firestore.collection('users').doc(user.uid).set({
          'email': user.email,
          'displayName': displayName,
          'lowercaseDisplayName': displayName.toLowerCase(),
          'photoURL': googlePhotoUrl,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        final userBox = Hive.box('userBox');
        await userBox.put('userId', user.uid);
        await userBox.put('email', user.email);
        await userBox.put('displayName', displayName);
        await userBox.put('photoURL', googlePhotoUrl);

        print('✅ [signInWithGoogle] Signed in user: ${user.uid}');
        await _initializePostAuthServices(user.uid);
      }

      return user;
    } on GoogleSignInException catch (e) {
      print('🔴 [signInWithGoogle] Google Sign-In error: ${e.code} - ${e.description}');
      return null;
    } on FirebaseAuthException catch (e) {
      print('🔴 [signInWithGoogle] Firebase auth error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('🔴 [signInWithGoogle] Unexpected error: $e');
      return null;
    }
  }

  // Only change needed in signOut():
Future<void> signOut(BuildContext context) async {
  try {
    print('🔵 [signOut] Starting sign out process');

    await _subjectService.cancelBackgroundSync();
    _subjectService.stopListeningForConnectivityChanges();  // ✅ Removed await
    print('✅ [signOut] Background tasks cancelled');

    await _googleSignIn.signOut();
    await _auth.signOut();

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


  Future<void> sendPasswordResetEmail(String email) async {
    try {
      print('🔵 [sendPasswordResetEmail] Sending reset email to: $email');
      await _auth.sendPasswordResetEmail(email: email);
      print('✅ [sendPasswordResetEmail] Password reset email sent');
    } on FirebaseAuthException catch (e) {
      print('🔴 [sendPasswordResetEmail] Error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('🔴 [sendPasswordResetEmail] Unexpected error: $e');
      rethrow;
    }
  }

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

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);
      print('✅ [changePassword] User re-authenticated successfully');

      await user.updatePassword(newPassword);
      print('✅ [changePassword] Password changed successfully');
    } on FirebaseAuthException catch (e) {
      print('🔴 [changePassword] Auth error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('🔴 [changePassword] Unexpected error: $e');
      rethrow;
    }
  }
}
