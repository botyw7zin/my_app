import 'package:flutter/material.dart';

class NavComponents {
  static Widget buildFAB(VoidCallback onPressed) {
    return Container(
      width: 65,
      height: 65,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFB968C7), Color(0xFF8E24AA)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: FloatingActionButton(
        onPressed: onPressed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
    );
  }

  static Widget buildBottomBar(Function(String) onItemTapped) {
    return _CustomBottomNav(onItemTapped: onItemTapped);
  }
}

class _CustomBottomNav extends StatefulWidget {
  final Function(String) onItemTapped;

  const _CustomBottomNav({required this.onItemTapped});

  @override
  State<_CustomBottomNav> createState() => _CustomBottomNavState();
}

class _CustomBottomNavState extends State<_CustomBottomNav> {
  int _selectedIndex = -1;

  Widget _buildButton(IconData icon, int index, String label) {
    final isSelected = _selectedIndex == index;
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: const Color(0xFF7B3FF2).withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 0,
                  offset: const Offset(0, 6),
                ),
              ]
            : [],
      ),
      child: IconButton(
        icon: Icon(icon, color: const Color(0xFF6A1B9A)),
        iconSize: 28,
        onPressed: () {
          setState(() {
            _selectedIndex = index;
          });
          widget.onItemTapped(label);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(28),
        topRight: Radius.circular(28),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          BottomAppBar(
            shape: const CircularNotchedRectangle(),
            notchMargin: 10.0,
            color: const Color(0xFFEEE9FF),
            height: 60,
            elevation: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildButton(Icons.home_rounded, 0, 'Home'),
                _buildButton(Icons.calendar_today_rounded, 1, 'Calendar'),
                const SizedBox(width: 40),
                _buildButton(Icons.description_rounded, 2, 'Documents'),
                _buildButton(Icons.people_rounded, 3, 'People'),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: CustomPaint(
              painter: NotchShadowPainter(),
              child: const SizedBox(height: 30, width: double.infinity),
            ),
          ),
        ],
      ),
    );
  }
}

class NotchShadowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final shadowPaint = Paint()
      ..color = const Color(0xFF7B3FF2).withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final path = Path();
    final centerX = size.width / 2;
    
    path.addArc(
      Rect.fromCircle(center: Offset(centerX, 16), radius: 38),
      0,
      3.14,
    );
    
    canvas.drawPath(path, shadowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
