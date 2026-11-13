import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/one_widgets.dart';
import '../domain/mentor_preview.dart';
import '../domain/mentor_repository.dart';
import '../data/mentor_providers.dart';
import '../../connections/presentation/connection_controls.dart';
import '../../connections/data/connections_providers.dart';
import 'mentor_goals_screen.dart';

class MentorshipScreen extends ConsumerStatefulWidget {
  const MentorshipScreen({super.key});
  @override
  ConsumerState<MentorshipScreen> createState() => _MentorshipScreenState();
}

class _MentorshipScreenState extends ConsumerState<MentorshipScreen> {
  final _domain = TextEditingController();
  List<MentorRecommendation> _rows = [];
  bool _busy = false, _more = false, _unconnected = false;
  String _sort = 'relevance', _appliedDomain = '';
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
    _domain.dispose();
    super.dispose();
  }

  Future<void> _load({bool next = false}) async {
    final generation = ++_generation;
    if (!next) _appliedDomain = _domain.text;
    setState(() {
      _busy = true;
      _error = null;
      if (!next) {
        _rows = [];
        _more = false;
      }
    });
    try {
      final rows = await ref
          .read(mentorRepositoryProvider)
          .recommend(
            domain: _appliedDomain,
            unconnected: _unconnected,
            sort: _sort,
            after: next && _rows.isNotEmpty ? _rows.last : null,
          );
      if (!mounted || generation != _generation) return;
      setState(() {
        _rows = next ? [..._rows, ...rows.take(20)] : rows.take(20).toList();
        _more = rows.length > 20;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _error = 'Recommendations unavailable. Check your connection or verified access and retry.',
        );
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _goals() async {
    final changed = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const MentorGoalsScreen()));
    if (mounted && changed == true) _load();
  }

  Future<void> _hide(MentorRecommendation m) async {
    try {
      await ref.read(mentorRepositoryProvider).block(m.id, true);
      if (!mounted) return;
      _load();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Mentor hidden from recommendations.'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              try {
                await ref.read(mentorRepositoryProvider).block(m.id, false);
                if (mounted) _load();
              } catch (_) {
                if (mounted) {
                  setState(
                    () => _error =
                        'Could not restore mentor. Retry when connected.',
                  );
                }
              }
            },
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not hide mentor. Check access and retry.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(networkRevisionProvider, (_, _) => _load());
    return PageBody(
      children: [
        const FeatureHeader(
          eyebrow: 'Learn across generations',
          title: 'Mentor recommendations',
          description: 'Find experience aligned with your next chapter. Every recommendation explains its evidence.',
        ),
        FilledButton.icon(
          onPressed: _goals,
          icon: const Icon(Icons.tune),
          label: const Text('Personalize your goals'),
        ),
        const SizedBox(height: 16),
        const Text(
          'Explainable matching: skills 40%, domain 30%, mentoring opt-in 20%, interests 10%. Missing signals are omitted and limited evidence caps scores. Scores measure relevance, not success probability or AI predictions.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _domain,
          maxLength: 120,
          decoration: const InputDecoration(labelText: 'Filter mentor domain'),
          onSubmitted: (_) => _load(),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in const {
              'relevance': 'Best relevance',
              'skills': 'Skill alignment',
              'domain': 'Domain alignment',
            }.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: _sort == entry.key,
                onSelected: (_) {
                  setState(() => _sort = entry.key);
                  _load();
                },
              ),
          ],
        ),
        Material(
          color: Colors.transparent,
          child: CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Only new connections'),
            value: _unconnected,
            onChanged: (v) {
              setState(() => _unconnected = v ?? false);
              _load();
            },
          ),
        ),
        OutlinedButton(
          onPressed: _busy ? null : () => _load(),
          child: const Text('Refresh recommendations'),
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Column(
            children: [
              Semantics(liveRegion: true, child: Text(_error!)),
              TextButton(
                onPressed: () => _load(),
                child: const Text('Retry recommendations'),
              ),
            ],
          ),
        if (!_busy && _error == null && _rows.isEmpty)
          const EmptyState(
            title: 'No eligible mentors yet',
            message: 'Try fewer filters or update your goals. Only verified, visible alumni who opted into mentoring appear.',
            icon: Icons.school_outlined,
          ),
        for (final mentor in _rows)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Text(
                        '${mentor.score} / 100 relevance',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Chip(
                        label: Text('Open to mentorship'),
                        avatar: Icon(Icons.check_circle_outline, size: 18),
                      ),
                    ],
                  ),
                  Text(
                    mentor.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    [
                          mentor.data['designation'],
                          mentor.data['company'],
                          mentor.data['institution'],
                        ]
                        .whereType<String>()
                        .where((s) => s.isNotEmpty)
                        .join(' | '),
                  ),
                  Text(
                    mentor.score == 0
                        ? 'Explore: no shared signals yet'
                        : mentor.evidence < 3
                        ? 'Limited evidence: ${mentor.evidence} of 3 personal signals'
                        : 'Based on 3 personal signals',
                  ),
                  const SizedBox(height: 12),
                  for (final reason in mentor.reasons)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(reason),
                    ),
                  if (mentor.connectionStatus != null)
                    Text('Relationship: ${mentor.connectionStatus}'),
                  TextButton(
                    onPressed: () => context.go('/alumni/${mentor.id}'),
                    child: const Text('View mentor profile'),
                  ),
                  ConnectionControls(peer: mentor.id),
                  TextButton(
                    onPressed: () => _hide(mentor),
                    child: const Text('Hide this mentor'),
                  ),
                ],
              ),
            ),
          ),
        if (_more)
          OutlinedButton(
            onPressed: _busy ? null : () => _load(next: true),
            child: const Text('Load more mentors'),
          ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// Existing home preview remains explicitly synthetic until its own feature task.

class MentorCard extends StatelessWidget {
  const MentorCard({required this.mentor, super.key});
  final MentorPreview mentor;
  @override
  Widget build(BuildContext context) => InfoCard(
    icon: Icons.person_outline,
    title: mentor.name,
    description: '${mentor.role}\n${mentor.focus}',
    trailing: const Text(
      'SAMPLE PROFILE',
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
      ),
    ),
  );
}
