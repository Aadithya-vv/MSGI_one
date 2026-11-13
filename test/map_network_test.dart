import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:msgi_one/app.dart';
import 'package:msgi_one/core/routing/app_routes.dart';
import 'package:msgi_one/core/routing/app_router.dart';
import 'package:msgi_one/features/auth/application/auth_providers.dart';
import 'package:msgi_one/features/auth/domain/auth_repository.dart';
import 'package:msgi_one/features/profile/data/profile_providers.dart';
import 'package:msgi_one/features/alumni_map/data/map_providers.dart';
import 'package:msgi_one/features/alumni_map/domain/map_repository.dart';
import 'package:msgi_one/features/alumni_map/presentation/world_geography.dart';
import 'package:msgi_one/features/connections/data/connections_providers.dart';
import 'package:msgi_one/features/connections/domain/connections_repository.dart';

import 'helpers/fake_auth_repository.dart';
import 'helpers/fake_profile_repository.dart';
import 'helpers/fake_network_repositories.dart';

Future<void> pumpNetworking(
  WidgetTester tester,
  String path, {
  FakeAlumniMapRepository? map,
  FakeConnectionsRepository? network,
  MembershipState membership = MembershipState.verifiedAlumni,
}) async {
  final auth = FakeAuthRepository(
    session: const AuthSession('viewer'),
    membership: membership,
  );
  addTearDown(auth.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        initialLocationProvider.overrideWithValue(path),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        alumniMapRepositoryProvider.overrideWithValue(
          map ?? FakeAlumniMapRepository(),
        ),
        connectionsRepositoryProvider.overrideWithValue(
          network ?? FakeConnectionsRepository(),
        ),
      ],
      child: const OneApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('City groups preserve consenting counts and split when zoomed', () {
    const cities = [
      CityCluster(
        id: 'one',
        name: 'Synthetic one',
        country: 'IN',
        latitude: 20,
        longitude: 0.1,
        count: 2,
      ),
      CityCluster(
        id: 'two',
        name: 'Synthetic two',
        country: 'IN',
        latitude: 21,
        longitude: 0.2,
        count: 3,
      ),
    ];
    expect(groupCities(cities, 1).single.count, 5);
    expect(groupCities(cities, 8).length, 2);
    expect(groupCities([], 2), isEmpty);
  });
  testWidgets(
    'Offline geography renders without a public tile server and marker opens city panel',
    (tester) async {
      final map = FakeAlumniMapRepository();
      await pumpNetworking(tester, AppRoutes.map, map: map);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.text('SAMPLE PREVIEW'), findsNothing);
      expect(find.byType(TileLayer), findsNothing);
      final marker = find.byTooltip('Synthetic test city');
      await tester.ensureVisible(marker);
      await tester.tap(marker);
      await tester.pumpAndSettle();
      expect(find.text('Synthetic city alumna'), findsOneWidget);
      expect(find.text('Synthetic test city alumni'), findsOneWidget);
      await tester.ensureVisible(find.text('Synthetic city alumna'));
      await tester.tap(find.text('Synthetic city alumna'));
      await tester.pumpAndSettle();
      expect(find.text('Alumni profile'), findsOneWidget);
      expect(find.text('Connect'), findsOneWidget);
    },
  );
  testWidgets('Map empty/offline/retry states do not invent markers', (
    tester,
  ) async {
    final map = FakeAlumniMapRepository()..fail = true;
    await pumpNetworking(tester, AppRoutes.map, map: map);
    expect(find.textContaining('Map data unavailable'), findsOneWidget);
    map.fail = false;
    map.rows = [];
    await tester.ensureVisible(find.text('Retry map'));
    await tester.tap(find.text('Retry map'));
    await tester.pumpAndSettle();
    expect(find.text('No map-visible alumni'), findsOneWidget);
  });
  testWidgets(
    'Map domains are applied explicitly and kept consistent for city members',
    (tester) async {
      final map = FakeAlumniMapRepository();
      await pumpNetworking(tester, AppRoutes.map, map: map);
      await tester.enterText(
        find.widgetWithText(TextField, 'Professional domain'),
        'Research',
      );
      final marker = find.byTooltip('Synthetic test city');
      await tester.ensureVisible(marker);
      await tester.tap(marker);
      await tester.pumpAndSettle();
      expect(map.domains.last, '');
      await tester.ensureVisible(find.text('Filter map'));
      await tester.tap(find.text('Filter map'));
      await tester.pumpAndSettle();
      expect(map.domains.last, 'Research');
    },
  );
  testWidgets(
    'Incoming acceptance, removal and tab refresh preserve network state',
    (tester) async {
      final network = FakeConnectionsRepository()
        ..value = const ProfessionalConnection(
          id: 'relationship',
          peerId: 'id-001',
          status: 'pending',
          incoming: true,
          available: true,
          name: 'Synthetic peer',
        );
      await pumpNetworking(tester, AppRoutes.network, network: network);
      await tester.tap(find.text('Incoming'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Accept'));
      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();
      expect(network.actions, ['accepted']);
      await tester.tap(find.text('Connected'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Remove connection'));
      await tester.tap(find.text('Remove connection'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove').last);
      await tester.pumpAndSettle();
      expect(network.actions, ['accepted', 'removed']);
      expect(find.text('No connections yet'), findsOneWidget);
    },
  );
  testWidgets(
    'Profile request status updates and outgoing cancel is available',
    (tester) async {
      final network = FakeConnectionsRepository();
      await pumpNetworking(tester, '/alumni/id-001', network: network);
      await tester.ensureVisible(find.text('Connect'));
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();
      expect(network.sends, 1);
      expect(find.text('Request sent'), findsOneWidget);
      await tester.ensureVisible(find.text('Cancel request'));
      await tester.tap(find.text('Cancel request'));
      await tester.pumpAndSettle();
      expect(network.actions, ['cancelled']);
      expect(find.text('Connect'), findsOneWidget);
    },
  );
  testWidgets(
    'Network failure is retryable and does not display fabricated members',
    (tester) async {
      final network = FakeConnectionsRepository()..fail = true;
      await pumpNetworking(tester, AppRoutes.network, network: network);
      expect(find.textContaining('Network unavailable'), findsOneWidget);
      network.fail = false;
      await tester.ensureVisible(find.text('Retry network'));
      await tester.tap(find.text('Retry network'));
      await tester.pumpAndSettle();
      expect(find.text('No connections yet'), findsOneWidget);
    },
  );
  testWidgets('Pending users cannot navigate to map or network', (
    tester,
  ) async {
    await pumpNetworking(
      tester,
      AppRoutes.map,
      membership: MembershipState.pending,
    );
    expect(find.text('Verification pending'), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);
  });
}
