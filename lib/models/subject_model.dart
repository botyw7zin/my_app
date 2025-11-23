import 'package:hive/hive.dart';

part 'subject_model.g.dart';

@HiveType(typeId: 0)
class Subject extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String name;
  @HiveField(2) String description;
  @HiveField(3) String type;
  @HiveField(4) DateTime? deadline;
  @HiveField(5) int hourGoal;
  @HiveField(6) DateTime createdAt;
  @HiveField(7) DateTime updatedAt;
  @HiveField(8) bool isSynced;
  @HiveField(9) bool isDeleted;
  @HiveField(10) String status; // "in progress", "done", "late"
  @HiveField(11) int hoursCompleted; // NEW

  Subject({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    this.deadline,
    required this.hourGoal,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
    this.isDeleted = false,
    this.status = 'in progress',
    this.hoursCompleted = 0, // NEW default
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type,
      'deadline': deadline?.toIso8601String(),
      'hourGoal': hourGoal,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'status': status,
      'hoursCompleted': hoursCompleted, // NEW
    };
  }

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      type: json['type'],
      deadline: json['deadline'] != null ? DateTime.parse(json['deadline']) : null,
      hourGoal: json['hourGoal'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      isSynced: true,
      isDeleted: false,
      status: json['status'] ?? 'in progress',
      hoursCompleted: json['hoursCompleted'] ?? 0, // NEW
    );
  }
}
