import 'package:flutter/material.dart';

class BottomNavWithFAB extends StatelessWidget {
  final Function(String) onItemTapped;
  final VoidCallback onAddPressed;

  const BottomNavWithFAB({
    Key? key,
    required this.onItemTapped,
    required this.onAddPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // This returns both the FAB and BottomAppBar
      ],
    );
  }
}
