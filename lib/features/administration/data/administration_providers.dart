import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_providers.dart';
import '../domain/administration_repository.dart';

class SupabaseAdministrationRepository implements AdministrationRepository {
  SupabaseAdministrationRepository(this.client);
  final SupabaseClient client;
  @override
  Future<Map<String, dynamic>> context() async => Map<String, dynamic>.from(
    await client
            .rpc('administration_context')
            .timeout(const Duration(seconds: 20))
        as Map,
  );
  @override
  Future<List<MembershipCandidate>> members({
    String status = 'pending',
    String? kind,
    int offset = 0,
  }) async {
    final rows = await client
        .rpc(
          'administration_members',
          params: {
            'p_status': status,
            'p_kind': kind,
            'p_offset': offset,
            'p_limit': 30,
          },
        )
        .timeout(const Duration(seconds: 20));
    return (rows as List)
        .map(
          (r) => MembershipCandidate(
            id: r['user_id'],
            name: r['display_name'],
            claimedKind: r['claimed_kind'],
            institutionId: r['institution_id'],
            departmentId: r['department_id'],
            joiningYear: r['joining_year'],
            graduationYear: r['graduation_year'],
            programme: r['programme'] ?? '',
            affiliation: r['affiliation'] ?? '',
            institution: r['institution'] ?? '',
            department: r['department'] ?? '',
            revision: r['revision'],
            status: r['status'],
            requestKind: r['request_kind'],
            professional: [
              r['designation'],
              r['company'],
              r['professional_domain'],
            ].whereType<String>().where((v) => v.isNotEmpty).join(' · '),
          ),
        )
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> history(
    String userId, {
    int offset = 0,
  }) async =>
      (await client
                  .rpc(
                    'administration_history',
                    params: {'p_user': userId, 'p_offset': offset},
                  )
                  .timeout(const Duration(seconds: 20))
              as List)
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
  @override
  Future<List<Map<String, dynamic>>> reports({
    String status = 'open',
    int offset = 0,
  }) async =>
      (await client
                  .rpc(
                    'administration_reports',
                    params: {'p_status': status, 'p_offset': offset},
                  )
                  .timeout(const Duration(seconds: 20))
              as List)
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
  @override
  Future<void> moderate(
    Map<String, dynamic> report,
    String status,
    String note,
    String requestId,
  ) async {
    await client
        .rpc(
          'decide_institutional_report',
          params: {
            'p_report': report['id'],
            'p_status': status,
            'p_note': note.trim(),
            'p_revision': report['revision'],
            'p_request': requestId,
          },
        )
        .timeout(const Duration(seconds: 20));
  }

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
    if (input.revision != null) {
      await client
          .rpc(
            'decide_institutional_membership',
            params: {
              'p_user': input.userId,
              'p_action': switch (input.decision) {
                ReviewDecision.verified => 'approve',
                ReviewDecision.rejected => 'reject',
                ReviewDecision.suspended => 'suspend',
                ReviewDecision.reinstate => 'reinstate',
                ReviewDecision.correction => 'correction',
              },
              'p_kind': input.verifiedKind,
              'p_category': input.category,
              'p_note': input.reason.trim(),
              'p_revision': input.revision,
              'p_request': input.requestId,
            },
          )
          .timeout(const Duration(seconds: 20));
      return;
    }
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

final administrationContextProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
      final access = ref.watch(authControllerProvider);
      if (!access.isVerified) {
        throw StateError('Verified administrator required');
      }
      return ref.watch(administrationRepositoryProvider).context();
    });
