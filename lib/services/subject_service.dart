import 'dart:async';  // ✅ ADD THIS IMPORT
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:workmanager/workmanager.dart';
import '../models/subject_model.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('>>> [WorkManager] Task started: $task');

    try {
      await Firebase.initializeApp();
      await Hive.initFlutter();
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(SubjectAdapter());
      }
      await Hive.openBox<Subject>('subjectsBox');

      await SubjectService.backgroundSyncToFirebase();

      print('>>> [WorkManager] Task completed successfully: $task');
      return Future.value(true);
    } catch (e) {
      print('>>> [WorkManager] Task failed: $task, error: $e');
      return Future.value(false);
    }
  });
}

class SubjectService {
  static final SubjectService _instance = SubjectService._internal();
  factory SubjectService() => _instance;
  SubjectService._internal();

  final _firestore = FirebaseFirestore.instance;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;  // ✅ Now properly imported

  static const String _syncTaskName = 'subject-sync-task';
  static const String _periodicSyncTaskName = 'periodic-subject-sync';

  Future<bool> _isOnline() async {
    final conn = await Connectivity().checkConnectivity();
    return conn != ConnectivityResult.none;
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
    final subjectId = const Uuid().v4();
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
      print('>>> [createSubject] Offline, scheduling background sync');
      await _scheduleOneOffSync();
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
    } else {
      print('>>> [updateSubject] Offline, scheduling background sync');
      await _scheduleOneOffSync();
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
    } else {
      print('>>> [deleteSubject] Offline, scheduling background sync');
      await _scheduleOneOffSync();
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
    int syncedCount = 0;
    for (final subject
        in subjectBox.values.where((s) => !s.isSynced && !s.isDeleted)) {
      print('>>> [syncToFirebase] Syncing: ${subject.id} - ${subject.name} (hoursCompleted: ${subject.hoursCompleted})');
      try {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('subjects')
            .doc(subject.id)
            .set(subject.toJson());
        subject.isSynced = true;
        await subject.save();
        syncedCount++;
        print('>>> [syncToFirebase] ✅ Synced to Firestore: ${subject.id}');
      } catch (e) {
        print('❌ Firestore sync error for subject ${subject.id}: $e');
      }
    }

    // Sync deletions
    for (final subject
        in subjectBox.values.where((s) => s.isDeleted && !s.isSynced)) {
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
        print('❌ Firestore delete error for subject ${subject.id}: $e');
      }
    }

    print('>>> [syncToFirebase] ✅ Sync complete. Synced $syncedCount subjects');
  }

  Future<void> initializeWorkManager() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: true,
    );
    print('>>> [initializeWorkManager] WorkManager initialized');

    await _registerPeriodicSync();
  }

  Future<void> _scheduleOneOffSync() async {
    await Workmanager().registerOneOffTask(
      _syncTaskName,
      _syncTaskName,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      initialDelay: const Duration(seconds: 10),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(seconds: 30),
    );
    print('>>> [_scheduleOneOffSync] Scheduled one-off sync task');
  }

  Future<void> _registerPeriodicSync() async {
    await Workmanager().registerPeriodicTask(
      _periodicSyncTaskName,
      _periodicSyncTaskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
    print('>>> [_registerPeriodicSync] Registered periodic sync task');
  }

  Future<void> cancelBackgroundSync() async {
    await Workmanager().cancelByUniqueName(_syncTaskName);
    await Workmanager().cancelByUniqueName(_periodicSyncTaskName);
    print('>>> [cancelBackgroundSync] Cancelled all sync tasks');
  }

  void listenForConnectivityChanges() {
    _connectivitySubscription?.cancel();
    
    print('>>> [listenForConnectivityChanges] Registering connectivity listener');

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((conn) async {
      print('>>> [listenForConnectivityChanges] Connectivity changed: $conn');
      final user = FirebaseAuth.instance.currentUser;
      print('>>> [listenForConnectivityChanges] user: ${user?.uid}');

      final subjectBox = Hive.box<Subject>('subjectsBox');
      final unsyncedCount = subjectBox.values.where((s) => !s.isSynced).length;
      print('>>> [listenForConnectivityChanges] Unsynced: $unsyncedCount');

      if (conn != ConnectivityResult.none && unsyncedCount > 0) {
        print('>>> [listenForConnectivityChanges] 🌐 Online with pending changes, syncing immediately');
        await syncToFirebase();
      }
    });
  }

  // ✅ FIXED: Removed async/await
  void stopListeningForConnectivityChanges() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    print('>>> [stopListeningForConnectivityChanges] Listener cancelled');
  }

  Future<void> clearLocalData() async {
    final subjectBox = Hive.box<Subject>('subjectsBox');
    await subjectBox.clear();
    print('>>> [clearLocalData] Local subjects cleared');
  }

  Future<void> loadFromFirebase(String userId) async {
    final subjectBox = Hive.box<Subject>('subjectsBox');
    
    try {
      final snap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('subjects')
          .get();
      print('>>> [loadFromFirebase] Fetching remote subjects (found: ${snap.docs.length})...');

      int addedCount = 0;
      int keptCount = 0;

      for (final doc in snap.docs) {
        final remoteJson = doc.data();
        final remote = Subject.fromJson(remoteJson);
        final local = subjectBox.get(remote.id);

        if (local == null) {
          await subjectBox.put(remote.id, remote);
          addedCount++;
          print('>>> [loadFromFirebase] ✅ Added new subject: ${remote.id} (hoursCompleted: ${remote.hoursCompleted})');
        } else {
          keptCount++;
          print('>>> [loadFromFirebase] ⏭️  Kept local subject (hoursCompleted: ${local.hoursCompleted}): ${remote.id}');
        }
      }
      
      print('>>> [loadFromFirebase] ✅ Load complete. Added: $addedCount, Kept: $keptCount');
    } catch (e) {
      print('❌ [loadFromFirebase] Error loading from Firebase: $e');
    }
  }

  List<Subject> getAllSubjects() {
    final subjectBox = Hive.box<Subject>('subjectsBox');
    return subjectBox.values
        .where((subject) => !subject.isDeleted)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<Subject> getSubjectsByType(String type) {
    return getAllSubjects()
        .where((subject) => subject.type == type)
        .toList();
  }

  List<Subject> getSubjectsByStatus(String status) {
    return getAllSubjects()
        .where((subject) => subject.status == status)
        .toList();
  }

  int getTotalHourGoal() {
    return getAllSubjects()
        .fold(0, (sum, subject) => sum + subject.hourGoal);
  }

  Future<void> addStudyHours(Subject subject, int deltaHours) async {
    print('>>> [addStudyHours] 📊 BEFORE: hoursCompleted=${subject.hoursCompleted}, hourGoal=${subject.hourGoal}, isSynced=${subject.isSynced}');
    
    final now = DateTime.now();
    subject.hoursCompleted =
        (subject.hoursCompleted + deltaHours).clamp(0, subject.hourGoal);
    subject.updatedAt = now;

    if (subject.hoursCompleted >= subject.hourGoal && subject.hourGoal > 0) {
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

    print('>>> [addStudyHours] 📊 AFTER: hoursCompleted=${subject.hoursCompleted}, status=${subject.status}, isSynced=${subject.isSynced}');

    if (await _isOnline()) {
      print('>>> [addStudyHours] 🌐 Online, syncing now');
      await syncToFirebase();
    } else {
      print('>>> [addStudyHours] 📴 Offline, scheduling background sync');
      await _scheduleOneOffSync();
    }
  }

  static Future<void> backgroundSyncToFirebase() async {
    print(">>> [backgroundSyncToFirebase] Background sync task started");

    final subjectBox = Hive.box<Subject>('subjectsBox');
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      print('>>> [backgroundSyncToFirebase] No user, skipping sync');
      return;
    }

    final conn = await Connectivity().checkConnectivity();
    if (conn == ConnectivityResult.none) {
      print('>>> [backgroundSyncToFirebase] No connectivity, aborting');
      return;
    }

    final now = DateTime.now();

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

    for (final subject
        in subjectBox.values.where((s) => !s.isSynced && !s.isDeleted)) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('subjects')
            .doc(subject.id)
            .set(subject.toJson());
        subject.isSynced = true;
        await subject.save();
        print(
            '>>> [backgroundSyncToFirebase] Synced to Firestore: ${subject.id}');
      } catch (e) {
        print(
            '❌ Firestore background sync error for subject ${subject.id}: $e');
      }
    }

    for (final subject
        in subjectBox.values.where((s) => s.isDeleted && !s.isSynced)) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('subjects')
            .doc(subject.id)
            .delete();
        await subject.delete();
        print(
            '>>> [backgroundSyncToFirebase] Deleted in Firestore and Hive: ${subject.id}');
      } catch (e) {
        print(
            '❌ Firestore background delete error for subject ${subject.id}: $e');
      }
    }
  }
}
