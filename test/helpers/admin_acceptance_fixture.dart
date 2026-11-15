// Synthetic test-only authorization/repository fixtures, never application wiring.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:msgi_one/app.dart';
import 'package:msgi_one/core/routing/app_router.dart';
import 'package:msgi_one/core/routing/app_routes.dart';
import 'package:msgi_one/features/administration/data/administration_providers.dart';
import 'package:msgi_one/features/administration/domain/administration_repository.dart';
import 'package:msgi_one/features/auth/application/auth_providers.dart';
import 'package:msgi_one/features/auth/domain/auth_repository.dart';
import 'package:material_ui/material_ui.dart';

import 'fake_auth_repository.dart';

class AdminAcceptanceRepository extends AdministrationRepository {
  bool authorized = true, moderated = false, fail = false;
  int memberCalls = 0, lastOffset = 0, reviewCalls = 0;
  String? lastStatus, lastKind;
  @override
  Future<Map<String, dynamic>> context() async {
    if (!authorized) throw StateError('PRIVATE DATABASE DETAIL');
    return {'pending': 31, 'reports': 1, 'requests': 1};
  }

  @override
  Future<List<MembershipCandidate>> pending({int limit = 30}) => members();
  @override
  Future<List<MembershipCandidate>> members({
    String status = 'pending',
    String? kind,
    int offset = 0,
  }) async {
    memberCalls++;
    lastOffset = offset;
    lastStatus = status;
    lastKind = kind;
    if (fail) throw StateError('PRIVATE DATABASE DETAIL');
    return List.generate(
      offset == 0 ? 30 : 1,
      (i) => MembershipCandidate(
        id: 'synthetic-${offset + i}',
        name: '[SYNTHETIC] Reviewer acceptance ${offset + i}',
        claimedKind: kind ?? 'alumni',
        institutionId: 'synthetic-institute',
        departmentId: null,
        joiningYear: 2020,
        graduationYear: 2024,
        programme: 'Synthetic programme for UI tests only',
        status: status,
        revision: '2026-01-01T00:00:00Z',
        requestKind: i == 0 ? 'appeal' : null,
      ),
    );
  }

  @override
  Future<void> review(MembershipReview input) async {
    reviewCalls++;
  }

  @override
  Future<List<Map<String, dynamic>>> history(
    String userId, {
    int offset = 0,
  }) async => [
    {
      'action': 'reject',
      'category': 'evidence_unavailable',
      'note': '[SYNTHETIC] Evidence awaiting independent review',
      'before_state': {'status': 'pending'},
      'after_state': {'status': 'rejected'},
      'actor_id': 'synthetic-reviewer',
      'created_at': '2026-11-15',
    },
  ];
  @override
  Future<List<Map<String, dynamic>>> reports({
    String status = 'open',
    int offset = 0,
  }) async => moderated
      ? []
      : [
          {
            'id': 'synthetic-report',
            'reason': 'privacy',
            'status': 'open',
            'details': '[SYNTHETIC] Privacy report for UI acceptance only.',
            'target_profile_id': 'synthetic-subject',
            'target_opportunity_id': null,
            'prior_reports': 2,
            'revision': '2026-01-01T00:00:00Z',
          },
        ];
  @override
  Future<void> moderate(
    Map<String, dynamic> report,
    String status,
    String note,
    String requestId,
  ) async {
    moderated = true;
  }
}

Widget adminAcceptanceApp(
  AdminAcceptanceRepository repo,
  FakeAuthRepository auth,
) => ProviderScope(
  overrides: [
    authRepositoryProvider.overrideWithValue(auth),
    administrationRepositoryProvider.overrideWithValue(repo),
    initialLocationProvider.overrideWithValue(AppRoutes.administration),
  ],
  child: const OneApp(),
);
FakeAuthRepository adminAcceptanceAuth() => FakeAuthRepository(
  session: const AuthSession('synthetic-reviewer'),
  membership: MembershipState.verifiedStaff,
);
