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


  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );


  // Initialize Hive
  await Hive.initFlutter();
  Hive.registerAdapter(SubjectAdapter());
  await Hive.openBox('userBox');
  await Hive.openBox<Subject>('subjectsBox');


  // Initialize WorkManager for background sync (runs once per app launch)
  final subjectService = SubjectService();
  await subjectService.initializeWorkManager();


  print('>>> [main] Firebase Auth current user: ${FirebaseAuth.instance.currentUser?.uid}');
  print('>>> [main] Hive boxes opened.');
  print('>>> [main] WorkManager initialized.');


  // Handle already-authenticated users on app restart
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    print('>>> [main] User already authenticated: ${currentUser.uid}');
    print('>>> [main] Initializing services for restored session...');
    
    // Load remote data and merge with local Hive
    await subjectService.loadFromFirebase(currentUser.uid);
    
    // Start connectivity listener for foreground sync
    subjectService.listenForConnectivityChanges();
    
    // Optional: Trigger immediate sync to push any offline changes
    await subjectService.syncToFirebase();
    
    print('>>> [main] Services initialized for restored user session.');
  } else {
    print('>>> [main] No authenticated user found.');
  }


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
