import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/subject_model.dart';
import 'package:uuid/uuid.dart';

class SubjectService {
  static const String _boxName = 'subjectsBox';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // Modified getter to ensure box is open
  Future<Box<Subject>> get _subjectBox async {
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox<Subject>(_boxName);
    }
    return Hive.box<Subject>(_boxName);
  }

  // CREATE
  Future<void> createSubject({
    required String name,
    required String description,
    required String type,
    DateTime? deadline,
    required int hourGoal,
  }) async {
    final box = await _subjectBox;
    final now = DateTime.now();
    final subject = Subject(
      id: _uuid.v4(),
      name: name,
      description: description,
      type: type,
      deadline: deadline,
      hourGoal: hourGoal,
      createdAt: now,
      updatedAt: now,
    );

    await box.put(subject.id, subject);
    print('✅ Subject created: ${subject.name}');
  }

  // READ (get all)
  Future<List<Subject>> getAllSubjects() async {
    final box = await _subjectBox;
    return box.values.toList();
  }

  // READ (get by ID)
  Future<Subject?> getSubject(String id) async {
    final box = await _subjectBox;
    return box.get(id);
  }

  // READ (stream for real-time updates)
  Stream<List<Subject>> watchSubjects() async* {
    final box = await _subjectBox;
    await for (var _ in box.watch()) {
      yield box.values.toList();
    }
  }

  // UPDATE
  Future<void> updateSubject(
    String id, {
    String? name,
    String? description,
    String? type,
    DateTime? deadline,
    int? hourGoal,
  }) async {
    final box = await _subjectBox;
    final subject = box.get(id);
    if (subject == null) {
      print('🔴 Subject not found: $id');
      return;
    }

    final updatedSubject = Subject(
      id: subject.id,
      name: name ?? subject.name,
      description: description ?? subject.description,
      type: type ?? subject.type,
      deadline: deadline ?? subject.deadline,
      hourGoal: hourGoal ?? subject.hourGoal,
      createdAt: subject.createdAt,
      updatedAt: DateTime.now(),
    );

    await box.put(id, updatedSubject);
    print('✅ Subject updated: ${updatedSubject.name}');
  }

  // DELETE
  Future<void> deleteSubject(String id) async {
    final box = await _subjectBox;
    await box.delete(id);
    print('✅ Subject deleted: $id');
  }

// SYNC TO FIREBASE (called on sign-out)
  Future<void> syncToFirebase(String userId) async {
  try {
    print('🔵 Syncing subjects to Firebase...');
    
    final subjects = await getAllSubjects();
    final subjectsJson = subjects.map((s) => s.toJson()).toList();

    // Use set with merge instead of update - creates document if it doesn't exist
    await _firestore.collection('users').doc(userId).set({
      'subjects': subjectsJson,
    }, SetOptions(merge: true));  // ← Changed from update() to set()

    print('✅ Synced ${subjects.length} subjects to Firebase');
  } catch (e) {
    print('🔴 Error syncing to Firebase: $e');
    rethrow;
  }
}

  // LOAD FROM FIREBASE (called on sign-in)
  Future<void> loadFromFirebase(String userId) async {
    try {
      print('🔵 Loading subjects from Firebase...');
      
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return;

      final data = doc.data();
      if (data == null || data['subjects'] == null) return;

      final List<dynamic> subjectsJson = data['subjects'];
      
      // Get box reference
      final box = await _subjectBox;
      
      // Clear existing Hive data
      await box.clear();
      
      // Load subjects into Hive
      for (var json in subjectsJson) {
        final subject = Subject.fromJson(json);
        await box.put(subject.id, subject);
      }

      print('✅ Loaded ${subjectsJson.length} subjects from Firebase');
    } catch (e) {
      print('🔴 Error loading from Firebase: $e');
      rethrow;
    }
  }

  // CLEAR LOCAL DATA (called on sign-out)
  Future<void> clearLocalData() async {
    final box = await _subjectBox;
    await box.clear();
    print('✅ Cleared local subject data');
  }
}
