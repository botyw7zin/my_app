import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/subject_model.dart';
import '../services/subject_service.dart';
import '../widgets/subject_card.dart';
import '../widgets/nav_components.dart'; // Import your nav components
import 'update_subject.dart';
import 'add_subject.dart'; // Import add subject screen

class SubjectsListScreen extends StatefulWidget {
  const SubjectsListScreen({super.key});

  @override
  State<SubjectsListScreen> createState() => _SubjectsListScreenState();
}

class _SubjectsListScreenState extends State<SubjectsListScreen> {
  final SubjectService _subjectService = SubjectService();
  String _selectedFilter = 'all';

  List<Subject> _filterSubjects(List<Subject> subjects) {
    switch (_selectedFilter) {
      case 'study':
      case 'personal':
        return subjects.where((s) => s.type == _selectedFilter).toList();
      case 'done':
      case 'in progress':
      case 'late':
        return subjects.where((s) => s.status == _selectedFilter).toList();
      default:
        return subjects;
    }
  }

  // Handle navigation from bottom nav
  void _handleNavigation(String label) {
    print('>>> [SubjectsListScreen] Navigation tapped: $label');
    
    switch (label) {
      case 'Home':
        // Navigate back to home
        Navigator.pop(context);
        break;
      case 'Calendar':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Calendar coming soon!')),
        );
        break;
      case 'Documents':
        // Already on documents, do nothing
        break;
      case 'People':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('People coming soon!')),
        );
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unknown navigation: $label')),
        );
    }
  }

  // Navigate to add subject screen
  void _navigateToAddSubject() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddSubjectScreen()),
    );
  }

  // Handle update navigation
  Future<void> _handleUpdate(Subject subject) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UpdateSubjectScreen(subject: subject),
      ),
    );
    
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subject updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // Handle delete with confirmation
  Future<void> _handleDelete(Subject subject) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF363A4D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Delete Subject',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to delete this subject?',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bookmark, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      subject.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                color: Colors.red.shade300,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        await _subjectService.deleteSubject(subject);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('"${subject.name}" deleted'),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting subject: $e'),
              backgroundColor: Colors.red.shade900,
            ),
          );
        }
      }
    }
  }

Future<void> _handleMarkAsDone(Subject subject) async {
  final isDone = subject.status.toLowerCase() == 'done';
  
  try {
    if (isDone) {
      // Reopen the subject - set hour goal back to a positive number if it's 0
      final newHourGoal = subject.hourGoal <= 0 ? 1 : subject.hourGoal;
      await _subjectService.updateSubject(
        subject,
        hourGoal: newHourGoal,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.restart_alt, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('"${subject.name}" marked as In Progress'),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      // Mark as done - set hour goal to 0
      await _subjectService.updateSubject(
        subject,
        hourGoal: 0,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('"${subject.name}" marked as Done! 🎉'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status: $e'),
          backgroundColor: Colors.red.shade900,
        ),
      );
    }
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C2F3E),
      appBar: AppBar(
        title: const Text('My Subjects'),
        backgroundColor: Colors.deepPurple,
        automaticallyImplyLeading: false, // Remove back button since we have bottom nav
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _selectedFilter = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All Subjects')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'study', child: Text('Study')),
              const PopupMenuItem(value: 'personal', child: Text('Personal')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'in progress', child: Text('In Progress')),
              const PopupMenuItem(value: 'done', child: Text('Done')),
              const PopupMenuItem(value: 'late', child: Text('Late')),
            ],
          ),
        ],
      ),
      body: ValueListenableBuilder<Box<Subject>>(
        valueListenable: Hive.box<Subject>('subjectsBox').listenable(),
        builder: (context, box, widget) {
          final allSubjects = _subjectService.getAllSubjects();
          final filteredSubjects = _filterSubjects(allSubjects);
          final totalHourGoal = _subjectService.getTotalHourGoal();

          if (allSubjects.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bookmark_border,
                    size: 80,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No subjects yet',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to create your first subject',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Stats Header
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.deepPurple,
                      Colors.deepPurple.shade700,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      icon: Icons.bookmark,
                      label: 'Total',
                      value: allSubjects.length.toString(),
                    ),
                    Container(
                      height: 40,
                      width: 1,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    _buildStatItem(
                      icon: Icons.timer,
                      label: 'Total Hours',
                      value: '$totalHourGoal hrs',
                    ),
                    Container(
                      height: 40,
                      width: 1,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    _buildStatItem(
                      icon: Icons.check_circle,
                      label: 'Done',
                      value: allSubjects
                          .where((s) => s.status == 'done')
                          .length
                          .toString(),
                    ),
                  ],
                ),
              ),

              // Filter Chip
              if (_selectedFilter != 'all')
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Chip(
                    label: Text(
                      'Filter: ${_selectedFilter.toUpperCase()}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Colors.deepPurple,
                    deleteIcon: const Icon(Icons.close, size: 18, color: Colors.white),
                    onDeleted: () {
                      setState(() {
                        _selectedFilter = 'all';
                      });
                    },
                  ),
                ),

              // Subjects List
              Expanded(
                child: filteredSubjects.isEmpty
                    ? Center(
                        child: Text(
                          'No subjects match this filter',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 16,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80), // Add padding for bottom nav
                        itemCount: filteredSubjects.length,
                        itemBuilder: (context, index) {
                          final subject = filteredSubjects[index];
                          return SubjectCard(
                            subject: subject,
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Tapped: ${subject.name}'),
                                  duration: const Duration(milliseconds: 500),
                                ),
                              );
                            },
                            onUpdate: () => _handleUpdate(subject),
                            onDelete: () => _handleDelete(subject),
                            onMarkAsDone: () => _handleMarkAsDone(subject), // ← ADD THIS LINE
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      // Add Bottom Navigation with FAB
      floatingActionButton: NavComponents.buildFAB(_navigateToAddSubject),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: NavComponents.buildBottomBar(_handleNavigation),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
