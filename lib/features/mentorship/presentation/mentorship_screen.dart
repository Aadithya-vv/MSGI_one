import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/one_widgets.dart';
import '../../../core/widgets/consumer_widgets.dart';
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

  Future<void> _filters() => showFilterSheet<void>(
    context,
    title: 'Refine recommendations',
    builder: (_) => StatefulBuilder(
      builder: (context, update) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    update(() {});
                    _load();
                  },
                ),
            ],
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Only new connections'),
            value: _unconnected,
            onChanged: (v) {
              setState(() => _unconnected = v ?? false);
              update(() {});
              _load();
            },
          ),
          OutlinedButton(
            onPressed: () => _load(),
            child: const Text('Refresh recommendations'),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    ref.listen(networkRevisionProvider, (_, _) => _load());
    return PageBody(
      itemCount: _rows.length,
      itemBuilder: (context, index) {
        final mentor = _rows[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PersonCard(
            key: ValueKey(mentor.id),
            name: mentor.name,
            headline: [
              mentor.data['designation'],
              mentor.data['company'],
            ].whereType<String>().where((s) => s.isNotEmpty).join(' | '),
            onProfile: () => context.go('/alumni/${mentor.id}'),
            skills: mentor.skills,
            indicator: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                StatusPill('${mentor.score} / 100 relevance'),
                const StatusPill(
                  'Open to mentorship',
                  icon: Icons.school_outlined,
                  color: OneColors.success,
                ),
              ],
            ),
            footer: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  mentor.score == 0
                      ? 'Explore: no shared signals yet'
                      : mentor.evidence < 3
                      ? 'Limited evidence: ${mentor.evidence} of 3 personal signals'
                      : 'Based on 3 personal signals',
                  style: const TextStyle(color: OneColors.muted, fontSize: 12),
                ),
                if (mentor.domains.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Works in your target domain: ${mentor.domains.join(', ')}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text(
                    'Why this mentor',
                    style: TextStyle(fontSize: 13),
                  ),
                  children: [
                    for (final reason in mentor.reasons)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            reason,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                  ],
                ),
                TextButton(
                  onPressed: () => context.go('/alumni/${mentor.id}'),
                  child: const Text('View mentor profile'),
                ),
                ConnectionControls(peer: mentor.id, compact: true),
                Align(
                  alignment: Alignment.centerRight,
                  child: PopupMenuButton<String>(
                    tooltip: 'Mentor options',
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'hide',
                        child: Text('Hide this mentor'),
                      ),
                    ],
                    onSelected: (_) => _hide(mentor),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      footer: [
        if (_busy && _rows.isNotEmpty) const LinearProgressIndicator(),
        if (_more)
          OutlinedButton(
            onPressed: _busy ? null : () => _load(next: true),
            child: const Text('Load more mentors'),
          ),
      ],
      children: [
        const FeedHeading(
          'Mentor recommendations',
          subtitle: 'Experience aligned with your next chapter.',
        ),
        QuickFilters(
          children: [
            ActionChip(
              avatar: const Icon(Icons.tune, size: 16),
              label: const Text('Personalize your goals'),
              onPressed: _goals,
            ),
            ActionChip(
              avatar: const Icon(Icons.filter_list, size: 16),
              label: const Text('Refine recommendations'),
              onPressed: _filters,
            ),
            ActionChip(
              label: const Text('How matching works'),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Relevance, explained'),
                  content: const Text(
                    'Skills 40%, domain 30%, mentoring opt-in 20%, interests 10%. Missing signals are omitted and limited evidence caps scores. Points measure relevance, not success probability or AI confidence.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_busy && _rows.isEmpty) const FeedSkeleton(),
        if (_error != null) ...[
          StatusNotice(_error),
          TextButton(
            onPressed: () => _load(),
            child: const Text('Retry recommendations'),
          ),
        ],
        if (!_busy && _error == null && _rows.isEmpty)
          const EmptyState(
            title: 'No eligible mentors yet',
            message: 'Try fewer filters or update your goals.',
            icon: Icons.school_outlined,
          ),
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
