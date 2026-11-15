import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../auth/application/auth_providers.dart';

final ownReviewStatusProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
      final access = ref.watch(authControllerProvider);
      if (access.userId == null) throw StateError('Sign in required');
      final client = ref.watch(supabaseClientProvider);
      if (client == null) throw StateError('Backend unavailable');
      return Map<String, dynamic>.from(
        await client
                .rpc('own_review_status')
                .timeout(const Duration(seconds: 20))
            as Map,
      );
    });

class MembershipRequestPanel extends ConsumerStatefulWidget {
  const MembershipRequestPanel({this.correction = false, super.key});
  final bool correction;
  @override
  ConsumerState<MembershipRequestPanel> createState() =>
      _MembershipRequestState();
}

class _MembershipRequestState extends ConsumerState<MembershipRequestPanel> {
  bool busy = false;
  String? message;
  @override
  Widget build(BuildContext context) => ref
      .watch(ownReviewStatusProvider)
      .when(
        loading: () => const LinearProgressIndicator(),
        error: (_, _) => TextButton(
          onPressed: () => ref.invalidate(ownReviewStatusProvider),
          child: const Text('Review information unavailable — retry'),
        ),
        data: (status) => Column(
          children: [
            if (status['category'] != null)
              Text(
                'Review category: ${(status['category'] as String).replaceAll('_', ' ')}',
              ),
            Text(
              const String.fromEnvironment('INSTITUTIONAL_SUPPORT_LABEL')
                      .isEmpty
                  ? 'Use an approved institutional channel for evidence or clarification. No support contact has been configured. Do not send documents, passwords or recovery links here. A request never restores access automatically.'
                  : 'Approved support channel: ${const String.fromEnvironment('INSTITUTIONAL_SUPPORT_LABEL')}. Do not send documents, passwords or recovery links here. Requests do not restore access automatically.',
            ),
            if (status['request_open'] == true)
              const Text(
                'Your review request is awaiting an authorized decision.',
              )
            else
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () async {
                        setState(() => busy = true);
                        try {
                          await ref
                              .read(supabaseClientProvider)!
                              .rpc(
                                'request_membership_review',
                                params: {
                                  'p_kind': widget.correction
                                      ? 'correction'
                                      : 'appeal',
                                },
                              )
                              .timeout(const Duration(seconds: 20));
                          if (mounted) {
                            setState(
                              () => message = 'Request recorded. Current access restrictions remain.',
                            );
                            ref.invalidate(ownReviewStatusProvider);
                          }
                        } catch (_) {
                          if (mounted) {
                            setState(
                              () => message = 'Request unavailable or limit reached. Use the approved institutional channel.',
                            );
                          }
                        } finally {
                          if (mounted) setState(() => busy = false);
                        }
                      },
                child: Text(
                  busy
                      ? 'Submitting…'
                      : widget.correction
                      ? 'Request academic correction'
                      : 'Request institutional review',
                ),
              ),
            if (message != null)
              Semantics(liveRegion: true, child: Text(message!)),
          ],
        ),
      );
}
