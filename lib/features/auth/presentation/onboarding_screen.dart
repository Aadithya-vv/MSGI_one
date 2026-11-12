import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/errors/error_state.dart';
import '../../../core/widgets/one_widgets.dart';
import '../application/auth_providers.dart';
import '../domain/onboarding.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Complete your profile')),
    body: SafeArea(
      child: PageBody(
        children: [
          const FeatureHeader(
            eyebrow: 'Your membership begins here',
            title: 'Complete your profile',
            description: 'Student or alumni is a self-declaration, not verification. All new profiles require institutional review.',
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
                        message: 'An administrator must add approved institutions, departments and skills before registration can continue.',
                      )
                    : _OnboardingForm(options: options),
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
  const _OnboardingForm({required this.options});
  final OnboardingOptions options;
  @override
  ConsumerState<_OnboardingForm> createState() => _OnboardingFormState();
}

class _OnboardingFormState extends ConsumerState<_OnboardingForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _joining = TextEditingController(),
      _graduation = TextEditingController(),
      _designation = TextEditingController(),
      _interests = TextEditingController();
  AccountKind _kind = AccountKind.student;
  String? _institution, _department, _city, _error;
  final _skills = <String>{};
  bool _directory = false, _map = false, _busy = false;
  @override
  void dispose() {
    for (final c in [_name, _joining, _graduation, _designation, _interests]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final input = OnboardingInput(
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
    );
    final problem = input.validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).submitOnboarding(input);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Profile submission failed. No verification has been granted. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(TextEditingController c, String label, {bool number = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
          controller: c,
          enabled: !_busy,
          keyboardType: number ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(labelText: label),
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'This field is required.' : null,
        ),
      );
  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field(_name, 'Display name'),
        DropdownButtonFormField<AccountKind>(
          initialValue: _kind,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Student or alumni'),
          items: AccountKind.values
              .map(
                (k) => DropdownMenuItem(
                  value: k,
                  child: Text(k == AccountKind.student ? 'Student' : 'Alumni'),
                ),
              )
              .toList(),
          onChanged: _busy ? null : (v) => setState(() => _kind = v!),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Institution'),
          items: widget.options.institutions
              .map((e) => DropdownMenuItem(value: e.id, child: Text(e.name)))
              .toList(),
          validator: (v) => v == null ? 'Select an institution.' : null,
          onChanged: _busy
              ? null
              : (v) => setState(() {
                  _institution = v;
                  _department = null;
                }),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: ValueKey(_institution),
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Department'),
          items: widget.options.departments
              .where((d) => d.institutionId == _institution)
              .map((e) => DropdownMenuItem(value: e.id, child: Text(e.name)))
              .toList(),
          validator: (v) => v == null ? 'Select a department.' : null,
          onChanged: _busy ? null : (v) => setState(() => _department = v),
        ),
        const SizedBox(height: 16),
        _field(_joining, 'Joining year', number: true),
        _field(
          _graduation,
          'Graduation year (actual or expected)',
          number: true,
        ),
        TextFormField(
          controller: _designation,
          enabled: !_busy,
          maxLength: 120,
          decoration: const InputDecoration(
            labelText: 'Professional designation (if applicable)',
          ),
        ),
        const SizedBox(height: 16),
        _field(_interests, 'Career interests (comma separated)'),
        const Text('Skills — select 1–20'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.options.skills
              .map(
                (s) => FilterChip(
                  label: Text(s.name),
                  selected: _skills.contains(s.id),
                  onSelected: _busy
                      ? null
                      : (selected) => setState(() {
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
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'City / country (optional)',
          ),
          items: [
            const DropdownMenuItem(
              value: '',
              child: Text('Do not share a city'),
            ),
            ...widget.options.cities.map(
              (c) => DropdownMenuItem(
                value: c.id,
                child: Text('${c.name}, ${c.countryCode}'),
              ),
            ),
          ],
          onChanged: _busy
              ? null
              : (v) => setState(() => _city = v == '' ? null : v),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show my approved profile in the directory'),
          value: _directory,
          onChanged: _busy ? null : (v) => setState(() => _directory = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Include my approximate city on the map'),
          subtitle: const Text(
            'Requires directory visibility and a city. No precise location is stored.',
          ),
          value: _map,
          onChanged: _busy ? null : (v) => setState(() => _map = v),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Semantics(liveRegion: true, child: Text(_error!)),
          ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(
            _busy ? 'Submitting…' : 'Submit for institutional review',
          ),
        ),
      ],
    ),
  );
}
