import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'screens/home.dart';
import 'screens/Splash.dart';
import 'screens/signin_screen.dart';
import 'screens/signup_screen.dart';
import 'models/subject_model.dart';
import 'services/subject_service.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🚀 [main] App starting...');


  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Hive
  await Hive.initFlutter();
  Hive.registerAdapter(SubjectAdapter());
  await Hive.openBox('userBox');
  await Hive.openBox<Subject>('subjectsBox');
  
  // Log initial Hive state
  final subjectsBox = Hive.box<Subject>('subjectsBox');
  print('✅ [main] Hive boxes opened');
  print('📦 [main] Subjects in Hive: ${subjectsBox.length}');
  
  // Log details of subjects if they exist
  if (subjectsBox.isNotEmpty) {
    print('📊 [main] Subject details:');
    for (var subject in subjectsBox.values.take(3)) {
      print('   - ${subject.name}: ${subject.hoursCompleted}/${subject.hourGoal} hours (synced: ${subject.isSynced})');
    }
  }

  // Initialize WorkManager for background sync
  await SubjectService().initializeWorkManager();

  print('>>> [main] Firebase Auth current user: ${FirebaseAuth.instance.currentUser?.uid}');
  print('>>> [main] Hive boxes opened.');
  print('>>> [main] WorkManager initialized.');

  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      ),
      home: const SplashPage(),
      routes: {
        '/login': (context) => LoginScreen(),
        '/signup': (context) => SignUpScreen(),
        '/home': (context) => const Home(),
      },
    );
  }
}
