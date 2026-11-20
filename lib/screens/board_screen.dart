import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/message.dart';
import '../services/auth_service.dart';
import '../services/board_service.dart';
import 'rules_lab_screen.dart';

class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key, required this.auth, required this.board});
  final AuthService auth;
  final BoardService board;

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  final _composer = TextEditingController();
  final _scroll = ScrollController();

  /// One stream instance for the lifetime of this screen; StreamBuilder
  /// cancels the subscription when the screen is disposed (Case File 3).
  late final Stream<List<Message>> _stream = widget.board.streamMessages();

  /// The id for the message currently being composed. Kept across retries
  /// and double taps, replaced only after a successful post.
  late String _draftId = widget.board.newDraftId();
  bool _posting = false;

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ));
  }

  Future<void> _post() async {
    if (_posting) return;
    final text = _composer.text;
    if (text.trim().isEmpty) {
      _snack('Type a message first.', error: true);
      return;
    }
    setState(() => _posting = true);
    try {
      final created =
          await widget.board.createMessage(draftId: _draftId, text: text);
      if (!created) _snack('Already posted; duplicate ignored.');
      _composer.clear();
      _draftId = widget.board.newDraftId();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut);
        }
      });
    } on ArgumentError catch (e) {
      _snack(e.message.toString(), error: true);
    } catch (e) {
      _snack(AuthService.friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _edit(Message m) async {
    final controller = TextEditingController(text: m.text);
    final newText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          maxLength: BoardService.maxLength,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (newText == null || newText.trim() == m.text) return;
    try {
      await widget.board.updateMessage(id: m.id, text: newText);
      _snack('Message updated.');
    } on ArgumentError catch (e) {
      _snack(e.message.toString(), error: true);
    } catch (e) {
      _snack(AuthService.friendlyError(e), error: true);
    }
  }

  Future<void> _delete(Message m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete message?'),
        content: Text('"${m.text}" will be removed for everyone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.board.deleteMessage(m.id);
      _snack('Message deleted.');
    } catch (e) {
      _snack(AuthService.friendlyError(e), error: true);
    }
  }

  Future<void> _showProfile() async {
    final record = await widget.auth.fetchMyRecord();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final ts = record?['registrationDateTime'];
        final when = ts == null
            ? 'pending'
            : DateFormat.yMMMd().add_jm().format(ts.toDate());
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('My Firestore record (users/{uid})',
                  style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (record == null)
                const Text('No record found.')
              else ...[
                _kv('uid', record['uid']),
                _kv('firstName', record['firstName']),
                _kv('lastName', record['lastName']),
                _kv('role', record['role']),
                _kv('registrationDateTime', when),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _kv(String k, Object? v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 160,
                child: Text(k,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
            Expanded(child: SelectableText('$v')),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final me = widget.auth.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vault Board'),
        actions: [
          IconButton(
            tooltip: 'Rules Lab',
            icon: const Icon(Icons.shield_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => RulesLabScreen(board: widget.board))),
          ),
          IconButton(
            tooltip: 'My record',
            icon: const Icon(Icons.person_outline),
            onPressed: _showProfile,
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => widget.auth.signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _stream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return _CenterNote(
                    icon: Icons.error_outline,
                    title: 'Could not load the board',
                    body: AuthService.friendlyError(snap.error!),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final msgs = snap.data!;
                if (msgs.isEmpty) {
                  return const _CenterNote(
                    icon: Icons.chat_bubble_outline,
                    title: 'The board is empty',
                    body: 'Be the first to post. Messages appear here live '
                        'for every signed-in user.',
                  );
                }
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) {
                    final m = msgs[i];
                    return _MessageTile(
                      message: m,
                      mine: m.authorUid == me?.uid,
                      onEdit: () => _edit(m),
                      onDelete: () => _delete(m),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('composer'),
                      controller: _composer,
                      maxLength: BoardService.maxLength,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Write a message...',
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    key: const Key('postButton'),
                    onPressed: _posting ? null : _post,
                    icon: _posting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({
    required this.message,
    required this.mine,
    required this.onEdit,
    required this.onDelete,
  });

  final Message message;
  final bool mine;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final time = message.createdAt == null
        ? 'sending...'
        : DateFormat.MMMd().add_jm().format(message.createdAt!);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Card(
          color: mine ? cs.primaryContainer : cs.surfaceContainerHighest,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mine ? '${message.authorName} (you)' : message.authorName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(message.text),
                      const SizedBox(height: 4),
                      Text(
                        message.editedAt != null ? '$time · edited' : time,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                // UX only: buttons hidden for others. Rules are the real lock.
                if (mine)
                  PopupMenuButton<String>(
                    onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CenterNote extends StatelessWidget {
  const _CenterNote(
      {required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(body, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
