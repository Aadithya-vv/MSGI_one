import 'dart:async';

import 'package:msgi_one/features/auth/domain/auth_repository.dart';
import 'package:msgi_one/features/auth/domain/onboarding.dart';

/// Test-only dependency. Never wired into application bootstrap or production.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.session,
    this.membership = MembershipState.verifiedAlumni,
  });
  AuthSession? session;
  MembershipState membership;
  final events = StreamController<AuthSession?>.broadcast(sync: true);
  bool failMembership = false, failRestore = false, failLogout = false;
  int signInCalls = 0, signUpCalls = 0, recoveryCalls = 0, passwordUpdates = 0;
  Completer<MembershipState>? membershipRequest;
  Completer<AuthSession?>? restorationRequest;
  OnboardingInput? submitted;
  @override
  Stream<AuthSession?> get sessions => events.stream;
  @override
  Future<AuthSession?> restoreSession() async {
    if (failRestore) throw const AuthFailure();
    return restorationRequest?.future ?? Future.value(session);
  }

  void emit(AuthSession? value) {
    session = value;
    events.add(value);
  }

  @override
  Future<void> signIn(String email, String password) async {
    signInCalls++;
    emit(const AuthSession('test-user'));
  }

  @override
  Future<void> signUp(String email, String password) async {
    signUpCalls++;
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    recoveryCalls++;
  }

  @override
  Future<void> updatePassword(String password) async {
    passwordUpdates++;
  }

  @override
  Future<void> signOut() async {
    if (failLogout) throw const AuthFailure();
    emit(null);
  }

  @override
  Future<MembershipState> loadMembership() async {
    if (failMembership) throw const AuthFailure();
    return membershipRequest?.future ?? Future.value(membership);
  }

  @override
  Future<OnboardingOptions> loadOnboardingOptions() async =>
      const OnboardingOptions(
        institutions: [
          CatalogEntry(id: 'institution', name: 'Test institution'),
        ],
        departments: [
          CatalogEntry(
            id: 'department',
            name: 'Test department',
            institutionId: 'institution',
          ),
        ],
        skills: [CatalogEntry(id: 'skill', name: 'Test skill')],
        cities: [
          CatalogEntry(id: 'city', name: 'Test city', countryCode: 'IN'),
        ],
      );
  @override
  Future<void> submitOnboarding(OnboardingInput input) async {
    submitted = input;
    membership = MembershipState.pending;
  }

  Future<void> dispose() => events.close();
}
