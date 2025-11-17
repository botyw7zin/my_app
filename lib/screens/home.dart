import 'package:flutter/material.dart';
import '../widgets/dashbar.dart'; // or package:your_app/widgets/dashbar.dart

class Home extends StatelessWidget {
  const Home({super.key});

  void _show(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.purple,
      appBar: AppBar(
        title: const Text('Purple Page'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              'Hello, Flutter!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12),
        child: RoundedActionBar(
          onHome: () => _show(context, 'Home tapped'),
          onSearch: () => _show(context, 'Search tapped'),
          onFavorite: () => _show(context, 'Favorite tapped'),
          onSettings: () => _show(context, 'Settings tapped'),
        ),
      ),
    );
  }
}
