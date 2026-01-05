import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/auth_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/background.dart';
import 'model_download_page.dart'; // Add this import


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
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'https://... (or leave empty for default)',
            hintStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF7550FF))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7550FF)),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
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
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Your name',
            hintStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF7550FF))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7550FF)),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );


    if (newName == null || newName.isEmpty) return;
    try {
      if (_uid.isNotEmpty) {
        await _auth.currentUser?.updateDisplayName(newName);
        await _firestore.collection('users').doc(_uid).update({
          'displayName': newName,
          'lowercaseDisplayName': newName.toLowerCase()
        });
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
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'email@example.com',
            hintStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF7550FF))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7550FF)),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
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
            TextField(
              controller: currentController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Current password',
                hintStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF7550FF))),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: newController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'New password',
                hintStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF7550FF))),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7550FF)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Change', style: TextStyle(color: Colors.white)),
          ),
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
    final photoURL = (box.get('photoURL') as String?) ?? '';


    return Scaffold(
      backgroundColor: const Color(0xFF1F2232),
      body: Stack(
        children: [
          // 1. Glowy Background
          const GlowyBackground(),


          // 2. Content Layer
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),


                // --- HEADER WITH BACK BUTTON ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'User Settings',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),


                const SizedBox(height: 30),


                // --- SCROLLABLE CONTENT ---
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 10),
                          
                          // Avatar centered with camera overlay
                          Center(
                            child: GestureDetector(
                              onTap: _updatePhoto,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CircleAvatar(
                                    radius: 100,
                                    backgroundColor: const Color(0xFF7550FF),
                                    child: ClipOval(
                                      child: SizedBox(
                                        width: 200,
                                        height: 200,
                                        child: photoURL.startsWith('http')
                                            ? Image.network(
                                                photoURL,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) {
                                                  return const Icon(Icons.person, size: 100, color: Colors.white);
                                                },
                                              )
                                            : (photoURL.isNotEmpty
                                                ? Image.asset(
                                                    photoURL,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) {
                                                      return const Icon(Icons.person, size: 100, color: Colors.white);
                                                    },
                                                  )
                                                : const Icon(Icons.person, size: 100, color: Colors.white)),
                                      ),
                                    ),
                                  ),
                                  // translucent camera overlay
                                  Container(
                                    width: 200,
                                    height: 200,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.3),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.photo_camera, color: Colors.white70, size: 48),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: Text(
                              displayName,
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(height: 40),


                          // Settings header
                          const Padding(
                            padding: EdgeInsets.only(left: 6.0, bottom: 12.0),
                            child: Text(
                              'Settings and Privacy',
                              style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(height: 18),


                          // Buttons area
                          Center(
                            child: Column(
                              children: [
                                _OutlineActionButton(
                                  text: 'Change Username',
                                  onTap: _updateUsername,
                                ),
                                const SizedBox(height: 22),
                                _OutlineActionButton(
                                  text: 'Change E-mail',
                                  onTap: _updateEmail,
                                  glowColor: const Color(0xFF00F1E0),
                                ),
                                const SizedBox(height: 22),
                                _OutlineActionButton(
                                  text: 'Change Password',
                                  onTap: _changePassword,
                                ),
                                const SizedBox(height: 22),
                                _OutlineActionButton(
                                  text: 'Download AI Models',
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const ModelDownloadScreen(),
                                      ),
                                    );
                                  },
                                  glowColor: const Color(0xFFFF3B30),
                                ),
                              ],
                            ),
                          ),
                          
                          // Extra space before logout
                          const SizedBox(height: 50),
                        ],
                      ),
                    ),
                  ),
                ),


                // --- LOGOUT BUTTON (PINNED BOTTOM) ---
                Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    child: CustomButton(
                      text: 'Logout',
                      onPressed: () => _authService.signOut(context),
                      width: 250,
                      height: 53,
                      fontSize: 20,
                      backgroundColor: const Color(0xFF7550FF),
                    ),
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


// Styled outlined button used on settings page
class _OutlineActionButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final Color glowColor;

  const _OutlineActionButton({required this.text, required this.onTap, this.glowColor = const Color(0xFF7550FF)});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 330,
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: glowColor.withOpacity(0.95), width: 2),
          boxShadow: [
            BoxShadow(
              color: glowColor.withOpacity(0.45),
              blurRadius: 28,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: glowColor.withOpacity(0.18),
              blurRadius: 18,
              spreadRadius: 0,
              offset: const Offset(0, -4),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
