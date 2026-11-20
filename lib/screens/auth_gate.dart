import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/board_service.dart';
import 'board_screen.dart';
import 'login_screen.dart';

/// Routes purely from authStateChanges(): signed in -> board,
/// signed out -> login. Services are constructed only after Firebase init.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthService _auth = AuthService();
  late final BoardService _board = BoardService();
  late final Stream<User?> _authStream = _auth.authStateChanges();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        if (user == null) {
          return LoginScreen(auth: _auth);
        }
        return BoardScreen(
          key: ValueKey(user.uid),
          auth: _auth,
          board: _board,
        );
      },
    );
  }
}
