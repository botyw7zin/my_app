import 'dart:async';
import 'package:flutter/material.dart';
import '../services/friends_service.dart';
import '../services/session_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// A reusable notification icon that listens for incoming friend requests
/// and session invites and shows a blue dot when there are unread notifications.
class NotificationIcon extends StatefulWidget {
  final double size;
  final VoidCallback? onPressed;
  const NotificationIcon({Key? key, this.size = 28, this.onPressed}) : super(key: key);

  @override
  State<NotificationIcon> createState() => _NotificationIconState();
}

class _NotificationIconState extends State<NotificationIcon> {
  final FriendService _friendService = FriendService();
  final SessionService _sessionService = SessionService();
  StreamSubscription? _friendSub;
  StreamSubscription? _sessionSub;
  bool _hasNotifications = false;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    _friendSub = _friendService.incomingRequestsStream().listen((snap) {
      final hasFriend = snap.docs.isNotEmpty;
      if (mounted) {
        setState(() {
          _hasNotifications = hasFriend || _hasNotifications;
        });
      }
    });

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
          _hasNotifications = hasInvite || _hasNotifications;
        });
      }
    });
  }

  @override
  void dispose() {
    _friendSub?.cancel();
    _sessionSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onPressed,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.notifications, color: Colors.white, size: widget.size),
          if (_hasNotifications)
            Positioned(
              right: 0,
              top: 4,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
