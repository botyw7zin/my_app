import 'dart:async';
import 'dart:ui'; // Needed for ImageFilter if referenced directly, though Glowy handles it
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Models
import '../models/subject_model.dart';
import '../models/study_session_model.dart';

// Services
import '../services/subject_service.dart';
import '../services/session_service.dart';
import '../services/friends_service.dart';

// Widgets
import '../widgets/custom_button.dart';
import '../widgets/background.dart'; // Import your new GlowyBackground file here

class TimerSessionScreen extends StatefulWidget {
  final Subject subject;
  final String? sessionId;
  final bool startFromZero;

  const TimerSessionScreen({super.key, required this.subject, this.sessionId, this.startFromZero = false});

  @override
  State<TimerSessionScreen> createState() => _TimerSessionScreenState();
}

class _TimerSessionScreenState extends State<TimerSessionScreen> {
  final SubjectService _subjectService = SubjectService();
  final SessionService _sessionService = SessionService();
  final FriendService _friendService = FriendService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _sessionId;
  Timer? _ticker;
  int _elapsedSeconds = 0;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.sessionId != null) {
        try {
          if (widget.startFromZero) {
            // When joining from an invite acceptance, start at 0 seconds.
            if (mounted) {
              setState(() {
                _elapsedSeconds = 0;
                _sessionId = widget.sessionId;
              });
            }
          } else {
            final ss = await _sessionService.sessionStream(widget.sessionId!).first;
            final now = DateTime.now();
            final diff = now.difference(ss.createdAt).inSeconds;
            if (mounted) {
              setState(() {
                _elapsedSeconds = diff > 0 ? diff : 0;
                _sessionId = widget.sessionId;
              });
            }
          }
        } catch (e) {
          debugPrint('>>> [TimerSession] Failed to load existing session: $e');
          if (mounted) setState(() => _sessionId = widget.sessionId);
        }
        _start();
      } else {
        try {
          final id = await _sessionService.createSession(widget.subject.id);
          if (mounted) {
            setState(() {
              _sessionId = id;
            });
          }
        } catch (e) {
          debugPrint('>>> [TimerSession] Failed to create session: $e');
        }
        _start();
      }
    });
  }

  Future<Map<String, dynamic>?> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _start() {
    if (_running) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _elapsedSeconds++;
        });
      }
    });
    setState(() => _running = true);
  }

  void _pause() {
    _ticker?.cancel();
    _ticker = null;
    setState(() => _running = false);
  }

  void _toggleRest() {
    if (_running) {
      _pause();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Timer paused for a break'), duration: Duration(seconds: 1)),
      );
    } else {
      _start();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resuming session'), duration: Duration(seconds: 1)),
      );
    }
  }

  String _fmt(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;

    if (h > 0) {
      return '${h.toString()}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _finishSession() async {
    _pause();
    final minutes = _elapsedSeconds ~/ 60;
    // First, always update session state (close if owner, leave if participant)
    if (_sessionId != null) {
      try {
        final raw = await _firestore.collection('studySessions').doc(_sessionId).get();
        final data = raw.data() ?? {};
        final ownerId = data['ownerId'] as String?;
        final myUid = FirebaseAuth.instance.currentUser?.uid;
        if (ownerId != null && myUid != null && ownerId == myUid) {
          await _sessionService.closeSession(_sessionId!);
        } else {
          await _sessionService.leaveSession(_sessionId!);
        }
      } catch (e) {
        debugPrint('Failed to update session state on finish: $e');
      }
    }

    // If no minutes recorded, just pop (session already closed/left above)
    if (minutes == 0) {
      Navigator.pop(context, false);
      return;
    }

    final addedHours = minutes / 60.0;

    try {
      await _subjectService.addStudyHours(widget.subject, addedHours);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added $minutes min to "${widget.subject.name}"')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    }
  }

  Future<void> _inviteFriend() async {
    if (_sessionId == null) return;

    final subjects = _subjectService.getAllSubjects();

    final selectedMap = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _InviteDialog(
        subjects: subjects,
        friendService: _friendService,
      ),
    );

    if (selectedMap == null) return;

    final selected = (selectedMap['selected'] ?? <String>[]) as List<String>;
    final suggestedId = selectedMap['suggested'] as String?;

    if (selected.isNotEmpty) {
      try {
        await _sessionService.inviteParticipants(
          _sessionId!,
          selected,
          suggestedSubjectId: suggestedId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invitations sent')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to invite: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Replaced BaseScreen with Scaffold + Stack + GlowyBackground
    return Scaffold(
      backgroundColor: const Color(0xFF1F2232), // Solid dark background base
      body: Stack(
        children: [
          // 1. The Glowy Background
          const GlowyBackground(),

          // 2. The Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // --- Header ---
                  FutureBuilder<Map<String, dynamic>?>(
                    future: _loadProfile(),
                    builder: (context, snapshot) {
                      final data = snapshot.data ?? {};
                      final displayName = (data['displayName'] ?? 'User') as String;
                      final photoURL = data['photoURL'] as String?;

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: const Color(0xFF7550FF),
                                backgroundImage: (photoURL != null && photoURL.startsWith('http'))
                                    ? NetworkImage(photoURL)
                                    : const AssetImage('assets/images/cat.png') as ImageProvider,
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Hello!",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  Text(
                                    displayName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: () => _finishSession(),
                            icon: const Icon(Icons.close, color: Colors.white, size: 28),
                          )
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 30),

                  // --- Subject Title ---
                  const Text(
                    'Concentration Session:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19, // Slightly smaller label
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subject.name.toLowerCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26, // Larger subject name
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // --- Timer Box ---
                  // Added a backdrop filter or opacity to make timer readable over glow
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    decoration: BoxDecoration(
                      color: const Color(0xFF363A4D).withOpacity(0.8), // Slightly transparent
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Center(
                      child: Text(
                        _fmt(_elapsedSeconds),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 64,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                          fontFeatures: [FontFeature.tabularFigures()], // Keeps numbers from jumping
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // --- Buttons ---
                  CustomButton(
                    text: "ask a friend to join",
                    onPressed: _inviteFriend,
                    backgroundColor: const Color(0xFF7550FF),
                    width: double.infinity,
                    height: 55,
                    fontSize: 18,
                  ),

                  const SizedBox(height: 16),

                  CustomButton(
                    text: _running ? "take a short rest" : "resume session",
                    onPressed: _toggleRest,
                    backgroundColor: _running ? const Color(0xFF7550FF) : Colors.orange,
                    width: double.infinity,
                    height: 55,
                    fontSize: 18,
                  ),

                  const SizedBox(height: 30),

                  // --- Participants List ---
                  Expanded(
                    child: _sessionId == null
                        ? const SizedBox.shrink()
                        : StreamBuilder<StudySession>(
                            stream: _sessionService.sessionStream(_sessionId!),
                            builder: (context, snap) {
                              if (!snap.hasData) return const SizedBox.shrink();

                              final ss = snap.data!;
                              final currentUid = FirebaseAuth.instance.currentUser?.uid;
                              final entries = ss.participants.entries
                                  .where((entry) {
                                    if (entry.key == currentUid) return false;
                                    final info = entry.value as Map<String, dynamic>?;
                                    if (info == null) return false;
                                    final status = (info['status'] ?? '') as String;
                                    return status == 'joined';
                                  })
                                  .toList();

                              if (entries.isEmpty) {
                                return const SizedBox.shrink();
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Align(
                                    alignment: Alignment.center,
                                    child: Text(
                                      "look who's here too",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w400),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Expanded(
                                    child: ListView.separated(
                                      itemCount: entries.length,
                                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                                      itemBuilder: (context, index) {
                                        final info = Map<String, dynamic>.from(entries[index].value ?? {});
                                        final name = info['displayName'] as String? ?? 'Friend';
                                        final photo = info['photoURL'] as String?;

                                        return Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.95),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: ListTile(
                                            leading: CircleAvatar(
                                              radius: 20,
                                              backgroundColor: Colors.grey[300],
                                              backgroundImage: (photo != null && photo.startsWith('http'))
                                                  ? NetworkImage(photo)
                                                  : const AssetImage('assets/images/cat.png') as ImageProvider,
                                            ),
                                            title: Text(
                                              name.toLowerCase(),
                                              style: const TextStyle(
                                                color: Colors.black,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Invite Dialog (Kept exactly as you had it) ---
class _InviteDialog extends StatefulWidget {
  final List<Subject> subjects;
  final FriendService friendService;

  const _InviteDialog({required this.subjects, required this.friendService});

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  final Set<String> _toSelect = {};
  String? _suggestedSubjectId;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF363A4D),
      title: const Text('Invite Friends', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: Column(
          children: [
            DropdownButton<String?>(
              value: _suggestedSubjectId,
              dropdownColor: const Color(0xFF363A4D),
              isExpanded: true,
              hint: const Text('Suggested subject (optional)', style: TextStyle(color: Colors.white70)),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('No suggestion', style: TextStyle(color: Colors.white70))),
                ...widget.subjects.map((s) => DropdownMenuItem<String?>(
                    value: s.id, child: Text(s.name, style: const TextStyle(color: Colors.white)))),
              ],
              onChanged: (v) => setState(() => _suggestedSubjectId = v),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: widget.friendService.friendsStream(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const Center(child: Text('No friends found', style: TextStyle(color: Colors.white70)));
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final d = docs[index].data();
                      final fid = docs[index].id;
                      final fname = (d['friendDisplayName'] ?? fid) as String;
                      final selectedFlag = _toSelect.contains(fid);

                      return ListTile(
                        title: Text(fname, style: const TextStyle(color: Colors.white)),
                        trailing: Checkbox(
                          value: selectedFlag,
                          activeColor: const Color(0xFF7550FF),
                          side: const BorderSide(color: Colors.white54),
                          onChanged: (v) {
                            if (v == true) {
                              _toSelect.add(fid);
                            } else {
                              _toSelect.remove(fid);
                            }
                            setState(() {});
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
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70))),
        ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7550FF)),
            onPressed: () =>
                Navigator.pop(context, {'selected': _toSelect.toList(), 'suggested': _suggestedSubjectId}),
            child: const Text('Invite', style: TextStyle(color: Colors.white))),
      ],
    );
  }
}