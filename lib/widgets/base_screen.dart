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
  final Widget? leading;

  const BaseScreen({
    super.key,
    required this.title,
    required this.body,
    required this.currentScreen,
    this.actions,
    this.appBarColor,
    this.automaticallyImplyLeading = false,
    this.leading,
  });

  void _navigateToAddSubject(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddSubjectScreen()),
    );
  }

  void _handleNavigation(BuildContext context, String label) {
    print('>>> [BaseScreen] Navigation tapped: $label from $currentScreen');

    if (label == currentScreen) {
      print('>>> [BaseScreen] Already on $label screen, ignoring navigation');
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
        print('>>> [BaseScreen] Unknown navigation label: $label');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C2F3E),
      appBar: AppBar(
        leading: leading,
        title: Text(title),
        backgroundColor: appBarColor ?? const Color(0xFF7550FF),
        automaticallyImplyLeading: automaticallyImplyLeading,
        actions: actions,
      ),
      body: Stack(
        children: [
          const GlowyBackground(),
          body,
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
