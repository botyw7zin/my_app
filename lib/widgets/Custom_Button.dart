import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final double width;
  final double height;
  final double fontSize;
  final Color backgroundColor;
  final String? iconAsset; // CHANGED: Now accepts an image path (e.g., 'assets/images/arrow.png')

  const CustomButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.width = 150,
    this.height = 50,
    this.fontSize = 18,
    required this.backgroundColor,
    this.iconAsset, // Defaults to null
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: EdgeInsets.zero, // Remove default padding to control layout manually
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. Centered Text
            // We use a container with width to ensure the text is truly centered 
            // relative to the button width, not just the available space.
            Container(
              width: width,
              alignment: Alignment.center,
              child: Text(
                text,
                style: TextStyle(
                  fontSize: fontSize,
                  fontFamily: 'LexendDeca',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // 2. Custom Image Arrow at the Right Frontier
            if (iconAsset != null)
              Positioned(
                right: 20, // Adjust this value to move it closer/further from edge
                child: Image.asset(
                  iconAsset!,
                  width: 24,  // Adjust size to match your design
                  height: 24,
                ),
              ),
          ],
        ),
      ),
    );
  }
}