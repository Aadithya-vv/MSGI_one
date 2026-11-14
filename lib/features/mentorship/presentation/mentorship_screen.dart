import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/one_widgets.dart';
import '../../../core/theme/app_theme.dart';
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
        Card(
          child: ExpansionTile(
            title: const Text('Refine recommendations'),
            leading: const Icon(Icons.tune),
            subtitle: Text(
              _appliedDomain.isEmpty
                  ? 'Domain, sorting and connections'
                  : _appliedDomain,
            ),
            childrenPadding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _domain,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Filter mentor domain',
                ),
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
            ],
          ),
        ),
        const SizedBox(height: 12),
        ExpansionTile(
          title: const Text('How matching works'),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: const [
            Text(
              'Explainable matching: skills 40%, domain 30%, mentoring opt-in 20%, interests 10%. Missing signals are omitted and limited evidence caps scores. Scores measure relevance, not success probability or AI predictions.',
            ),
          ],
        ),
        const SizedBox(height: 16),
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
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ProfileAvatar(mentor.name),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mentor.name,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                [
                                      mentor.data['designation'],
                                      mentor.data['company'],
                                    ]
                                    .whereType<String>()
                                    .where((s) => s.isNotEmpty)
                                    .join(' \u00b7 '),
                                style: const TextStyle(
                                  color: OneColors.muted,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Chip(label: Text('${mentor.score} / 100 relevance')),
                        const Chip(
                          label: Text('Open to mentorship'),
                          avatar: Icon(Icons.school_outlined, size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      mentor.score == 0
                          ? 'Explore: no shared signals yet'
                          : mentor.evidence < 3
                          ? 'Limited evidence: ${mentor.evidence} of 3 personal signals'
                          : 'Based on 3 personal signals',
                      style: const TextStyle(
                        color: OneColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    if (mentor.domains.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          'Works in your target domain: ${mentor.domains.join(', ')}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    if (mentor.skills.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      SkillTags(mentor.skills),
                    ],
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Why this mentor'),
                      children: [
                        for (final reason in mentor.reasons)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(reason),
                            ),
                          ),
                      ],
                    ),
                    if (mentor.connectionStatus != null)
                      Text(
                        'Relationship: ${mentor.connectionStatus}',
                        style: const TextStyle(
                          color: OneColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    TextButton(
                      onPressed: () => context.go('/alumni/${mentor.id}'),
                      child: const Text('View mentor profile'),
                    ),
                    ConnectionControls(peer: mentor.id),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => _hide(mentor),
                        child: const Text('Hide this mentor'),
                      ),
                    ),
                  ],
                ),
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
