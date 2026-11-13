import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/one_widgets.dart';
import '../data/connections_providers.dart';
import '../domain/connections_repository.dart';
import 'connection_controls.dart';

class NetworkScreen extends ConsumerStatefulWidget {
  const NetworkScreen({super.key});
  @override
  ConsumerState<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends ConsumerState<NetworkScreen> {
  NetworkTab _tab = NetworkTab.accepted;
  List<ProfessionalConnection> _people = [];
  bool _busy = false, _more = false;
  String? _error;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _load({bool next = false}) async {
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
      if (!next) {
        _people = [];
        _more = false;
      }
    });
    try {
      final rows = await ref
          .read(connectionsRepositoryProvider)
          .list(
            _tab,
            after: next && _people.isNotEmpty ? _people.last.id : null,
          );
      if (!mounted || generation != _generation) return;
      setState(() {
        _people = next
            ? [..._people, ...rows.take(20)]
            : rows.take(20).toList();
        _more = rows.length > 20;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _error = 'Network unavailable. Check your connection or membership and retry.',
        );
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(networkRevisionProvider, (_, _) => _load());
    return PageBody(
      children: [
        const FeatureHeader(
          eyebrow: 'Professional connections',
          title: 'My network',
          description: 'Review incoming requests, manage invitations and stay connected with verified members.',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: NetworkTab.values
              .map(
                (t) => ChoiceChip(
                  label: Text(
                    t == NetworkTab.incoming
                        ? 'Incoming'
                        : t == NetworkTab.outgoing
                        ? 'Outgoing'
                        : 'Connected',
                  ),
                  selected: _tab == t,
                  onSelected: (_) {
                    setState(() => _tab = t);
                    _load();
                  },
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Column(
            children: [
              Text(_error!),
              TextButton(onPressed: _load, child: const Text('Retry network')),
            ],
          ),
        if (!_busy && _error == null && _people.isEmpty)
          EmptyState(
            title:
                'No ${_tab == NetworkTab.accepted ? 'connections' : '${_tab.name} requests'} yet',
            message: 'Requests and connections appear here after verified members connect.',
            icon: Icons.people_outline,
            action: TextButton(
              onPressed: () => context.go(AppRoutes.discover),
              child: const Text('Discover alumni'),
            ),
          ),
        for (final person in _people)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    person.name ?? 'Member unavailable',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (person.company?.isNotEmpty ?? false)
                    Text(person.company!),
                  if (person.available)
                    TextButton(
                      onPressed: () => context.go('/alumni/${person.peerId}'),
                      child: const Text('View profile'),
                    ),
                  if (person.name == null)
                    const Text(
                      'This member is currently private or unavailable.',
                    ),
                  ConnectionControls(peer: person.peerId, connection: person),
                ],
              ),
            ),
          ),
        if (_more)
          OutlinedButton(
            onPressed: _busy ? null : () => _load(next: true),
            child: const Text('Load more connections'),
          ),
        TextButton(
          onPressed: _busy ? null : _load,
          child: const Text('Refresh network'),
        ),
      ],
    );
  }
}
