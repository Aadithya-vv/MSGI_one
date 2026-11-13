import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/one_widgets.dart';
import '../../catalog/domain/catalog_repository.dart';
import '../../catalog/presentation/catalog_picker.dart';
import '../domain/mentor_repository.dart';
import '../data/mentor_providers.dart';

class MentorGoalsScreen extends ConsumerStatefulWidget {
  const MentorGoalsScreen({super.key});
  @override
  ConsumerState<MentorGoalsScreen> createState() => _MentorGoalsScreenState();
}

class _MentorGoalsScreenState extends ConsumerState<MentorGoalsScreen> {
  final _interests = TextEditingController(),
      _domains = TextEditingController(),
      _aims = TextEditingController();
  final _form = GlobalKey<FormState>();
  final _existing = <String>{},
      _learning = <String>{},
      _names = <String, String>{};
  bool _loading = true, _saving = false, _loaded = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _interests.dispose();
    _domains.dispose();
    _aims.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final g = await ref.read(mentorRepositoryProvider).goals();
      if (!mounted) return;
      _interests.text = g.interests.join(', ');
      _domains.text = g.domains.join(', ');
      _aims.text = g.objectives.join(', ');
      _existing.addAll(g.existing);
      _learning.addAll(g.learning);
      _names.addAll(g.skillNames);
      _loaded = true;
    } catch (_) {
      if (mounted) {
        _error =
            'Preferences unavailable. Retry without changing your saved goals.';
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> _list(String s) => s
      .split(',')
      .map((v) => v.trim())
      .where((v) => v.isNotEmpty)
      .toSet()
      .toList();
  String? _validate(String? s, int length) {
    final list = _list(s ?? '');
    return list.length > 10 || list.any((v) => v.length > length)
        ? 'Use up to 10 entries, each at most $length characters.'
        : null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(mentorRepositoryProvider)
          .save(
            MentorGoals(
              interests: _list(_interests.text),
              domains: _list(_domains.text),
              existing: _existing.toList(),
              learning: _learning.toList(),
              objectives: _list(_aims.text),
            ),
          );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Goals could not be saved. Your edits remain here; check access or connection and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _skills(String label, Set<String> chosen) => ExpansionTile(
    title: Text(label),
    children: [
      Wrap(
        spacing: 8,
        children: [
          for (final id in chosen)
            InputChip(
              label: Text(_names[id] ?? 'Saved skill'),
              onDeleted: _saving
                  ? null
                  : () => setState(() => chosen.remove(id)),
            ),
        ],
      ),
      CatalogPicker(
        kind: CatalogKind.skills,
        label: label,
        enabled: !_saving,
        onSelected: (entry) {
          if (chosen.length < 30) {
            setState(() {
              chosen.add(entry.id);
              _names[entry.id] = entry.name;
            });
          }
        },
      ),
      const Text(
        'Choose up to 30 catalog skills. Selection does not change your public profile.',
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Your mentorship goals')),
    body: PageBody(
      children: [
        const Text(
          'Your private preferences personalize deterministic recommendations. Comma-separated entries use exact, case-insensitive matching. Objectives help you plan; they are not scored.',
        ),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
        if (!_loading && !_loaded)
          TextButton(onPressed: _load, child: const Text('Retry preferences')),
        if (!_loading && _loaded)
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                TextFormField(
                  controller: _interests,
                  enabled: !_saving,
                  maxLength: 810,
                  decoration: const InputDecoration(
                    labelText: 'Career interests',
                    helperText: 'For example: Research, Robotics',
                  ),
                  validator: (s) => _validate(s, 80),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _domains,
                  enabled: !_saving,
                  maxLength: 1210,
                  decoration: const InputDecoration(
                    labelText: 'Target professional domains',
                    helperText: 'For example: Embedded Systems',
                  ),
                  validator: (s) => _validate(s, 120),
                ),
                const SizedBox(height: 16),
                _skills('Existing skills', _existing),
                _skills('Skills to learn', _learning),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _aims,
                  enabled: !_saving,
                  maxLength: 1210,
                  decoration: const InputDecoration(
                    labelText: 'Mentorship objectives',
                    helperText:
                        'For example: Career planning, Interview preparation',
                  ),
                  validator: (s) => _validate(s, 120),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving goals...' : 'Save goals'),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
