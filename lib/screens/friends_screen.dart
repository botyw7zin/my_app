import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/friends_service.dart';
import '../widgets/base_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final FriendService _friendService = FriendService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = false;
  String _error = '';
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _results = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
          final friendDisplayName =
              (data['friendDisplayName'] ?? '') as String;
          final friendPhotoURL = data['friendPhotoURL'] as String?;

          return Card(
            color: const Color(0xFF363A4D),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF7550FF),
                backgroundImage: (friendPhotoURL != null &&
                        friendPhotoURL.startsWith('http'))
                    ? NetworkImage(friendPhotoURL)
                    : const AssetImage('assets/images/cat.png')
                        as ImageProvider,
              ),
              title: Text(
                friendDisplayName.isNotEmpty
                    ? friendDisplayName
                    : friendUserId,
                style: const TextStyle(color: Colors.white),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.remove_circle, color: Colors.red),
                onPressed: () async {
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
                          onPressed: () =>
                              Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(context, true),
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
      title: 'Friends',
      currentScreen: 'People',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Search bar
            TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by username',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF7550FF)),
                filled: true,
                fillColor: const Color(0xFF363A4D),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _results = [];
                            _error = '';
                          });
                        },
                      )
                    : null,
              ),
              onSubmitted: (_) => _performSearch(),
            ),
            const SizedBox(height: 8),
            if (_error.isNotEmpty)
              Text(
                _error,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: Color(0xFF7550FF)),
              ),
            const SizedBox(height: 8),

            // Search results (if any)
            if (_results.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Search results',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _results.length,
                    itemBuilder: (context, index) =>
                        _buildSearchResultTile(_results[index]),
                  ),
                  const SizedBox(height: 16),
                ],
              ),

            // Friends list
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Your friends',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildFriendsList(),
          ],
        ),
      ),
    );
  }
}
