import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/friends_service.dart';

class FriendsSearchScreen extends StatefulWidget {
  const FriendsSearchScreen({super.key});

  @override
  State<FriendsSearchScreen> createState() => _FriendsSearchScreenState();
}

class _FriendsSearchScreenState extends State<FriendsSearchScreen> {
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
      await _friendService.sendFriendRequest(userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Friend request sent'),
          backgroundColor: Colors.green,
        ),
      );
      await _performSearch(); // refresh statuses
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildResultTile(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
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
          color = Colors.deepPurple;
        } else {
          label = 'Add friend';
          enabled = true;
          color = Colors.deepPurple;
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
              backgroundColor: Colors.deepPurple,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C2F3E),
      appBar: AppBar(
        title: const Text('Find Friends'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by username',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.deepPurple),
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
          ),
          const SizedBox(height: 8),
          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _error,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: Colors.deepPurple),
            ),
          Expanded(
            child: _results.isEmpty && !_isLoading && _error.isEmpty
                ? const Center(
                    child: Text(
                      'Search for friends by username',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _results.length,
                    itemBuilder: (context, index) => _buildResultTile(_results[index]),
                  ),
          ),
        ],
      ),
    );
  }
}
