import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/subject_model.dart';
import '../widgets/subject_card.dart';
import '../services/subject_service.dart';
import 'update_subject.dart';
import '../widgets/base_screen.dart';
import 'home.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _today;
  late DateTime _firstOfMonth;
  late DateTime _lastOfMonth;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _today = DateTime.now();
    _firstOfMonth = DateTime(_today.year, _today.month, 1);
    _lastOfMonth = DateTime(_today.year, _today.month + 1, 0);
    _selected = DateTime(_today.year, _today.month, _today.day);
  }

  final SubjectService _subjectService = SubjectService();

  List<DateTime> _daysInMonth() {
    final days = <DateTime>[];
    for (int d = 1; d <= _lastOfMonth.day; d++) {
      days.add(DateTime(_firstOfMonth.year, _firstOfMonth.month, d));
    }
    return days;
  }

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _endOfDay(DateTime d) => DateTime(d.year, d.month, d.day + 1);

  Stream<QuerySnapshot<Map<String, dynamic>>> _subjectsForSelectedDay() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final start = Timestamp.fromDate(_startOfDay(_selected));
    final end = Timestamp.fromDate(_endOfDay(_selected));
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('subjects')
        .where('deadline', isGreaterThanOrEqualTo: start)
        .where('deadline', isLessThan: end)
        .orderBy('deadline')
        .snapshots();
  }

  // Build local list for selected day using Hive
  List<Subject> _localSubjectsForSelectedDay() {
    final all = _subjectService.getAllSubjects();
    final start = _startOfDay(_selected);
    final end = _endOfDay(_selected);
    return all.where((s) {
      if (s.deadline == null) return false;
      return !s.deadline!.isBefore(start) && s.deadline!.isBefore(end);
    }).toList()
      ..sort((a, b) => a.deadline!.compareTo(b.deadline!));
  }

  @override
  Widget build(BuildContext context) {
    final days = _daysInMonth();

    return BaseScreen(
      title: '${_today.year} - ${_today.month.toString().padLeft(2, '0')}',
      currentScreen: 'Calendar',
      appBarColor: const Color(0xFF2C2F3E),
      automaticallyImplyLeading: false,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () {
          // Ensure we navigate back to Home as a clean route stack
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const Home()),
            (route) => false,
          );
        },
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          onPressed: () {},
        ),
      ],
      body: Column(
        children: [
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: days.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final day = days[index];
                final isSelected = day.year == _selected.year &&
                    day.month == _selected.month &&
                    day.day == _selected.day;

                return GestureDetector(
                  onTap: () => setState(() => _selected = day),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF7550FF)
                          : const Color(0xFF363A4D),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF9C84FF)
                            : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                              [day.weekday % 7],
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          day.day.toString(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<bool>(
              future: _subjectService.isOnline(),
              builder: (context, onlineSnapshot) {
                final online = onlineSnapshot.data == true;

                if (onlineSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.deepPurple),
                  );
                }

                if (online) {
                  // Online: use Firestore live stream
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _subjectsForSelectedDay(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.deepPurple),
                        );
                      }
                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const Center(
                          child: Text(
                            'No subjects due on this day',
                            style: TextStyle(color: Colors.white70),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data();

                          // Convert Firestore document to Subject model (best-effort)
                          DateTime? deadline;
                          final rawDeadline = data['deadline'];
                          if (rawDeadline is Timestamp) {
                            deadline = rawDeadline.toDate();
                          } else if (rawDeadline is String) {
                            try {
                              deadline = DateTime.parse(rawDeadline);
                            } catch (_) {
                              deadline = null;
                            }
                          }

                          final subject = Subject(
                            id: doc.id,
                            name: (data['name'] ?? 'Untitled') as String,
                            description: (data['description'] ?? '') as String,
                            type: (data['type'] ?? '') as String,
                            deadline: deadline,
                            hourGoal: (data['hourGoal'] ?? 0) as int,
                            createdAt: DateTime.now(),
                            updatedAt: DateTime.now(),
                            isSynced: true,
                            isDeleted: false,
                            status: (data['status'] ?? 'in progress') as String,
                            hoursCompleted: (data['hoursCompleted'] ?? 0).toDouble(),
                          );

                          return SubjectCard(
                            subject: subject,
                            onTap: () {},
                            onDelete: () async {
                              try {
                                if (Hive.isBoxOpen('subjectsBox')) {
                                  final box = Hive.box<Subject>('subjectsBox');
                                  final local = box.get(subject.id);
                                  if (local != null) {
                                    await _subjectService.deleteSubject(local);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Marked subject for deletion')),
                                    );
                                    return;
                                  }
                                }

                                final uid = FirebaseAuth.instance.currentUser!.uid;
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(uid)
                                    .collection('subjects')
                                    .doc(subject.id)
                                    .delete();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Subject deleted')),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error deleting subject: $e')),
                                );
                              }
                            },
                            onUpdate: () async {
                              try {
                                if (Hive.isBoxOpen('subjectsBox')) {
                                  final box = Hive.box<Subject>('subjectsBox');
                                  final local = box.get(subject.id);
                                  if (local != null) {
                                    final res = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => UpdateSubjectScreen(subject: local),
                                      ),
                                    );
                                    if (res == true && mounted) setState(() {});
                                    return;
                                  }
                                }

                                final res = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => UpdateSubjectScreen(subject: subject),
                                  ),
                                );
                                if (res == true && mounted) setState(() {});
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error opening update: $e')),
                                );
                              }
                            },
                            onMarkAsDone: () async {
                              try {
                                if (Hive.isBoxOpen('subjectsBox')) {
                                  final box = Hive.box<Subject>('subjectsBox');
                                  final local = box.get(subject.id);
                                  if (local != null) {
                                    if (local.status.toLowerCase() == 'done') {
                                      await _subjectService.updateSubject(local, name: local.name);
                                    } else {
                                      local.status = 'done';
                                      local.isSynced = false;
                                      await local.save();
                                      await _subjectService.syncToFirebase();
                                    }
                                    if (mounted) setState(() {});
                                    return;
                                  }
                                }

                                final uid = FirebaseAuth.instance.currentUser!.uid;
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(uid)
                                    .collection('subjects')
                                    .doc(subject.id)
                                    .update({'status': 'done'});
                                if (mounted) setState(() {});
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error updating status: $e')),
                                );
                              }
                            },
                          );
                        },
                      );
                    },
                  );
                } else {
                  // Offline: use local Hive subjects
                  final localList = _localSubjectsForSelectedDay();
                  if (localList.isEmpty) {
                    return const Center(
                      child: Text(
                        'No subjects due on this day (offline)',
                        style: TextStyle(color: Colors.white70),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: localList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final subject = localList[index];
                      return SubjectCard(
                        subject: subject,
                        onTap: () {},
                        onDelete: () async {
                          try {
                            await _subjectService.deleteSubject(subject);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Marked subject for deletion (offline)')),
                            );
                            if (mounted) setState(() {});
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error deleting subject: $e')),
                            );
                          }
                        },
                        onUpdate: () async {
                          try {
                            final res = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UpdateSubjectScreen(subject: subject),
                              ),
                            );
                            if (res == true && mounted) setState(() {});
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error opening update: $e')),
                            );
                          }
                        },
                        onMarkAsDone: () async {
                          try {
                            if (subject.status.toLowerCase() == 'done') {
                              await _subjectService.updateSubject(subject, name: subject.name);
                            } else {
                              subject.status = 'done';
                              subject.isSynced = false;
                              await subject.save();
                            }
                            if (mounted) setState(() {});
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error updating status: $e')),
                            );
                          }
                        },
                      );
                    },
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
