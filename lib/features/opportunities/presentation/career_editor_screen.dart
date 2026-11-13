import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/one_widgets.dart';
import '../../auth/application/auth_providers.dart';
import '../../catalog/domain/catalog_repository.dart';
import '../../catalog/presentation/catalog_picker.dart';
import '../domain/career_repository.dart';
import '../data/career_providers.dart';

class CareerEditorScreen extends ConsumerStatefulWidget {
  const CareerEditorScreen({super.key, this.id});
  final String? id;
  @override
  ConsumerState<CareerEditorScreen> createState() => _CareerEditorScreenState();
}

class _CareerEditorScreenState extends ConsumerState<CareerEditorScreen> {
  final _form = GlobalKey<FormState>();
  final _fields = {
    for (final key in [
      'title',
      'description',
      'organization',
      'professional_domain',
      'location_text',
      'external_url',
    ])
      key: TextEditingController(),
  };
  late final String _id = widget.id ?? careerRequestId();
  String _kind = 'job', _audience = 'community', _status = 'draft';
  String? _expected, _error;
  final _skills = <String>{}, _names = <String, String>{};
  bool _remote = false,
      _referral = false,
      _loading = true,
      _loaded = false,
      _busy = false,
      _allowed = false;
  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(careerRepositoryProvider);
      _allowed = await repo.canPublish();
      if (_allowed && widget.id != null) {
        final post = await repo.detail(_id);
        if (post == null ||
            post.authorId != ref.read(authControllerProvider).userId ||
            post.archived) {
          throw StateError('Unavailable');
        }
        final labels = await repo.skillNames(
          (post.data['skill_ids'] as List).cast<String>(),
        );
        if (!mounted) return;
        for (final key in _fields.keys) {
          _fields[key]!.text = post.data[key] as String? ?? '';
        }
        _kind = post.data['kind'] as String;
        _status = post.status;
        _expected = post.updated;
        _audience = post.data['audience'] as String;
        _remote = post.data['remote'] as bool;
        _referral = post.data['referral'] as bool;
        _skills.addAll((post.data['skill_ids'] as List).cast<String>());
        _names.addAll(labels);
      }
      _loaded = true;
    } catch (_) {
      if (mounted) {
        _error = 'Post unavailable or editing is not permitted. Retry loading.';
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save(String status) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_form.currentState!.validate() || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(careerRepositoryProvider).save(_id, {
        for (final e in _fields.entries) e.key: e.value.text.trim(),
        'kind': _kind,
        'audience': _audience,
        'status': status,
        'remote': _remote,
        'referral': _referral,
        'skill_ids': _skills.toList(),
      }, expected: _expected);
      if (mounted) context.go('/opportunities/$_id');
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not save. Check your input, access and connection. Your entries remain here. If the post changed elsewhere, reopen it before editing.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.id == null ? 'Create opportunity' : 'Edit opportunity',
      ),
      leading: BackButton(onPressed: () => context.go('/opportunities')),
    ),
    body: PageBody(
      children: [
        if (_loading) const LinearProgressIndicator(),
        if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
        if (!_loaded && !_loading)
          TextButton(onPressed: _load, child: const Text('Retry editor')),
        if (_loaded && !_allowed)
          const Text(
            'Publishing requires verified alumni or authorized administrator access.',
          ),
        if (_loaded && _allowed)
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Save a draft to continue later. Unsaved entries stay only on this screen. Publish only information intended for the selected verified audience.',
                ),
                const SizedBox(height: 16),
                for (final e in const {
                  'title': ('Opportunity title', 160),
                  'description': ('Description', 6000),
                  'organization': ('Organization', 160),
                  'professional_domain': ('Career domain', 120),
                  'location_text': ('Location (optional)', 160),
                  'external_url': ('Application URL (optional)', 2048),
                }.entries) ...[
                  TextFormField(
                    key: Key('career-${e.key}'),
                    controller: _fields[e.key],
                    enabled: !_busy,
                    maxLength: e.value.$2,
                    minLines: e.key == 'description' ? 4 : 1,
                    maxLines: e.key == 'description' ? 8 : 1,
                    decoration: InputDecoration(
                      labelText: e.value.$1,
                      helperText: e.key == 'external_url'
                          ? 'Public HTTPS links only; no login credentials in URLs.'
                          : null,
                    ),
                    validator: (v) {
                      final text = (v ?? '').trim();
                      if (e.key == 'title' && text.length < 3) {
                        return 'Enter a title of at least 3 characters.';
                      }
                      if (e.key == 'description' && text.length < 10) {
                        return 'Describe the opportunity in at least 10 characters.';
                      }
                      if (e.key == 'external_url' &&
                          text.isNotEmpty &&
                          safeCareerUrl(text) == null) {
                        return 'Use a public HTTPS URL without credentials, private hosts or ports.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _kind,
                  decoration: const InputDecoration(
                    labelText: 'Opportunity type',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'job', child: Text('Job')),
                    DropdownMenuItem(
                      value: 'internship',
                      child: Text('Internship'),
                    ),
                    DropdownMenuItem(
                      value: 'collaboration',
                      child: Text('Project collaboration'),
                    ),
                  ],
                  onChanged: _busy
                      ? null
                      : (v) => setState(() {
                          _kind = v!;
                          if (v == 'collaboration') _referral = false;
                        }),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _audience,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Who can see this?',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'community',
                      child: Text('Verified community'),
                    ),
                    DropdownMenuItem(
                      value: 'institution',
                      child: Text('My institution'),
                    ),
                    DropdownMenuItem(
                      value: 'department',
                      child: Text('My department'),
                    ),
                  ],
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _audience = v!),
                ),
                Material(
                  color: Colors.transparent,
                  child: CheckboxListTile(
                    title: const Text('Remote available'),
                    value: _remote,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _remote = v!),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: CheckboxListTile(
                    title: const Text('Referral available'),
                    value: _referral,
                    onChanged: _busy || _kind == 'collaboration'
                        ? null
                        : (v) => setState(() => _referral = v!),
                  ),
                ),
                const SectionHeading('Required skills'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final id in _skills)
                      InputChip(
                        label: Text(_names[id] ?? 'Saved skill'),
                        onDeleted: _busy
                            ? null
                            : () => setState(() => _skills.remove(id)),
                      ),
                  ],
                ),
                CatalogPicker(
                  kind: CatalogKind.skills,
                  label: 'required skills',
                  enabled: !_busy,
                  onSelected: (e) {
                    if (_skills.length < 30) {
                      setState(() {
                        _skills.add(e.id);
                        _names[e.id] = e.name;
                      });
                    }
                  },
                ),
                const Text('Optional: choose up to 30 catalog skills.'),
                const SizedBox(height: 20),
                if (_busy) const LinearProgressIndicator(),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () =>
                            _save(_status == 'closed' ? 'closed' : 'published'),
                  child: Text(
                    _status == 'published' || _status == 'closed'
                        ? 'Save changes'
                        : 'Publish opportunity',
                  ),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : () => _save('draft'),
                  child: const Text('Save draft'),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
