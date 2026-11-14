import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/one_widgets.dart';
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
  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      FeatureHeader(
        eyebrow: 'Career Bridge',
        title: 'Career opportunities',
        description: widget.simulated
            ? 'Fictional jobs, internships and projects. Explore possibilities; these are not real vacancies.'
            : 'Find your next role, referral or project. Shared by eligible members of the verified MSGI community.',
      ),
      if (_canPublish)
        FilledButton.icon(
          onPressed: () => context.go('/opportunities/new'),
          icon: const Icon(Icons.add),
          label: const Text('Create opportunity'),
        ),
      if (!_busy && !_canPublish && _error == null && !widget.simulated)
        const Text(
          'Publishing is reserved for verified alumni and authorized administrators.',
        ),
      const SizedBox(height: 16),
      TextField(
        controller: _search,
        maxLength: 100,
        onSubmitted: (_) => _load(),
        decoration: const InputDecoration(
          labelText: 'Search opportunities',
          prefixIcon: Icon(Icons.search),
          counterText: '',
        ),
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
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
        ],
      ),
      ExpansionTile(
        title: const Text('Filter opportunities'),
        leading: const Icon(Icons.tune),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _domain,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Career domain filter',
            ),
          ),
          TextField(
            controller: _location,
            maxLength: 160,
            decoration: const InputDecoration(labelText: 'Location filter'),
          ),
          _check('Remote only', _remote, (v) => setState(() => _remote = v)),
          _check(
            'Referrals only',
            _referrals,
            (v) => setState(() => _referrals = v),
          ),
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
                _load();
              },
            ),
          CatalogPicker(
            kind: CatalogKind.skills,
            label: 'opportunity skills',
            onSelected: (e) {
              setState(() {
                _skill = e.id;
                _skillName = e.name;
              });
              _load();
            },
          ),
        ],
      ),
      Card(
        child: ExpansionTile(
          title: const Text('Status and sorting'),
          subtitle: Text(
            _mine ? 'Your posts and drafts' : 'Open community posts',
          ),
          childrenPadding: const EdgeInsets.all(16),
          children: [
            _check(
              'My posts and drafts',
              _mine,
              (v) => setState(() {
                _mine = v;
                _state = v ? 'all' : 'published';
              }),
            ),
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
                      _load();
                    },
                  ),
              ],
            ),
            const Text(
              'Drafts, closed posts and archives are author-only. My posts includes your retained archives.',
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
                      _load();
                    },
                  ),
              ],
            ),
            const Text(
              'Skill overlap uses your public profile skills against listed requirements. It is not an AI prediction or eligibility assessment.',
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      OutlinedButton(
        onPressed: _busy ? null : () => _load(),
        child: const Text('Search Career Bridge'),
      ),
      if (_busy) const LinearProgressIndicator(),
      if (_error != null) ...[
        Semantics(liveRegion: true, child: Text(_error!)),
        TextButton(
          onPressed: () => _load(),
          child: const Text('Retry careers'),
        ),
      ],
      if (!_busy && _error == null && _posts.isEmpty)
        const EmptyState(
          title: 'No opportunities found',
          message: 'Try fewer filters or return later. Only posts permitted for your account appear.',
        ),
      for (final p in _posts)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Chip(
                        label: Text(careerKindLabel(p.data['kind'] as String)),
                      ),
                      Chip(
                        label: Text(
                          p.archived ? 'Archived' : careerStatusLabel(p.status),
                        ),
                      ),
                      if (p.data['remote'] == true)
                        const Chip(label: Text('Remote')),
                      if (p.data['referral'] == true)
                        const Chip(label: Text('Referral')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    p.title,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${p.data['organization']} \u00b7 ${p.data['professional_domain']}',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    p.data['location_text'] as String? ?? '',
                    style: const TextStyle(
                      color: OneColors.muted,
                      fontSize: 13,
                    ),
                  ),
                  if ((p.data['shared_count'] as num? ?? 0) > 0)
                    Text(
                      '${p.data['shared_count']} listed skills in common',
                      style: const TextStyle(
                        color: OneColors.blue,
                        fontSize: 12,
                      ),
                    ),
                  TextButton(
                    onPressed: () => context.go('/opportunities/${p.id}'),
                    child: const Text('View opportunity'),
                  ),
                ],
              ),
            ),
          ),
        ),
      if (_more)
        OutlinedButton(
          onPressed: _busy ? null : () => _load(next: true),
          child: const Text('Load more opportunities'),
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
