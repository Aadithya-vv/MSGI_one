import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../domain/auth_repository.dart';
import '../domain/onboarding.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);
  final sb.SupabaseClient _client;
  bool _recovering = false;
  AuthSession? _session() {
    final user = _client.auth.currentSession?.user;
    return user == null
        ? null
        : AuthSession(user.id, passwordRecovery: _recovering);
  }

  @override
  Stream<AuthSession?> get sessions => _client.auth.onAuthStateChange.map((
    event,
  ) {
    if (event.event == sb.AuthChangeEvent.passwordRecovery) _recovering = true;
    if (event.event == sb.AuthChangeEvent.signedOut) _recovering = false;
    return _session();
  });
  Future<T> _safe<T>(Future<T> Function() action) async {
    try {
      return await action().timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const AuthFailure();
    }
  }

  @override
  Future<AuthSession?> restoreSession() => _safe(() async {
    if (_client.auth.currentSession?.isExpired ?? false) {
      await _client.auth.refreshSession();
    }
    return _session();
  });
  @override
  Future<void> signIn(String email, String password) => _safe(() async {
    _recovering = false;
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  });
  @override
  Future<void> signUp(String email, String password) => _safe(() async {
    await _client.auth.signUp(email: email.trim(), password: password);
  });
  @override
  Future<void> requestPasswordReset(String email) =>
      _safe(() => _client.auth.resetPasswordForEmail(email.trim()));
  @override
  Future<void> updatePassword(String password) => _safe(() async {
    await _client.auth.updateUser(sb.UserAttributes(password: password));
    _recovering = false;
  });
  @override
  Future<void> signOut() => _safe(() => _client.auth.signOut());
  static MembershipState parseMembership(Map<String, dynamic> row) {
    final status = row['status'];
    if (status == 'suspended') return MembershipState.suspended;
    if (status == 'rejected') return MembershipState.rejected;
    if (status == null && row['profile_complete'] == false) {
      return MembershipState.incomplete;
    }
    if (row['profile_complete'] != true) {
      throw const AuthFailure('Membership data could not be verified.');
    }
    if (status == 'pending') return MembershipState.pending;
    if (status == 'verified' && row['verified_kind'] == 'student') {
      return MembershipState.verifiedStudent;
    }
    if (status == 'verified' && row['verified_kind'] == 'alumni') {
      return MembershipState.verifiedAlumni;
    }
    throw const AuthFailure('Membership data could not be verified.');
  }

  @override
  Future<MembershipState> loadMembership() => _safe(() async {
    final rows = await _client.rpc('my_membership') as List;
    if (rows.length != 1) throw const AuthFailure();
    return parseMembership(Map<String, dynamic>.from(rows.single as Map));
  });
  @override
  Future<OnboardingOptions> loadOnboardingOptions() => _safe(() async {
    final rows = await Future.wait([
      _client
          .from('institutions')
          .select('id,name')
          .eq('active', true)
          .order('name'),
      _client
          .from('departments')
          .select('id,name,institution_id')
          .eq('active', true)
          .order('name'),
      _client.from('skills').select('id,name').order('name').limit(200),
      _client
          .from('cities')
          .select('id,name,country_code')
          .order('name')
          .limit(200),
    ]);
    List<CatalogEntry> entries(List<Map<String, dynamic>> data) => data
        .map(
          (r) => CatalogEntry(
            id: r['id'] as String,
            name: r['name'] as String,
            institutionId: r['institution_id'] as String?,
            countryCode: r['country_code'] as String?,
          ),
        )
        .toList(growable: false);
    return OnboardingOptions(
      institutions: entries(rows[0]),
      departments: entries(rows[1]),
      skills: entries(rows[2]),
      cities: entries(rows[3]),
    );
  });
  @override
  Future<void> submitOnboarding(OnboardingInput input) => _safe(() async {
    final problem = input.validate();
    if (problem != null) throw AuthFailure(problem);
    await _client.rpc('submit_onboarding', params: input.toRpc());
  });
}
