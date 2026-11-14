import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/one_widgets.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/errors/error_state.dart';
import '../../profile/domain/profile_repository.dart';
import '../../catalog/domain/catalog_repository.dart';
import '../../catalog/presentation/catalog_picker.dart';
import '../application/directory_controller.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({
    super.key,
    this.description = 'Only verified alumni who opt into the directory appear here. Location is shown only with map consent.',
  });
  final String description;
  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  final _query = TextEditingController(),
      _profession = TextEditingController(),
      _year = TextEditingController();
  String? _institution, _department, _skill, _city;
  final _labels = <String, String>{};
  String? _yearError;
  VoidCallback? _refreshSheet;
  void _change(VoidCallback change) {
    setState(change);
    _refreshSheet?.call();
  }

  int get _filterCount =>
      _labels.length +
      (_profession.text.isEmpty ? 0 : 1) +
      (_year.text.isEmpty ? 0 : 1);
  void _clear() {
    _change(() {
      _profession.clear();
      _year.clear();
      _institution = null;
      _department = null;
      _skill = null;
      _city = null;
      _labels.clear();
      _yearError = null;
    });
  }

  Future<void> _filters() async {
    final saved = [
      _profession.text,
      _year.text,
      _institution,
      _department,
      _skill,
      _city,
    ];
    final labels = Map<String, String>.from(_labels);
    var applied = false;
    await showFilterSheet<void>(
      context,
      title: 'Filter alumni',
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, update) {
          _refreshSheet = () => update(() {});
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ..._filterFields(),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  if (_search()) {
                    applied = true;
                    Navigator.pop(sheetContext);
                  }
                },
                child: const Text('Apply alumni filters'),
              ),
              TextButton(onPressed: _clear, child: const Text('Clear filters')),
            ],
          );
        },
      ),
    );
    _refreshSheet = null;
    if (!applied && mounted) {
      setState(() {
        _profession.text = saved[0]!;
        _year.text = saved[1]!;
        _institution = saved[2];
        _department = saved[3];
        _skill = saved[4];
        _city = saved[5];
        _labels
          ..clear()
          ..addAll(labels);
        _yearError = null;
      });
    }
  }

  @override
  void dispose() {
    _query.dispose();
    _profession.dispose();
    _year.dispose();
    super.dispose();
  }

  bool _search() {
    if (_year.text.isNotEmpty &&
        (int.tryParse(_year.text) == null ||
            int.parse(_year.text) < 1950 ||
            int.parse(_year.text) > 2200)) {
      _change(() => _yearError = 'Enter a valid graduation year.');
      return false;
    }
    ref
        .read(directoryProvider.notifier)
        .search(
          DirectoryFilter(
            search: _query.text,
            institution: _institution,
            department: _department,
            year: int.tryParse(_year.text),
            profession: _profession.text,
            skill: _skill,
            city: _city,
          ),
        );
    return true;
  }

  List<Widget> _filterFields() => [
    TextField(
      controller: _profession,
      maxLength: 120,
      decoration: const InputDecoration(
        labelText: 'Profession, company or domain',
      ),
    ),
    TextField(
      controller: _year,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Graduation year',
        errorText: _yearError,
      ),
    ),
    CatalogPicker(
      kind: CatalogKind.institutions,
      compact: true,
      selectedLabel: _labels['institution'],
      label: 'Institutions',
      onSelected: (e) => _change(() {
        _institution = e.id;
        _department = null;
        _labels['institution'] = e.name;
        _labels.remove('department');
      }),
    ),
    if (_institution != null)
      CatalogPicker(
        key: ValueKey(_institution),
        kind: CatalogKind.departments,
        compact: true,
        selectedLabel: _labels['department'],
        institutionId: _institution,
        label: 'Departments',
        onSelected: (e) => _change(() {
          _department = e.id;
          _labels['department'] = e.name;
        }),
      ),
    CatalogPicker(
      kind: CatalogKind.skills,
      compact: true,
      selectedLabel: _labels['skill'],
      label: 'Skills',
      onSelected: (e) => _change(() {
        _skill = e.id;
        _labels['skill'] = e.name;
      }),
    ),
    CatalogPicker(
      kind: CatalogKind.cities,
      compact: true,
      selectedLabel: _labels['city'],
      label: 'Cities',
      onSelected: (e) => _change(() {
        _city = e.id;
        _labels['city'] = e.name;
      }),
    ),
  ];

  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      FeatureHeader(
        eyebrow: 'Your alumni community',
        title: 'Discover alumni',
        description: widget.description,
      ),
      TextField(
        key: const Key('alumni-search'),
        controller: _query,
        maxLength: 100,
        onSubmitted: (_) => _search(),
        decoration: const InputDecoration(
          labelText: 'Search alumni by name',
          prefixIcon: Icon(Icons.search),
        ),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _filters,
        icon: const Icon(Icons.tune),
        label: Text(
          _filterCount == 0
              ? 'Filter alumni'
              : 'Filter alumni ($_filterCount active)',
        ),
      ),
      if (_filterCount > 0)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final label in _labels.values)
                Chip(label: Text(label, softWrap: true)),
              if (_profession.text.isNotEmpty)
                Chip(label: Text(_profession.text)),
              if (_year.text.isNotEmpty) Chip(label: Text(_year.text)),
            ],
          ),
        ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: _search,
            icon: const Icon(Icons.search),
            label: const Text('Search alumni'),
          ),
          TextButton(
            onPressed: () {
              _query.clear();
              _clear();
              _search();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
      const SizedBox(height: 20),
      ref
          .watch(directoryProvider)
          .when(
            loading: () => const LoadingState(),
            error: (_, _) => ErrorState(
              message: 'Directory unavailable. Your access may have changed, or the network is unavailable.',
              onRetry: _search,
            ),
            data: (page) => Column(
              children: [
                if (page.people.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${page.people.length} alumni loaded',
                        style: const TextStyle(
                          color: OneColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                if (page.people.isEmpty)
                  const EmptyState(
                    title: 'No alumni found',
                    message: 'Try fewer filters. Only approved, visible alumni are listed.',
                  ),
                for (final person in page.people)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Semantics(
                      button: true,
                      child: InkWell(
                        onTap: () => context.go('/alumni/${person.id}'),
                        borderRadius: BorderRadius.circular(20),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ProfileAvatar(person.name),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            person.name,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            [
                                                  person.text('designation'),
                                                  person.text('company'),
                                                ]
                                                .where((s) => s.isNotEmpty)
                                                .join(' \u00b7 '),
                                            style: const TextStyle(
                                              color: OneColors.muted,
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  [
                                    person.text('institution'),
                                    person.text('department'),
                                    person.text('graduation_year'),
                                  ].where((s) => s.isNotEmpty).join(' \u00b7 '),
                                  style: const TextStyle(
                                    color: OneColors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                                if (person.skills.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  SkillTags(person.skills.take(3).toList()),
                                ],
                                if (person.mentoring)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 10),
                                    child: Text(
                                      'Available for mentoring',
                                      style: TextStyle(
                                        color: OneColors.blue,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                const Text(
                                  'View profile',
                                  style: TextStyle(
                                    color: OneColors.blue,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (page.moreError)
                  const Text(
                    'Next page could not be loaded. Existing results are retained.',
                  ),
                if (page.hasMore)
                  OutlinedButton(
                    onPressed: page.loadingMore
                        ? null
                        : () => ref.read(directoryProvider.notifier).next(),
                    child: Text(
                      page.loadingMore
                          ? 'Loading more…'
                          : page.moreError
                          ? 'Retry next page'
                          : 'Load more alumni',
                    ),
                  ),
              ],
            ),
          ),
    ],
  );
}
