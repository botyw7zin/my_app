import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/subject_model.dart';

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

  @override
  Widget build(BuildContext context) {
    final days = _daysInMonth();

    return Scaffold(
      backgroundColor: const Color(0xFF2C2F3E),
      appBar: AppBar(
        title: Text(
          '${_today.year} - ${_today.month.toString().padLeft(2, '0')}',
        ),
        backgroundColor: Colors.deepPurple,
      ),
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
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _subjectsForSelectedDay(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child:
                        CircularProgressIndicator(color: Colors.deepPurple),
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
                    final data = docs[index].data();
                    final title = (data['name'] ?? 'Untitled') as String;
                    final type = (data['type'] ?? '') as String;
                    final ts = data['deadline'] as Timestamp?;
                    final deadline = ts?.toDate();

                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF363A4D),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        title: Text(
                          title,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (type.isNotEmpty)
                              Text(
                                type,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            if (deadline != null)
                              Text(
                                'Due at ${deadline.hour.toString().padLeft(2, '0')}:${deadline.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 12),
                              ),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right,
                            color: Colors.white54),
                        onTap: () {
                          // TODO: open subject details
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
