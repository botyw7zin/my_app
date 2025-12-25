import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/study_session_model.dart';

class SessionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get _currentUser => _auth.currentUser;

  String get _uid {
    final u = _currentUser;
    if (u == null) throw Exception('Not authenticated');
    return u.uid;
  }

  /// Create a new session with the owner as joined participant
  Future<String> createSession(String ownerSubjectId) async {
    final ownerId = _uid;
    String displayName = '';
    String? photoURL;
    try {
      final profileSnap = await _firestore.collection('users').doc(ownerId).get();
      final profile = profileSnap.data() ?? {};
      displayName = (profile['displayName'] ?? '') as String;
      photoURL = profile['photoURL'] as String?;
    } catch (e) {
      try {
        final userBox = Hive.box('userBox');
        displayName = (userBox.get('displayName') ?? '') as String;
        photoURL = (userBox.get('photoURL') ?? null) as String?;
      } catch (_) {
        // ignore
      }
    }

    final docRef = await _firestore.collection('studySessions').add({
      'ownerId': ownerId,
      'ownerSubjectId': ownerSubjectId,
      'participants': {
        ownerId: {
          'status': 'joined',
          'selectedSubjectId': ownerSubjectId,
          'displayName': displayName,
          'photoURL': photoURL,
          'joinedAt': FieldValue.serverTimestamp(),
        }
      },
      'participantIds': [ownerId],
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<void> inviteParticipants(String sessionId, List<String> userIds, {String? suggestedSubjectId, String? suggestedSubjectName}) async {
    final docRef = _firestore.collection('studySessions').doc(sessionId);
    final snap = await docRef.get();
    if (!snap.exists) throw Exception('Session not found');

    final data = snap.data() ?? {};
    final participants = Map<String, dynamic>.from(data['participants'] ?? {});
    final participantIds = List<String>.from(data['participantIds'] ?? []);

    for (final uid in userIds) {
      if (!participants.containsKey(uid)) {
        // Try to denormalize invitee's name/photo so owner sees them immediately
        String displayName = '';
        String? photoURL;
        try {
          final profileSnap = await _firestore.collection('users').doc(uid).get();
          final profile = profileSnap.data() ?? {};
          displayName = (profile['displayName'] ?? '') as String;
          photoURL = profile['photoURL'] as String?;
        } catch (e) {
          // Best-effort: leave blank if cannot fetch
        }

        final entry = {
          'status': 'invited',
          'selectedSubjectId': null,
          'displayName': displayName,
          'photoURL': photoURL,
        };

        if (suggestedSubjectId != null) {
          entry['suggestedSubjectId'] = suggestedSubjectId;
          entry['suggestedSubjectName'] = suggestedSubjectName;
        }

        participants[uid] = entry;
        participantIds.add(uid);
      }
    }

    await docRef.update({'participants': participants, 'participantIds': participantIds});
  }

  Future<void> joinSession(String sessionId, String selectedSubjectId) async {
    final uid = _uid;
    String displayName = '';
    String? photoURL;

    // Try to read profile from Firestore; on failure, fall back to Hive local cache
    try {
      final profileSnap = await _firestore.collection('users').doc(uid).get();
      final profile = profileSnap.data() ?? {};
      displayName = (profile['displayName'] ?? '') as String;
      photoURL = profile['photoURL'] as String?;
    } catch (e) {
      try {
        final userBox = Hive.box('userBox');
        displayName = (userBox.get('displayName') ?? '') as String;
        photoURL = (userBox.get('photoURL') ?? null) as String?;
      } catch (e2) {
        // swallow and continue with empty/defaults
        displayName = '';
        photoURL = null;
      }
    }

    final docRef = _firestore.collection('studySessions').doc(sessionId);
    final snap = await docRef.get();
    if (!snap.exists) throw Exception('Session not found');

    final data = snap.data() ?? {};
    // Prevent joining if owner has left or session is no longer active
    final ownerLeft = data['ownerLeft'] as bool? ?? false;
    final status = (data['status'] ?? 'active') as String;
    if (ownerLeft) throw Exception('The session owner has left. This session is closed.');
    if (status != 'active') throw Exception('This session is no longer active.');

    final participants = Map<String, dynamic>.from(data['participants'] ?? {});
    participants[uid] = {
      'status': 'joined',
      'selectedSubjectId': selectedSubjectId,
      'displayName': displayName,
      'photoURL': photoURL,
      'joinedAt': FieldValue.serverTimestamp(),
    };

    final participantIds = List<String>.from(data['participantIds'] ?? []);
    if (!participantIds.contains(uid)) participantIds.add(uid);

    await docRef.update({'participants': participants, 'participantIds': participantIds});
  }

  Future<void> leaveSession(String sessionId) async {
    final uid = _uid;
    final docRef = _firestore.collection('studySessions').doc(sessionId);
    final snap = await docRef.get();
    if (!snap.exists) return;

    final data = snap.data() ?? {};
    final participants = Map<String, dynamic>.from(data['participants'] ?? {});
    final participantIds = List<String>.from(data['participantIds'] ?? []);

    // If the owner is leaving, mark the session as closed so others cannot join
    final ownerId = data['ownerId'] as String?;
    if (ownerId != null && ownerId == uid) {
      participants.remove(uid);
      participantIds.remove(uid);
      final updateData = {
        'participants': participants,
        'participantIds': participantIds,
        'ownerLeft': true,
        'status': 'closed',
        'closedAt': FieldValue.serverTimestamp(),
      };
      await docRef.update(updateData);
      return;
    }

    // Regular participant leaving
    participants.remove(uid);
    participantIds.remove(uid);

    await docRef.update({'participants': participants, 'participantIds': participantIds});
  }

  Stream<StudySession> sessionStream(String sessionId) {
    final docRef = _firestore.collection('studySessions').doc(sessionId);
    return docRef.snapshots().map((doc) => StudySession.fromDoc(doc));
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> sessionsForUserStream() {
    final uid = _uid;
    // Include sessions the user is a participant of, even if owner has left or session closed,
    // so that invites or closed sessions can be surfaced in the UI with appropriate messaging.
    return _firestore
        .collection('studySessions')
        .where('participantIds', arrayContains: uid)
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
