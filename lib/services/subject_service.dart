import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/subject_model.dart';

class SubjectService {
  // Singleton implementation
  static final SubjectService _instance = SubjectService._internal();
  factory SubjectService() => _instance;
  SubjectService._internal();

  final _firestore = FirebaseFirestore.instance;

  bool _connectivityListening = false;

  Future<bool> _isOnline() async {
    final conn = await Connectivity().checkConnectivity();
    return conn == ConnectivityResult.mobile || conn == ConnectivityResult.wifi;
  }

  Future<void> createSubject({
    required String name,
    required String description,
    required String type,
    DateTime? deadline,
    required int hourGoal,
  }) async {
    final subjectBox = Hive.box<Subject>('subjectsBox');
    final now = DateTime.now();
    final subjectId = Uuid().v4();
    final subject = Subject(
      id: subjectId,
      name: name,
      description: description,
      type: type,
      deadline: deadline,
      hourGoal: hourGoal,
      createdAt: now,
      updatedAt: now,
      isSynced: false,
      isDeleted: false,
      status: 'in progress',
    );
    await subjectBox.put(subjectId, subject);
    print('>>> [createSubject] Created subject in Hive: $subjectId - $name');
    if (await _isOnline()) {
      print('>>> [createSubject] Online, syncing now');
      await syncToFirebase();
    } else {
      print('>>> [createSubject] Offline, pending sync');
    }
  }

  Future<void> updateSubject(
    Subject subject, {
    String? name,
    String? description,
    String? type,
    DateTime? deadline,
    int? hourGoal,
  }) async {
    final now = DateTime.now();
    if (name != null) subject.name = name;
    if (description != null) subject.description = description;
    if (type != null) subject.type = type;
    if (deadline != null) subject.deadline = deadline;
    if (hourGoal != null) subject.hourGoal = hourGoal;
    subject.updatedAt = now;
    // Status logic
    if (subject.hourGoal <= 0) {
      subject.status = 'done';
    } else if (subject.deadline != null &&
        now.isAfter(subject.deadline!) &&
        subject.status != 'done') {
      subject.status = 'late';
    } else if (subject.status != 'done') {
      subject.status = 'in progress';
    }
    subject.isSynced = false;
    await subject.save();

    print('>>> [updateSubject] Updated subject: ${subject.id} - ${subject.name}');
    if (await _isOnline()) {
      print('>>> [updateSubject] Online, syncing now');
      await syncToFirebase();
    }
  }

  Future<void> deleteSubject(Subject subject) async {
    subject.isDeleted = true;
    subject.isSynced = false;
    await subject.save();
    print('>>> [deleteSubject] Marked for deletion: ${subject.id} - ${subject.name}');
    if (await _isOnline()) {
      print('>>> [deleteSubject] Online, syncing now');
      await syncToFirebase();
    }
  }

  Future<void> syncToFirebase() async {
    final subjectBox = Hive.box<Subject>('subjectsBox');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('>>> [syncToFirebase] No auth user, skipping.');
      return;
    }
    final now = DateTime.now();

    // Mark as late if deadline has passed
    for (final subject in subjectBox.values) {
      if (subject.hourGoal > 0 &&
          subject.deadline != null &&
          now.isAfter(subject.deadline!) &&
          subject.status != 'done' &&
          subject.status != 'late') {
        subject.status = 'late';
        subject.isSynced = false;
        await subject.save();
      }
    }

    // Sync new/updated
    for (final subject in subjectBox.values.where((s) => !s.isSynced && !s.isDeleted)) {
      print('>>> [syncToFirebase] Syncing: ${subject.id} - ${subject.name}');
      try {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('subjects')
            .doc(subject.id)
            .set(subject.toJson());
        subject.isSynced = true;
        await subject.save();
        print('>>> [syncToFirebase] Synced to Firestore: ${subject.id}');
      } catch (e) {
        print('Firestore sync error for subject ${subject.id}: $e');
      }
    }

    // Sync deletions
    for (final subject in subjectBox.values.where((s) => s.isDeleted && !s.isSynced)) {
      print('>>> [syncToFirebase] Remote delete: ${subject.id}');
      try {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('subjects')
            .doc(subject.id)
            .delete();
        await subject.delete();
        print('>>> [syncToFirebase] Deleted in Firestore and Hive: ${subject.id}');
      } catch (e) {
        print('Firestore delete error for subject ${subject.id}: $e');
      }
    }
  }

  // Call this ONCE per session after login
  void listenForConnectivityChanges() {
    if (_connectivityListening) return;
    _connectivityListening = true;
    Connectivity().onConnectivityChanged.listen((conn) async {
      print('>>> [listenForConnectivityChanges] Connectivity changed: $conn');
      final user = FirebaseAuth.instance.currentUser;
      print('>>> [listenForConnectivityChanges] user: ${user?.uid}');
      final subjectBox = Hive.box<Subject>('subjectsBox');
      print('>>> [listenForConnectivityChanges] Unsynced: ${subjectBox.values.where((s) => !s.isSynced).length}');
      if (conn == ConnectivityResult.mobile || conn == ConnectivityResult.wifi) {
        await syncToFirebase();
      }
    });
  }

  Future<void> clearLocalData() async {
    final subjectBox = Hive.box<Subject>('subjectsBox');
    await subjectBox.clear();
    print('>>> [clearLocalData] Local subjects cleared');
  }

  Future<void> loadFromFirebase(String userId) async {
    final subjectBox = Hive.box<Subject>('subjectsBox');
    final snap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('subjects')
        .get();
    print('>>> [loadFromFirebase] Fetching remote subjects...');
    for (final doc in snap.docs) {
      final remoteJson = doc.data();
      final remote = Subject.fromJson(remoteJson);
      final local = subjectBox.get(remote.id);
      if (local == null || local.updatedAt.isBefore(remote.updatedAt)) {
        await subjectBox.put(remote.id, remote);
        print('>>> [loadFromFirebase] Updated local subject: ${remote.id}');
      }
    }
  }
}
