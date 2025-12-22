import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/session_service.dart';
import '../services/subject_service.dart';
import '../models/study_session_model.dart';

class IncomingSessionsScreen extends StatefulWidget {
  const IncomingSessionsScreen({super.key});

  @override
  State<IncomingSessionsScreen> createState() => _IncomingSessionsScreenState();
}

class _IncomingSessionsScreenState extends State<IncomingSessionsScreen> {
  final SessionService _sessionService = SessionService();
  final SubjectService _subjectService = SubjectService();

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<void> _accept(StudySession session) async {
    final subjects = _subjectService.getAllSubjects();
    if (subjects.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You need at least one subject to join')));
      return;
    }

    String? selectedId = subjects.first.id;

    final chosen = await showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF363A4D),
          title: const Text('Select Subject', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: double.maxFinite,
            child: StatefulBuilder(builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: subjects.map((s) {
                  return RadioListTile<String>(
                    value: s.id,
                    groupValue: selectedId,
                    title: Text(s.name, style: const TextStyle(color: Colors.white)),
                    onChanged: (v) => setState(() => selectedId = v),
                    activeColor: Colors.white,
                  );
                }).toList(),
              );
            }),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(context, selectedId), child: const Text('Join')),
          ],
        );
      },
    );

    if (chosen == null) return;

    try {
      await _sessionService.joinSession(session.id, chosen);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Joined session')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to join: $e')));
    }
  }

  Future<void> _decline(StudySession session) async {
    try {
      await _sessionService.leaveSession(session.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Declined invitation')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to decline: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Invitations'),
        backgroundColor: const Color(0xFF2C2F3E),
      ),
      backgroundColor: const Color(0xFF1F2130),
      body: StreamBuilder(
        stream: _sessionService.sessionsForUserStream(),
        builder: (context, AsyncSnapshot snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = (snapshot.data as dynamic).docs as List;
          final sessions = docs.map((d) => StudySession.fromDoc(d)).where((s) {
            final p = s.participants[_uid] as Map<String, dynamic>?;
            return p != null && (p['status'] as String?) == 'invited';
          }).toList();

          if (sessions.isEmpty) {
            return const Center(child: Text('No invitations', style: TextStyle(color: Colors.white70)));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: sessions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final s = sessions[index];
              return Card(
                color: const Color(0xFF2C2F3E),
                child: ListTile(
                  title: Text('Session by ${s.ownerId}', style: const TextStyle(color: Colors.white)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Text('Created: ${s.createdAt.toLocal().toString()}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      Text('Participants: ${s.participantIds.length}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                  trailing: Wrap(
                    spacing: 6,
                    children: [
                      TextButton(onPressed: () => _decline(s), child: const Text('Decline')),
                      ElevatedButton(onPressed: () => _accept(s), child: const Text('Accept')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
