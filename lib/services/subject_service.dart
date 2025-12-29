import 'dart:async';
import 'dart:io';
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
  
  // ✅ ADD THIS LINE - Track connectivity subscription
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  static const String _syncTaskName = 'subject-sync-task';
  static const String _periodicSyncTaskName = 'periodic-subject-sync';

  // ------- Pure Local CRUD Operations (No Connectivity Checks) -------
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
    // If online, attempt to push to Firestore immediately
    if (await _isOnline()) {
      try {
        final user = FirebaseAuth.instance.currentUser!;
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('subjects')
            .doc(subjectId)
            .set(_toFirestoreJson(subject));
        subject.isSynced = true;
        await subject.save();
        print('>>> [createSubject] Synced new subject to Firestore: $subjectId');
      } catch (e) {
        print('>>> [createSubject] Failed to push new subject immediately: $e');
      }
    }
  }

  /// Returns true if device likely has internet access and a signed-in user.
  /// Uses connectivity_plus to check network interface and a DNS lookup
  /// as a lightweight confirmation of internet reachability.
  Future<bool> _isOnline() async {
    try {
      final conn = await Connectivity().checkConnectivity();
      final user = FirebaseAuth.instance.currentUser;
      if (conn == ConnectivityResult.none || user == null) return false;

      // Perform a quick DNS lookup to confirm actual internet access.
      try {
        final result = await InternetAddress.lookup('example.com').timeout(const Duration(seconds: 4));
        if (result.isNotEmpty && result.first.rawAddress.isNotEmpty) {
          return true;
        }
        return false;
      } catch (_) {
        return false;
      }
    } catch (e) {
      print('>>> [_isOnline] Error checking connectivity: $e');
      return false;
    }
  }

  /// Public wrapper so UI can check online state
  Future<bool> isOnline() async => _isOnline();

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

    print('>>> [updateSubject] Updated subject in Hive: ${subject.id} - ${subject.name}');
    // If online, attempt immediate remote update (optimistic sync)
    if (await _isOnline()) {
      try {
        final user = FirebaseAuth.instance.currentUser!;
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('subjects')
            .doc(subject.id)
            .set(_toFirestoreJson(subject));
        subject.isSynced = true;
        await subject.save();
        print('>>> [updateSubject] Synced updated subject to Firestore: ${subject.id}');
      } catch (e) {
        print('>>> [updateSubject] Failed to sync update immediately: $e');
      }
    }
  }

  Future<void> deleteSubject(Subject subject) async {
    // If online try to delete immediately remotely and locally
    if (await _isOnline()) {
      try {
        final user = FirebaseAuth.instance.currentUser!;
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('subjects')
            .doc(subject.id)
            .delete();
        // remove local immediately
        await subject.delete();
        print('>>> [deleteSubject] Deleted remote and local: ${subject.id} - ${subject.name}');
        return;
      } catch (e) {
        print('>>> [deleteSubject] Failed to delete remote immediately: $e — marking for deletion locally');
        // fall through to mark for deletion locally
      }
    }

    // Offline or failed remote deletion: mark for deletion locally and schedule sync
    subject.isDeleted = true;
    subject.isSynced = false;
    await subject.save();
    print('>>> [deleteSubject] Marked for deletion in Hive: ${subject.id} - ${subject.name}');
  }

  Future<void> addStudyHours(Subject subject, double deltaHours) async {
    final now = DateTime.now();
    subject.hoursCompleted = (subject.hoursCompleted + deltaHours).clamp(0.0, subject.hourGoal.toDouble());
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
    
    print('>>> [addStudyHours] Updated hours in Hive: ${subject.id} - ${subject.hoursCompleted}/${subject.hourGoal}');
    // Attempt immediate sync when online
    if (await _isOnline()) {
      try {
        final user = FirebaseAuth.instance.currentUser!;
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('subjects')
            .doc(subject.id)
            .set(_toFirestoreJson(subject));
        subject.isSynced = true;
        await subject.save();
        print('>>> [addStudyHours] Synced hours update to Firestore: ${subject.id}');
      } catch (e) {
        print('>>> [addStudyHours] Failed to sync hours immediately: $e');
      }
    }
  }

  // ------- Centralized Sync Logic -------

  Future<void> syncToFirebase() async {
    final subjectBox = Hive.box<Subject>('subjectsBox');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('>>> [syncToFirebase] No auth user, skipping.');
      return;
    }
    final now = DateTime.now();

    print('>>> [syncToFirebase] Starting sync...');

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
          .set(_toFirestoreJson(subject));
        subject.isSynced = true;
        await subject.save();
        syncedCount++;
        print('>>> [syncToFirebase] ✅ Synced to Firestore: ${subject.id}');
      } catch (e) {
        print('>>> [syncToFirebase] Firestore sync error for subject ${subject.id}: $e');
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
        print('>>> [syncToFirebase] Firestore delete error for subject ${subject.id}: $e');
      }
    }
    
    print('>>> [syncToFirebase] Sync completed');
  }

  // ------- WorkManager Integration -------

  /// Initialize WorkManager - call once in main() after Firebase init
  Future<void> initializeWorkManager() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: true,
    );
    print('>>> [initializeWorkManager] WorkManager initialized');

    await _registerPeriodicSync();
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

  /// Cancel all background sync tasks
  Future<void> cancelBackgroundSync() async {
    await Workmanager().cancelByUniqueName(_syncTaskName);
    await Workmanager().cancelByUniqueName(_periodicSyncTaskName);
    
    // Also cancel connectivity listener
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    
    print('>>> [cancelBackgroundSync] Cancelled all sync tasks and listeners');
  }

  /// Call this ONCE per session after login - triggers sync when coming online
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

      // Use stronger isOnline check to avoid false positives from network interface
      if (await _isOnline()) {
        try {
          print('>>> [listenForConnectivityChanges] Confirmed internet, performing two-way sync');
          await syncBothWays();
        } catch (e) {
          print('>>> [listenForConnectivityChanges] syncBothWays failed: $e');
        }
      } else {
        print('>>> [listenForConnectivityChanges] No internet after verification, skipping sync');
      }
    });

    // Immediately check current state and attempt sync if online when listener is registered
    (() async {
      try {
        final onlineNow = await _isOnline();
        print('>>> [listenForConnectivityChanges] Initial online check: $onlineNow');
        if (onlineNow) {
          await syncBothWays();
        }
      } catch (e) {
        print('>>> [listenForConnectivityChanges] Initial sync check failed: $e');
      }
    })();
  }

  /// Manual sync trigger (e.g., pull-to-refresh or "Sync Now" button)
  Future<void> manualSync() async {
    print('>>> [manualSync] User triggered manual sync');
    await syncToFirebase();
  }

  // Helper to parse date values stored as Timestamp, ISO string, or milliseconds
  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    try {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    } catch (_) {
      return null;
    }
    return null;
  }

  Subject _subjectFromRemote(String id, Map<String, dynamic> data) {
    final deadline = _parseDate(data['deadline']);
    final createdAt = _parseDate(data['createdAt']) ?? DateTime.now();
    final updatedAt = _parseDate(data['updatedAt']) ?? createdAt;

    return Subject(
      id: id,
      name: (data['name'] ?? '') as String,
      description: (data['description'] ?? '') as String,
      type: (data['type'] ?? '') as String,
      deadline: deadline,
      hourGoal: (data['hourGoal'] ?? 0) as int,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isSynced: true,
      isDeleted: false,
      status: (data['status'] ?? 'in progress') as String,
      hoursCompleted: (data['hoursCompleted'] ?? 0).toDouble(),
    );
  }

  /// Convert a local Subject into a Firestore-friendly Map where dates are Timestamps
  Map<String, dynamic> _toFirestoreJson(Subject s) {
    return {
      'id': s.id,
      'name': s.name,
      'description': s.description,
      'type': s.type,
      'deadline': s.deadline != null ? Timestamp.fromDate(s.deadline!) : null,
      'hourGoal': s.hourGoal,
      'createdAt': Timestamp.fromDate(s.createdAt),
      'updatedAt': Timestamp.fromDate(s.updatedAt),
      'status': s.status,
      'hoursCompleted': s.hoursCompleted,
    };
  }

  /// Two-way sync: merge remote -> local and push local -> remote where appropriate
  Future<void> syncBothWays() async {
    final subjectBox = Hive.box<Subject>('subjectsBox');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('>>> [syncBothWays] No auth user, skipping.');
      return;
    }

    try {
      print('>>> [syncBothWays] Starting two-way sync for user: ${user.uid}');

      // 1) Pull remote docs
      final snap = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('subjects')
          .get();

      // Process remote -> local
      for (final doc in snap.docs) {
        final remoteData = doc.data();
        final remote = _subjectFromRemote(doc.id, remoteData);
        final local = subjectBox.get(remote.id);

        // If local is marked deleted, honor that and remove remote + local immediately
        if (local != null && local.isDeleted) {
          try {
            await _firestore
                .collection('users')
                .doc(user.uid)
                .collection('subjects')
                .doc(local.id)
                .delete();
            await local.delete();
            print('>>> [syncBothWays] Local was deleted -> removed remote and local: ${local.id}');
            continue;
          } catch (e) {
            print('>>> [syncBothWays] Error propagating local deletion for ${local.id}: $e');
            // If deletion fails, skip this doc to avoid accidental overwrite
            continue;
          }
        }

        if (local == null) {
          await subjectBox.put(remote.id, remote);
          print('>>> [syncBothWays] Remote -> Local added: ${remote.id}');
          continue;
        }

        if (local.updatedAt.isBefore(remote.updatedAt)) {
          // remote newer -> overwrite local
          await subjectBox.put(remote.id, remote);
          print('>>> [syncBothWays] Remote newer -> Local updated: ${remote.id}');
        } else if (local.updatedAt.isAfter(remote.updatedAt)) {
          // local newer -> push local to remote
          if (local.isDeleted) {
            // delete remote and local
            try {
              await _firestore
                  .collection('users')
                  .doc(user.uid)
                  .collection('subjects')
                  .doc(local.id)
                  .delete();
              await local.delete();
              print('>>> [syncBothWays] Local was deleted -> removed remote and local: ${local.id}');
            } catch (e) {
              print('>>> [syncBothWays] Error deleting remote doc ${local.id}: $e');
            }
          } else {
            try {
                await _firestore
                  .collection('users')
                  .doc(user.uid)
                  .collection('subjects')
                  .doc(local.id)
                  .set(_toFirestoreJson(local));
              local.isSynced = true;
              await local.save();
              print('>>> [syncBothWays] Local newer -> pushed to remote: ${local.id}');
            } catch (e) {
              print('>>> [syncBothWays] Error pushing local ${local.id}: $e');
            }
          }
        }
      }

      // 2) Push remaining local-only or unsynced
      for (final local in subjectBox.values.toList()) {
        if (local.isDeleted && !local.isSynced) {
          try {
            await _firestore
                .collection('users')
                .doc(user.uid)
                .collection('subjects')
                .doc(local.id)
                .delete();
            await local.delete();
            print('>>> [syncBothWays] Deleted remote and removed local: ${local.id}');
            continue;
          } catch (e) {
            print('>>> [syncBothWays] Error deleting remote for local ${local.id}: $e');
          }
        }

        if (!local.isSynced && !local.isDeleted) {
          try {
            await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('subjects')
              .doc(local.id)
              .set(_toFirestoreJson(local));
            local.isSynced = true;
            await local.save();
            print('>>> [syncBothWays] Pushed local -> remote: ${local.id}');
          } catch (e) {
            print('>>> [syncBothWays] Error pushing local ${local.id}: $e');
          }
        }
      }

      print('>>> [syncBothWays] Two-way sync completed');
      // Final cleanup: ensure any subjects marked `isDeleted` are removed from Hive
      // only after confirming remote doc is absent or removed. This prevents
      // leaving tombstones in Hive after a successful sync.
      for (final local in subjectBox.values.where((s) => s.isDeleted).toList()) {
        final docRef = _firestore
            .collection('users')
            .doc(user.uid)
            .collection('subjects')
            .doc(local.id);
        try {
          final remoteSnap = await docRef.get();
          if (!remoteSnap.exists) {
            await local.delete();
            print('>>> [syncBothWays] Cleanup: remote missing -> removed local tombstone: ${local.id}');
            continue;
          }

          // If remote exists try deleting it, then remove local
          await docRef.delete();
          await local.delete();
          print('>>> [syncBothWays] Cleanup: deleted remote and removed local: ${local.id}');
        } catch (e) {
          print('>>> [syncBothWays] Cleanup: failed to remove ${local.id}: $e');
          // keep the local tombstone for next sync attempt
        }
      }
    } catch (e) {
      print('>>> [syncBothWays] Error during sync: $e');
    }
  }

  // ------- Data Management -------

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
      final remote = _subjectFromRemote(doc.id, remoteJson);
      final local = subjectBox.get(remote.id);

      // If remote stores deadline as a String (older data), migrate it to Timestamp
      final rawDeadline = remoteJson['deadline'];
      if (rawDeadline is String) {
        final parsed = _parseDate(rawDeadline);
        if (parsed != null) {
          try {
            await _firestore
                .collection('users')
                .doc(userId)
                .collection('subjects')
                .doc(doc.id)
                .update({'deadline': Timestamp.fromDate(parsed)});
            print('>>> [loadFromFirebase] Migrated remote deadline to Timestamp for ${doc.id}');
          } catch (e) {
            print('>>> [loadFromFirebase] Failed to migrate deadline for ${doc.id}: $e');
          }
        }
      }

      // If the local copy has been marked deleted while offline, honor that deletion
      // and remove remote + local instead of re-creating it from remote.
      if (local != null && local.isDeleted) {
        try {
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('subjects')
              .doc(doc.id)
              .delete();
          await local.delete();
          print('>>> [loadFromFirebase] Local was deleted -> removed remote and local: ${doc.id}');
          continue;
        } catch (e) {
          print('>>> [loadFromFirebase] Failed to propagate local deletion for ${doc.id}: $e');
          // If deletion failed, skip overwriting local for safety
          continue;
        }
      }

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

  // ------- Background Sync (Called by WorkManager) -------

  /// For Workmanager/background sync - runs in separate isolate
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

    // Delegate to two-way sync which handles pull + push + deletions
    try {
      await SubjectService().syncBothWays();
      print('>>> [backgroundSyncToFirebase] Delegated to syncBothWays');
    } catch (e) {
      print('>>> [backgroundSyncToFirebase] Error delegating sync: $e');
    }
  }
}
