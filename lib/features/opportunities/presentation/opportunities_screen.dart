import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/one_widgets.dart';
import '../../../core/widgets/consumer_widgets.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/opportunity_preview.dart';
import '../domain/career_repository.dart';
import '../data/career_providers.dart';
import '../../catalog/domain/catalog_repository.dart';
import '../../catalog/presentation/catalog_picker.dart';

class OpportunitiesScreen extends ConsumerStatefulWidget {
  const OpportunitiesScreen({super.key, this.simulated = false});
  final bool simulated;
  @override
  ConsumerState<OpportunitiesScreen> createState() =>
      _OpportunitiesScreenState();
}

class _OpportunitiesScreenState extends ConsumerState<OpportunitiesScreen> {
  final _search = TextEditingController(),
      _domain = TextEditingController(),
      _location = TextEditingController();
  String _kind = 'all', _state = 'published', _sort = 'recent', _scope = 'all';
  String? _skill, _skillName;
  bool _mine = false,
      _remote = false,
      _referrals = false,
      _busy = false,
      _more = false,
      _canPublish = false;
  String? _error;
  int _generation = 0;
  List<CareerPost> _posts = [];
  Map<String, dynamic> _applied = {};
  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _generation++;
    _search.dispose();
    _domain.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _load({bool next = false}) async {
    final generation = ++_generation;
    if (!next) {
      _applied = {
        'search': _search.text,
        'domain': _domain.text,
        'location': _location.text,
        'kind': _kind,
        'status': _state,
        'sort': _sort,
        'scope': _scope,
        'skill': _skill,
        'mine': _mine,
        'remote': _remote,
        'referral': _referrals,
      };
    }
    setState(() {
      _busy = true;
      _error = null;
      if (!next) {
        _posts = [];
        _more = false;
      }
    });
    try {
      final repo = ref.read(careerRepositoryProvider);
      final can = await repo.canPublish();
      final rows = await repo.list(
        _applied,
        after: next && _posts.isNotEmpty ? _posts.last : null,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _canPublish = can;
        _posts = next ? [..._posts, ...rows.take(20)] : rows.take(20).toList();
        _more = rows.length > 20;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _error = 'Career Bridge unavailable. Check your connection or verified access and retry.',
        );
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Widget _check(String label, bool value, ValueChanged<bool> changed) =>
      Material(
        color: Colors.transparent,
        child: CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          value: value,
          onChanged: (v) {
            changed(v!);
            _load();
          },
        ),
      );
  Future<void> _filters() => showFilterSheet<void>(
    context,
    title: 'Opportunity filters',
    builder: (_) => StatefulBuilder(
      builder: (context, update) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _domain,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Career domain filter',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _location,
            maxLength: 160,
            decoration: const InputDecoration(labelText: 'Location filter'),
          ),
          _check('Remote only', _remote, (v) {
            setState(() => _remote = v);
            update(() {});
          }),
          _check('Referrals only', _referrals, (v) {
            setState(() => _referrals = v);
            update(() {});
          }),
          _check('My posts and drafts', _mine, (v) {
            setState(() {
              _mine = v;
              _state = v ? 'all' : 'published';
            });
            update(() {});
          }),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in const {
                'published': 'Open posts',
                'closed': 'Closed posts',
                'draft': 'Drafts',
                'all': 'Any status',
              }.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: _state == e.key,
                  onSelected: (_) {
                    setState(() => _state = e.key);
                    update(() {});
                    _load();
                  },
                ),
            ],
          ),
          const Text(
            'Drafts, closed posts and archives are author-only.',
            style: TextStyle(fontSize: 12, color: OneColors.muted),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final e in const {
                'recent': 'Most recent',
                'relevance': 'Skill overlap',
              }.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: _sort == e.key,
                  onSelected: (_) {
                    setState(() => _sort = e.key);
                    update(() {});
                    _load();
                  },
                ),
            ],
          ),
          const Text(
            'Skill overlap compares listed requirements with your public skills; it is not an AI prediction.',
            style: TextStyle(fontSize: 12, color: OneColors.muted),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _scope,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Audience filter'),
            items: [
              for (final e in const {
                'all': 'Any audience',
                'community': 'Community',
                'institution': 'My institution',
                'department': 'My department',
              }.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) {
              setState(() => _scope = v!);
              _load();
            },
          ),
          if (_skillName != null)
            InputChip(
              label: Text(_skillName!),
              onDeleted: () {
                setState(() {
                  _skill = null;
                  _skillName = null;
                });
                update(() {});
                _load();
              },
            ),
          CatalogPicker(
            kind: CatalogKind.skills,
            label: 'opportunity skills',
            compact: true,
            onSelected: (e) {
              setState(() {
                _skill = e.id;
                _skillName = e.name;
              });
              update(() {});
              _load();
            },
          ),
          FilledButton(
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              _load();
            },
            child: const Text('Search Career Bridge'),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => PageBody(
    itemCount: _posts.length,
    itemBuilder: (context, index) {
      final p = _posts[index];
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    StatusPill(
                      careerKindLabel(p.data['kind'] as String),
                      icon: p.data['kind'] == 'collaboration'
                          ? Icons.groups_outlined
                          : Icons.work_outline,
                    ),
                    StatusPill(
                      p.archived ? 'Archived' : careerStatusLabel(p.status),
                      color: p.status == 'published'
                          ? OneColors.success
                          : OneColors.muted,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  p.title,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  p.data['organization'] as String? ?? '',
                  style: const TextStyle(color: OneColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    Text(
                      p.data['remote'] == true
                          ? 'Remote'
                          : p.data['location_text'] as String? ?? '',
                      style: const TextStyle(
                        color: OneColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    if (p.data['referral'] == true)
                      const Text(
                        'Referral available',
                        style: TextStyle(color: OneColors.blue, fontSize: 12),
                      ),
                    if ((p.data['shared_count'] as num? ?? 0) > 0)
                      Text(
                        '${p.data['shared_count']} skills in common',
                        style: const TextStyle(
                          color: OneColors.blue,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                if (p.skills.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: SkillTags(p.skills.take(3).toList()),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => context.go('/opportunities/${p.id}'),
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('View opportunity'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
    footer: [
      if (_busy && _posts.isNotEmpty) const LinearProgressIndicator(),
      if (_more)
        OutlinedButton(
          onPressed: _busy ? null : () => _load(next: true),
          child: const Text('Load more opportunities'),
        ),
    ],
    children: [
      FeedHeading(
        'Opportunities',
        subtitle: widget.simulated
            ? 'Fictional openings. Real possibilities to explore.'
            : 'Find your next role, project or referral.',
      ),
      CompactSearch(
        controller: _search,
        label: 'Search opportunities',
        onSearch: () => _load(),
        onFilters: _filters,
        filterCount:
            (_remote ? 1 : 0) +
            (_referrals ? 1 : 0) +
            (_mine ? 1 : 0) +
            (_skill == null ? 0 : 1) +
            (_domain.text.isEmpty ? 0 : 1) +
            (_location.text.isEmpty ? 0 : 1),
      ),
      const SizedBox(height: 8),
      QuickFilters(
        children: [
          for (final e in const {
            'all': 'All types',
            'job': 'Jobs',
            'internship': 'Internships',
            'collaboration': 'Projects',
          }.entries)
            ChoiceChip(
              label: Text(e.value),
              selected: _kind == e.key,
              onSelected: (_) {
                setState(() => _kind = e.key);
                _load();
              },
            ),
          FilterChip(
            label: const Text('Referrals'),
            selected: _referrals,
            onSelected: (v) {
              setState(() => _referrals = v);
              _load();
            },
          ),
          ActionChip(
            label: const Text('Status and sorting'),
            onPressed: _filters,
          ),
          if (_canPublish)
            ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: const Text('Create opportunity'),
              onPressed: () => context.go('/opportunities/new'),
            ),
        ],
      ),
      const SizedBox(height: 12),
      if (_busy && _posts.isEmpty) const FeedSkeleton(),
      if (_error != null) ...[
        StatusNotice(_error),
        TextButton(
          onPressed: () => _load(),
          child: const Text('Retry careers'),
        ),
      ],
      if (!_busy && _error == null && _posts.isEmpty)
        const EmptyState(
          title: 'No opportunities found',
          message: 'Try fewer filters or return later.',
        ),
    ],
  );
}

class OpportunityCard extends StatelessWidget {
  const OpportunityCard({required this.opportunity, super.key});
  final OpportunityPreview opportunity;
  @override
  Widget build(BuildContext context) => InfoCard(
    icon: Icons.work_outline,
    title: opportunity.title,
    description: '${opportunity.type}\n${opportunity.location}',
  );
}

String careerKindLabel(String value) => switch (value) {
  'job' => 'Job',
  'internship' => 'Internship',
  'collaboration' => 'Project',
  _ => value,
};
String careerStatusLabel(String value) => switch (value) {
  'published' => 'Open',
  'closed' => 'Closed',
  'draft' => 'Draft',
  _ => value,
};
