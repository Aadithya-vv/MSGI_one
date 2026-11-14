import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:msgi_one/core/theme/app_theme.dart';
import 'package:msgi_one/core/widgets/one_widgets.dart';
import 'package:msgi_one/features/demo/presentation/demo_experience.dart';
import 'package:msgi_one/features/demo/domain/demo_store.dart';
import 'package:msgi_one/features/home/presentation/community_highlights.dart';
import 'package:msgi_one/features/mentorship/data/mentor_providers.dart';
import 'package:msgi_one/features/opportunities/data/career_providers.dart';

import 'app_test.dart' show pumpRoute;

import 'package:msgi_one/core/routing/app_routes.dart';

import 'helpers/fake_mentor_repository.dart';
import 'helpers/fake_career_repository.dart';

import 'package:msgi_one/features/catalog/presentation/catalog_picker.dart';
import 'package:msgi_one/features/catalog/domain/catalog_repository.dart';
import 'package:msgi_one/features/auth/domain/onboarding.dart';
import 'package:msgi_one/features/profile/data/profile_providers.dart';

Future<void> tapText(WidgetTester tester, String text) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  final target = find.text(text).first;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Home highlights use injected repositories and empty states, never legacy previews',
    (tester) async {
      final mentors = FakeMentorRepository()..people = [];
      final careers = FakeCareerRepository()..rows = [];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mentorRepositoryProvider.overrideWithValue(mentors),
            careerRepositoryProvider.overrideWithValue(careers),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: SingleChildScrollView(child: CommunityHighlights()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Your next mentor is ahead'), findsOneWidget);
      expect(find.text('New doors will open'), findsOneWidget);
      expect(find.text('SAMPLE PROFILE'), findsNothing);
    },
  );

  testWidgets('Password visibility is explicit and keeps form input local', (
    tester,
  ) async {
    await pumpRoute(tester, AppRoutes.signup);
    final field = find.byKey(const Key('auth-password'));
    expect(
      tester
          .widget<TextField>(
            find.descendant(of: field, matching: find.byType(TextField)),
          )
          .obscureText,
      true,
    );
    await tester.tap(find.byTooltip('Show password'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(
            find.descendant(of: field, matching: find.byType(TextField)),
          )
          .obscureText,
      false,
    );
    expect(find.byTooltip('Hide password'), findsOneWidget);
  });

  testWidgets('Status notices respect reduced motion and announce updates', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const Scaffold(body: StatusNotice('Changes saved')),
        ),
      ),
    );
    expect(
      tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher)).duration,
      Duration.zero,
    );
    expect(find.text('Changes saved'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.liveRegion == true,
      ),
      findsWidgets,
    );
  });

  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Demo filters/cards/navigation fit $width at $scale text', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final store = DemoStore()..switchRole(DemoRole.student);
        addTearDown(store.dispose);
        await tester.pumpWidget(DemoExperience(store: store, onExit: () {}));
        await tester.pumpAndSettle();
        expect(find.text('Demo'), findsOneWidget);
        await tapText(tester, 'Discover');
        await tapText(tester, 'Filter alumni');
        await tester.enterText(
          find.widgetWithText(TextField, 'Graduation year'),
          'abc',
        );
        await tapText(tester, 'Apply alumni filters');
        expect(find.text('Enter a valid graduation year.'), findsOneWidget);
        expect(find.byTooltip('Close filters'), findsOneWidget);
        await tester.enterText(
          find.widgetWithText(TextField, 'Graduation year'),
          '2022',
        );
        await tapText(tester, 'Apply alumni filters');
        expect(find.text('Filter alumni (1 active)'), findsOneWidget);
        await tapText(tester, 'Clear');
        expect(find.text('Filter alumni'), findsOneWidget);
        await tapText(tester, 'Filter alumni');
        await tester.enterText(
          find.widgetWithText(TextField, 'Graduation year'),
          '2020',
        );
        await tester.tap(find.byTooltip('Close filters'));
        await tester.pumpAndSettle();
        expect(find.text('Filter alumni'), findsOneWidget);
        await tapText(tester, 'Home');
        await tapText(tester, 'Find a mentor');
        await tapText(tester, 'Refine recommendations');
        expect(find.text('Only new connections'), findsOneWidget);
        await tapText(tester, 'Refine recommendations');
        await tapText(tester, 'Home');
        await tapText(tester, 'Career Bridge');
        await tapText(tester, 'Status and sorting');
        expect(find.text('My posts and drafts'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('Catalog and skill labels wrap long text at 200 percent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: ProviderScope(
            overrides: [
              catalogRepositoryProvider.overrideWithValue(LongLabelCatalog()),
            ],
            child: Scaffold(
              body: PageBody(
                children: [
                  const SkillTags([
                    'A very long professional skill label covering embedded systems and infrastructure',
                  ]),
                  CatalogPicker(
                    kind: CatalogKind.institutions,
                    label: 'Institutions',
                    onSelected: (_) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

class LongLabelCatalog implements CatalogRepository {
  @override
  Future<List<CatalogEntry>> search(
    CatalogKind kind, {
    String query = '',
    String? institutionId,
    int page = 0,
  }) async => [
    const CatalogEntry(
      id: 'synthetic-long',
      name: 'An explicitly synthetic institution with a very long department and engineering education catalog label',
    ),
  ];
}
