import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get _currentUser => _auth.currentUser;

  String get _uid {
    final user = _currentUser;
    if (user == null) {
      throw Exception('Not authenticated');
    }
    return user.uid;
  }

  /// ---------- HELPERS ----------

  Future<Map<String, dynamic>?> _currentUserProfile() async {
    final doc = await _firestore.collection('users').doc(_uid).get();
    return doc.data();
  }

  /// ---------- SEARCH ----------

  /// Search users by username prefix (displayName, case-insensitive via lowercaseDisplayName)
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> searchUsersByUsername(
    String query,
  ) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final snap = await _firestore
        .collection('users')
        .where('lowercaseDisplayName', isGreaterThanOrEqualTo: q)
        .where('lowercaseDisplayName', isLessThanOrEqualTo: '$q\uf8ff')
        .limit(20)
        .get();

    return snap.docs;
  }

  /// ---------- FRIEND REQUESTS ----------

  Future<void> sendFriendRequest(String toUserId) async {
    final fromUserId = _uid;
    if (fromUserId == toUserId) {
      throw Exception("You can't add yourself");
    }

    // Load sender profile once to denormalize name + photo on the request
    final profile = await _currentUserProfile();
    final fromDisplayName = profile?['displayName'] as String? ?? '';
    final fromPhotoURL = profile?['photoURL'] as String?;
    await _firestore
        .collection('users')
        .doc(toUserId)
        .collection('friendRequests')
        .add({
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'fromDisplayName': fromDisplayName,
      'fromPhotoURL': fromPhotoURL,
    });
  }

  Future<void> acceptFriendRequest(String requestId, String fromUserId) async {
    final toUserId = _uid;
    final now = DateTime.now();

    final batch = _firestore.batch();

    final reqRef = _firestore
        .collection('users')
        .doc(toUserId)
        .collection('friendRequests')
        .doc(requestId);

    // Mark request as accepted
    batch.update(reqRef, {'status': 'accepted'});

    // Add both sides friendship
    final myFriendRef = _firestore
        .collection('users')
        .doc(toUserId)
        .collection('friends')
        .doc(fromUserId);

    final theirFriendRef = _firestore
        .collection('users')
        .doc(fromUserId)
        .collection('friends')
        .doc(toUserId);

    batch.set(myFriendRef, {
      'friendUserId': fromUserId,
      'createdAt': now,
    });

    batch.set(theirFriendRef, {
      'friendUserId': toUserId,
      'createdAt': now,
    });

    await batch.commit();
  }

  Future<void> rejectFriendRequest(String requestId) async {
    final toUserId = _uid;
    final reqRef = _firestore
        .collection('users')
        .doc(toUserId)
        .collection('friendRequests')
        .doc(requestId);
    await reqRef.update({'status': 'rejected'});
  }

  /// ---------- FRIENDSHIP STATE ----------

  Future<void> removeFriend(String friendUserId) async {
    final myId = _uid;

    final batch = _firestore.batch();

    final myFriendRef = _firestore
        .collection('users')
        .doc(myId)
        .collection('friends')
        .doc(friendUserId);
    final theirFriendRef = _firestore
        .collection('users')
        .doc(friendUserId)
        .collection('friends')
        .doc(myId);

    batch.delete(myFriendRef);
    batch.delete(theirFriendRef);

    await batch.commit();
  }

  Future<bool> isFriend(String otherUserId) async {
    final myId = _uid;
    final doc = await _firestore
        .collection('users')
        .doc(myId)
        .collection('friends')
        .doc(otherUserId)
        .get();
    return doc.exists;
  }

  Future<String?> existingRequestStatus(String otherUserId) async {
    final myId = _uid;
    final snap = await _firestore
        .collection('users')
        .doc(otherUserId)
        .collection('friendRequests')
        .where('fromUserId', isEqualTo: myId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return snap.docs.first.data()['status'] as String?;
  }

  /// ---------- STREAMS ----------

  Stream<QuerySnapshot<Map<String, dynamic>>> incomingRequestsStream() {
    final toUserId = _uid;
    return _firestore
        .collection('users')
        .doc(toUserId)
        .collection('friendRequests')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> friendsStream() {
    final myId = _uid;
    return _firestore
        .collection('users')
        .doc(myId)
        .collection('friends')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
