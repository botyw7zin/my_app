import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/auth_service.dart';
import '../widgets/base_screen.dart';
import '../widgets/custom_button.dart';
import '../screens/model_download_page.dart'; // ADD THIS IMPORT


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


    return BaseScreen(
      title: 'User Settings',
      currentScreen: 'People',
      automaticallyImplyLeading: true,
      appBarColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              // Avatar centered
              Center(
                child: GestureDetector(
                  onTap: _updatePhoto,
                  child: CircleAvatar(
                    radius: 80,
                    backgroundImage: (photoURL.startsWith('http')) ? NetworkImage(photoURL) : AssetImage(photoURL) as ImageProvider,
                    backgroundColor: const Color(0xFF7550FF),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  displayName,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 26),


              // Settings header
              const Padding(
                padding: EdgeInsets.only(left: 6.0, bottom: 12.0),
                child: Text(
                  'Settings and Privacy',
                  style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),


              // Buttons area - center constrained width
              Center(
                child: Column(
                  children: [
                    _OutlineActionButton(
                      text: 'Change Username',
                      color: const Color(0xFF46BDF0),
                      onTap: _updateUsername,
                    ),
                    const SizedBox(height: 12),
                    _OutlineActionButton(
                      text: 'Change E-mail',
                      color: const Color(0xFF5EE0B8),
                      onTap: _updateEmail,
                    ),
                    const SizedBox(height: 12),
                    _OutlineActionButton(
                      text: 'Change password',
                      color: const Color(0xFF7A6BFF),
                      onTap: _changePassword,
                    ),
                    const SizedBox(height: 12),
                    // NEW: AI Model Download Button
                    _OutlineActionButton(
                      text: 'AI Support Model',
                      color: const Color(0xFFFF6B9D),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ModelDownloadPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),


              const Spacer(),


              // Logout button centered with shadow
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 18.0),
                  child: SizedBox(
                    width: 260,
                    child: CustomButton(
                      text: 'Logout',
                      onPressed: () => _authService.signOut(context),
                      width: double.infinity,
                      height: 56,
                      fontSize: 18,
                      backgroundColor: const Color(0xFF7550FF),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



// Small styled outlined button used on settings page
class _OutlineActionButton extends StatelessWidget {
  final String text;
  final Color color;
  final VoidCallback onTap;


  const _OutlineActionButton({required this.text, required this.color, required this.onTap});


  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 320,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: color.withOpacity(0.9), width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.18),
              blurRadius: 12,
              spreadRadius: 1,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/auth_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/background.dart'; // Make sure this path is correct for your project

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
              crossAxisAlignment: CrossAxisAlignment.start, // Align header left
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

                const SizedBox(height: 30), // Increased spacing

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
                          const SizedBox(height: 40), // Increased spacing

                          // Settings header
                          const Padding(
                            padding: EdgeInsets.only(left: 6.0, bottom: 12.0),
                            child: Text(
                              'Settings and Privacy',
                              style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(height: 20), // Extra spacing between header and buttons

                          // Buttons area
                          Center(
                            child: Column(
                              children: [
                                _OutlineActionButton(
                                  text: 'Change Username',
                                  onTap: _updateUsername,
                                ),
                                const SizedBox(height: 22), // Increased spacing
                                _OutlineActionButton(
                                  text: 'Change E-mail',
                                  onTap: _updateEmail,
                                ),
                                const SizedBox(height: 22), // Increased spacing
                                _OutlineActionButton(
                                  text: 'Change Password',
                                  onTap: _changePassword,
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
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40), // Increased bottom padding
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

  const _OutlineActionButton({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 64, // Increased vertical space
        padding: const EdgeInsets.symmetric(horizontal: 20), // Text starts from left with padding
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30), // Rounder corners
          border: Border.all(color: const Color(0xFF7550FF), width: 2), // Purple border
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7550FF).withOpacity(0.3), // Purple glow
              blurRadius: 15,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.black, // Purple text
            fontSize: 18, // Larger font
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}