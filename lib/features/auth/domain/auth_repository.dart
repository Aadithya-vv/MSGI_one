import 'onboarding.dart';

class AuthSession {
  const AuthSession(this.userId, {this.passwordRecovery = false});
  final String userId;
  final bool passwordRecovery;
}

enum MembershipState {
  incomplete,
  pending,
  verifiedStudent,
  verifiedAlumni,
  rejected,
  suspended,
}

enum AccessPhase {
  loading,
  configurationRequired,
  signedOut,
  incomplete,
  pending,
  verifiedStudent,
  verifiedAlumni,
  rejected,
  suspended,
  passwordRecovery,
  error,
}

class AccessState {
  const AccessState(this.phase, {this.userId});
  final AccessPhase phase;
  final String? userId;
  bool get isVerified =>
      phase == AccessPhase.verifiedStudent ||
      phase == AccessPhase.verifiedAlumni;
}

class AuthFailure implements Exception {
  const AuthFailure([
    this.message = 'Unable to complete the request. Please try again.',
  ]);
  final String message;
  @override
  String toString() => message;
}

abstract interface class AuthRepository {
  Stream<AuthSession?> get sessions;
  Future<AuthSession?> restoreSession();
  Future<void> signIn(String email, String password);
  Future<void> signUp(String email, String password);
  Future<void> requestPasswordReset(String email);
  Future<void> updatePassword(String password);
  Future<void> signOut();
  Future<MembershipState> loadMembership();
  Future<OnboardingOptions> loadOnboardingOptions();
  Future<void> submitOnboarding(OnboardingInput input);
}

abstract final class AuthValidation {
  static String? email(String? value) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value?.trim() ?? '')
      ? null
      : 'Enter a valid email address.';
  static String? password(String? value) =>
      value != null && value.length >= 12 && value.length <= 128
      ? null
      : 'Use a password of 12–128 characters.';
}
