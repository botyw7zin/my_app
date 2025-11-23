import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/base_screen.dart';
import '../services/auth_service.dart';
import 'friends_request_screen.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _show(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _signOut() async {
    try {
      await _authService.signOut(context);
    } catch (e) {
      _show('Sign out failed: $e');
    }
  }

  Future<Map<String, dynamic>?> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  void _openUserSettings() {
    _show('Settings coming soon');
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'Home',
      currentScreen: 'Home',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<Map<String, dynamic>?>(
              future: _loadProfile(),
              builder: (context, snapshot) {
                final data = snapshot.data ?? {};
                final displayName = (data['displayName'] ?? '') as String;
                final photoURL = data['photoURL'] as String?;

                return InkWell(
                  onTap: _openUserSettings,
                  borderRadius: BorderRadius.circular(24),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFF7550FF),
                        backgroundImage: (photoURL != null &&
                                photoURL.startsWith('http'))
                            ? NetworkImage(photoURL)
                            : const AssetImage('assets/images/cat.png')
                                as ImageProvider,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        displayName.isNotEmpty ? displayName : 'User',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Expanded(
              child: Center(
                child: Text(
                  'Welcome to StudySync!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications),
          tooltip: 'Friend Requests',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const FriendRequestsScreen(),
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Sign Out',
          onPressed: () async {
            final shouldLogout = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Sign Out'),
                content: const Text('Are you sure you want to sign out?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      'Sign Out',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            );

            if (shouldLogout == true && mounted) {
              _signOut();
            }
          },
        ),
      ],
    );
  }
}
