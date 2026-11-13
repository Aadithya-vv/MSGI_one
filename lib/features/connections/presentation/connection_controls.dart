import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../auth/application/auth_providers.dart';
import '../data/connections_providers.dart';
import '../domain/connections_repository.dart';

class ConnectionControls extends ConsumerStatefulWidget {
  const ConnectionControls({super.key, required this.peer, this.connection});
  final String peer;
  final ProfessionalConnection? connection;
  @override
  ConsumerState<ConnectionControls> createState() => _ConnectionControlsState();
}

class _ConnectionControlsState extends ConsumerState<ConnectionControls> {
  bool _busy = false;
  String? _error;
  Future<void> _act(String action) async {
    if (_busy) return;
    final c =
        widget.connection ??
        ref.read(connectionWithProvider(widget.peer)).asData?.value;
    if (action == 'removed') {
      final approved = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Remove connection?'),
          content: const Text(
            'This removes the accepted connection. A new request can be sent later.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep connection'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (approved != true || !mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(connectionsRepositoryProvider);
      if (action == 'send') {
        await repo.send(widget.peer);
      } else {
        if (c == null) throw StateError('Refresh relationship');
        await repo.transition(c.id, action);
      }
      if (!mounted) return;
      ref.invalidate(connectionWithProvider(widget.peer));
      ref.read(networkRevisionProvider.notifier).refresh();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Connection updated.')));
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Connection could not be updated. Check access or refresh and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _buttons(ProfessionalConnection? c) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        c == null
            ? 'Not connected'
            : c.status == 'pending'
            ? (c.incoming ? 'Incoming request' : 'Request sent')
            : c.status == 'accepted'
            ? 'Connected'
            : c.status == 'rejected'
            ? 'Request declined'
            : 'Previous connection closed',
      ),
      if (_busy) const LinearProgressIndicator(),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          if (c == null || c.status == 'cancelled')
            FilledButton(
              onPressed: _busy ? null : () => _act('send'),
              child: const Text('Connect'),
            ),
          if (c?.status == 'pending' && c!.incoming) ...[
            if (c.eligible)
              FilledButton(
                onPressed: _busy ? null : () => _act('accepted'),
                child: const Text('Accept'),
              ),
            OutlinedButton(
              onPressed: _busy ? null : () => _act('rejected'),
              child: const Text('Decline'),
            ),
          ],
          if (c?.status == 'pending' && !c!.incoming)
            OutlinedButton(
              onPressed: _busy ? null : () => _act('cancelled'),
              child: const Text('Cancel request'),
            ),
          if (c?.status == 'accepted')
            OutlinedButton(
              onPressed: _busy ? null : () => _act('removed'),
              child: const Text('Remove connection'),
            ),
        ],
      ),
      if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
    ],
  );
  @override
  Widget build(BuildContext context) {
    if (widget.peer == ref.watch(authControllerProvider).userId) {
      return const Text('This is your profile.');
    }
    if (widget.connection != null) return _buttons(widget.connection);
    return ref
        .watch(connectionWithProvider(widget.peer))
        .when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => TextButton(
            onPressed: () =>
                ref.invalidate(connectionWithProvider(widget.peer)),
            child: const Text('Connection status unavailable. Retry'),
          ),
          data: _buttons,
        );
  }
}
