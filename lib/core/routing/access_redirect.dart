import '../../features/auth/domain/auth_repository.dart';
import 'app_routes.dart';

String? accessRedirect(AccessState access, String path) {
  if (access.phase == AccessPhase.pending &&
      (path == AppRoutes.profileEdit || path == AppRoutes.ownProfile)) {
    return null;
  }
  final requiredPath = switch (access.phase) {
    AccessPhase.configurationRequired => AppRoutes.setup,
    AccessPhase.loading => AppRoutes.authLoading,
    AccessPhase.error => AppRoutes.authError,
    AccessPhase.incomplete => AppRoutes.onboarding,
    AccessPhase.pending => AppRoutes.pending,
    AccessPhase.rejected || AccessPhase.suspended => AppRoutes.membershipStatus,
    AccessPhase.passwordRecovery => AppRoutes.resetPassword,
    _ => null,
  };
  if (requiredPath != null) return path == requiredPath ? null : requiredPath;
  const publicPaths = {
    AppRoutes.startup,
    AppRoutes.welcome,
    AppRoutes.login,
    AppRoutes.signup,
    AppRoutes.recover,
  };
  if (access.phase == AccessPhase.signedOut) {
    return publicPaths.contains(path) ? null : AppRoutes.login;
  }
  if (access.isVerified &&
      {
        AppRoutes.login,
        AppRoutes.signup,
        AppRoutes.recover,
        AppRoutes.resetPassword,
        AppRoutes.setup,
        AppRoutes.authLoading,
        AppRoutes.authError,
        AppRoutes.onboarding,
        AppRoutes.pending,
        AppRoutes.membershipStatus,
      }.contains(path)) {
    return AppRoutes.home;
  }
  return null;
}
