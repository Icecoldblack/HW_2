import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Owns every Firebase Authentication call plus the one-time write of the
/// private users/{uid} record. Widgets never talk to FirebaseAuth directly.
class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  /// Stable auth-state stream used by AuthGate for routing.
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Creates the Auth account, then writes users/{uid} with the five
  /// required fields. If the Firestore write fails the Auth account is
  /// deleted so we never leave a user without a record.
  Future<void> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user!;
    try {
      await saveUserRecord(
        uid: user.uid,
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        role: role,
      );
      await user.updateDisplayName('${firstName.trim()} ${lastName.trim()}');
    } catch (e) {
      await user.delete();
      rethrow;
    }
  }

  Future<void> saveUserRecord({
    required String uid,
    required String firstName,
    required String lastName,
    required String role,
  }) {
    return _db.collection('users').doc(uid).set({
      'uid': uid,
      'firstName': firstName,
      'lastName': lastName,
      'role': role,
      'registrationDateTime': FieldValue.serverTimestamp(),
    });
  }

  /// Reads the signed-in user's own record (rules allow only owner reads).
  Future<Map<String, dynamic>?> fetchMyRecord() async {
    final uid = currentUser?.uid;
    if (uid == null) return null;
    final snap = await _db.collection('users').doc(uid).get();
    return snap.data();
  }

  Future<void> signOut() => _auth.signOut();

  /// Translate Firebase errors into safe, helpful messages.
  static String friendlyError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          return 'That email address is not valid.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Email or password is incorrect.';
        case 'email-already-in-use':
          return 'An account already exists for that email.';
        case 'weak-password':
          return 'Password is too weak (use at least 6 characters).';
        case 'too-many-requests':
          return 'Too many attempts. Wait a moment and try again.';
        case 'network-request-failed':
          return 'No network connection. Check your internet and retry.';
      }
      return e.message ?? 'Authentication failed (${e.code}).';
    }
    if (e is FirebaseException) {
      if (e.code == 'permission-denied') {
        return 'Permission denied by Firestore security rules.';
      }
      if (e.code == 'unavailable') {
        return 'Firestore is unreachable right now. Try again.';
      }
      return e.message ?? 'Firestore error (${e.code}).';
    }
    return 'Something went wrong. Please try again.';
  }
}
