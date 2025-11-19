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

  User? getCurrentUser() {
    return _auth.currentUser;
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // REGISTER
  Future<User?> registerWithEmail(String email, String password) async {
    try {
      print('🔵 Registering user: $email');
      
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;
      
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'email': email,
          'displayName': email.split('@')[0],
          'createdAt': FieldValue.serverTimestamp(),
          'subjects': [],
        });
        
        final userBox = Hive.box('userBox');
        await userBox.put('userId', user.uid);
        await userBox.put('email', email);
        await userBox.put('displayName', email.split('@')[0]);
        
        print('✅ Registration successful');
      }
      
      return user;
    } on FirebaseAuthException catch (e) {
      print('🔴 Registration error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('🔴 Error: $e');
      return null;
    }
  }

  // SIGN IN
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      print('🔵 Signing in: $email');
      
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      User? user = result.user;
      
      if (user != null) {
        final userBox = Hive.box('userBox');
        await userBox.put('userId', user.uid);
        await userBox.put('email', user.email);
        await userBox.put('displayName', user.displayName ?? email.split('@')[0]);
        
        // Load subjects from Firebase
        await _subjectService.loadFromFirebase(user.uid);
        
        print('✅ Sign in successful');
      }
      
      return user;
    } on FirebaseAuthException catch (e) {
      print('🔴 Sign in error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('🔴 Error: $e');
      return null;
    }
  }

  // GOOGLE SIGN IN
  Future<User?> signInWithGoogle() async {
    try {
      print('🔵 Starting Google Sign-In');
      
      await _ensureGoogleSignInInitialized();
      
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final String? idToken = googleAuth.idToken;
      
      if (idToken == null) {
        print('🔴 Failed to get ID token');
        return null;
      }

      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: null,
      );

      UserCredential result = await _auth.signInWithCredential(credential);
      User? user = result.user;

      if (user != null) {
        // Check if user exists
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        
        if (!userDoc.exists) {
          // New user - create document
          await _firestore.collection('users').doc(user.uid).set({
            'email': user.email,
            'displayName': user.displayName ?? googleUser.displayName,
            'photoURL': user.photoURL ?? googleUser.photoUrl,
            'subjects': [],
          });
        } else {
          // Existing user - load subjects
          await _subjectService.loadFromFirebase(user.uid);
        }
        
        final userBox = Hive.box('userBox');
        await userBox.put('userId', user.uid);
        await userBox.put('email', user.email);
        await userBox.put('displayName', user.displayName ?? googleUser.displayName);
        await userBox.put('photoURL', user.photoURL ?? googleUser.photoUrl);
        
        print('✅ Google Sign-In successful: ${user.email}');
      }

      return user;
    } on GoogleSignInException catch (e) {
      print('🔴 Google Sign-In error: ${e.code} - ${e.description}');
      return null;
    } on FirebaseAuthException catch (e) {
      print('🔴 Firebase auth error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('🔴 Unexpected error: $e');
      return null;
    }
  }

  // SIGN OUT - Sync to Firebase then clear and navigate to splash
  Future<void> signOut(BuildContext context) async {
    try {
      final user = _auth.currentUser;
      
      if (user != null) {
        // Sync subjects to Firebase before signing out
        await _subjectService.syncToFirebase(user.uid);
      }
      
      await _googleSignIn.signOut();
      await _auth.signOut();
      
      // Clear all local data
      final userBox = Hive.box('userBox');
      await userBox.clear();
      await _subjectService.clearLocalData();
      
      print('✅ Signed out, synced to Firebase, and cleared cache');
      
      // Navigate to splash page and remove all previous routes
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const SplashPage()),
          (route) => false,
        );
      }
    } catch (e) {
      print('❌ Sign out error: $e');
      rethrow;
    }
  }
}
