import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/backend_config.dart';
import '../data/supabase_auth_repository.dart';
import '../domain/auth_repository.dart';
import '../domain/onboarding.dart';

final backendConfigProvider = Provider<BackendConfig>(
  (ref) => BackendConfig.fromEnvironment(),
);
final backendInitializationErrorProvider = Provider<String?>((ref) => null);
final supabaseClientProvider = Provider<SupabaseClient?>((ref) => null);
final authRepositoryProvider = Provider<AuthRepository?>((ref) {
  if (ref.watch(backendConfigProvider).problem != null ||
      ref.watch(backendInitializationErrorProvider) != null) {
    return null;
  }
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : SupabaseAuthRepository(client);
});
final onboardingOptionsProvider = FutureProvider<OnboardingOptions>((
  ref,
) async {
  final repository = ref.watch(authRepositoryProvider);
  if (repository == null) throw const AuthFailure();
  return repository.loadOnboardingOptions();
});
final authControllerProvider = NotifierProvider<AuthController, AccessState>(
  AuthController.new,
);

class AuthController extends Notifier<AccessState> {
  AuthRepository? _repository;
  AuthSession? _session;
  int _generation = 0;
  bool _disposed = false;
  bool _logoutBlocked = false;
  @override
  AccessState build() {
    _disposed = false;
    _generation++;
    _repository = ref.watch(authRepositoryProvider);
    final repository = _repository;
    if (repository == null) {
      return const AccessState(AccessPhase.configurationRequired);
    }
    final subscription = repository.sessions.listen(
      _onSession,
      onError: (Object _) => _failClosed(),
    );
    final timer = Timer.periodic(const Duration(seconds: 60), (_) => refresh());
    ref.onDispose(() {
      _disposed = true;
      _generation++;
      subscription.cancel();
      timer.cancel();
    });
    final generation = _generation;
    Future.microtask(() async {
      try {
        final session = await repository.restoreSession();
        if (!_disposed && generation == _generation) await _onSession(session);
      } catch (_) {
        if (!_disposed && generation == _generation) _failClosed();
      }
    });
    return const AccessState(AccessPhase.loading);
  }

  void _failClosed() {
    if (_disposed) return;
    _generation++;
    state = AccessState(AccessPhase.error, userId: _session?.userId);
  }

  Future<void> _onSession(AuthSession? session) async {
    if (_disposed || (_logoutBlocked && session != null)) return;
    final generation = ++_generation;
    _session = session;
    if (session == null) {
      state = const AccessState(AccessPhase.signedOut);
      return;
    }
    if (session.passwordRecovery) {
      state = AccessState(AccessPhase.passwordRecovery, userId: session.userId);
      return;
    }
    state = AccessState(AccessPhase.loading, userId: session.userId);
    try {
      final membership = await _repository!.loadMembership();
      if (_disposed || generation != _generation) return;
      final phase = switch (membership) {
        MembershipState.incomplete => AccessPhase.incomplete,
        MembershipState.pending => AccessPhase.pending,
        MembershipState.verifiedStudent => AccessPhase.verifiedStudent,
        MembershipState.verifiedAlumni => AccessPhase.verifiedAlumni,
        MembershipState.rejected => AccessPhase.rejected,
        MembershipState.suspended => AccessPhase.suspended,
      };
      state = AccessState(phase, userId: session.userId);
    } catch (_) {
      if (!_disposed && generation == _generation) _failClosed();
    }
  }

  Future<void> refresh() async {
    if (_repository == null || _disposed || _logoutBlocked) return;
    if (_session != null) {
      await _onSession(_session);
      return;
    }
    final generation = _generation;
    try {
      final session = await _repository!.restoreSession();
      if (!_disposed && generation == _generation) await _onSession(session);
    } catch (_) {
      if (!_disposed && generation == _generation) _failClosed();
    }
  }

  Future<void> signIn(String email, String password) async {
    _logoutBlocked = false;
    await _repository!.signIn(email, password);
    await refresh();
  }

  Future<void> signUp(String email, String password) async {
    _logoutBlocked = false;
    await _repository!.signUp(email, password);
    await refresh();
  }

  Future<void> signOut() async {
    _logoutBlocked = true;
    _generation++;
    _session = null;
    state = const AccessState(AccessPhase.loading);
    try {
      await _repository!.signOut();
      if (!_disposed) state = const AccessState(AccessPhase.signedOut);
    } catch (_) {
      _failClosed();
    }
  }

  Future<void> submitOnboarding(OnboardingInput input) async {
    await _repository!.submitOnboarding(input);
    await refresh();
  }

  Future<void> updatePassword(String password) async {
    await _repository!.updatePassword(password);
    final userId = _session?.userId;
    if (userId != null) await _onSession(AuthSession(userId));
  }
}
