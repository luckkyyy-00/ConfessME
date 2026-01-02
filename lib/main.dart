import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'providers/confession_provider.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'widgets/responsive_wrapper.dart';

final DateTime startTime = DateTime.now();

late final Future<FirebaseApp> firebaseInit;

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Start Firebase init without awaiting
  firebaseInit =
      Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).catchError((e) {
        debugPrint('Firebase initialization failed: $e');
        return Firebase.app(); // Fallback to default app if already initialized
      });

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => ConfessionProvider())],
      child: const ConfessApp(),
    ),
  );
}

class ConfessApp extends StatefulWidget {
  const ConfessApp({super.key});

  @override
  State<ConfessApp> createState() => _ConfessAppState();
}

class _ConfessAppState extends State<ConfessApp> {
  bool _showOnboarding = true;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final now = DateTime.now();
      debugPrint('First frame: ${now.difference(startTime).inMilliseconds}ms');
    });
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _showOnboarding = prefs.getBool('showOnboarding') ?? true;
        _initialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CONFESS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: FutureBuilder<FirebaseApp>(
        future: firebaseInit,
        builder: (context, snapshot) {
          if (!snapshot.hasData || !_initialized) {
            return const Scaffold(
              backgroundColor: Color(0xFF0A0E21),
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFFFFD700)),
              ),
            );
          }
          return ResponsiveWrapper(
            child: _showOnboarding
                ? const OnboardingScreen()
                : const HomeScreen(),
          );
        },
      ),
    );
  }
}
