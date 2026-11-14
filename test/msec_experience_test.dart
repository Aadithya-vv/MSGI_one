import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:msgi_one/core/theme/app_theme.dart';
import 'package:msgi_one/features/catalog/domain/academic_catalog.dart';
import 'package:msgi_one/features/catalog/domain/catalog_repository.dart';
import 'package:msgi_one/features/catalog/data/academic_catalog_provider.dart';
import 'package:msgi_one/features/demo/domain/demo_store.dart';
import 'package:msgi_one/features/demo/data/demo_repositories.dart';
import 'package:msgi_one/features/demo/presentation/demo_experience.dart';
import 'package:msgi_one/features/profile/domain/profile_repository.dart';
import 'package:msgi_one/features/profile/data/supabase_profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:msgi_one/features/auth/application/auth_providers.dart';
import 'package:msgi_one/features/connections/presentation/connection_controls.dart';

Future<void> tapMsec(WidgetTester tester, Finder target) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(tester.element(target.first), alignment: .5);
  await tester.pumpAndSettle();
  await tester.tap(target.first);
  await tester.pumpAndSettle();
}

Future<DemoStore> pumpMsec(
  WidgetTester tester, {
  DemoRole role = DemoRole.student,
  double scale = 1,
}) async {
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final store = DemoStore()..switchRole(role);
  addTearDown(store.dispose);
  await tester.pumpWidget(DemoExperience(store: store, onExit: () {}));
  await tester.pumpAndSettle();
  return store;
}

void main() {
  test('Approved MSEC catalog has exactly nine UG, four PG and one separate academic department', () {
    final catalog = MsecCatalog.catalog;
    expect(catalog.name, 'Meenakshi Sundararajan Engineering College (MSEC)');
    expect(
      catalog.programmes
          .where((p) => p.level == ProgrammeLevel.undergraduate)
          .length,
      9,
    );
    expect(
      catalog.programmes
          .where((p) => p.level == ProgrammeLevel.postgraduate)
          .length,
      4,
    );
    expect(
      catalog.programmes.map((p) => p.name),
      unorderedEquals([
        'B.Tech. Artificial Intelligence & Data Science',
        'B.Tech. Artificial Intelligence & Machine Learning',
        'B.E. Civil Engineering',
        'B.E. Computer Science and Engineering',
        'B.E. Computer Science & Engineering (Cybersecurity)',
        'B.E. Electrical and Electronics Engineering',
        'B.E. Electronics and Communication Engineering',
        'B.Tech. Information Technology',
        'B.E. Mechanical Engineering',
        'M.E. Computer Science',
        'M.E. Construction Engineering and Management',
        'M.E. Embedded Systems and Technologies',
        'M.E. Energy Engineering',
      ]),
    );
    expect(catalog.departments.single.name, 'Science and Humanities');
    expect(catalog.programmes.map((p) => p.id).toSet().length, 13);
    expect(
      catalog.programmes.every((p) => p.institutionId == catalog.id),
      true,
    );
    expect(catalog.programme(MsecCatalog.scienceHumanitiesId), isNull);
  });

  test(
    'Catalog is demo-scoped and departments never contain degree programmes',
    () async {
      final real = ProviderContainer(),
          store = DemoStore(),
          demo = createDemoContainer(DemoStore());
      addTearDown(real.dispose);
      addTearDown(demo.dispose);
      addTearDown(store.dispose);
      expect(real.read(academicCatalogsProvider), isEmpty);
      expect(demo.read(academicCatalogsProvider).single.id, MsecCatalog.id);
      expect(demo.read(supabaseClientProvider), isNull);
      expect(demo.read(authRepositoryProvider), isNull);
      final departments = await DemoCatalogRepository().search(
        CatalogKind.departments,
        institutionId: MsecCatalog.id,
      );
      expect(departments.map((d) => d.name), ['Science and Humanities']);
      expect(
        await DemoCatalogRepository().search(
          CatalogKind.departments,
          institutionId: 'future-institution',
        ),
        isEmpty,
      );
    },
  );

  test('All fictional academic affiliations resolve consistently without inventing departments', () {
    final store = DemoStore();
    addTearDown(store.dispose);
    for (final p in store.profiles.values) {
      expect(p['institution_id'], MsecCatalog.id);
      expect(p['institution'], MsecCatalog.name);
      if (p['role'] == 'staff') {
        expect(p['programme_id'], isNull);
        expect(p['department'], 'Science and Humanities');
      } else {
        final programme = MsecCatalog.catalog.programme(
          p['programme_id'] as String?,
        );
        expect(programme, isNotNull);
        expect(p['programme'], programme!.name);
        expect(p['degree'], programme.name);
        expect(p['department_id'], '');
      }
      expect(p.containsKey('verified'), false);
    }
    expect(
      store.profiles.values
          .where((p) => p['role'] == 'alumni')
          .map((p) => p['programme_id'])
          .toSet()
          .length,
      13,
    );
  });

  test(
    'Programme filtering composes with institutional and visibility filters',
    () async {
      final store = DemoStore(), repo = DemoProfileRepository(DemoStore());
      addTearDown(store.dispose);
      addTearDown(repo.store.dispose);
      final rows = await repo.discover(
        const DirectoryFilter(
          institution: MsecCatalog.id,
          programme: 'msec-ug-cse-cybersecurity',
        ),
      );
      expect(rows, isNotEmpty);
      expect(
        rows.every(
          (p) => p.data['programme_id'] == 'msec-ug-cse-cybersecurity',
        ),
        true,
      );
      expect(
        await repo.discover(
          const DirectoryFilter(
            institution: 'future-institution',
            programme: 'msec-ug-cse',
          ),
        ),
        isEmpty,
      );
      expect(
        await repo.discover(
          const DirectoryFilter(department: MsecCatalog.scienceHumanitiesId),
        ),
        isEmpty,
      );
    },
  );

  test('Previous demo snapshots upgrade academics without losing names, requests or privacy', () {
    final old = DemoStore()..switchRole(DemoRole.alumni);
    addTearDown(old.dispose);
    old.updatePerson({'display_name': 'Presenter name', 'map_opt_in': false});
    old.connections['demo-link-01']!['status'] = 'accepted';
    old.person['institution_id'] = 'demo-campus-a';
    old.person['programme_id'] = null;
    final snapshot = old.snapshot()..['version'] = 2;
    final restored = DemoStore.restore(snapshot);
    addTearDown(restored.dispose);
    expect(restored.person['display_name'], 'Presenter name');
    expect(restored.person['map_opt_in'], false);
    expect(restored.person['institution_id'], MsecCatalog.id);
    expect(
      restored.person['programme'],
      'M.E. Embedded Systems and Technologies',
    );
    expect(restored.connections['demo-link-01']!['status'], 'accepted');
    expect(restored.role, DemoRole.alumni);
  });

  test(
    'Staff cannot claim a degree programme or publishing/admin capabilities',
    () async {
      final store = DemoStore()..switchRole(DemoRole.staff);
      addTearDown(store.dispose);
      expect(
        () => store.updatePerson({'programme_id': 'msec-ug-cse'}),
        throwsArgumentError,
      );
      expect(await DemoCareerRepository(store).canPublish(), false);
      expect(store.person.containsKey('admin'), false);
    },
  );

  test(
    'Unsupported hosted programme filters fail before issuing an RPC',
    () async {
      final client = SupabaseClient(
        'http://127.0.0.1:1',
        'synthetic-public-key',
      );
      addTearDown(client.dispose);
      await expectLater(
        SupabaseProfileRepository(client)
            .discover(const DirectoryFilter(programme: 'msec-ug-cse')),
        throwsUnsupportedError,
      );
    },
  );

  testWidgets('Direct mentor entry uses Home as the Android Back fallback', (
    tester,
  ) async {
    await pumpMsec(tester);
    GoRouter.of(tester.element(find.byType(NavigationBar))).go('/mentors');
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Welcome, Mira Rao'), findsOneWidget);
  });

  testWidgets(
    'Create and edit return to one detail page and then the opportunities parent',
    (tester) async {
      await pumpMsec(tester, role: DemoRole.alumni);
      await tapMsec(tester, find.text('Opportunities'));
      await tapMsec(tester, find.text('Create opportunity'));
      await tester.enterText(
        find.byKey(const Key('career-title')),
        'Fictional MSEC project',
      );
      await tester.enterText(
        find.byKey(const Key('career-description')),
        'A fictional learning collaboration for the isolated demo.',
      );
      await tapMsec(tester, find.text('Save draft'));
      expect(find.text('Opportunity details'), findsOneWidget);
      await tapMsec(tester, find.text('Edit opportunity'));
      await tester.enterText(
        find.byKey(const Key('career-title')),
        'Updated fictional MSEC project',
      );
      await tapMsec(tester, find.text('Save draft'));
      expect(find.text('Updated fictional MSEC project'), findsOneWidget);
      expect(find.byKey(const Key('career-title')), findsNothing);
      await tapMsec(tester, find.byTooltip('Back'));
      expect(find.text('Opportunities'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Welcome, Arjun Iyer'), findsOneWidget);
    },
  );

  testWidgets(
    'Student programme selection persists and does not become an academic department',
    (tester) async {
      final store = await pumpMsec(tester);
      await tapMsec(tester, find.text('Profile'));
      await tapMsec(tester, find.text('Edit demo profile'));
      await tapMsec(tester, find.byKey(const Key('demo-programme')));
      await tapMsec(tester, find.text('B.Tech. Information Technology').last);
      await tapMsec(tester, find.text('Save demo profile'));
      expect(store.person['programme_id'], 'msec-ug-it');
      expect(store.person['department_id'], '');
      final restored = DemoStore.restore(store.snapshot());
      addTearDown(restored.dispose);
      expect(restored.person['degree'], 'B.Tech. Information Technology');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Editing an alumni programme refreshes retained discovery without clearing its filter',
    (tester) async {
      await pumpMsec(tester, role: DemoRole.alumni);
      await tapMsec(tester, find.text('Discover'));
      await tapMsec(tester, find.text('Filter alumni'));
      await tapMsec(tester, find.text('Degree programmes'));
      await tapMsec(
        tester,
        find.widgetWithText(
          DropdownButtonFormField<String>,
          'Programme filter',
        ),
      );
      await tapMsec(
        tester,
        find.text('M.E. Embedded Systems and Technologies').last,
      );
      await tapMsec(tester, find.text('Apply alumni filters'));
      expect(find.text('Arjun Iyer'), findsOneWidget);
      await tapMsec(tester, find.text('Profile'));
      await tapMsec(tester, find.text('Edit demo profile'));
      await tapMsec(tester, find.byKey(const Key('demo-programme')));
      await tester.scrollUntilVisible(
        find.text('M.E. Energy Engineering'),
        120,
        scrollable: find.byType(Scrollable).last,
      );
      await tapMsec(tester, find.text('M.E. Energy Engineering').last);
      await tapMsec(tester, find.text('Save demo profile'));
      await tapMsec(tester, find.text('Discover'));
      expect(find.text('No alumni found'), findsOneWidget);
      expect(find.text('Filter alumni (1 active)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Staff profile uses department context and has no student programme picker',
    (tester) async {
      await pumpMsec(tester, role: DemoRole.staff, scale: 2);
      await tapMsec(tester, find.text('Profile'));
      await tapMsec(tester, find.text('Edit demo profile'));
      expect(find.byKey(const Key('demo-programme')), findsNothing);
      expect(
        find.textContaining('Academic department: Science and Humanities'),
        findsOneWidget,
      );
      expect(find.text('Review memberships'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Connection buttons match no relationship, incoming, outgoing and accepted states',
    (tester) async {
      final store = DemoStore();
      addTearDown(store.dispose);
      for (final item in [
        ('demo-alumni-08', 'Connect'),
        ('demo-alumni-02', 'Accept'),
        ('demo-alumni-01', 'Cancel request'),
        ('demo-alumni-03', 'Remove connection'),
      ]) {
        final scope = createDemoContainer(store);
        addTearDown(scope.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            key: UniqueKey(),
            container: scope,
            child: MaterialApp(
              theme: AppTheme.light,
              home: Scaffold(
                body: ConnectionControls(peer: item.$1, compact: true),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(item.$2), findsOneWidget);
        expect(
          find.text('Accept'),
          item.$1 == 'demo-alumni-02' ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Decline'),
          item.$1 == 'demo-alumni-02' ? findsOneWidget : findsNothing,
        );
      }
    },
  );

  testWidgets(
    'Mentor profile and Android Back return to the actual parent without losing role',
    (tester) async {
      final store = await pumpMsec(tester);
      await tapMsec(tester, find.text('Find a mentor'));
      await tapMsec(tester, find.text('View mentor profile'));
      expect(find.text('Sample alumni profile'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Mentor recommendations'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Welcome, Mira Rao'), findsOneWidget);
      expect(store.role, DemoRole.student);
    },
  );

  testWidgets(
    'Opportunity detail Back returns to feed then Home, without duplicate editors',
    (tester) async {
      await pumpMsec(tester);
      await tapMsec(tester, find.text('Opportunities'));
      await tapMsec(tester, find.text('View opportunity'));
      await tapMsec(tester, find.byTooltip('Back'));
      expect(find.text('Opportunities'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Welcome, Mira Rao'), findsOneWidget);
    },
  );

  testWidgets(
    'Long programme labels fit an enlarged small-screen filter sheet',
    (tester) async {
      await pumpMsec(tester, scale: 2);
      await tapMsec(tester, find.text('Discover'));
      await tapMsec(tester, find.text('Filter alumni'));
      await tapMsec(tester, find.text('Degree programmes'));
      await tapMsec(
        tester,
        find.widgetWithText(
          DropdownButtonFormField<String>,
          'Programme filter',
        ),
      );
      await tapMsec(
        tester,
        find.text('B.E. Computer Science & Engineering (Cybersecurity)').last,
      );
      await tapMsec(tester, find.text('Apply alumni filters'));
      expect(find.text('Filter alumni (1 active)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
