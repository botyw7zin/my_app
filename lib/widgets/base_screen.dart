import 'package:flutter/material.dart';
import '../widgets/nav_components.dart';
import '../widgets/background.dart';
import '../screens/home.dart';
import '../screens/subject_list_screen.dart';
import '../screens/add_subject.dart';
import '../screens/friends_screen.dart';
import '../screens/calendar_screen.dart';

class BaseScreen extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Color? appBarColor;
  final String currentScreen; // 'Home', 'Documents', 'People', 'Calendar'
  final bool automaticallyImplyLeading;
  final bool showAppBar; // New property to toggle AppBar visibility
  final Widget? leading;

  const BaseScreen({
    super.key,
    required this.title,
    required this.body,
    required this.currentScreen,
    this.actions,
    this.appBarColor,
    this.automaticallyImplyLeading = false,
    this.showAppBar = true, // Defaults to true
    this.leading,

    
  });

  void _navigateToAddSubject(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddSubjectScreen()),
    );
  }

  void _handleNavigation(BuildContext context, String label) {
    if (label == currentScreen) {
      return;
    }

    switch (label) {
      case 'Home':
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const Home()),
          (route) => false,
        );
        break;
      case 'Calendar':
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const CalendarScreen()),
          (route) => false,
        );
        break;
      case 'Documents':
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const SubjectsListScreen()),
          (route) => false,
        );
        break;
      case 'People':
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const FriendsScreen()),
          (route) => false,
        );
        break;
      default:
        debugPrint('>>> [BaseScreen] Unknown navigation label: $label');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C2F3E),
      
      // If showAppBar is false, we pass null. This removes the header space.
      appBar: showAppBar
          ? AppBar(
              leading: leading,

              title: Text(title),
              backgroundColor: appBarColor ?? const Color(0xFF7550FF),
              automaticallyImplyLeading: automaticallyImplyLeading,
              actions: actions,
            )
          : null,
          
      body: Stack(
        children: [
          const GlowyBackground(),
          
          // --- THE FIX IS HERE ---
          // SafeArea ensures content doesn't go behind the status bar or notch.
          SafeArea(
            child: body,
          ),
        ],
      ),
      floatingActionButton:
          NavComponents.buildFAB(() => _navigateToAddSubject(context)),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: NavComponents.buildBottomBar(
        (label) => _handleNavigation(context, label),
      ),
    );
  }
}