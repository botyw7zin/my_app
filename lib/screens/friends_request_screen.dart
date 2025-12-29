import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/friends_service.dart';
import '../services/session_service.dart';
import '../services/subject_service.dart';
import '../models/study_session_model.dart';
import '../screens/timer_session_screen.dart';
import '../widgets/background.dart';

class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> {
  final FriendService _friendService = FriendService();
  final SessionService _sessionService = SessionService();
  final SubjectService _subjectService = SubjectService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Container(
            color: const Color(0xFF2C2F3E),
            width: double.infinity,
            height: double.infinity,
          ),
          const GlowyBackground(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Notifications',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Session invites
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: _session_service_sessionsForUserStream(),
                            builder: (context, snap) {
                              if (!snap.hasData) return const SizedBox.shrink();
                              final docs = snap.data!.docs;
                              final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                              final invites = docs
                                  .map((d) => StudySession.fromDoc(d))
                                  .where((s) {
                                    final p = s.participants[uid] as Map<String, dynamic>?;
                                    return p != null && (p['status'] as String?) == 'invited';
                                  })
                                  .toList();

                              if (invites.isEmpty) return const SizedBox.shrink();

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: 8),
                                  const Text('Session Invites', style: TextStyle(color: Colors.white70, fontSize: 14)),
                                  const SizedBox(height: 8),
                                  ...invites.map((s) {
                                    final ownerInfo = (s.participants[s.ownerId] as Map<String, dynamic>?) ?? {};
                                    final ownerName = (ownerInfo['displayName'] as String?) ?? s.ownerId;
                                    final ownerPhoto = ownerInfo['photoURL'] as String?;

                                    return Card(
                                      color: const Color(0xFF363A4D).withOpacity(0.9),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      margin: const EdgeInsets.only(bottom: 12),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: const Color(0xFF7550FF),
                                          backgroundImage: (ownerPhoto != null && ownerPhoto.startsWith('http'))
                                              ? NetworkImage(ownerPhoto)
                                              : const AssetImage('assets/images/cat.png') as ImageProvider,
                                        ),
                                        title: Text('$ownerName invited you', style: const TextStyle(color: Colors.white)),
                                        subtitle: Text('Session Invite — Participants: ${s.participantIds.length}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                        trailing: Wrap(
                                          spacing: 6,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.close, color: Colors.red),
                                              onPressed: () async {
                                                try {
                                                  await _session_service_leaveSession(s.id);
                                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Declined invitation')));
                                                } catch (e) {
                                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to decline: $e')));
                                                }
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.check, color: Colors.green),
                                              onPressed: () async {
                                                final subjects = _subject_service_getAll();
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
                                                            children: subjects.map((s2) {
                                                              return RadioListTile<String>(
                                                                value: s2.id,
                                                                groupValue: selectedId,
                                                                title: Text(s2.name, style: const TextStyle(color: Colors.white)),
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
                                                  // Re-fetch session before joining to ensure it's still joinable
                                                  final sessSnap = await _sessionService.sessionStream(s.id).first;
                                                  final raw = await FirebaseFirestore.instance.collection('studySessions').doc(s.id).get();
                                                  final data = raw.data() ?? {};
                                                  final ownerLeft = data['ownerLeft'] as bool? ?? false;
                                                  final status = (data['status'] ?? 'active') as String;
                                                  if (ownerLeft || status != 'active') {
                                                    if (!mounted) return;
                                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot join — the session owner has left or the session is closed')));
                                                    return;
                                                  }

                                                  await _session_service_joinSession(s.id, chosen);
                                                  if (!mounted) return;
                                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Joined session')));
                                                  final subj = _subjectService.getAllSubjects().firstWhere((x) => x.id == chosen);
                                                  if (!mounted) return;
                                                  Navigator.push(context, MaterialPageRoute(builder: (_) => TimerSessionScreen(subject: subj, sessionId: s.id, startFromZero: true)));
                                                } catch (e) {
                                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to join: $e')));
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ],
                              );
                            },
                          ),

                          const SizedBox(height: 12),

                          // Friend requests
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: _friendService.incomingRequestsStream(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(color: Color(0xFF7550FF)),
                                );
                              }

                              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                return const Center(
                                  child: Text(
                                    'No friend requests',
                                    style: TextStyle(color: Colors.white70, fontSize: 16),
                                  ),
                                );
                              }

                              final docs = snapshot.data!.docs;

                              return ListView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: docs.length,
                                itemBuilder: (context, index) {
                                  final doc = docs[index];
                                  final data = doc.data();
                                  final requestId = doc.id;
                                  final fromUserId = data['fromUserId'] as String;
                                  final fromDisplayName = (data['fromDisplayName'] ?? '') as String;
                                  final fromPhotoURL = data['fromPhotoURL'] as String?;

                                  return Card(
                                    color: const Color(0xFF363A4D).withOpacity(0.9),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: const Color(0xFF7550FF),
                                        backgroundImage: (fromPhotoURL != null && fromPhotoURL.startsWith('http'))
                                            ? NetworkImage(fromPhotoURL)
                                            : const AssetImage('assets/images/cat.png') as ImageProvider,
                                      ),
                                      title: Text(
                                        fromDisplayName.isNotEmpty ? fromDisplayName : 'Friend request',
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                      subtitle: Text(
                                        'From: ${fromDisplayName.isNotEmpty ? fromDisplayName : fromUserId}',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                      trailing: FutureBuilder<bool>(
                                        future: _friendService.isFriend(fromUserId),
                                        builder: (context, snapFriend) {
                                          final alreadyFriend = snapFriend.data == true;

                                          return Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.close, color: Colors.red),
                                                onPressed: () async {
                                                  try {
                                                    await _friendService.rejectFriendRequest(requestId);
                                                    if (mounted) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(content: Text('Request rejected')),
                                                      );
                                                    }
                                                  } catch (e) {
                                                    if (mounted) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(content: Text('Failed to reject: $e')),
                                                      );
                                                    }
                                                  }
                                                },
                                              ),
                                              IconButton(
                                                icon: Icon(Icons.check, color: alreadyFriend ? Colors.grey : Colors.green),
                                                onPressed: alreadyFriend
                                                    ? null
                                                    : () async {
                                                        try {
                                                          await _friendService.acceptFriendRequest(requestId, fromUserId);
                                                          if (mounted) {
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              const SnackBar(content: Text('Friend added')),
                                                            );
                                                          }
                                                        } catch (e) {
                                                          if (mounted) {
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              SnackBar(content: Text('Failed to accept: $e')),
                                                            );
                                                          }
                                                        }
                                                      },
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper wrappers to keep build body readable and allow easier testing/mocking
  List<dynamic> _subject_service_getAll() => _subjectService.getAllSubjects();
  Future<void> _session_service_joinSession(String sessionId, String subjectId) => _sessionService.joinSession(sessionId, subjectId);
  Future<void> _session_service_leaveSession(String sessionId) => _sessionService.leaveSession(sessionId);
  Stream<QuerySnapshot<Map<String, dynamic>>> _session_service_sessionsForUserStream() => _sessionService.sessionsForUserStream();
}