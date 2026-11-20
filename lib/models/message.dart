import 'package:cloud_firestore/cloud_firestore.dart';

/// Typed model for a messages/{msgId} document.
class Message {
  Message({
    required this.id,
    required this.text,
    required this.authorUid,
    required this.authorName,
    required this.createdAt,
    this.editedAt,
  });

  final String id;
  final String text;
  final String authorUid;
  final String authorName;

  /// Null only for a moment while a local write waits for the server
  /// timestamp (pending write in the snapshot).
  final DateTime? createdAt;
  final DateTime? editedAt;

  factory Message.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Message(
      id: doc.id,
      text: (d['text'] ?? '') as String,
      authorUid: (d['authorUid'] ?? '') as String,
      authorName: (d['authorName'] ?? 'Unknown') as String,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      editedAt: (d['editedAt'] as Timestamp?)?.toDate(),
    );
  }
}
