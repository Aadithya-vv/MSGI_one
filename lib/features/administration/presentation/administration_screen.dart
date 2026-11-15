import 'administration_dashboard.dart';

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
      title: const Text('Institutional administration'),
      leading: BackButton(onPressed: () => context.go(AppRoutes.profile)),
    ),
    body: SafeArea(
      child: ref
          .watch(administrationContextProvider)
          .when(
            loading: () => const LoadingState(),
            error: (_, _) => ErrorState(
              message: 'Administrator access is required, or reviews could not be loaded. No privileges have been changed.',
              onRetry: () => ref.invalidate(administrationContextProvider),
            ),
            data: (summary) => AdministrationDashboard(
              summary: summary,
              onReview: (candidate) async {
                final saved = await showDialog<bool>(
                  context: context,
                  builder: (_) => _ReviewDialog(candidate: candidate),
                );
                if (!context.mounted) {
                  return;
                }
                ref.invalidate(administrationContextProvider);
                if (saved == true && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Membership decision recorded.'),
                    ),
                  );
                }
              },
            ),
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
  String _category = 'record_checked';
  final _requestId = administrationRequestId();
  bool _busy = false, _evidenceChecked = false;
  List<ReviewDecision> get allowed => switch (widget.candidate.status) {
    'verified' => [ReviewDecision.suspended, ReviewDecision.correction],
    'rejected' => [ReviewDecision.correction],
    'suspended' => [ReviewDecision.reinstate],
    _ => [
      ReviewDecision.verified,
      ReviewDecision.rejected,
      ReviewDecision.suspended,
    ],
  };
  @override
  void initState() {
    super.initState();
    _decision = allowed.first;
  }

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
      verifiedKind:
          (_decision == ReviewDecision.verified ||
              _decision == ReviewDecision.reinstate)
          ? _kind
          : null,
      revision: widget.candidate.revision,
      requestId: _requestId,
      category: _category,
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
          () => _error = 'Review unavailable or changed. Close, refresh the queue and inspect history before deciding again.',
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
              items: allowed
                  .map((d) => DropdownMenuItem(value: d, child: Text(d.name)))
                  .toList(),
              onChanged: _busy ? null : (v) => setState(() => _decision = v!),
            ),
            if (_decision == ReviewDecision.verified ||
                _decision == ReviewDecision.reinstate)
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _kind,
                decoration: const InputDecoration(
                  labelText: 'Verified account type',
                ),
                items: const [
                  DropdownMenuItem(value: 'student', child: Text('Student')),
                  DropdownMenuItem(value: 'alumni', child: Text('Alumni')),
                  DropdownMenuItem(
                    value: 'staff',
                    child: Text('Faculty / Staff'),
                  ),
                ],
                onChanged: _busy ? null : (v) => setState(() => _kind = v),
              ),
            DropdownButtonFormField<String>(
              initialValue: _category,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Safe reason category',
              ),
              items:
                  const [
                        'record_checked',
                        'details_mismatch',
                        'evidence_unavailable',
                        'policy_violation',
                        'appeal_review',
                        'duplicate_account',
                      ]
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.replaceAll('_', ' ')),
                        ),
                      )
                      .toList(),
              onChanged: _busy ? null : (v) => setState(() => _category = v!),
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
