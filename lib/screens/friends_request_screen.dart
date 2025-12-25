import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/friends_service.dart';
import '../widgets/background.dart'; 

class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> {
  final FriendService _friendService = FriendService();

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

                // --- REQUESTS LIST ---
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
                        padding: const EdgeInsets.symmetric(horizontal: 16),
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}