import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../widgets/base_screen.dart';
import '../services/auth_service.dart';
import 'friends_request_screen.dart';
import 'incoming_sessions_screen.dart';
import 'user_settings_screen.dart';
import '../services/subject_service.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final AuthService _authService = AuthService();
  final SubjectService _subjectService = SubjectService();
  bool _isSyncing = false;

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

  Future<void> _syncNow() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      await _subjectService.syncBothWays();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync completed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  // User settings are opened via the avatar tap; no extra helpers required.

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: '',
      currentScreen: 'Home',
      appBarColor: const Color(0xFF2C2F3E),
      automaticallyImplyLeading: false,
      showAppBar: false, // 1. Hide the AppBar
      
      body: Padding(
        padding: const EdgeInsets.all(16), // 2. Standard padding is now safe
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            ValueListenableBuilder(
              valueListenable: Hive.box('userBox').listenable(),
              builder: (context, Box box, _) {
                final displayName = (box.get('displayName') ?? '') as String;
                final photoURL =
                    (box.get('photoURL') ?? 'assets/images/cat.png') as String;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Profile picture (tappable -> settings)
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const UserSettingsScreen()),
                        );
                      },
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFF7550FF),
                        backgroundImage: (photoURL.startsWith('http'))
                            ? NetworkImage(photoURL)
                            : const AssetImage('assets/images/cat.png') as ImageProvider,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Name Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Hello!',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          Text(
                            displayName.isNotEmpty ? displayName : 'User',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // --- ICON 1: Notifications ---
                    IconButton(
                      icon: const Icon(Icons.notifications, color: Colors.white),
                      iconSize: 28,
                      tooltip: 'Friend Requests',
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FriendRequestsScreen(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(width: 8),

                    // --- ICON 2: Sign Out ---
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      iconSize: 28,
                      tooltip: 'Sign Out',
                      constraints: const BoxConstraints(),
                      onPressed: () async {
                        final shouldLogout = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: const Color(0xFF363A4D),
                            title: const Text('Sign Out',
                                style: TextStyle(color: Colors.white)),
                            content: const Text(
                              'Are you sure you want to sign out?',
                              style: TextStyle(color: Colors.white70),
                            ),
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
    );
  }
}