import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:workmanager/workmanager.dart';
import '../models/subject_model.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';

// IMPORTANT: Top-level callback dispatcher for WorkManager
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('>>> [WorkManager] Task started: $task');
    
    try {
      // Initialize Firebase for background isolate
      await Firebase.initializeApp();
      
      // Initialize Hive with adapter
      await Hive.initFlutter();
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(SubjectAdapter());
      }
      await Hive.openBox<Subject>('subjectsBox');
      
      // Execute background sync
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
  // Singleton implementation
  static final SubjectService _instance = SubjectService._internal();
  factory SubjectService() => _instance;
  SubjectService._internal();

  final _firestore = FirebaseFirestore.instance;
  bool _connectivityListening = false;

  // WorkManager task names
  static const String _syncTaskName = 'subject-sync-task';
  static const String _periodicSyncTaskName = 'periodic-subject-sync';

  // ------- Main App/Foreground Logic -------

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

  // ------- WorkManager Integration -------

  /// Initialize WorkManager - call once in main() after Firebase init
  Future<void> initializeWorkManager() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: true, // Set to false in production
    );
    print('>>> [initializeWorkManager] WorkManager initialized');
    
    // Register periodic background sync (runs every 15 minutes minimum)
    await _registerPeriodicSync();
  }

  /// Schedule a one-off sync task when network becomes available
  Future<void> _scheduleOneOffSync() async {
    await Workmanager().registerOneOffTask(
      _syncTaskName,
      _syncTaskName,
      constraints: Constraints(
        networkType: NetworkType.connected, // Only run when connected
      ),
      initialDelay: Duration(seconds: 10), // Wait 10 seconds before trying
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: Duration(seconds: 30),
    );
    print('>>> [_scheduleOneOffSync] Scheduled one-off sync task');
  }

  /// Register periodic background sync (runs every 15 minutes)
  Future<void> _registerPeriodicSync() async {
    await Workmanager().registerPeriodicTask(
      _periodicSyncTaskName,
      _periodicSyncTaskName,
      frequency: Duration(minutes: 15), // Minimum allowed frequency
      constraints: Constraints(
        networkType: NetworkType.connected, // Only when online
        requiresBatteryNotLow: true, // Don't drain battery
      ),
      existingWorkPolicy: ExistingWorkPolicy.keep, // Don't duplicate tasks
    );
    print('>>> [_registerPeriodicSync] Registered periodic sync task');
  }

  /// Cancel all background sync tasks
  Future<void> cancelBackgroundSync() async {
    await Workmanager().cancelByUniqueName(_syncTaskName);
    await Workmanager().cancelByUniqueName(_periodicSyncTaskName);
    print('>>> [cancelBackgroundSync] Cancelled all sync tasks');
  }

  // Call this ONCE per session after login (works when app is open)
  void listenForConnectivityChanges() {
    if (_connectivityListening) return;
    _connectivityListening = true;
    
    Connectivity().onConnectivityChanged.listen((conn) async {
      print('>>> [listenForConnectivityChanges] Connectivity changed: $conn');
      final user = FirebaseAuth.instance.currentUser;
      print('>>> [listenForConnectivityChanges] user: ${user?.uid}');
      
      final subjectBox = Hive.box<Subject>('subjectsBox');
      print('>>> [listenForConnectivityChanges] Unsynced: ${subjectBox.values.where((s) => !s.isSynced).length}');
      
      if (conn != ConnectivityResult.none) {
        print('>>> [listenForConnectivityChanges] Online, syncing immediately');
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

  /// Get all subjects (non-deleted) from Hive
List<Subject> getAllSubjects() {
  final subjectBox = Hive.box<Subject>('subjectsBox');
  return subjectBox.values
      .where((subject) => !subject.isDeleted)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Most recent first
}

/// Get subjects by type
List<Subject> getSubjectsByType(String type) {
  return getAllSubjects()
      .where((subject) => subject.type == type)
      .toList();
}

/// Get subjects by status
List<Subject> getSubjectsByStatus(String status) {
  return getAllSubjects()
      .where((subject) => subject.status == status)
      .toList();
}

/// Calculate total hour goal across all subjects
int getTotalHourGoal() {
  return getAllSubjects()
      .fold(0, (sum, subject) => sum + subject.hourGoal);
}

// Increment hours, clamp to goal, auto-set done
Future<void> addStudyHours(Subject subject, int deltaHours) async {
  final now = DateTime.now();
  subject.hoursCompleted = (subject.hoursCompleted + deltaHours).clamp(0, subject.hourGoal);
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

  if (await _isOnline()) {
    await syncToFirebase();
  }
}


  /// ---- For Workmanager/background sync ----
  static Future<void> backgroundSyncToFirebase() async {
    print(">>> [backgroundSyncToFirebase] Background sync task started");
    
    final subjectBox = Hive.box<Subject>('subjectsBox');
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      print('>>> [backgroundSyncToFirebase] No user, skipping sync');
      return;
    }
    
    // Check connectivity
    final conn = await Connectivity().checkConnectivity();
    if (conn == ConnectivityResult.none) {
      print('>>> [backgroundSyncToFirebase] No connectivity, aborting');
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
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('subjects')
            .doc(subject.id)
            .set(subject.toJson());
        subject.isSynced = true;
        await subject.save();
        print('>>> [backgroundSyncToFirebase] Synced to Firestore: ${subject.id}');
      } catch (e) {
        print('Firestore background sync error for subject ${subject.id}: $e');
      }
    }
    
    // Sync deletions
    for (final subject in subjectBox.values.where((s) => s.isDeleted && !s.isSynced)) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('subjects')
            .doc(subject.id)
            .delete();
        await subject.delete();
        print('>>> [backgroundSyncToFirebase] Deleted in Firestore and Hive: ${subject.id}');
      } catch (e) {
        print('Firestore background delete error for subject ${subject.id}: $e');
      }
    }
  }
}


