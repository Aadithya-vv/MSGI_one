import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/one_widgets.dart';
import '../../../core/widgets/consumer_widgets.dart';
import '../../connections/presentation/connection_controls.dart';
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
  Widget build(BuildContext context) {
    final result = ref.watch(directoryProvider), page = result.asData?.value;
    return PageBody(
      itemCount: page?.people.length ?? 0,
      itemBuilder: (context, index) {
        final person = page!.people[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PersonCard(
            key: ValueKey(person.id),
            name: person.name,
            headline: [
              person.text('designation'),
              person.text('company'),
            ].where((s) => s.isNotEmpty).join(' | '),
            education: [
              person.text('department'),
              person.text('graduation_year'),
              person.text('institution'),
            ].where((s) => s.isNotEmpty).join(' / '),
            skills: person.skills,
            onProfile: () => context.go('/alumni/${person.id}'),
            indicator: person.mentoring
                ? const StatusPill(
                    'Open to mentoring',
                    icon: Icons.school_outlined,
                    color: OneColors.success,
                  )
                : null,
            footer: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextButton(
                  onPressed: () => context.go('/alumni/${person.id}'),
                  child: const Text('View profile'),
                ),
                ConnectionControls(peer: person.id, compact: true),
              ],
            ),
          ),
        );
      },
      footer: [
        if (page?.moreError ?? false)
          const Text(
            'Next page could not be loaded. Existing results are retained.',
          ),
        if (page?.hasMore ?? false)
          OutlinedButton(
            onPressed: page!.loadingMore
                ? null
                : () => ref.read(directoryProvider.notifier).next(),
            child: Text(
              page.loadingMore
                  ? 'Loading more...'
                  : page.moreError
                  ? 'Retry next page'
                  : 'Load more alumni',
            ),
          ),
      ],
      children: [
        const FeedHeading(
          'Discover alumni',
          subtitle: 'Find experience. Build your network.',
        ),
        CompactSearch(
          controller: _query,
          label: 'Search alumni by name',
          fieldKey: const Key('alumni-search'),
          onSearch: _search,
          onFilters: _filters,
          filterCount: _filterCount,
        ),
        const SizedBox(height: 8),
        QuickFilters(
          children: [
            ActionChip(
              avatar: const Icon(Icons.tune, size: 16),
              onPressed: _filters,
              label: Text(
                _filterCount == 0
                    ? 'Filter alumni'
                    : 'Filter alumni ($_filterCount active)',
              ),
            ),
            ActionChip(label: const Text('Search alumni'), onPressed: _search),
            ActionChip(
              label: const Text('Clear'),
              onPressed: () {
                _query.clear();
                _clear();
                _search();
              },
            ),
          ],
        ),
        if (_labels.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SkillTags(_labels.values.toList()),
          ),
        const SizedBox(height: 12),
        result.when(
          loading: () => const FeedSkeleton(),
          error: (_, _) => ErrorState(
            message: 'Directory unavailable. Your access or connection may have changed.',
            onRetry: _search,
          ),
          data: (page) => page.people.isEmpty
              ? const EmptyState(
                  title: 'No alumni found',
                  message: 'Try another name or fewer filters.',
                )
              : Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${page.people.length} alumni loaded',
                    style: const TextStyle(
                      color: OneColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
