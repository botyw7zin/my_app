import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_app/widgets/Custom_Button.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool _showButton = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Wait 1.5 seconds to show splash
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    // Check if user is logged in
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // User is logged in, go directly to home
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      // User not logged in, show the "LET'S START" button
      setState(() {
        _showButton = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C2F3E),
      body: SafeArea(
        child: Column(
          children: [
            // Image section, centered higher on the page
            Expanded(
              flex: 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Image.asset(
                    'assets/images/StudySync.png',
                    width: 268,
                    height: 296,
                  ),
                ],
              ),
            ),
            Spacer(flex: 1),
            // Bottom section: Title, Description, and Button
            Padding(
              padding: const EdgeInsets.only(bottom: 48),
              child: Column(
                children: [
                  const Text(
                    'StudySync',
                    style: TextStyle(
                      color: Color(0xFF00C8B3),
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'This productive tool is designed to help you better manage your study time and be with friends while you do it!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontFamily: 'Lexend Deca',
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Show button after checking auth, or loading indicator
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _showButton
                        ? CustomButton(
                            text: 'LET\'S START',
                            width: 200,
                            height: 60,
                            fontSize: 24,
                            onPressed: () {
                              Navigator.pushReplacementNamed(context, '/login');
                            },
                          )
                        : const CircularProgressIndicator(
                            color: Color(0xFF00C8B3),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
