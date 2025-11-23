import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/nav_components.dart';
import '../widgets/background.dart';
import '../services/auth_service.dart';
import 'add_subject.dart';
import 'subject_list_screen.dart';
import 'friends_screen.dart';
import 'friends_request_screen.dart'; // <-- import your requests screen

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final AuthService _authService = AuthService();

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

  void _navigateToAddSubject() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddSubjectScreen()),
    );
  }

  void _handleNavigation(String label) {
    print('>>> [Home] Navigation tapped: $label');

    switch (label) {
      case 'Home':
        break;
      case 'Calendar':
        _show('Calendar coming soon!');
        break;
      case 'Documents':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SubjectsListScreen(),
          ),
        );
        break;
      case 'People':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const FriendsScreen(),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C2F3E),
      appBar: AppBar(
        title: const Text('Home'),
        backgroundColor: Colors.deepPurple,
        actions: [
          // Friend requests button
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
          // Sign out button
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
      ),
      body: Stack(
        children: [
          const GlowyBackground(),
          const Center(
            child: Text(
              'test!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: NavComponents.buildFAB(_navigateToAddSubject),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: NavComponents.buildBottomBar(_handleNavigation),
    );
  }
}
