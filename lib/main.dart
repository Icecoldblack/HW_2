import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/auth_gate.dart';
import 'screens/splash_screen.dart';

/// Spice #1 (Emulator Explorer): run with
///   flutter run --dart-define=USE_EMULATOR=true
/// to point Auth + Firestore at the local Emulator Suite instead of production.
const bool kUseEmulator = bool.fromEnvironment('USE_EMULATOR');
const String kEmulatorHost =
    String.fromEnvironment('EMULATOR_HOST', defaultValue: '10.0.2.2');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MessageBoardApp());
}

class MessageBoardApp extends StatelessWidget {
  const MessageBoardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vault Board',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0039A6),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const Bootstrap(),
    );
  }
}

/// Initializes Firebase behind the splash screen. The future is created once
/// in initState so rebuilds never restart initialization.
class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});

  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  late Future<void> _init;

  @override
  void initState() {
    super.initState();
    _init = _initialize();
  }

  Future<void> _initialize() async {
    final started = DateTime.now();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kUseEmulator) {
      await FirebaseAuth.instance.useAuthEmulator(kEmulatorHost, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(kEmulatorHost, 8080);
    }
    // Keep the splash visible long enough to be seen (min 1.5s).
    final elapsed = DateTime.now().difference(started);
    const minSplash = Duration(milliseconds: 1500);
    if (elapsed < minSplash) {
      await Future.delayed(minSplash - elapsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _init,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, size: 56),
                    const SizedBox(height: 12),
                    const Text(
                      'Firebase could not start. Check your connection and setup.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () =>
                          setState(() => _init = _initialize()),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const SplashScreen();
        }
        return const AuthGate();
      },
    );
  }
}
