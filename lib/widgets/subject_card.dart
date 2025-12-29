import 'package:flutter/material.dart';
import '../models/subject_model.dart';

class SubjectCard extends StatelessWidget {
  final Subject subject;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onUpdate;
  final VoidCallback? onMarkAsDone;

  const SubjectCard({
    super.key,
    required this.subject,
    this.onTap,
    this.onDelete,
    this.onUpdate,
    this.onMarkAsDone,
  });

  // Get icon and color based on type
  IconData _getTypeIcon() {
    switch (subject.type.toLowerCase()) {
      case 'study':
        return Icons.school;
      case 'personal':
        return Icons.person;
      default:
        return Icons.bookmark;
    }
  }

  Color _getTypeColor() {
    switch (subject.type.toLowerCase()) {
      case 'study':
        return Colors.blue;
      case 'personal':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor() {
    switch (subject.status.toLowerCase()) {
      case 'done':
        return Colors.green;
      case 'late':
        return Colors.red;
      case 'in progress':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (subject.status.toLowerCase()) {
      case 'done':
        return Icons.check_circle;
      case 'late':
        return Icons.warning;
      case 'in progress':
        return Icons.pending;
      default:
        return Icons.circle;
    }
  }

  String _formatDeadline() {
    if (subject.deadline == null) return 'No deadline';
    final deadline = subject.deadline!;
    return '${deadline.day}/${deadline.month}/${deadline.year}';
  }

  String _formatProgressTime(double hours) {
    if (hours < 1.0) {
      final minutes = (hours * 60).round();
      return '$minutes min';
    }
    // show one decimal hour when >= 1
    return '${hours.toStringAsFixed(1)} hrs';
  }

  double _getProgress() {
    if (subject.hourGoal <= 0) return 0;
    final value = (subject.hoursCompleted / subject.hourGoal).clamp(0.0, 1.0);
    return value.isNaN ? 0 : value;
  }

  void _showActionMenu(BuildContext context) {
    final isDone = subject.status.toLowerCase() == 'done';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF363A4D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Subject Title Header
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(_getTypeIcon(), color: _getTypeColor(), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      subject.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Mark as Done / Undone Option
            if (!isDone)
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: const Text(
                  'Mark as Done',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Complete this subject',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(context);
                  if (onMarkAsDone != null) onMarkAsDone!();
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.restart_alt, color: Colors.orange),
                title: const Text(
                  'Mark as In Progress',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Reopen this subject',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(context);
                  if (onMarkAsDone != null) onMarkAsDone!();
                },
              ),

            const Divider(color: Colors.white24),

            // Update Option
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text(
                'Update Subject',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Edit details and settings',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                if (onUpdate != null) onUpdate!();
              },
            ),

            const Divider(color: Colors.white24),

            // Delete Option
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Delete Subject',
                style: TextStyle(color: Colors.red),
              ),
              subtitle: const Text(
                'Permanently remove',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                if (onDelete != null) onDelete!();
              },
            ),

            const SizedBox(height: 10),

            // Cancel Button
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _getProgress();
    final progressPercent = (progress * 100).toStringAsFixed(0);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: const Color(0xFF363A4D),
      child: InkWell(
        onTap: onTap,
        onLongPress: () => _showActionMenu(context),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Title and Type Icon
              Row(
                children: [
                  // Type Icon Badge
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getTypeColor().withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getTypeIcon(),
                      color: _getTypeColor(),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subject.type.toUpperCase(),
                          style: TextStyle(
                            color: _getTypeColor(),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getStatusColor(),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(),
                          color: _getStatusColor(),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          subject.status.toUpperCase(),
                          style: TextStyle(
                            color: _getStatusColor(),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Description
              Text(
                subject.description,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),

              // Footer: Hour Goal and Deadline
              Row(
                children: [
                  // Hour Goal
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.timer,
                            color: Colors.deepPurple,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${subject.hourGoal} hrs',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Text(
                            ' goal',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Deadline
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: subject.deadline == null
                            ? Colors.grey.withOpacity(0.2)
                            : Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: subject.deadline == null
                                ? Colors.grey
                                : Colors.orange,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _formatDeadline(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Progress bar + text
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Progress',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${_formatProgressTime(subject.hoursCompleted)}/${subject.hourGoal} hrs  ($progressPercent%)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        subject.status.toLowerCase() == 'done'
                            ? Colors.green
                            : subject.status.toLowerCase() == 'late'
                                ? Colors.red
                                : Colors.deepPurple,
                      ),
                    ),
                  ),
                ],
              ),

              // Sync Status Indicator
              if (!subject.isSynced)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.cloud_upload,
                        size: 14,
                        color: Colors.orange.shade300,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Pending sync',
                        style: TextStyle(
                          color: Colors.orange.shade300,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
