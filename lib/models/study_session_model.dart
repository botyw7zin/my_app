import 'package:cloud_firestore/cloud_firestore.dart';

class StudySession {
  final String id;
  final String ownerId;
  final String ownerSubjectId;
  final Map<String, dynamic> participants; // uid -> {status, selectedSubjectId, displayName, photoURL}
  final List<String> participantIds;
  final String status; // 'active' | 'ended'
  final DateTime createdAt;

  StudySession({
    required this.id,
    required this.ownerId,
    required this.ownerSubjectId,
    required this.participants,
    required this.participantIds,
    required this.status,
    required this.createdAt,
  });

  factory StudySession.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final created = data['createdAt'] as Timestamp?;
    return StudySession(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      ownerSubjectId: data['ownerSubjectId'] ?? '',
      participants: Map<String, dynamic>.from(data['participants'] ?? {}),
      participantIds: List<String>.from(data['participantIds'] ?? []),
      status: data['status'] ?? 'active',
      createdAt: created?.toDate() ?? DateTime.now(),
    );
  }
}
