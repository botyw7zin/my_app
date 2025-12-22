import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/auth_service.dart';

class UserSettingsScreen extends StatefulWidget {
  const UserSettingsScreen({super.key});

  @override
  State<UserSettingsScreen> createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends State<UserSettingsScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  String get _uid => _auth.currentUser?.uid ?? '';

  Future<void> _updatePhoto() async {
    final box = Hive.box('userBox');
    final controller = TextEditingController(text: box.get('photoURL') as String? ?? '');
    final res = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF363A4D),
        title: const Text('Update Photo URL', style: TextStyle(color: Colors.white)),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'https://...')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );

    if (res == null) return;
    try {
      if (_uid.isNotEmpty) {
        await _auth.currentUser?.updatePhotoURL(res);
        await _firestore.collection('users').doc(_uid).update({'photoURL': res});
      }
      await box.put('photoURL', res);
      if (mounted) setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile photo updated')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update photo: $e')));
    }
  }

  Future<void> _updateUsername() async {
    final box = Hive.box('userBox');
    final controller = TextEditingController(text: box.get('displayName') as String? ?? '');
    final newName = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF363A4D),
        title: const Text('Change Username', style: TextStyle(color: Colors.white)),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Your name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );

    if (newName == null || newName.isEmpty) return;
    try {
      if (_uid.isNotEmpty) {
        await _auth.currentUser?.updateDisplayName(newName);
        await _firestore.collection('users').doc(_uid).update({'displayName': newName, 'lowercaseDisplayName': newName.toLowerCase()});
      }
      await box.put('displayName', newName);
      if (mounted) setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Username updated')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update username: $e')));
    }
  }

  Future<void> _updateEmail() async {
    final controller = TextEditingController(text: _auth.currentUser?.email ?? '');
    final newEmail = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF363A4D),
        title: const Text('Change Email', style: TextStyle(color: Colors.white)),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'email@example.com')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );

    if (newEmail == null || newEmail.isEmpty) return;
    try {
      await _authService.changeEmail(newEmail);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email updated')));
    } on FirebaseAuthException catch (e) {
      String msg = e.message ?? e.code;
      if (e.code == 'requires-recent-login') msg = 'Please re-login and try again';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update email: $msg')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update email: $e')));
    }
  }

  Future<void> _changePassword() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final res = await showDialog<bool?>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF363A4D),
        title: const Text('Change Password', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: currentController, decoration: const InputDecoration(hintText: 'Current password'), obscureText: true),
            const SizedBox(height: 8),
            TextField(controller: newController, decoration: const InputDecoration(hintText: 'New password'), obscureText: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Change')),
        ],
      ),
    );

    if (res != true) return;
    final current = currentController.text;
    final nw = newController.text;
    try {
      await _authService.changePassword(current, nw);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to change password: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('userBox');
    final displayName = (box.get('displayName') ?? '') as String;
    final photoURL = (box.get('photoURL') ?? 'assets/images/cat.png') as String;

    return Scaffold(
      appBar: AppBar(title: const Text('User Settings'), backgroundColor: const Color(0xFF2C2F3E)),
      backgroundColor: const Color(0xFF1F2130),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: _updatePhoto,
              child: CircleAvatar(
                radius: 48,
                backgroundImage: (photoURL.startsWith('http')) ? NetworkImage(photoURL) : AssetImage(photoURL) as ImageProvider,
                backgroundColor: const Color(0xFF7550FF),
              ),
            ),
            const SizedBox(height: 12),
            Center(child: Text(displayName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _updateUsername, child: const Text('Change Username')),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _updateEmail, child: const Text('Change Email')),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _changePassword, child: const Text('Change Password')),
          ],
        ),
      ),
    );
  }
}
