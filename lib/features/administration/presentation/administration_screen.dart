import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/one_widgets.dart';
import '../../../core/errors/error_state.dart';
import '../../auth/application/auth_providers.dart';
import '../data/administration_providers.dart';
import '../domain/administration_repository.dart';

class AdministrationScreen extends ConsumerWidget {
  const AdministrationScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      title: const Text('Membership review'),
      leading: BackButton(onPressed: () => context.go(AppRoutes.profile)),
    ),
    body: SafeArea(
      child: PageBody(
        children: [
          const FeatureHeader(
            eyebrow: 'Trusted institutional review',
            title: 'Review pending memberships',
            description: 'Check identity and institutional evidence through approved channels. An account claim or email confirmation is not institutional verification.',
          ),
          ref
              .watch(pendingReviewsProvider)
              .when(
                loading: () => const LoadingState(),
                error: (_, _) => ErrorState(
                  message: 'Administrator access is required, or reviews could not be loaded. No privileges have been changed.',
                  onRetry: () => ref.invalidate(pendingReviewsProvider),
                ),
                data: (people) => Column(
                  children: [
                    if (people.isEmpty)
                      const EmptyState(
                        title: 'No pending reviews',
                        message: 'Submitted profiles awaiting verification appear here.',
                      ),
                    for (final p in people)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                p.name,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              Text(
                                'Claimed ${p.claimedKind} · ${p.joiningYear}–${p.graduationYear}',
                              ),
                              SelectableText(
                                'Account: ${p.id}\nInstitution: ${p.institutionId}\nDepartment: ${p.departmentId}',
                              ),
                              OutlinedButton(
                                onPressed:
                                    p.id ==
                                        ref.read(authControllerProvider).userId
                                    ? null
                                    : () async {
                                        final saved = await showDialog<bool>(
                                          context: context,
                                          builder: (_) =>
                                              _ReviewDialog(candidate: p),
                                        );
                                        if (saved == true && context.mounted) {
                                          ref.invalidate(
                                            pendingReviewsProvider,
                                          );
                                        }
                                      },
                                child: const Text('Review evidence and decide'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (people.length == 100)
                      const Text(
                        'Showing the first 100 pending profiles. Process reviews and refresh for further accounts.',
                      ),
                    TextButton(
                      onPressed: () => ref.invalidate(pendingReviewsProvider),
                      child: const Text('Refresh pending reviews'),
                    ),
                  ],
                ),
              ),
        ],
      ),
    ),
  );
}

class _ReviewDialog extends ConsumerStatefulWidget {
  const _ReviewDialog({required this.candidate});
  final MembershipCandidate candidate;
  @override
  ConsumerState<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends ConsumerState<_ReviewDialog> {
  final _reason = TextEditingController();
  ReviewDecision _decision = ReviewDecision.verified;
  String? _kind, _error;
  bool _busy = false, _evidenceChecked = false;
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final input = MembershipReview(
      userId: widget.candidate.id,
      decision: _decision,
      reason: _reason.text,
      verifiedKind: _decision == ReviewDecision.verified ? _kind : null,
    );
    final problem = input.validate(ref.read(authControllerProvider).userId);
    if (problem != null || !_evidenceChecked) {
      setState(
        () => _error = problem ?? 'Confirm independent evidence review first.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(administrationRepositoryProvider).review(input);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Review failed. Confirm email, current permissions and account state, then retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text('Review ${widget.candidate.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<ReviewDecision>(
              initialValue: _decision,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Decision'),
              items: ReviewDecision.values
                  .map((d) => DropdownMenuItem(value: d, child: Text(d.name)))
                  .toList(),
              onChanged: _busy ? null : (v) => setState(() => _decision = v!),
            ),
            if (_decision == ReviewDecision.verified)
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _kind,
                decoration: const InputDecoration(
                  labelText: 'Verified account type',
                ),
                items: const [
                  DropdownMenuItem(value: 'student', child: Text('Student')),
                  DropdownMenuItem(value: 'alumni', child: Text('Alumni')),
                ],
                onChanged: _busy ? null : (v) => setState(() => _kind = v),
              ),
            TextField(
              controller: _reason,
              enabled: !_busy,
              maxLength: 1000,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Private audit reason',
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'I independently reviewed the required evidence.',
              ),
              value: _evidenceChecked,
              onChanged: _busy
                  ? null
                  : (v) => setState(() => _evidenceChecked = v!),
            ),
            if (_error != null)
              Semantics(liveRegion: true, child: Text(_error!)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Saving…' : 'Confirm review'),
        ),
      ],
    ),
  );
}
