import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/message.dart';

/// Owns every Firestore call for the public messages collection.
/// Create, live-stream read, update, delete: typed methods only.
class BoardService {
  BoardService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  static const int maxLength = 500;

  CollectionReference<Map<String, dynamic>> get _messages =>
      _db.collection('messages');

  /// Generates a fresh id for one compose action. The UI keeps this id until
  /// the post succeeds, so double taps, retries and offline replays all
  /// target the SAME document (Spice #4: Idempotent Alchemist).
  String newDraftId() {
    final r = Random.secure();
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(20, (_) => chars[r.nextInt(chars.length)]).join();
  }

  /// CREATE. Exactly-once: a transaction creates messages/{draftId} only if
  /// it does not already exist. A second call with the same id is a no-op.
  /// Returns true when this call created the document.
  Future<bool> createMessage({
    required String draftId,
    required String text,
  }) async {
    final user = _requireUser();
    final clean = _validate(text);
    final ref = _messages.doc(draftId);
    return _db.runTransaction<bool>((tx) async {
      final existing = await tx.get(ref);
      if (existing.exists) return false;
      tx.set(ref, {
        'text': clean,
        'authorUid': user.uid,
        'authorName': user.displayName?.isNotEmpty == true
            ? user.displayName
            : (user.email ?? 'Anonymous'),
        'createdAt': FieldValue.serverTimestamp(),
        'editedAt': null,
      });
      return true;
    });
  }

  /// READ (live). snapshots() re-emits on every change from any device.
  Stream<List<Message>> streamMessages() {
    return _messages
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((q) => q.docs.map(Message.fromDoc).toList());
  }

  /// UPDATE a single document. Rules also enforce ownership server-side.
  Future<void> updateMessage({required String id, required String text}) {
    _requireUser();
    return _messages.doc(id).update({
      'text': _validate(text),
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  /// DELETE a single document. Rules also enforce ownership server-side.
  Future<void> deleteMessage(String id) {
    _requireUser();
    return _messages.doc(id).delete();
  }

  /// Rules-test helper used by the in-app "Rules Lab" screen: deliberately
  /// attempts a write the UI would normally hide, so the permission-denied
  /// error visibly comes from Firestore, not from the UI.
  Future<void> attemptForeignUpdate(String id) {
    return _messages.doc(id).update({
      'text': 'hijacked by another user',
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  /// One-shot server read used for the signed-out denial drill.
  Future<int> attemptServerRead() async {
    final q = await _messages.limit(1).get(const GetOptions(source: Source.server));
    return q.size;
  }

  Future<void> attemptForgedCreate(String forgedUid) {
    return _messages.add({
      'text': 'forged author test',
      'authorUid': forgedUid,
      'authorName': 'Forger',
      'createdAt': FieldValue.serverTimestamp(),
      'editedAt': null,
    });
  }

  User _requireUser() {
    final u = _auth.currentUser;
    if (u == null) {
      throw StateError('You must be signed in.');
    }
    return u;
  }

  String _validate(String text) {
    final t = text.trim();
    if (t.isEmpty) throw ArgumentError('Message cannot be empty.');
    if (t.length > maxLength) {
      throw ArgumentError('Message must be $maxLength characters or fewer.');
    }
    return t;
  }
}
