import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/errors/error_state.dart';
import '../../../core/widgets/one_widgets.dart';
import '../application/auth_providers.dart';
import '../domain/onboarding.dart';
import '../domain/auth_repository.dart';
import '../../profile/data/profile_providers.dart';
import '../../catalog/domain/catalog_repository.dart';
import '../../catalog/presentation/catalog_picker.dart';

OnboardingInput? _resumeInput(
  Map<String, dynamic>? draft,
  OnboardingInput? own,
  bool verified,
) {
  if (draft == null) return own;
  final content = {...draft};
  if (verified && own != null) {
    final saved = own.toJson();
    for (final key in [
      'kind',
      'institution_id',
      'department_id',
      'joining_year',
      'graduation_year',
    ]) {
      content[key] = saved[key];
    }
  }
  return OnboardingInput.fromJson(content);
}

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      title: const Text('Complete your profile'),
      leading:
          ref.watch(authControllerProvider).isVerified ||
              ref.watch(authControllerProvider).phase == AccessPhase.pending
          ? BackButton(
              onPressed: () => context.go(
                ref.read(authControllerProvider).isVerified
                    ? AppRoutes.profile
                    : AppRoutes.pending,
              ),
            )
          : null,
    ),
    body: SafeArea(
      child: PageBody(
        children: [
          const FeatureHeader(
            eyebrow: 'Your membership begins here',
            title: 'Complete your profile',
            description: 'Save progress privately and resume later. Student or alumni is a claim; institutional review grants access.',
          ),
          ref
              .watch(onboardingOptionsProvider)
              .when(
                loading: () => const LoadingState(),
                error: (_, _) => ErrorState(
                  message: 'Institutional options could not be loaded.',
                  onRetry: () => ref.invalidate(onboardingOptionsProvider),
                ),
                data: (options) =>
                    options.institutions.isEmpty ||
                        options.departments.isEmpty ||
                        options.skills.isEmpty
                    ? const EmptyState(
                        title: 'Institutional catalog is not ready',
                        message: 'Approved institutions, departments and skills are required before registration can continue.',
                      )
                    : ref
                          .watch(profileDraftProvider)
                          .when(
                            loading: () => const LoadingState(),
                            error: (_, _) => ErrorState(
                              message: 'Saved progress unavailable.',
                              onRetry: () =>
                                  ref.invalidate(profileDraftProvider),
                            ),
                            data: (draft) => ref
                                .watch(ownProfileProvider)
                                .when(
                                  loading: () => const LoadingState(),
                                  error: (_, _) => ErrorState(
                                    message:
                                        'Your profile could not be loaded.',
                                    onRetry: () =>
                                        ref.invalidate(ownProfileProvider),
                                  ),
                                  data: (own) => _OnboardingForm(
                                    options: options,
                                    initial: _resumeInput(
                                      ref
                                              .read(onboardingBufferProvider)
                                              ?.toJson() ??
                                          draft,
                                      own?.input,
                                      ref
                                          .read(authControllerProvider)
                                          .isVerified,
                                    ),
                                  ),
                                ),
                          ),
              ),
          TextButton(
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
            child: const Text('Log out'),
          ),
        ],
      ),
    ),
  );
}

class _OnboardingForm extends ConsumerStatefulWidget {
  const _OnboardingForm({required this.options, this.initial});
  final OnboardingOptions options;
  final OnboardingInput? initial;
  @override
  ConsumerState<_OnboardingForm> createState() => _OnboardingFormState();
}

class _OnboardingFormState extends ConsumerState<_OnboardingForm> {
  final _careerSection = GlobalKey(), _privacySection = GlobalKey();
  int _step = 0;
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _joining = TextEditingController(),
      _graduation = TextEditingController(),
      _designation = TextEditingController(),
      _interests = TextEditingController(),
      _company = TextEditingController(),
      _domain = TextEditingController(),
      _bio = TextEditingController(),
      _degree = TextEditingController();
  AccountKind _kind = AccountKind.student;
  String? _institution, _department, _city, _error;
  final _skills = <String>{};
  bool _readyToRemember = false, _submitted = false;
  bool _departmentLoading = false;
  bool _directory = false, _map = false, _mentoring = false, _busy = false;
  late List<CatalogEntry> _institutions, _departments, _skillOptions, _cities;
  @override
  void initState() {
    super.initState();
    for (final c in [
      _name,
      _joining,
      _graduation,
      _designation,
      _interests,
      _company,
      _domain,
      _bio,
      _degree,
    ]) {
      c.addListener(_remember);
    }
    _institutions = [...widget.options.institutions];
    _departments = [...widget.options.departments];
    _skillOptions = [...widget.options.skills];
    _cities = [...widget.options.cities];
    Future.microtask(() {
      if (mounted) _readyToRemember = true;
    });
    final i = widget.initial;
    if (i == null) {
      _readyToRemember = true;
      return;
    }
    _name.text = i.displayName;
    _kind = i.kind;
    _institution = i.institutionId.isEmpty ? null : i.institutionId;
    _department = i.departmentId.isEmpty ? null : i.departmentId;
    _joining.text = i.joiningYear == 0 ? '' : '${i.joiningYear}';
    _graduation.text = i.graduationYear == 0 ? '' : '${i.graduationYear}';
    _designation.text = i.designation;
    _interests.text = i.interests.join(', ');
    _skills.addAll(i.skillIds);
    _city = i.cityId;
    _directory = i.directoryVisible;
    _map = i.mapOptIn;
    _company.text = i.company;
    _domain.text = i.professionalDomain;
    _bio.text = i.biography;
    _degree.text = i.degree;
    _mentoring = i.mentoring;
    // Preserve saved selections outside the first catalog page without pretending
    // their labels are official. New choices still require real catalog results.
    if (_institution != null &&
        !_institutions.any((e) => e.id == _institution)) {
      _institutions.add(
        CatalogEntry(id: _institution!, name: 'Saved institution'),
      );
    }
    if (_department != null && !_departments.any((e) => e.id == _department)) {
      _departments.add(
        CatalogEntry(
          id: _department!,
          name: 'Saved department',
          institutionId: _institution,
        ),
      );
    }
    if (_city != null && !_cities.any((e) => e.id == _city)) {
      _cities.add(CatalogEntry(id: _city!, name: 'Saved city'));
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _joining,
      _graduation,
      _designation,
      _interests,
      _company,
      _domain,
      _bio,
      _degree,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  OnboardingInput _input() => OnboardingInput(
    displayName: _name.text,
    kind: _kind,
    institutionId: _institution ?? '',
    departmentId: _department ?? '',
    joiningYear: int.tryParse(_joining.text) ?? 0,
    graduationYear: int.tryParse(_graduation.text) ?? 0,
    designation: _designation.text,
    interests: _interests.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(),
    skillIds: _skills.toList(),
    cityId: _city,
    directoryVisible: _directory,
    mapOptIn: _map,
    company: _company.text,
    professionalDomain: _domain.text,
    biography: _bio.text,
    degree: _degree.text,
    mentoring: _mentoring,
  );
  void _remember() {
    if (mounted && _readyToRemember && !_submitted) {
      ref.read(onboardingBufferProvider.notifier).store(_input());
    }
  }

  void _update(VoidCallback change) {
    setState(change);
    _remember();
  }

  Future<void> _chooseInstitution(String? value) async {
    _update(() {
      _institution = value;
      _department = null;
      _departmentLoading = false;
    });
    if (value == null || _departments.any((d) => d.institutionId == value)) {
      return;
    }
    _update(() => _departmentLoading = true);
    try {
      final rows = await ref
          .read(catalogRepositoryProvider)
          .search(CatalogKind.departments, institutionId: value);
      if (mounted && _institution == value) {
        _update(() => _departments.addAll(rows));
      }
    } catch (_) {
      if (mounted && _institution == value) {
        _update(
          () => _error = 'Departments could not be loaded. Retry using Search more catalog options.',
        );
      }
    } finally {
      if (mounted && _institution == value) {
        _update(() => _departmentLoading = false);
      }
    }
  }

  Future<void> _save({bool draft = false}) async {
    final input = _input();
    if (!draft) {
      if (!_form.currentState!.validate()) return;
      final problem = input.validate();
      if (problem != null) {
        _update(() => _error = problem);
        return;
      }
    }
    _update(() {
      _busy = true;
      _error = null;
    });
    try {
      if (draft) {
        await ref.read(profileRepositoryProvider).saveDraft(input.toJson());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Progress saved privately to your account.'),
            ),
          );
        }
      } else {
        await ref.read(authControllerProvider.notifier).submitOnboarding(input);
        _submitted = true;
        ref.read(onboardingBufferProvider.notifier).store(null);
        ref.invalidate(ownProfileProvider);
        ref.invalidate(profileDraftProvider);
        if (mounted) {
          context.go(
            ref.read(authControllerProvider).isVerified
                ? AppRoutes.profile
                : AppRoutes.pending,
          );
        }
      }
    } catch (_) {
      if (mounted) {
        _update(
          () => _error = 'Save failed. Your entries remain here; retry. No verification has been granted.',
        );
      }
    } finally {
      if (mounted) _update(() => _busy = false);
    }
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool number = false,
    bool required = true,
    bool locked = false,
    int? max,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: c,
      enabled: !_busy && !locked,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      maxLength: max,
      decoration: InputDecoration(labelText: label),
      validator: (v) => required && (v == null || v.trim().isEmpty)
          ? 'This field is required.'
          : null,
    ),
  );
  Widget _select(
    String label,
    String? value,
    List<CatalogEntry> items,
    ValueChanged<String?> change, {
    bool locked = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: DropdownButtonFormField<String>(
      key: ValueKey('$label-$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: items
          .map((e) => DropdownMenuItem(value: e.id, child: Text(e.name)))
          .toList(),
      validator: (v) => v == null ? 'Select $label.' : null,
      onChanged: _busy || locked ? null : change,
    ),
  );
  @override
  Widget build(BuildContext context) {
    final verified = ref.watch(authControllerProvider).isVerified;
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: 'Onboarding section ${_step + 1} of 3',
            child: LinearProgressIndicator(value: (_step + 1) / 3),
          ),
          Text('Section ${_step + 1} of 3 · Save progress at any time'),
          const SectionHeading('1. Identity and education'),
          _field(_name, 'Display name', max: 80),
          DropdownButtonFormField<AccountKind>(
            initialValue: _kind,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Student or alumni'),
            items: AccountKind.values
                .map(
                  (k) => DropdownMenuItem(
                    value: k,
                    child: Text(
                      k == AccountKind.student ? 'Student' : 'Alumni',
                    ),
                  ),
                )
                .toList(),
            onChanged: _busy || verified
                ? null
                : (v) => _update(() => _kind = v!),
          ),
          const SizedBox(height: 16),
          _select(
            'Institution',
            _institution,
            _institutions,
            _chooseInstitution,
            locked: verified,
          ),
          if (_departmentLoading) const LinearProgressIndicator(),
          _select(
            'Department',
            _department,
            _departments.where((d) => d.institutionId == _institution).toList(),
            (v) => _update(() => _department = v),
            locked: verified,
          ),
          _field(_joining, 'Joining year', number: true, locked: verified),
          _field(
            _graduation,
            'Graduation year (actual or expected)',
            number: true,
            locked: verified,
          ),
          if (verified)
            const Text(
              'Verified education changes require institutional review.',
            ),
          _field(
            _degree,
            'Degree / qualification (optional)',
            required: false,
            max: 120,
          ),
          TextButton(
            onPressed: () {
              _update(() => _step = 1);
              Scrollable.ensureVisible(
                _careerSection.currentContext!,
                duration: const Duration(milliseconds: 250),
              );
            },
            child: const Text('Continue to career and expertise'),
          ),
          SectionHeading('2. Career and expertise', key: _careerSection),
          _field(
            _designation,
            'Professional designation (if applicable)',
            required: false,
            max: 120,
          ),
          if (_kind == AccountKind.alumni) ...[
            _field(
              _company,
              'Company / organization (optional)',
              required: false,
              max: 120,
            ),
            _field(
              _domain,
              'Professional domain (optional)',
              required: false,
              max: 120,
            ),
            _field(
              _bio,
              'Professional biography (optional)',
              required: false,
              max: 1000,
            ),
            SwitchListTile(
              title: const Text('Available for mentoring'),
              value: _mentoring,
              onChanged: _busy ? null : (v) => _update(() => _mentoring = v),
            ),
          ],
          _field(_interests, 'Career interests (comma separated)'),
          Text('Skills — select 1–20 (${_skills.length} selected)'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _skillOptions
                .map(
                  (s) => FilterChip(
                    label: Text(s.name),
                    selected: _skills.contains(s.id),
                    onSelected: _busy
                        ? null
                        : (selected) => _update(() {
                            if (selected) {
                              _skills.add(s.id);
                            } else {
                              _skills.remove(s.id);
                            }
                          }),
                  ),
                )
                .toList(),
          ),
          TextButton(
            onPressed: () {
              _update(() => _step = 2);
              Scrollable.ensureVisible(
                _privacySection.currentContext!,
                duration: const Duration(milliseconds: 250),
              );
            },
            child: const Text('Continue to location and privacy'),
          ),
          SectionHeading('3. Location and privacy', key: _privacySection),
          _select(
            'City / country (optional)',
            _city ?? '',
            [
              const CatalogEntry(id: '', name: 'Do not share a city'),
              ..._cities.map(
                (c) => CatalogEntry(
                  id: c.id,
                  name:
                      '${c.name}${c.countryCode == null ? '' : ', ${c.countryCode}'}',
                ),
              ),
            ],
            (v) => _update(() {
              _city = v == '' ? null : v;
              if (_city == null) _map = false;
            }),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show my approved profile in the directory'),
            subtitle: const Text(
              'Shares your professional biography, career, education and skills with verified members after approval.',
            ),
            value: _directory,
            onChanged: _busy
                ? null
                : (v) => _update(() {
                    _directory = v;
                    if (!v) _map = false;
                  }),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Include my approximate city on the map'),
            subtitle: const Text(
              'Requires directory visibility and a city. No precise location is stored.',
            ),
            value: _map,
            onChanged: _busy || !_directory || _city == null
                ? null
                : (v) => _update(() => _map = v),
          ),
          ExpansionTile(
            title: const Text('Search more catalog options'),
            children: [
              if (!verified)
                CatalogPicker(
                  kind: CatalogKind.institutions,
                  label: 'Institutions',
                  enabled: !_busy,
                  onSelected: (e) {
                    _update(() {
                      if (!_institutions.any((x) => x.id == e.id)) {
                        _institutions.add(e);
                      }
                    });
                    _chooseInstitution(e.id);
                  },
                ),
              if (!verified && _institution != null)
                CatalogPicker(
                  key: ValueKey(_institution),
                  kind: CatalogKind.departments,
                  institutionId: _institution,
                  label: 'Departments',
                  enabled: !_busy,
                  onSelected: (e) => _update(() {
                    if (!_departments.any((x) => x.id == e.id)) {
                      _departments.add(e);
                    }
                    _department = e.id;
                  }),
                ),
              CatalogPicker(
                kind: CatalogKind.skills,
                label: 'Skills',
                enabled: !_busy,
                onSelected: (e) => _update(() {
                  if (!_skillOptions.any((x) => x.id == e.id)) {
                    _skillOptions.add(e);
                  }
                  _skills.add(e.id);
                }),
              ),
              CatalogPicker(
                kind: CatalogKind.cities,
                label: 'Cities',
                enabled: !_busy,
                onSelected: (e) => _update(() {
                  if (!_cities.any((x) => x.id == e.id)) _cities.add(e);
                  _city = e.id;
                }),
              ),
            ],
          ),
          if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
          OutlinedButton(
            onPressed: _busy ? null : () => _save(draft: true),
            child: const Text('Save progress privately'),
          ),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(
              _busy
                  ? 'Submitting…'
                  : verified
                  ? 'Save profile changes'
                  : 'Submit for institutional review',
            ),
          ),
        ],
      ),
    );
  }
}
