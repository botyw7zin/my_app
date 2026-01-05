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
    

    // Perform a full two-way sync: pull remote -> local and push local -> remote
    await _subjectService.syncBothWays();

    // Start connectivity listener for future changes (will trigger two-way sync when back online)
    _subjectService.listenForConnectivityChanges();

    
  }


  Future<User?> registerWithEmail(
    String email,
    String password,
    String username,
  ) async {
    try {
      
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;


      if (user != null) {
        final String defaultPhotoUrl = 'assets/images/cat.png';


        await _firestore.collection('users').doc(user.uid).set({
          'email': email,
          'displayName': username,
          'lowercaseDisplayName': username.toLowerCase(),
          'photoURL': defaultPhotoUrl,
          'createdAt': FieldValue.serverTimestamp(),
        });


        // Save to local Hive storage
        final userBox = Hive.box('userBox');
        await userBox.put('userId', user.uid);
        await userBox.put('email', email);
        await userBox.put('displayName', username);
        await userBox.put('photoURL', defaultPhotoUrl);


        


        // Initialize post-auth services
        await _initializePostAuthServices(user.uid);
      }
      return user;
    } on FirebaseAuthException catch (e) {
      
      rethrow;
    } catch (e) {
      
      return null;
    }
  }


  Future<User?> signInWithEmail(String email, String password) async {
    try {
      
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


        // Save to local Hive storage
        await userBox.put('userId', user.uid);
        await userBox.put('email', user.email);
        await userBox.put('displayName', effectiveDisplayName);
        await userBox.put(
          'photoURL',
          data?['photoURL'] ?? 'assets/images/cat.png',
        );


        


        // Initialize post-auth services (includes loadFromFirebase)
        await _initializePostAuthServices(user.uid);
      }
      return user;
    } on FirebaseAuthException catch (e) {
      
      rethrow;
    } catch (e) {
      
      return null;
    }
  }


  Future<User?> signInWithGoogle() async {
    try {
      
      await _ensureGoogleSignInInitialized();


      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;


      if (idToken == null) {
        
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
            user.photoURL ?? googleUser.photoUrl ?? 'assets/images/cat.png';


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


        


        // Initialize post-auth services (includes loadFromFirebase)
        await _initializePostAuthServices(user.uid);
      }


      return user;
    } on GoogleSignInException catch (e) {
      
      return null;
    } on FirebaseAuthException catch (e) {
      
      rethrow;
    } catch (e) {
      
      return null;
    }
  }


  Future<void> signOut(BuildContext context) async {
    try {
      


      // Cancel all background sync tasks
      await _subjectService.cancelBackgroundSync();
      


      // Sign out from Google and Firebase
      await _googleSignIn.signOut();
      await _auth.signOut();


      // Clear local storage
      final userBox = Hive.box('userBox');
      await userBox.clear();
      await _subjectService.clearLocalData();


      


      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const SplashPage()),
          (route) => false,
        );
      }
    } catch (e) {
      
      rethrow;
    }
  }



  Future<void> sendPasswordResetEmail(String email) async {
    try {
      
      await _auth.sendPasswordResetEmail(email: email);
      
    } on FirebaseAuthException catch (e) {
      
      rethrow;
    } catch (e) {
      
      rethrow;
    }
  }


  /// Change password for currently authenticated user
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      
      final user = _auth.currentUser;


      if (user == null) {
        
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
      


      // Update password
      await user.updatePassword(newPassword);
      
    } on FirebaseAuthException catch (e) {
      
      rethrow;
    } catch (e) {
      
      rethrow;
    }
  }

  /// Change email for the currently authenticated user
  Future<void> changeEmail(String newEmail) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw FirebaseAuthException(code: 'no-user', message: 'No user logged in');

      // Attempt to update email; this may throw requires-recent-login
      // Cast to dynamic to avoid analyzer/platform SDK mismatches
      await (user as dynamic).updateEmail(newEmail);

      // Update Firestore user doc and local Hive cache
      await _firestore.collection('users').doc(user.uid).update({'email': newEmail});
      final box = Hive.box('userBox');
      await box.put('email', newEmail);
    } on FirebaseAuthException catch (e) {
      
      rethrow;
    } catch (e) {
      
      rethrow;
    }
  }
}
