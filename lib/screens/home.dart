import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'Home',
      currentScreen: 'Home',
      body: const Center(
        child: Text(
          'Welcome to StudySync!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
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
