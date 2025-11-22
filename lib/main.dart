import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'login.dart';
import 'signup.dart';
import 'main_screen.dart';
import 'services/notification_service.dart';
import 'services/presence_service.dart';
import 'complete_profile_screen.dart';
import 'services/deadline_checker_service.dart';
import 'theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.initialize();
  await NotificationService.initializeLocalNotifications();
  DeadlineCheckerService.checkDeadlinesOnStartup();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const StudySwapApp(),
    ),
  );
}

class StudySwapApp extends StatefulWidget {
  const StudySwapApp({super.key});

  @override
  State<StudySwapApp> createState() => _StudySwapAppState();
}

class _StudySwapAppState extends State<StudySwapApp> {
  @override
  void initState() {
    super.initState();
    PresenceService.setOnline();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'StudySwap',
      debugShowCheckedModeBanner: false,

      // Light theme
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        cardColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
        ),
        cardTheme: const CardThemeData(color: Colors.white, elevation: 2),
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ).copyWith(
              surface: Colors.white,
              surfaceContainerLow: Colors.white,
              surfaceContainerLowest: Colors.white,
            ),
      ),

      // Dark theme
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        cardColor: Colors.grey[850],
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[900],
          foregroundColor: Colors.white,
          elevation: 1,
        ),
        cardTheme: CardThemeData(color: Colors.grey[850], elevation: 2),
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ).copyWith(
              surface: Colors.grey[900],
              surfaceContainerLow: Colors.grey[850],
              surfaceContainerLowest: Colors.grey[900],
            ),
      ),

      themeMode: themeProvider.themeMode,

      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading StudySwap...'),
                  ],
                ),
              ),
            );
          }

          if (snapshot.hasData) {
            NotificationService.updateFCMToken();
            PresenceService.setOnline();
            return const MainScreen();
          } else {
            return const LoginScreen();
          }
        },
      ),

      routes: {
        '/home': (context) => const MainScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/complete-profile': (context) => const CompleteProfileScreen(),
      },
    );
  }
}
