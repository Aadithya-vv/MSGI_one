import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/community_identity.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/application/auth_providers.dart';
import '../../profile/data/profile_providers.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../discovery/application/directory_controller.dart';
import '../../discovery/presentation/discovery_screen.dart';
import '../../alumni_map/data/map_providers.dart';
import '../../alumni_map/presentation/alumni_map_screen.dart';
import '../../connections/data/connections_providers.dart';
import '../../connections/presentation/network_screen.dart';
import '../../mentorship/data/mentor_providers.dart';
import '../../mentorship/presentation/mentorship_screen.dart';
import '../../opportunities/data/career_providers.dart';
import '../../opportunities/presentation/opportunities_screen.dart';
import '../../opportunities/presentation/career_detail_screen.dart';
import '../../opportunities/presentation/career_editor_screen.dart';
import '../../profile/domain/profile_repository.dart';
import '../domain/demo_store.dart';
import '../data/demo_repositories.dart';
import 'demo_screens.dart';

class DemoDirectoryController extends DirectoryController {
  @override
  Future<DirectoryPage> build() async {
    final rows = await ref
        .watch(profileRepositoryProvider)
        .discover(const DirectoryFilter());
    return DirectoryPage(rows.take(20).toList(), hasMore: rows.length > 20);
  }
}

/// A parentless scope: neither an Auth repository nor a Supabase client can flow
/// into this experience. Production route guards/providers remain unchanged.
ProviderContainer createDemoContainer(DemoStore store) => ProviderContainer(
  overrides: [
    supabaseClientProvider.overrideWithValue(null),
    authRepositoryProvider.overrideWithValue(null),
    communityUserIdProvider.overrideWithValue(store.actor),
    catalogRepositoryProvider.overrideWithValue(DemoCatalogRepository()),
    profileRepositoryProvider.overrideWithValue(DemoProfileRepository(store)),
    ownProfileProvider.overrideWith((_) => DemoProfileRepository(store).own()),
    profileDraftProvider.overrideWith(
      (_) => DemoProfileRepository(store).draft(),
    ),
    directoryProvider.overrideWith(DemoDirectoryController.new),
    alumniMapRepositoryProvider.overrideWithValue(DemoMapRepository(store)),
    connectionsRepositoryProvider.overrideWithValue(
      DemoConnectionsRepository(store),
    ),
    connectionWithProvider.overrideWith(
      (ref, peer) => DemoConnectionsRepository(store).withMember(peer),
    ),
    mentorRepositoryProvider.overrideWithValue(DemoMentorRepository(store)),
    careerRepositoryProvider.overrideWithValue(DemoCareerRepository(store)),
  ],
);

class DemoExperience extends StatefulWidget {
  const DemoExperience({
    super.key,
    required this.store,
    required this.onExit,
    this.storageProblem = false,
  });
  final DemoStore store;
  final VoidCallback onExit;
  final bool storageProblem;
  @override
  State<DemoExperience> createState() => _DemoExperienceState();
}

class _DemoExperienceState extends State<DemoExperience> {
  late ProviderContainer _container;
  late GoRouter _router;
  @override
  void initState() {
    super.initState();
    _configure();
  }

  void _configure() {
    _container = createDemoContainer(widget.store);
    _router = GoRouter(
      initialLocation: '/home',
      overridePlatformDefaultLocation: true,
      routes: [
        ShellRoute(
          builder: (context, state, child) => _frame(child),
          routes: [
            GoRoute(
              path: '/opportunities/new',
              builder: (_, _) =>
                  const CareerEditorScreen(allowExternalLinks: false),
            ),
            GoRoute(
              path: '/opportunities/:id/edit',
              builder: (_, s) => CareerEditorScreen(
                id: s.pathParameters['id']!,
                allowExternalLinks: false,
                intro: 'Create a simulated opportunity. Save a draft to continue later; nothing is posted to the real community.',
              ),
            ),
            GoRoute(
              path: '/opportunities/:id',
              builder: (_, s) =>
                  CareerDetailScreen(id: s.pathParameters['id']!),
            ),
            GoRoute(
              path: '/alumni/:id',
              builder: (_, s) {
                final p = widget.store.profiles[s.pathParameters['id']];
                return AlumniDetailScreen(
                  userId: s.pathParameters['id']!,
                  title: 'Sample ${p?['role'] ?? 'member'} profile',
                  eyebrow: 'Fictional demonstration profile',
                );
              },
            ),
            ShellRoute(
              builder: (context, state, child) =>
                  _DemoNavigation(location: state.uri.path, child: child),
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (_, _) => DemoHomeScreen(store: widget.store),
                ),
                GoRoute(
                  path: '/discover',
                  builder: (_, _) => const DiscoveryScreen(
                    description: 'Fictional alumni only. Profiles and activities are simulated; no institutional verification or endorsement is implied.',
                  ),
                ),
                GoRoute(
                  path: '/profile',
                  builder: (_, _) => DemoOwnProfileScreen(store: widget.store),
                ),
                GoRoute(
                  path: '/community',
                  builder: (_, _) => DemoCommunityScreen(store: widget.store),
                ),
                GoRoute(
                  path: '/map',
                  builder: (_, _) => const AlumniMapScreen(
                    enableNetworkTiles: false,
                    description: 'Explore fictional alumni at approximate sample city centers using bundled offline geography. No tracking or real people.',
                  ),
                ),
                GoRoute(
                  path: '/network',
                  builder: (_, _) => const NetworkScreen(),
                ),
                GoRoute(
                  path: '/mentors',
                  builder: (_, _) => const MentorshipScreen(),
                ),
                GoRoute(
                  path: '/opportunities',
                  builder: (_, _) => const OpportunitiesScreen(simulated: true),
                ),
              ],
            ),
          ],
        ),
      ],
      errorBuilder: (ctx, _) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => GoRouter.of(ctx).go('/home'),
            child: const Text('Demo page unavailable. Return home'),
          ),
        ),
      ),
    );
  }

  void _rebuild(VoidCallback change) {
    final oldRouter = _router, oldScope = _container;
    change();
    setState(_configure);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      oldRouter.dispose();
      oldScope.dispose();
    });
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: _router.routerDelegate.navigatorKey.currentContext!,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset the demo?'),
        content: const Text(
          'Restore all fictional profiles, requests, goals and opportunities, then return to Student. Real accounts and data are untouched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep demo'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset demo'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) _rebuild(widget.store.reset);
  }

  @override
  void dispose() {
    _router.dispose();
    _container.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => UncontrolledProviderScope(
    container: _container,
    child: MaterialApp.router(
      key: ValueKey(_container),
      title: 'MSGI One Demo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _router,
    ),
  );
  Widget _frame(Widget child) => Material(
    color: OneColors.background,
    textStyle: const TextStyle(fontSize: 14, color: OneColors.navy),
    child: SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 2,
              children: [
                const Text(
                  'MSGI One',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Chip(
                  label: Text('Demo'),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: Color(0xFFFFF3CE),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: OneColors.navy,
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: DropdownButton<DemoRole>(
                    isExpanded: true,
                    style: const TextStyle(fontSize: 14, color: OneColors.navy),
                    value: widget.store.role,
                    items: [
                      for (final role in DemoRole.values)
                        DropdownMenuItem(
                          value: role,
                          child: Text(
                            role.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (role) {
                      if (role != null && role != widget.store.role) {
                        _rebuild(() => widget.store.switchRole(role));
                      }
                    },
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Demo controls',
                  onSelected: (value) {
                    if (value == 'reset') {
                      _reset();
                    } else if (value == 'exit') {
                      widget.onExit();
                    } else {
                      showDialog<void>(
                        context:
                            _router.routerDelegate.navigatorKey.currentContext!,
                        builder: (ctx) => AlertDialog(
                          title: const Text('All activity is simulated'),
                          content: const Text(
                            'Fictional profiles, institutions, organizations and opportunities. No real authentication, approval, jobs or administrator privileges. Reset affects only local demo state.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Got it'),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'about',
                      child: Text('About simulated data'),
                    ),
                    PopupMenuItem(value: 'reset', child: Text('Reset demo')),
                    PopupMenuItem(value: 'exit', child: Text('Exit demo')),
                  ],
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Fictional people and activities. No real account or approval.',
              style: TextStyle(fontSize: 11),
            ),
          ),
          if (widget.storageProblem)
            const Text(
              'Demo storage unavailable. This session stays in memory.',
              style: TextStyle(fontSize: 11),
            ),
          Expanded(child: child),
        ],
      ),
    ),
  );
}

class _DemoNavigation extends StatelessWidget {
  const _DemoNavigation({required this.location, required this.child});
  final String location;
  final Widget child;
  static const paths = ['/home', '/discover', '/map', '/network', '/profile'];
  @override
  Widget build(BuildContext context) => Scaffold(
    body: child,
    bottomNavigationBar: NavigationBar(
      selectedIndex: mathIndex(location),
      onDestinationSelected: (i) => context.go(paths[i]),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.search), label: 'Discover'),
        NavigationDestination(icon: Icon(Icons.public), label: 'Map'),
        NavigationDestination(
          icon: Icon(Icons.people_outline),
          label: 'Network',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Profile',
        ),
      ],
    ),
  );
  int mathIndex(String p) => paths.contains(p) ? paths.indexOf(p) : 0;
}
