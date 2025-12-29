import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../widgets/base_screen.dart';
import '../widgets/notification_icon.dart';
import '../services/auth_service.dart';
import 'friends_request_screen.dart';
import 'incoming_sessions_screen.dart';
import 'user_settings_screen.dart';
import '../services/subject_service.dart';
import '../services/friends_service.dart';
import '../services/session_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final AuthService _authService = AuthService();
  final SubjectService _subjectService = SubjectService();
  bool _isSyncing = false;
  final FriendService _friendService = FriendService();
  final SessionService _sessionService = SessionService();
  bool _hasNotifications = false;
  bool _hasFriendRequests = false;
  bool _hasSessionInvites = false;
  StreamSubscription? _friendSub;
  StreamSubscription? _sessionSub;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    // Listen for incoming friend requests
    _friendSub = _friendService.incomingRequestsStream().listen((snap) {
      final hasFriend = snap.docs.isNotEmpty;
      if (mounted) {
        setState(() {
          _hasFriendRequests = hasFriend;
          _hasNotifications = _hasFriendRequests || _hasSessionInvites;
        });
      }
    });

    // Listen for session invites for this user
    _sessionSub = _sessionService.sessionsForUserStream().listen((snap) {
      bool hasInvite = false;
      final uidLocal = uid;
      for (final doc in snap.docs) {
        final data = doc.data();
        if (data == null) continue;
        final participants = data['participants'] as Map<String, dynamic>?;
        if (participants != null && uidLocal != null) {
          final entry = participants[uidLocal] as Map<String, dynamic>?;
          if (entry != null && entry['status'] == 'invited') {
            hasInvite = true;
            break;
          }
        }
      }
      if (mounted) {
        setState(() {
          _hasSessionInvites = hasInvite;
          _hasNotifications = _hasFriendRequests || _hasSessionInvites;
        });
      }
    });
  }

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
  void dispose() {
    _friendSub?.cancel();
    _sessionSub?.cancel();
    super.dispose();
  }

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

                    // --- ICON 1: Notifications (with unread dot) ---
                    NotificationIcon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FriendRequestsScreen(),
                          ),
                        );
                      },
                    ),

                    // Sign out button removed as requested
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