import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_app/widgets/custom_button.dart';
import 'package:my_app/widgets/background.dart';

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
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      setState(() {
        _showButton = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C2F3E),
      body: Stack(
        children: [
          // Reusable background component
          const GlowyBackground(),
          
          // Main content
          SafeArea(
            child: Center(
              child: Column(
                children: [
                  const SizedBox(height: 100), // Top spacing
                  
                  // Logo positioned high
                  Image.asset(
                    'assets/images/StudySync.png',
                    width: 268,
                    height: 296,
                  ),
                  
                  const Spacer(), // Push content to bottom
                  
                  // Bottom content
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const Text(
                          'StudySync',
                          style: TextStyle(
                            color: Color(0xFF00C8B3),
                            fontSize: 36,
                            fontFamily: 'LexendDeca',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'This productive tool is designed to help\nyou better manage your study time\nand be with friends while you do it!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontFamily: 'Lexend Deca',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 32),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _showButton
                              ? CustomButton(
                                  text: 'LET\'S START',
                                  width: 331,
                                  height: 52,
                                  fontSize: 20,
                                  backgroundColor: const Color(0xFF7550FF),
                                  onPressed: () {
                                    Navigator.pushReplacementNamed(context, '/login');
                                  },
                                )
                              : const SizedBox(
                                  width: 331,
                                  height: 52,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF00C8B3),
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
