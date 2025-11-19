import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
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

  Future<User?> registerWithEmail(String email, String password) async {
    try {
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
      }
      
      return user;
    } on FirebaseAuthException catch (e) {
      print('Registration error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('Error: $e');
      return null;
    }
  }

  Future<User?> signInWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      print('Sign in error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('Error: $e');
      return null;
    }
  }

  Future<User?> signInWithGoogle() async {
    try {
      await _ensureGoogleSignInInitialized();
      
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final String? idToken = googleAuth.idToken;
      
      if (idToken == null) {
        print('Failed to get ID token');
        return null;
      }

      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: null,
      );

      UserCredential result = await _auth.signInWithCredential(credential);
      User? user = result.user;

      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'email': user.email,
          'displayName': user.displayName ?? googleUser.displayName,
          'photoURL': user.photoURL ?? googleUser.photoUrl,
          'lastSignIn': FieldValue.serverTimestamp(),
          'subjects': [],
        }, SetOptions(merge: true));
      }

      return user;
    } on GoogleSignInException catch (e) {
      print('Google Sign-In error: ${e.code} - ${e.description}');  // FIXED: .description
      return null;
    } on FirebaseAuthException catch (e) {
      print('Firebase auth error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('Unexpected error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<void> addSubject(String userId, String subject) async {
    await _firestore.collection('users').doc(userId).update({
      'subjects': FieldValue.arrayUnion([subject])
    });
  }

  Future<Map<String, dynamic>?> getUserData(String userId) async {
    DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
    if (doc.exists) {
      return doc.data() as Map<String, dynamic>?;
    }
    return null;
  }
}
