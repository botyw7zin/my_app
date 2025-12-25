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
      // We set the scaffold background to transparent because we are handling
      // the background color and the glow inside the Stack below.
      backgroundColor: Colors.transparent, 
      body: Stack(
        children: [
          // 1. Solid Dark Base Layer
          Container(
            color: const Color(0xFF2C2F3E),
            width: double.infinity,
            height: double.infinity,
          ),

          // 2. The Glowy Splotches Layer
          const GlowyBackground(),

          // 3. The Content Layer (Header + List)
          SafeArea(
            child: Column(
              children: [
                // --- CUSTOM HEADER (Back Button + Title) ---
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

                // --- INVITES + REQUESTS LIST ---
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // --- SESSION INVITES ---
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: _sessionService.sessionsForUserStream(),
                            builder: (context, snap) {
                              if (!snap.hasData) return const SizedBox.shrink();
                              final docs = snap.data!.docs;
                              final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                              final invites = docs.map((d) => StudySession.fromDoc(d)).where((s) {
                                final p = s.participants[uid] as Map<String, dynamic>?;
                                return p != null && (p['status'] as String?) == 'invited';
                              }).toList();

                              if (invites.isEmpty) return const SizedBox.shrink();

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: 8),
                                  const Text('Session Invites', style: TextStyle(color: Colors.white70, fontSize: 14)),
                                  const SizedBox(height: 8),
                                  ...invites.map((s) {
                                    return Card(
                                      color: const Color(0xFF363A4D).withOpacity(0.9),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      margin: const EdgeInsets.only(bottom: 12),
                                      child: ListTile(
                                        title: Text('Session by ${s.ownerId}', style: const TextStyle(color: Colors.white)),
                                        subtitle: Text('Participants: ${s.participantIds.length}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                        trailing: Wrap(
                                          spacing: 6,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.close, color: Colors.red),
                                              onPressed: () async {
                                                try {
                                                  await _sessionService.leaveSession(s.id);
                                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Declined invitation')));
                                                } catch (e) {
                                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to decline: $e')));
                                                }
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.check, color: Colors.green),
                                              onPressed: () async {
                                                // Choose a subject then join
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
                                                  await _sessionService.joinSession(s.id, chosen);
                                                  if (!mounted) return;
                                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Joined session')));
                                                  // Navigate to timer, joining existing session (pass sessionId)
                                                  final subj = _subjectService.getAllSubjects().firstWhere((x) => x.id == chosen);
                                                  if (!mounted) return;
                                                  Navigator.push(context, MaterialPageRoute(builder: (_) => TimerSessionScreen(subject: subj, sessionId: s.id)));
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

                          const SizedBox(height: 6),

                          // --- FRIEND REQUESTS ---
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
                                    // Make card slightly transparent to let the glow show through a bit
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
                                              // Reject Button
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
                                              // Accept Button
                                              IconButton(
                                                icon: Icon(Icons.check,
                                                    color: alreadyFriend ? Colors.grey : Colors.green),
                                                onPressed: alreadyFriend
                                                    ? null
                                                    : () async {
                                                        try {
                                                          await _friendService.acceptFriendRequest(
                                                            requestId,
                                                            fromUserId,
                                                          );
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
}