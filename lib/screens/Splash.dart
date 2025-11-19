import 'package:flutter/material.dart';
import 'package:my_app/widgets/Custom_Button.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

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
                        fontFamily: 'Lexend Deca', // <-- Change here!
                      ),
                    ),

                  const SizedBox(height: 32),
                  CustomButton(
                    text: 'LET\'S START',
                    width: 200,
                    height: 60,
                    fontSize: 24,
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
