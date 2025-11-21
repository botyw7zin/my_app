import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed; // <-- make nullable
  final double width;
  final double height;
  final double fontSize;

  const CustomButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.width = 150,
    this.height = 50,
    this.fontSize = 18, 
    required Color backgroundColor, // Default size for bigger words
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF5F33E1),
          foregroundColor: Colors.white,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold, // optional, makes it even bigger
          ),
        ),
      ),
    );
  }
}



class GoogleLoginButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final double width;
  final double height;
  final double fontSize;

  const GoogleLoginButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.width = 250,
    this.height = 50,
    this.fontSize = 18,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,        // white button background
          foregroundColor: Colors.black,        // black text
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/google_logo.png',   // add the "G" logo asset in your assets folder
              height: 28,
              width: 28,
            ),
            const SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: Colors.black,            // black text
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
