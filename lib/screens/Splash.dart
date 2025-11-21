import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_app/widgets/custom_button.dart';

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

  // Clean splotch without shadows
  Widget buildGlowySplotch({
    required double left,
    required double top,
    required double size,
    required Color color,
    double borderRadius = 28,
    double blurSigma = 40,
  }) {
    final core = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: RadialGradient(
          center: Alignment(-0.2, -0.2),
          radius: 0.9,
          colors: [
            color.withOpacity(0.35),
            color.withOpacity(0.12),
            color.withOpacity(0.02),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
        // boxShadow removed for cleaner look
      ),
    );

    return Positioned(
      left: left,
      top: top,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: core,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF2C2F3E),
      body: Stack(
        children: [
          // Blue splotches
          buildGlowySplotch(
            left: -20,
            top: 30,
            size: 75,
            color: const Color(0xFF46BDF0),
            borderRadius: 18,
            blurSigma: 32,
          ),
          buildGlowySplotch(
            left: w - 90,
            top: 60,
            size: 65,
            color: const Color(0xFF46BDF0),
            borderRadius: 16,
            blurSigma: 30,
          ),
          buildGlowySplotch(
            left: w - 100,
            top: h - 160,
            size: 85,
            color: const Color(0xFF46BDF0),
            borderRadius: 20,
            blurSigma: 34,
          ),
          
          // Yellow splotches
          buildGlowySplotch(
            left: 20,
            top: h - 190,
            size: 70,
            color: const Color(0xFFEDF046),
            borderRadius: 17,
            blurSigma: 32,
          ),
          buildGlowySplotch(
            left: w / 2 - 40,
            top: h / 3,
            size: 60,
            color: const Color(0xFFEDF046),
            borderRadius: 15,
            blurSigma: 28,
          ),
          buildGlowySplotch(
            left: w / 2 + 50,
            top: 80,
            size: 68,
            color: const Color(0xFFEDF046),
            borderRadius: 16,
            blurSigma: 30,
          ),
          
          // Purple/teal
          buildGlowySplotch(
            left: 35,
            top: h / 2 - 70,
            size: 65,
            color: const Color(0xFF7A6BFF),
            borderRadius: 16,
            blurSigma: 30,
          ),
          buildGlowySplotch(
            left: w / 2 + 25,
            top: h - 140,
            size: 58,
            color: const Color(0xFF5EE0B8),
            borderRadius: 14,
            blurSigma: 28,
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
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
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _showButton
                            ? CustomButton(
                                text: 'LET\'S START',
                                width: 200,
                                height: 60,
                                fontSize: 24,
                                backgroundColor: Color(0xFF7550FF),
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
        ],
      ),
    );
  }
}
