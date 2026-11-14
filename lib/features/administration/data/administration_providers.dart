import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_providers.dart';
import '../domain/administration_repository.dart';

class SupabaseAdministrationRepository implements AdministrationRepository {
  SupabaseAdministrationRepository(this.client);
  final SupabaseClient client;
  @override
  Future<List<MembershipCandidate>> pending({int limit = 30}) async {
    final rows = await client
        .rpc('pending_memberships_v2', params: {'p_limit': limit})
        .timeout(const Duration(seconds: 20));
    return (rows as List)
        .map(
          (r) => MembershipCandidate(
            id: r['user_id'] as String,
            name: r['display_name'] as String,
            claimedKind: r['claimed_kind'] as String,
            institutionId: r['institution_id'] as String,
            departmentId: r['department_id'] as String?,
            joiningYear: r['joining_year'] as int?,
            graduationYear: r['graduation_year'] as int?,
            programme: r['programme'] as String? ?? '',
            affiliation: r['affiliation'] as String? ?? '',
            institution: r['institution'] as String? ?? '',
            department: r['department'] as String? ?? '',
          ),
        )
        .toList();
  }

  @override
  Future<void> review(MembershipReview input) async {
    final problem = input.validate(client.auth.currentUser?.id);
    if (problem != null) throw ArgumentError(problem);
    await client
        .rpc(
          'review_membership',
          params: {
            'p_user_id': input.userId,
            'p_status': input.decision.name,
            'p_verified_kind': input.verifiedKind,
            'p_reason': input.reason.trim(),
          },
        )
        .timeout(const Duration(seconds: 20));
  }
}

final administrationRepositoryProvider = Provider<AdministrationRepository>((
  ref,
) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) throw StateError('Backend unavailable');
  return SupabaseAdministrationRepository(client);
});
final pendingReviewsProvider =
    FutureProvider.autoDispose<List<MembershipCandidate>>((ref) {
      final state = ref.watch(authControllerProvider);
      if (!state.isVerified) {
        throw StateError('Verified administrator required');
      }
      return ref.watch(administrationRepositoryProvider).pending(limit: 100);
    });
