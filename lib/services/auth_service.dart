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

  Future<User?> registerWithEmail(String email, String password, String username) async {
    try {
      print('🔵 [registerWithEmail] Registering user: $email');
      UserCredential result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      User? user = result.user;

      if (user != null) {
        final String defaultPhotoUrl = 'assets/cat.png';
        await _firestore.collection('users').doc(user.uid).set({
          'email': email,
          'displayName': username,
          'photoURL': defaultPhotoUrl,
          'createdAt': FieldValue.serverTimestamp(),
        });
        final userBox = Hive.box('userBox');
        await userBox.put('userId', user.uid);
        await userBox.put('email', email);
        await userBox.put('displayName', username);
        await userBox.put('photoURL', defaultPhotoUrl);

        print('✅ [registerWithEmail] Registration successful for ${user.uid}');
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
      UserCredential result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      User? user = result.user;

      if (user != null) {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        final data = userDoc.data();
        final userBox = Hive.box('userBox');

        if (!userDoc.exists || data == null || !data.containsKey('photoURL')) {
          await _firestore.collection('users').doc(user.uid).set({
            'email': user.email,
            'displayName': user.displayName ?? 'User',
            'photoURL': 'assets/cat.png',
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          await userBox.put('photoURL', 'assets/cat.png');
        }

        await userBox.put('userId', user.uid);
        await userBox.put('email', user.email);
        await userBox.put('displayName', data?['displayName'] ?? user.displayName ?? '');
        await userBox.put('photoURL', data?['photoURL'] ?? 'assets/cat.png');

        print('✅ [signInWithEmail] Signed in user: ${user.uid}');
        await _subjectService.loadFromFirebase(user.uid);
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
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
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
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        final String displayName = user.displayName ?? googleUser.displayName ?? 'Google User';
        final String googlePhotoUrl = user.photoURL ?? googleUser.photoUrl ?? 'assets/cat.png';

        await _firestore.collection('users').doc(user.uid).set({
          'email': user.email,
          'displayName': displayName,
          'photoURL': googlePhotoUrl,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        final userBox = Hive.box('userBox');
        await userBox.put('userId', user.uid);
        await userBox.put('email', user.email);
        await userBox.put('displayName', displayName);
        await userBox.put('photoURL', googlePhotoUrl);

        print('✅ [signInWithGoogle] Signed in user: ${user.uid}');
        await _subjectService.loadFromFirebase(user.uid);
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

  Future<void> signOut(BuildContext context) async {
    try {
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
}
