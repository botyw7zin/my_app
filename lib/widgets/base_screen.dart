import 'package:flutter/material.dart';
import '../widgets/nav_components.dart';
import '../widgets/background.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../screens/home.dart';
import '../screens/user_settings_screen.dart';
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
  final bool showAppBar;
  final Widget? leading;

  const BaseScreen({
    super.key,
    required this.title,
    required this.body,
    required this.currentScreen,
    this.actions,
    this.appBarColor,
    this.automaticallyImplyLeading = false,
    this.showAppBar = true,
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
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C2F3E),
      
      appBar: showAppBar
          ? AppBar(
              leading: leading,
              title: Text(title),
              backgroundColor: appBarColor ?? const Color(0xFF7550FF),
              automaticallyImplyLeading: automaticallyImplyLeading,
              actions: [
                // 1. Preserve any actions passed from other screens
                if (actions != null) ...actions!,

                // 2. Avatar Logic (Listeners for changes)
                ValueListenableBuilder(
                  valueListenable: Hive.box('userBox').listenable(),
                  builder: (context, Box box, _) {
                    final photoURL = (box.get('photoURL') as String?) ?? '';

                    return Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const UserSettingsScreen()),
                          );
                        },
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFF7550FF),
                          child: ClipOval(
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: _buildAvatarImage(photoURL),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            )
          : null,
          
      body: Stack(
        children: [
          const GlowyBackground(),
          
          // SafeArea ensures content doesn't go behind the status bar
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

  // Helper method to safely build the image
  Widget _buildAvatarImage(String photoURL) {
    if (photoURL.startsWith('http')) {
      return Image.network(
        photoURL,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.person, color: Colors.white);
        },
      );
    } else if (photoURL.isNotEmpty) {
      return Image.asset(
        photoURL,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.person, color: Colors.white);
        },
      );
    } else {
      // Default fallback
      return const Icon(Icons.person, color: Colors.white);
    }
  }
}