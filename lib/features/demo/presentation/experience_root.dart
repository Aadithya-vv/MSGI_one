import 'dart:convert';
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app.dart';
import '../../../core/config/production_session.dart';
import '../../../core/config/experience_actions.dart';
import '../../../core/config/app_config.dart';
import '../../../core/config/auth_entry_links.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/one_widgets.dart';
import '../../../core/routing/app_router.dart';
import '../../auth/application/auth_providers.dart';
import '../domain/demo_store.dart';
import '../data/demo_persistence.dart';
import '../../catalog/presentation/msec_institution_identity.dart';
import 'demo_experience.dart';

enum _Experience { loading, entry, chooseRole, demo, production }

class ExperienceRoot extends StatefulWidget {
  const ExperienceRoot({
    super.key,
    this.persistence,
    this.links,
    this.openProduction = ProductionSession.fromGateway,
    this.competitionOnly = const bool.fromEnvironment('MSGI_COMPETITION_ONLY'),
  });
  final DemoPersistence? persistence;
  final AuthEntryLinks? links;
  final Future<ProductionSession> Function() openProduction;

  /// Release-only offline boundary; ordinary development auth stays unchanged.
  final bool competitionOnly;
  @override
  State<ExperienceRoot> createState() => _ExperienceRootState();
}

class _ExperienceRootState extends State<ExperienceRoot> {
  late final DemoPersistence _persistence =
      widget.persistence ?? PreferencesDemoPersistence();
  DemoStore? _store;
  _Experience _experience = _Experience.loading;
  bool _storageProblem = false;
  String? _problem;
  ProductionSession? _production;
  ProviderContainer? _realScope;
  Future<void> _writes = Future.value();
  late final AuthEntryLinks _links = widget.links ?? PlatformAuthEntryLinks();
  StreamSubscription<Uri>? _linkSubscription;
  final _pendingLinks = <Uri>[];
  bool _restored = false;
  Future<void> _callbacks = Future.value();
  String? _lastLink;
  DateTime? _lastLinkAt;
  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    Map<String, dynamic>? value;
    try {
      value = await _persistence.read().timeout(const Duration(seconds: 3));
    } catch (_) {
      _storageProblem = true;
    }
    if (!mounted) return;
    _store = DemoStore.restore(value);
    _store!.addListener(_save);
    _linkSubscription = _links.events.listen((uri) {
      if (_restored) {
        _acceptLink(uri);
      } else {
        _pendingLinks.add(uri);
      }
    }, onError: (Object _) {});
    try {
      final initial = await _links.initial().timeout(
        const Duration(seconds: 2),
      );
      if (initial != null) _pendingLinks.add(initial);
    } catch (_) {}
    if (!mounted) return;
    _restored = true;
    setState(
      () => _experience = _store!.active ? _Experience.demo : _Experience.entry,
    );
    for (final uri in _pendingLinks) {
      _acceptLink(uri);
    }
    _pendingLinks.clear();
  }

  void _acceptLink(Uri uri) {
    if (widget.competitionOnly) return;
    if (!isProductionAuthEntry(uri)) return;
    final now = DateTime.now(), key = uri.toString();
    if (key == _lastLink &&
        _lastLinkAt != null &&
        now.difference(_lastLinkAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastLink = key;
    _lastLinkAt = now;
    _callbacks = _callbacks
        .then((_) async {
          if (!mounted) return;
          if (_experience != _Experience.production) await _real();
          if (!mounted || _experience != _Experience.production) return;
          await WidgetsBinding.instance.endOfFrame;
          try {
            await _production?.handleAuthEntry(uri);
          } catch (_) {
            _realScope?.read(authControllerProvider.notifier).authLinkFailed();
          }
        })
        .catchError((Object _) {
          /* Never log callback URLs or credentials. */
        });
  }

  void _save() {
    final copy =
        jsonDecode(jsonEncode(_store!.snapshot())) as Map<String, dynamic>;
    _writes = _writes.then((_) => _persistence.write(copy)).catchError((
      Object _,
    ) {
      if (mounted) setState(() => _storageProblem = true);
    });
  }

  Future<bool> _leaveReal() async {
    final session = _production;
    if (session == null) return true;
    setState(() => _experience = _Experience.loading);
    await WidgetsBinding.instance.endOfFrame;
    _realScope?.dispose();
    _realScope = null;
    try {
      await session.close();
      _production = null;
      return true;
    } catch (_) {
      if (mounted) {
        setState(() {
          _problem = 'Could not stop the real backend safely. Restart the app before entering the demo.';
          _experience = _Experience.entry;
        });
      }
      return false;
    }
  }

  Future<void> _demoEntry() async {
    if (!await _leaveReal() || !mounted) return;
    setState(() => _experience = _Experience.chooseRole);
  }

  void _enter(DemoRole role) {
    _store!.switchRole(role);
    setState(() => _experience = _Experience.demo);
  }

  void _exit() {
    _store!.active = false;
    _store!.changed();
    setState(() => _experience = _Experience.entry);
  }

  Future<void> _real() async {
    if (widget.competitionOnly) return;
    if (_openingProduction != null) return _openingProduction!;
    final future = _openReal();
    _openingProduction = future;
    try {
      await future;
    } finally {
      _openingProduction = null;
    }
  }

  Future<void>? _openingProduction;
  Future<void> _openReal() async {
    if (_production != null && !await _leaveReal()) return;
    setState(() {
      _experience = _Experience.loading;
      _problem = null;
    });
    await WidgetsBinding.instance.endOfFrame;
    try {
      final session = await widget.openProduction();
      if (!mounted) {
        await session.close();
        return;
      }
      _production = session;
      _realScope = ProviderContainer(
        overrides: [
          backendConfigProvider.overrideWithValue(session.config),
          backendInitializationErrorProvider.overrideWithValue(session.error),
          supabaseClientProvider.overrideWithValue(session.client),
          initialLocationProvider.overrideWithValue('/home'),
          ignorePlatformInitialRouteProvider.overrideWithValue(true),
          exploreDemoActionProvider.overrideWithValue(_demoEntry),
          appEntryActionProvider.overrideWithValue(() async {
            if (await _leaveReal() && mounted) {
              setState(() => _experience = _Experience.entry);
            }
          }),
        ],
      );
      _store!.active = false;
      _store!.changed();
      setState(() => _experience = _Experience.production);
    } catch (_) {
      if (mounted) {
        setState(() {
          _problem = 'Real sign-in could not initialize. You can still explore the isolated demo.';
          _experience = _Experience.entry;
        });
      }
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _store?.removeListener(_save);
    _store?.dispose();
    _realScope?.dispose();
    unawaited(_production?.close().catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_experience == _Experience.demo) {
      return DemoExperience(
        store: _store!,
        storageProblem: _storageProblem,
        onExit: _exit,
      );
    }
    if (_experience == _Experience.production) {
      return UncontrolledProviderScope(
        container: _realScope!,
        child: const OneApp(),
      );
    }
    return MaterialApp(
      initialRoute: '/',
      title: AppConfig.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        body: SafeArea(
          child: PageBody(
            children: [
              const SizedBox(height: 24),
              const BrandMark(prominent: true),
              const SizedBox(height: 24),
              if (_experience == _Experience.loading) ...[
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 16),
                const MsecInstitutionIdentity(),
              ] else if (_experience == _Experience.chooseRole) ...[
                const FeatureHeader(
                  eyebrow: 'Explore Demo',
                  title: 'Choose a perspective',
                  description: 'MSEC programme names use supplied institutional information. People, affiliations and activity are fictional. Staff is a community role, not an administrator.',
                ),
                for (final role in DemoRole.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _enter(role),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF3CE),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(switch (role) {
                                  DemoRole.student => Icons.school_outlined,
                                  DemoRole.alumni => Icons.work_outline,
                                  DemoRole.staff => Icons.groups_outlined,
                                }, color: OneColors.navy),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${role.label} demo',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      switch (role) {
                                        DemoRole.student => 'Find mentors, explore careers and build your network.',
                                        DemoRole.alumni => 'Share experience, connect and open new doors.',
                                        DemoRole.staff => 'Explore students, alumni and the wider community.',
                                      },
                                      style: const TextStyle(
                                        color: OneColors.muted,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                TextButton(
                  onPressed: () =>
                      setState(() => _experience = _Experience.entry),
                  child: const Text('Back to app entry'),
                ),
              ] else ...[
                const FeatureHeader(
                  eyebrow: 'One Community. Infinite Connections.',
                  title: 'Where every generation\nhas something to share.',
                  description: 'Discover mentors, careers and connections across the MSGI community.',
                ),
                FilledButton.icon(
                  onPressed: _demoEntry,
                  icon: const Icon(Icons.explore_outlined),
                  label: const Text('Explore Demo'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'No account, email or internet required. Fictional profiles and simulated activities, stored separately on this device.',
                ),
                const SizedBox(height: 16),
                const MsecInstitutionIdentity(campusPreview: true),
                const SizedBox(height: 24),
                if (widget.competitionOnly)
                  const Text(
                    'Offline competition demonstration · All people and activity are fictional.',
                  )
                else ...[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.login),
                    onPressed: _real,
                    label: const Text('Sign in to real community'),
                  ),
                  TextButton(
                    onPressed: () async {
                      await _real();
                      if (mounted && _experience == _Experience.production) {
                        _realScope?.read(appRouterProvider).go('/signup');
                      }
                    },
                    child: const Text('Create an account'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Real access keeps existing email confirmation, institutional verification and privacy rules.',
                  ),
                ],
                if (_problem != null) Text(_problem!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
