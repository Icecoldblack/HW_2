import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/board_service.dart';

/// Evidence screen: fires writes the normal UI hides so the denial is
/// shown coming from Firestore security rules, not from the client.
class RulesLabScreen extends StatefulWidget {
  const RulesLabScreen({super.key, required this.board});
  final BoardService board;

  @override
  State<RulesLabScreen> createState() => _RulesLabScreenState();
}

class _RulesLabScreenState extends State<RulesLabScreen> {
  final _docId = TextEditingController();
  final List<String> _log = [];
  bool _busy = false;

  @override
  void dispose() {
    _docId.dispose();
    super.dispose();
  }

  Future<void> _run(String label, Future<void> Function() action) async {
    setState(() => _busy = true);
    final stamp = TimeOfDay.now().format(context);
    try {
      await action();
      _log.insert(0, '[$stamp] $label -> ALLOWED (unexpected if not yours)');
    } catch (e) {
      _log.insert(0, '[$stamp] $label -> DENIED: ${AuthService.friendlyError(e)}'
          '\n    raw: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rules Lab')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'These buttons bypass the hidden-button UX and call Firestore '
            'directly. Copy the id of ANOTHER user\'s message from the '
            'Firestore console, paste it below, and try to hijack it. '
            'Expected: permission-denied from Firestore.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _docId,
            decoration: const InputDecoration(
                labelText: "Another user's message id"),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: _busy
                ? null
                : () => _run('Cross-uid UPDATE ${_docId.text}',
                    () => widget.board.attemptForeignUpdate(_docId.text.trim())),
            child: const Text('Try to UPDATE that message'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: _busy
                ? null
                : () => _run('Cross-uid DELETE ${_docId.text}',
                    () => widget.board.deleteMessage(_docId.text.trim())),
            child: const Text('Try to DELETE that message'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: _busy
                ? null
                : () => _run('CREATE with forged authorUid',
                    () => widget.board.attemptForgedCreate('someone-else-uid')),
            child: const Text('Try to CREATE with a forged authorUid'),
          ),
          const Divider(height: 32),
          Text('Results', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_log.isEmpty) const Text('No attempts yet.'),
          ..._log.map((l) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SelectableText(l,
                    style: const TextStyle(fontFamily: 'monospace')),
              )),
        ],
      ),
    );
  }
}
