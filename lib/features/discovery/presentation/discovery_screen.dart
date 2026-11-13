import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/one_widgets.dart';
import '../../../core/errors/error_state.dart';
import '../../profile/domain/profile_repository.dart';
import '../../catalog/domain/catalog_repository.dart';
import '../../catalog/presentation/catalog_picker.dart';
import '../application/directory_controller.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});
  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  final _query = TextEditingController(),
      _profession = TextEditingController(),
      _year = TextEditingController();
  String? _institution, _department, _skill, _city;
  final _labels = <String, String>{};
  @override
  void dispose() {
    _query.dispose();
    _profession.dispose();
    _year.dispose();
    super.dispose();
  }

  void _search() {
    if (_year.text.isNotEmpty &&
        (int.tryParse(_year.text) == null ||
            int.parse(_year.text) < 1950 ||
            int.parse(_year.text) > 2200)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid graduation year.')),
      );
      return;
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
  }

  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      const FeatureHeader(
        eyebrow: 'Your alumni community',
        title: 'Discover alumni',
        description: 'Only verified alumni who opt into the directory appear here. Location is shown only with map consent.',
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
      ExpansionTile(
        title: const Text('Filter alumni'),
        children: [
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
            decoration: const InputDecoration(labelText: 'Graduation year'),
          ),
          CatalogPicker(
            kind: CatalogKind.institutions,
            label: 'Institutions',
            onSelected: (e) => setState(() {
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
              institutionId: _institution,
              label: 'Departments',
              onSelected: (e) => setState(() {
                _department = e.id;
                _labels['department'] = e.name;
              }),
            ),
          CatalogPicker(
            kind: CatalogKind.skills,
            label: 'Skills',
            onSelected: (e) => setState(() {
              _skill = e.id;
              _labels['skill'] = e.name;
            }),
          ),
          CatalogPicker(
            kind: CatalogKind.cities,
            label: 'Cities',
            onSelected: (e) => setState(() {
              _city = e.id;
              _labels['city'] = e.name;
            }),
          ),
        ],
      ),
      Wrap(
        spacing: 8,
        children: _labels.values.map((s) => Chip(label: Text(s))).toList(),
      ),
      Row(
        children: [
          Expanded(
            child: FilledButton(
              onPressed: _search,
              child: const Text('Search alumni'),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _query.clear();
                _profession.clear();
                _year.clear();
                _institution = null;
                _department = null;
                _skill = null;
                _city = null;
                _labels.clear();
              });
              _search();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
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
                        child: InfoCard(
                          icon: Icons.person_outline,
                          title: person.name,
                          description:
                              '${person.text('designation')} ${person.text('company')}\n${person.text('institution')} · ${person.text('graduation_year')}\n${person.skills.join(', ')}${person.mentoring ? '\nAvailable for mentoring' : ''}',
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
