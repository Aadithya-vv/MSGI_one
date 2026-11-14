import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/auth/presentation/auth_screens.dart';
import '../../features/auth/presentation/auth_form_screen.dart';
import '../../features/auth/presentation/access_screen.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/application/auth_providers.dart';
import '../../features/auth/domain/auth_repository.dart';
import 'access_redirect.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/discovery/presentation/discovery_screen.dart';
import '../../features/alumni_map/presentation/alumni_map_screen.dart';
import '../../features/connections/presentation/network_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/administration/presentation/administration_screen.dart';
import '../../features/mentorship/presentation/mentorship_screen.dart';
import '../../features/opportunities/presentation/opportunities_screen.dart';
import '../../features/opportunities/presentation/career_editor_screen.dart';
import '../../features/opportunities/presentation/career_detail_screen.dart';
import '../errors/error_state.dart';
import '../widgets/one_shell.dart';
import 'app_routes.dart';

final initialLocationProvider = Provider<String>((ref) => AppRoutes.startup);
final ignorePlatformInitialRouteProvider = Provider<bool>((ref) => false);
final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  final router = createAppRouter(
    ignorePlatformInitialRoute: ref.watch(ignorePlatformInitialRouteProvider),
    initialLocation: ref.watch(initialLocationProvider),
    access: () => ref.read(authControllerProvider),
    refreshListenable: refresh,
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

/// UI guards complement, and never replace, database authorization.
GoRouter createAppRouter({
  bool ignorePlatformInitialRoute = false,
  String initialLocation = AppRoutes.startup,
  required AccessState Function() access,
  Listenable? refreshListenable,
}) {
  String? resumeLocation;
  return GoRouter(
    overridePlatformDefaultLocation: ignorePlatformInitialRoute,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final current = access();
      final path = state.uri.path;
      if (current.phase == AccessPhase.loading &&
          path != AppRoutes.authLoading) {
        resumeLocation = path;
      }
      if (current.phase != AccessPhase.loading &&
          path == AppRoutes.authLoading &&
          resumeLocation != null) {
        final resume = resumeLocation!;
        resumeLocation = null;
        return accessRedirect(current, resume) ?? resume;
      }
      return accessRedirect(current, path);
    },
    initialLocation: initialLocation,
    errorBuilder: (context, state) => Scaffold(
      body: SafeArea(
        child: Center(
          child: ErrorState(
            message: 'This page could not be found.',
            onRetry: () => context.go(AppRoutes.welcome),
          ),
        ),
      ),
    ),
    routes: [
      GoRoute(
        path: '/opportunities/new',
        builder: (_, _) => const CareerEditorScreen(),
      ),
      GoRoute(
        path: '/opportunities/:id/edit',
        builder: (_, state) =>
            CareerEditorScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/opportunities/:id',
        builder: (_, state) =>
            CareerDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.administration,
        builder: (_, _) => const AdministrationScreen(),
      ),
      GoRoute(
        path: AppRoutes.profileEdit,
        builder: (_, _) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.ownProfile,
        builder: (_, _) =>
            const Scaffold(body: SafeArea(child: ProfileScreen())),
      ),
      GoRoute(
        path: '/alumni/:id',
        builder: (_, state) =>
            AlumniDetailScreen(userId: state.pathParameters['id']!),
      ),
      for (final path in [
        AppRoutes.setup,
        AppRoutes.authLoading,
        AppRoutes.authError,
        AppRoutes.pending,
        AppRoutes.membershipStatus,
      ])
        GoRoute(path: path, builder: (_, _) => const AccessScreen()),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, _) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.recover,
        builder: (_, _) => const AuthScreen(recovery: true),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (_, _) => const AuthScreen(reset: true),
      ),
      GoRoute(
        path: AppRoutes.startup,
        builder: (_, _) => const StartupScreen(),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        builder: (_, _) => const WelcomeScreen(),
      ),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const AuthScreen()),
      GoRoute(
        path: AppRoutes.signup,
        builder: (_, _) => const AuthScreen(signup: true),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            OneShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: AppRoutes.home, builder: (_, _) => const HomeScreen()),
          GoRoute(
            path: AppRoutes.discover,
            builder: (_, _) => const DiscoveryScreen(),
          ),
          GoRoute(
            path: AppRoutes.map,
            builder: (_, _) => const AlumniMapScreen(),
          ),
          GoRoute(
            path: AppRoutes.network,
            builder: (_, _) => const NetworkScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (_, _) => const ProfileScreen(),
          ),
          GoRoute(
            path: AppRoutes.mentors,
            builder: (_, _) => const MentorshipScreen(),
          ),
          GoRoute(
            path: AppRoutes.opportunities,
            builder: (_, _) => const OpportunitiesScreen(),
          ),
        ],
      ),
    ],
  );
}
