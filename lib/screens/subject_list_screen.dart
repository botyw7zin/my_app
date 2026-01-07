import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../models/subject_model.dart';
import '../services/subject_service.dart';
import '../widgets/base_screen.dart';
import 'update_subject.dart';
import 'friends_request_screen.dart'; // Add this line
import '../widgets/notification_icon.dart';
import 'timer_session_screen.dart';
import 'user_settings_screen.dart';
class SubjectsListScreen extends StatefulWidget {
  const SubjectsListScreen({super.key});

  @override
  State<SubjectsListScreen> createState() => _SubjectsListScreenState();
}

class _SubjectsListScreenState extends State<SubjectsListScreen> {
  final SubjectService _subjectService = SubjectService();
  String _selectedFilter = 'all';
  Set<String> _expandedSubjects = {};
  bool _isInitializing = true; // ✅ Add loading state

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  // ✅ Add initialization method
  Future<void> _initializeData() async {
    // Wait a bit for auth service initialization to complete
    await Future.delayed(const Duration(milliseconds: 500));
    
    final subjectBox = Hive.box<Subject>('subjectsBox');
    
    // Log first subject for debugging
    if (subjectBox.isNotEmpty) {
      final firstSubject = subjectBox.values.first;
    }
    
    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

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
        subject.hoursCompleted = 0.0;
        subject.status = 'in progress';
        await _subjectService.updateSubject(subject);

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
        subject.hoursCompleted = subject.hourGoal.toDouble();
        subject.status = 'done';
        await _subjectService.updateSubject(subject);

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

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'study':
        return const Color(0xFF7550FF);
      case 'personal':
        return const Color(0xFFFF6B6B);
      default:
        return Colors.blue;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'done':
        return Colors.green;
      case 'in progress':
        return Colors.orange;
      case 'late':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'done':
        return '✓';
      case 'in progress':
        return '⏱';
      case 'late':
        return '⚠';
      default:
        return '•';
    }
  }

  Widget _buildExpandableSubjectCard(Subject subject) {
    final isExpanded = _expandedSubjects.contains(subject.id);
    final progress = subject.hourGoal > 0
        ? (subject.hoursCompleted / subject.hourGoal).clamp(0.0, 1.0)
        : 0.0;
    final progressPercent = (progress * 100).toInt();
    final typeColor = _getTypeColor(subject.type);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: typeColor.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedSubjects.remove(subject.id);
                } else {
                  _expandedSubjects.add(subject.id);
                }
              });
            },
            onLongPress: () async {
              // Open timer session page for this subject
              final res = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TimerSessionScreen(subject: subject),
                ),
              );
              if (res == true && mounted) setState(() {});
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      subject.type.toLowerCase() == 'study'
                          ? Icons.school
                          : Icons.person,
                      color: typeColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject.name,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subject.type.toUpperCase(),
                          style: TextStyle(
                            color: typeColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  CircularPercentIndicator(
                    radius: 28.0,
                    lineWidth: 5.0,
                    percent: progress,
                    center: Text(
                      '$progressPercent%',
                      style: TextStyle(
                        color: typeColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    progressColor: typeColor,
                    backgroundColor: typeColor.withOpacity(0.2),
                    circularStrokeCap: CircularStrokeCap.round,
                    animation: true,
                    animationDuration: 800,
                  ),
                  const SizedBox(width: 8),
                  
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.black54,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildExpandedContent(subject),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(Subject subject) {
    final typeColor = _getTypeColor(subject.type);
    final statusColor = _getStatusColor(subject.status);
    
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _formatProgressDisplay(subject.hoursCompleted, subject.hourGoal),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: subject.hourGoal > 0
                      ? (subject.hoursCompleted / subject.hourGoal).clamp(0.0, 1.0)
                      : 0.0,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(typeColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Description',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subject.description,
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: statusColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getStatusIcon(subject.status),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      subject.status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (subject.deadline != null)
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Due: ${subject.deadline!.day}/${subject.deadline!.month}/${subject.deadline!.year}',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _handleMarkAsDone(subject),
                  icon: Icon(
                    subject.status.toLowerCase() == 'done'
                        ? Icons.restart_alt
                        : Icons.check_circle_outline,
                    size: 18,
                  ),
                  label: Text(
                    subject.status.toLowerCase() == 'done'
                        ? 'Reopen'
                        : 'Mark Done',
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: subject.status.toLowerCase() == 'done'
                        ? Colors.orange
                        : Colors.green,
                    side: BorderSide(
                      color: subject.status.toLowerCase() == 'done'
                          ? Colors.orange
                          : Colors.green,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _handleUpdate(subject),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: typeColor,
                    side: BorderSide(color: typeColor),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _handleDelete(subject),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  minimumSize: const Size(0, 0),
                ),
                child: const Icon(Icons.delete, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatProgressDisplay(double hoursCompleted, int hourGoal) {
    if (hoursCompleted < 1.0) {
      final minutes = (hoursCompleted * 60).round();
      return '$minutes min/${hourGoal} hours';
    }
    return '${hoursCompleted.toStringAsFixed(1)}/${hourGoal} hours';
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'My Subjects',
      showAppBar: false,
      currentScreen: 'Documents',
      body: _isInitializing // ✅ Show loading indicator while initializing
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF7550FF),
              ),
            )
          : ValueListenableBuilder<Box<Subject>>(
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
                   // 1. HEADER SECTION (Updated with Filter)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: ValueListenableBuilder(
                      valueListenable: Hive.box('userBox').listenable(),
                      builder: (context, Box userBox, _) {
                        final displayName = (userBox.get('displayName') ?? '') as String;
                        final photoURL = (userBox.get('photoURL') ?? 'assets/images/cat.png') as String;
                        return Row(
                  children: [
                    // --- CHANGED: Profile Picture with Navigation Logic ---
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const UserSettingsScreen()),
                        );
                      },
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFF7550FF),
                        backgroundImage: (photoURL != null && photoURL.startsWith('http'))
                            ? NetworkImage(photoURL)
                            : const AssetImage('assets/images/cat.png') as ImageProvider,
                      ),
                    ),
                    const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Hello!', style: TextStyle(color: Colors.white70, fontSize: 14)),
                                  Text(
                                    displayName.isNotEmpty ? displayName : 'User',
                                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            // Filter Icon (Moved here)
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.filter_list, color: Colors.white),
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
                            // Notification Icon
                            NotificationIcon(
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FriendRequestsScreen())),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF7550FF),
                            const Color(0xFF7550FF).withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7550FF).withOpacity(0.3),
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
                    if (_selectedFilter != 'all')
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Chip(
                          label: Text(
                            'Filter: ${_selectedFilter.toUpperCase()}',
                            style: const TextStyle(color: Colors.white),
                          ),
                          backgroundColor: const Color(0xFF7550FF),
                          deleteIcon: const Icon(Icons.close, size: 18, color: Colors.white),
                          onDeleted: () {
                            setState(() {
                              _selectedFilter = 'all';
                            });
                          },
                        ),
                      ),
                      // --- LIST HEADER TEXT ---
                          if (allSubjects.isNotEmpty)
                            const Padding(
                              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Subjects- Projects',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
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
                              padding: const EdgeInsets.only(bottom: 80),
                              itemCount: filteredSubjects.length,
                              itemBuilder: (context, index) {
                                final subject = filteredSubjects[index];
                                return _buildExpandableSubjectCard(subject);
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
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
