import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'dart:ui'; 

// Models & Services
import '../models/subject_model.dart';
import '../services/subject_service.dart';
import '../services/friends_service.dart';

// Screens
import 'home.dart';
import 'friends_request_screen.dart';

// Widgets
import '../widgets/background.dart'; 

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
  
  // Filter state: 'All', 'done', 'In Progress'
  String _currentFilter = 'All';

  final SubjectService _subjectService = SubjectService();
  final FriendService _friendService = FriendService();

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

  // --- Filtering Logic ---
  List<Subject> _applyFilter(List<Subject> subjects) {
    if (_currentFilter == 'All') return subjects;
    if (_currentFilter == 'done') {
      return subjects.where((s) => s.status.toLowerCase() == 'done').toList();
    }
    if (_currentFilter == 'In Progress') {
      return subjects.where((s) => s.status.toLowerCase() != 'done').toList();
    }
    return subjects;
  }

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

  // --- Helper to Map Firestore Data to Subject ---
  Subject _mapDocumentToSubject(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    // Handle Deadline Parsing safely
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

    return Subject(
      id: doc.id,
      name: (data['name'] ?? 'Untitled') as String,
      description: (data['description'] ?? '') as String,
      type: (data['type'] ?? '') as String,
      deadline: deadline,
      hourGoal: (data['hourGoal'] ?? 0) as int,
      createdAt: DateTime.now(), // Fallback
      updatedAt: DateTime.now(),
      isSynced: true,
      isDeleted: false,
      status: (data['status'] ?? 'in progress') as String,
      hoursCompleted: (data['hoursCompleted'] ?? 0).toDouble(),
    );
  }

  // --- Actions ---

  Future<void> _deleteSubject(Subject subject) async {
    try {
      // Check Hive first
      if (Hive.isBoxOpen('subjectsBox')) {
        final box = Hive.box<Subject>('subjectsBox');
        final local = box.get(subject.id);
        if (local != null) {
          await _subjectService.deleteSubject(local);
           if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subject deleted')));
          setState(() {}); 
          return;
        }
      }
      // Firebase fallback
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('subjects')
          .doc(subject.id)
          .delete();
           if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subject deleted')));
    } catch (e) {
      debugPrint('Error deleting: $e');
    }
  }

@override
  Widget build(BuildContext context) {
    final days = _daysInMonth();

    return Scaffold(
      backgroundColor: const Color(0xFF1F2232),
      body: Stack(
        children: [
          // 1. Background
          const GlowyBackground(),

          // 2. Content
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, // Ensures everything aligns left
              children: [
                const SizedBox(height: 10),

                // --- HEADER ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const Home()),
                          (_) => false,
                        ),
                      ),
                      const Text(
                        'calendar', 
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Stack(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications, color: Colors.white),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const FriendRequestsScreen()),
                            ),
                          ),
                           // Red Dot Logic
                           Positioned(
                              right: 12,
                              top: 12,
                              child: StreamBuilder<QuerySnapshot>(
                                stream: _friendService.incomingRequestsStream(),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                                     return Container(
                                      width: 8, height: 8,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF7550FF), 
                                        shape: BoxShape.circle,
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // --- DAY SELECTOR ---
                SizedBox(
                  height: 90,
                  child: ListView.separated(
                    // Aligns the scrolling days with the content below
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: days.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final day = days[index];
                      final isSelected = day.day == _selected.day;
                      final mName = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][day.month - 1];
                      final wName = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][day.weekday - 1];

                      return GestureDetector(
                        onTap: () => setState(() => _selected = day),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 65,
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF7550FF) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(mName, style: TextStyle(color: isSelected ? Colors.white70 : Colors.black54, fontSize: 12)),
                              const SizedBox(height: 4),
                              Text('${day.day}', style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontSize: 22, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(wName, style: TextStyle(color: isSelected ? Colors.white70 : Colors.black54, fontSize: 12)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // --- FILTER TABS (FIXED ALIGNMENT) ---
                // We removed SingleChildScrollView to lock alignment.
                // We use Padding horizontal: 20 to match the list below exactly.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0), 
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start, // Forces buttons to start from the left
                    children: [
                      _buildFilterTab('All'),
                      const SizedBox(width: 12),
                      _buildFilterTab('done'),
                      const SizedBox(width: 12),
                      // Flexible allows the last tab to shrink if screen is too small, preventing overflow
                      Flexible(child: _buildFilterTab('In Progress')),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // --- TASK LIST ---
                Expanded(
                  child: FutureBuilder<bool>(
                    future: _subjectService.isOnline(),
                    builder: (context, onlineSnap) {
                      final isOnline = onlineSnap.data == true;
                      
                      // Shared List Builder Helper
                      Widget buildList(List<Subject> items) {
                        if (items.isEmpty) return _emptyState();
                        return ListView.separated(
                          // MATCHING PADDING: horizontal 20 ensures alignment with Filter Tabs
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 16),
                          itemBuilder: (ctx, i) => _buildCard(items[i]),
                        );
                      }

                      // OFFLINE MODE
                      if (!isOnline && onlineSnap.connectionState == ConnectionState.done) {
                        return buildList(_applyFilter(_localSubjectsForSelectedDay()));
                      }

                      // ONLINE MODE
                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _subjectsForSelectedDay(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                             return const Center(child: CircularProgressIndicator(color: Colors.white));
                          }
                          final docs = snapshot.data?.docs ?? [];
                          final allSubjects = docs.map((doc) => _mapDocumentToSubject(doc)).toList();
                          final filtered = _applyFilter(allSubjects);
                          
                          return buildList(filtered);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  // --- Helper Widgets ---

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today, color: Colors.white.withOpacity(0.3), size: 50),
          const SizedBox(height: 10),
          Text(
            'No tasks found',
            style: TextStyle(color: Colors.white.withOpacity(0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String title) {
    final isActive = _currentFilter == title;
    return GestureDetector(
      onTap: () => setState(() => _currentFilter = title),
      child: Container(
        // INCREASED PADDING HERE
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF7550FF) : const Color(0xFFEBEBF5), 
          borderRadius: BorderRadius.circular(24), // Slightly more rounded
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : const Color(0xFF7550FF),
            fontWeight: FontWeight.w600,
            fontSize: 16, // INCREASED FONT SIZE
          ),
        ),
      ),
    );
  }

  Widget _buildCard(Subject subject) {
    final isDone = subject.status.toLowerCase() == 'done';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Subject Type (Small) + Trash Icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                subject.name.toUpperCase(), 
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () => _deleteSubject(subject),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE5E5), 
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFFFF6B6B),
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 4),

          // Main Title (Description)
          Text(
            subject.description.isNotEmpty ? subject.description : 'Study Session',
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          // Bottom Row: Time + Status Chip
          Row(
            children: [
              const Icon(Icons.access_time_filled, size: 16, color: Color(0xFF9898AA)),
              const SizedBox(width: 4),
              Text(
                '${subject.hourGoal}:00h',
                style: const TextStyle(
                  color: Color(0xFF9898AA),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              
              // Status Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDone 
                      ? const Color(0xFFE0F7FA) 
                      : const Color(0xFFFFEAD1), 
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isDone ? 'done' : 'In Progress',
                  style: TextStyle(
                    color: isDone ? Colors.cyan[700] : Colors.orange[800],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}