import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_app/widgets/custom_button.dart';
import 'package:my_app/widgets/background.dart';
import 'package:my_app/services/subject_service.dart';

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
      try {
        final subjectService = SubjectService();
        await subjectService.syncBothWays();
        subjectService.listenForConnectivityChanges();
      } catch (e) {
        // non-fatal
      }
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      setState(() {
        _showButton = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions
    final screenWidth = MediaQuery.of(context).size.width;

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
                  const SizedBox(height: 30), // Top spacing

                  // --- UPDATED LOGO SECTION ---
                  Container(
                    // Multiplied by 0.8 to make it take 80% of screen width
                    width: screenWidth * 0.8, 
                    child: Image.asset(
                      'assets/images/StudySync.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  // ----------------------------

                  const SizedBox(height: 170), // Push content to bottom

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
                        const SizedBox(height: 30),
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
                                  width: double.infinity,
                                  height: 52,
                                  fontSize: 20,
                                  backgroundColor: const Color(0xFF7550FF),
                                  onPressed: () {
                                    Navigator.pushReplacementNamed(context, '/login');
                                  },
                                  iconAsset: 'assets/images/Arrow - Left.png',
                                )
                              : const SizedBox(
                                  width: double.infinity,
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