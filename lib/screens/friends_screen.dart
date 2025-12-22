import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/friends_service.dart';
import '../widgets/base_screen.dart';
import 'friends_request_screen.dart'; // Add this line

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final FriendService _friendService = FriendService();
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  String _error = '';
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _results = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _error = '';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final docs = await _friendService.searchUsersByUsername(query);
      setState(() {
        _results = docs;
      });
    } catch (e) {
      setState(() {
        _error = 'Error searching users: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendRequest(String userId) async {
    try {
      print('>>> _sendRequest to: $userId, auth uid: ${FirebaseAuth.instance.currentUser?.uid}');
      await _friendService.sendFriendRequest(userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Friend request sent'),
          backgroundColor: Colors.green,
        ),
      );
      await _performSearch();
    } catch (e, st) {
      print('>>> _sendRequest error: $e');
      print(st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSearchResultTile(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final userId = doc.id;
    final username = (data['displayName'] ?? '') as String;
    final email = (data['email'] ?? '') as String?;
    final photoURL = data['photoURL'] as String?;

    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        _friendService.isFriend(userId),
        _friendService.existingRequestStatus(userId),
      ]),
      builder: (context, snapshot) {
        final isFriend = snapshot.hasData ? snapshot.data![0] as bool : false;
        final requestStatus = snapshot.hasData ? snapshot.data![1] as String? : null;

        String label;
        bool enabled;
        Color color;

        if (isFriend) {
          label = 'Friends';
          enabled = false;
          color = Colors.grey;
        } else if (requestStatus == 'pending') {
          label = 'Requested';
          enabled = false;
          color = Colors.orange;
        } else if (requestStatus == 'rejected') {
          label = 'Request again';
          enabled = true;
          color = const Color(0xFF7550FF);
        } else {
          label = 'Add friend';
          enabled = true;
          color = const Color(0xFF7550FF);
        }

        final loadingState = snapshot.connectionState == ConnectionState.waiting;

        return Card(
          color: const Color(0xFF363A4D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF7550FF),
              backgroundImage: (photoURL != null && photoURL.startsWith('http'))
                  ? NetworkImage(photoURL)
                  : null,
              child: (photoURL == null || !photoURL.startsWith('http'))
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),
            title: Text(
              username.isNotEmpty ? username : userId,
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: email != null
                ? Text(
                    email,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  )
                : null,
            trailing: ElevatedButton(
              onPressed: enabled && !loadingState ? () => _sendRequest(userId) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: loadingState
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      label,
                      style: const TextStyle(fontSize: 12),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFriendsList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _friendService.friendsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF7550FF)),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No friends yet',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final friendUserId = data['friendUserId'] as String;
            final friendDisplayName = (data['friendDisplayName'] ?? '') as String;
            final friendPhotoURL = data['friendPhotoURL'] as String?;

            return InkWell(
              onTap: () {
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
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF7550FF),
                            backgroundImage: (friendPhotoURL != null && friendPhotoURL.startsWith('http'))
                                ? NetworkImage(friendPhotoURL)
                                : const AssetImage('assets/images/cat.png') as ImageProvider,
                          ),
                          title: Text(
                            friendDisplayName.isNotEmpty ? friendDisplayName : friendUserId,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Divider(color: Colors.white24),
                        ListTile(
                          leading: const Icon(Icons.remove_circle, color: Colors.red),
                          title: const Text('Remove Friend', style: TextStyle(color: Colors.white)),
                          onTap: () async {
                            Navigator.pop(context);
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: const Color(0xFF363A4D),
                                title: const Text(
                                  'Remove Friend',
                                  style: TextStyle(color: Colors.white),
                                ),
                                content: Text(
                                  'Remove ${friendDisplayName.isNotEmpty ? friendDisplayName : friendUserId} from your friends?',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text(
                                      'Remove',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await _friendService.removeFriend(friendUserId);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
              splashColor: const Color(0xFF7550FF).withOpacity(0.3),
              highlightColor: const Color(0xFF7550FF).withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFF7550FF),
                      backgroundImage: (friendPhotoURL != null && friendPhotoURL.startsWith('http'))
                          ? NetworkImage(friendPhotoURL)
                          : const AssetImage('assets/images/cat.png') as ImageProvider,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        friendDisplayName.isNotEmpty ? friendDisplayName : friendUserId,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: '',
      currentScreen: 'People',
      appBarColor: const Color(0xFF2C2F3E),
      showAppBar: false, // Hide the default purple bar
      automaticallyImplyLeading: false,
      body: Column(
        children: [
          // 1. HEADER (Profile + Hello + Notification Icon)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: FutureBuilder<Map<String, dynamic>?>(
              future: _loadProfile(),
              builder: (context, snapshot) {
                final data = snapshot.data ?? {};
                final displayName = (data['displayName'] ?? '') as String;
                final photoURL = data['photoURL'] as String?;

                return Row(
                  children: [
                    // Profile Picture
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFF7550FF),
                      backgroundImage: (photoURL != null && photoURL.startsWith('http'))
                          ? NetworkImage(photoURL)
                          : const AssetImage('assets/images/cat.png') as ImageProvider,
                    ),
                    const SizedBox(width: 12),
                    // "Hello! Name" Text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Hello!',
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          Text(
                            displayName.isNotEmpty ? displayName : 'User',
                            style: const TextStyle(
                              color: Colors.white, 
                              fontSize: 20, 
                              fontWeight: FontWeight.bold
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Notification Icon (Top Right)
                    IconButton(
                      icon: const Icon(Icons.notifications, color: Colors.white, size: 28),
                      onPressed: () {
                         // Navigate to friend requests
                         Navigator.push(context, MaterialPageRoute(builder: (_) => const FriendRequestsScreen()));
                      },
                    ),
                  ],
                );
              },
            ),
          ),

          // 2. SEARCH SECTION ("Invite a friend")
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 4.0, bottom: 8.0),
                  child: Text(
                    'invite a friend',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    hintText: 'friend username',
                    hintStyle: const TextStyle(color: Colors.grey),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, color: Colors.black, size: 16),
                      onPressed: _performSearch,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _performSearch(),
                ),
              ],
            ),
          ),

          // 3. SEARCH RESULTS or FRIENDS LIST
          if (_isLoading)
             const Padding(
               padding: EdgeInsets.all(30),
               child: Center(child: CircularProgressIndicator(color: Color(0xFF7550FF))),
             ),
          
          if (_error.isNotEmpty)
             Padding(
               padding: const EdgeInsets.all(16.0),
               child: Text(_error, style: const TextStyle(color: Colors.redAccent)),
             ),

          // Conditional List Rendering
          if (_results.isNotEmpty)
            // Show Search Results
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    const Text('Search Results', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, index) => _buildSearchResultTile(_results[index]),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            // Show Your Friends List
            Expanded(
              child: Column(
                children: [
                  const SizedBox(height: 30),
                  // "Your Friends" Title
                  const Center(
                    child: Text(
                      'Your Friends',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // The List
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildFriendsList(),
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