import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/subject_model.dart';
import '../models/study_session_model.dart';
import '../services/subject_service.dart';
import '../services/session_service.dart';
import '../services/friends_service.dart';

class TimerSessionScreen extends StatefulWidget {
  final Subject subject;

  const TimerSessionScreen({super.key, required this.subject});

  @override
  State<TimerSessionScreen> createState() => _TimerSessionScreenState();
}

class _TimerSessionScreenState extends State<TimerSessionScreen> {
  final SubjectService _subjectService = SubjectService();

  final SessionService _sessionService = SessionService();
  final FriendService _friendService = FriendService();

  String? _sessionId;

  Timer? _ticker;
  int _elapsedSeconds = 0;
  bool _running = false;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _start() {
    if (_running) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsedSeconds++;
      });
    });
    setState(() => _running = true);
  }

  void _pause() {
    _ticker?.cancel();
    _ticker = null;
    setState(() => _running = false);
  }

  void _reset() {
    _pause();
    setState(() => _elapsedSeconds = 0);
  }

  @override
  void initState() {
    super.initState();
    // start automatically when the page opens
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _start();
      try {
        final id = await _sessionService.createSession(widget.subject.id);
        setState(() {
          _sessionId = id;
        });
      } catch (e) {
        print('>>> [TimerSession] Failed to create session: $e');
      }
    });
  }

  String _fmt(int seconds) {
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Future<void> _finishSession() async {
    _pause();
    final minutes = _elapsedSeconds ~/ 60; // integer minutes
    if (minutes == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session was less than 1 minute — nothing added.')));
      Navigator.pop(context, false);
      return;
    }

    final addedHours = minutes / 60.0; // fractional hours based on minutes

    try {
      await _subjectService.addStudyHours(widget.subject, addedHours);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added $minutes minute(s) (${addedHours.toStringAsFixed(2)} hrs) to "${widget.subject.name}"')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add study time: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final subject = widget.subject;

    return Scaffold(
      appBar: AppBar(
        title: Text('Timer — ${subject.name}'),
        backgroundColor: const Color(0xFF2C2F3E),
      ),
      backgroundColor: const Color(0xFF1F2130),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Text(
              subject.name,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              subject.description,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 24),
            // Participants area
            if (_sessionId != null)
              StreamBuilder<StudySession>(
                stream: _sessionService.sessionStream(_sessionId!),
                builder: (context, snap) {
                  if (!snap.hasData) return const SizedBox.shrink();
                  final ss = snap.data!;
                  final entries = ss.participants.entries.toList();
                  final allSubjects = _subjectService.getAllSubjects();
                  final subjectMap = {for (var s in allSubjects) s.id: s.name};
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Participants', style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 120,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: entries.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final uid = entries[index].key;
                            final info = Map<String, dynamic>.from(entries[index].value ?? {});
                            final dn = info['displayName'] as String?;
                            final status = info['status'] as String? ?? 'invited';
                            final selected = info['selectedSubjectId'] as String?;

                            final name = (dn != null && dn.isNotEmpty)
                                ? dn
                                : (uid == FirebaseAuth.instance.currentUser?.uid ? 'You' : 'Friend');

                            String? photo = info['photoURL'] as String?;
                            if (photo == null && uid == FirebaseAuth.instance.currentUser?.uid) {
                              try {
                                final box = Hive.box('userBox');
                                photo = box.get('photoURL') as String?;
                              } catch (_) {}
                            }

                            final effectiveImage = (photo != null && photo.startsWith('http')) ? NetworkImage(photo) : const AssetImage('assets/images/cat.png');

                            return Container(
                              width: 200,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: Colors.deepPurple,
                                        backgroundImage: effectiveImage as ImageProvider,
                                        radius: 26,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text('Status: $status', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                  Text('Subject: ${selected != null ? (subjectMap[selected] ?? 'Unknown subject') : 'Not selected'}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  );
                },
              ),
            const SizedBox(height: 8),
            // Invite friends button
            if (_sessionId != null)
              ElevatedButton.icon(
                onPressed: () async {
                  final subjects = _subjectService.getAllSubjects();
                  final selectedMap = await showDialog<Map<String, dynamic>>(
                    context: context,
                    builder: (context) {
                      final toSelect = <String>{};
                      String? suggestedSubjectId;
                      return StatefulBuilder(builder: (context, setState) {
                        return AlertDialog(
                          backgroundColor: const Color(0xFF363A4D),
                          title: const Text('Invite Friends', style: TextStyle(color: Colors.white)),
                          content: SizedBox(
                            width: double.maxFinite,
                            height: 360,
                            child: Column(
                              children: [
                                // Optional suggested subject for all invites
                                DropdownButton<String?>(
                                  value: suggestedSubjectId,
                                  dropdownColor: const Color(0xFF363A4D),
                                  hint: const Text('Suggested subject (optional)', style: TextStyle(color: Colors.white70)),
                                  items: [
                                    const DropdownMenuItem<String?>(value: null, child: Text('No suggestion', style: TextStyle(color: Colors.white70))),
                                    ...subjects.map((s) => DropdownMenuItem<String?>(value: s.id, child: Text(s.name, style: const TextStyle(color: Colors.white)))),
                                  ],
                                  onChanged: (v) => setState(() => suggestedSubjectId = v),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
                                    stream: _friendService.friendsStream(),
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                                      final docs = snapshot.data!.docs;
                                      if (docs.isEmpty) return const Center(child: Text('No friends', style: TextStyle(color: Colors.white70)));
                                      return ListView.builder(
                                        itemCount: docs.length,
                                        itemBuilder: (context, index) {
                                          final d = docs[index].data();
                                          final fid = docs[index].id;
                                          final fname = (d['friendDisplayName'] ?? fid) as String;
                                          final fphoto = d['friendPhotoURL'] as String?;
                                          final selectedFlag = toSelect.contains(fid);
                                          return ListTile(
                                            leading: CircleAvatar(backgroundImage: (fphoto != null && fphoto.startsWith('http')) ? NetworkImage(fphoto) : null, backgroundColor: Colors.deepPurple),
                                            title: Text(fname, style: const TextStyle(color: Colors.white)),
                                            trailing: Checkbox(value: selectedFlag, onChanged: (v) { if (v==true) toSelect.add(fid); else toSelect.remove(fid); setState(() {}); }),
                                            onTap: () { if (toSelect.contains(fid)) toSelect.remove(fid); else toSelect.add(fid); setState(() {}); },
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, <String, dynamic>{}), child: const Text('Cancel')),
                            ElevatedButton(onPressed: () => Navigator.pop(context, {'selected': toSelect.toList(), 'suggested': suggestedSubjectId}), child: const Text('Invite')),
                          ],
                        );
                      });
                    },
                  );

                  final selected = (selectedMap?['selected'] ?? <String>[]) as List<String>;
                  final suggestedId = selectedMap?['suggested'] as String?;
                  final subjectMapForInvite = {for (var s in subjects) s.id: s.name};
                  final suggestedName = suggestedId == null ? null : subjectMapForInvite[suggestedId];

                  if (selected.isNotEmpty) {
                    try {
                      await _sessionService.inviteParticipants(_sessionId!, selected, suggestedSubjectId: suggestedId, suggestedSubjectName: suggestedName);
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invitations sent')));
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to invite: $e')));
                    }
                  }
                },
                icon: const Icon(Icons.person_add),
                label: const Text('Invite Friends'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7550FF)),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: Center(
                child: Text(
                  _fmt(_elapsedSeconds),
                  style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            // Pause / Resume button
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _running ? _pause : _start,
                  icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                  label: Text(_running ? 'Pause' : 'Resume'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _running ? Colors.orange : const Color(0xFF7550FF),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Big Finish Session button
            ElevatedButton(
              onPressed: _elapsedSeconds <= 0 ? null : _finishSession,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text('Finish Session', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
