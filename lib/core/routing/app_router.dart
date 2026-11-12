import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/auth/presentation/auth_screens.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/discovery/presentation/discovery_screen.dart';
import '../../features/alumni_map/presentation/alumni_map_screen.dart';
import '../../features/connections/presentation/network_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/mentorship/presentation/mentorship_screen.dart';
import '../../features/opportunities/presentation/opportunities_screen.dart';
import '../errors/error_state.dart';
import '../widgets/nexus_shell.dart';
import 'app_routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = createAppRouter();
  ref.onDispose(router.dispose);
  return router;
});

/// Preview routes are public. Real session and verification guards belong here
/// when auth is implemented; no screen currently grants backend access.
GoRouter createAppRouter({
  String initialLocation = AppRoutes.startup,
}) => GoRouter(
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
    GoRoute(path: AppRoutes.startup, builder: (_, _) => const StartupScreen()),
    GoRoute(path: AppRoutes.welcome, builder: (_, _) => const WelcomeScreen()),
    GoRoute(path: AppRoutes.login, builder: (_, _) => const AuthScreen()),
    GoRoute(
      path: AppRoutes.signup,
      builder: (_, _) => const AuthScreen(signup: true),
    ),
    ShellRoute(
      builder: (context, state, child) =>
          NexusShell(location: state.uri.path, child: child),
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
