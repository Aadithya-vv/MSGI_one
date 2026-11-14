import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:msgi_one/features/demo/domain/demo_store.dart';
import 'package:msgi_one/features/demo/data/demo_repositories.dart';
import 'package:msgi_one/features/demo/presentation/demo_experience.dart';
import 'package:msgi_one/features/auth/application/auth_providers.dart';
import 'package:msgi_one/core/community_identity.dart';
import 'package:msgi_one/features/connections/domain/connections_repository.dart';
import 'package:msgi_one/features/profile/domain/profile_repository.dart';
import 'package:msgi_one/features/mentorship/domain/mentor_repository.dart';
import 'package:msgi_one/features/opportunities/data/career_providers.dart';
import 'package:msgi_one/features/profile/data/profile_providers.dart';

import 'helpers/fake_profile_repository.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  test(
    'Perspective changes cannot misattribute an in-flight demo publish',
    () async {
      final s = DemoStore()..switchRole(DemoRole.alumni);
      addTearDown(s.dispose);
      final repo = DemoCareerRepository(s);
      final input = (await repo.detail('demo-post-01'))!.input;
      final future = repo.save('demo-race', input);
      s.switchRole(DemoRole.student);
      await expectLater(future, throwsStateError);
      expect(s.posts.containsKey('demo-race'), false);
    },
  );
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Fixture network is coherent, fictional and contains required perspectives',
    () {
      final s = DemoStore();
      addTearDown(s.dispose);
      expect(s.profiles.length, 36);
      expect(s.profiles.values.where((p) => p['role'] == 'alumni').length, 24);
      expect(s.profiles.values.where((p) => p['role'] == 'student').length, 8);
      expect(s.profiles.values.where((p) => p['role'] == 'staff').length, 4);
      expect(s.posts.length, 12);
      for (final p in s.profiles.values) {
        expect(
          (p['display_name'] as String).split(' ').length,
          greaterThanOrEqualTo(2),
        );
        expect(p['display_name'], isNot(contains('Alumni 0')));
        expect(p.containsKey('verified'), false);
        expect(p.containsKey('email'), false);
        expect((p['institution'] as String).startsWith('Sample'), true);
      }
      for (final p in s.posts.values) {
        expect(s.profiles.containsKey(p['author_id']), true);
        expect(p['external_url'], '');
        expect(p['description'], contains('not a real vacancy'));
      }
    },
  );
  test(
    'Demo scope has no Auth session, API client or inherited real repository',
    () async {
      final store = DemoStore();
      final real = FakeProfileRepository();
      final parent = ProviderContainer(
        overrides: [profileRepositoryProvider.overrideWithValue(real)],
      );
      final demo = createDemoContainer(store);
      addTearDown(parent.dispose);
      addTearDown(demo.dispose);
      addTearDown(store.dispose);
      expect(demo.read(supabaseClientProvider), isNull);
      expect(demo.read(authRepositoryProvider), isNull);
      expect(demo.read(authControllerProvider).isVerified, false);
      expect(demo.read(communityUserIdProvider), 'demo-student-01');
      expect(identical(demo.read(profileRepositoryProvider), real), false);
      expect(await demo.read(careerRepositoryProvider).canPublish(), false);
      expect(real.savedDraft, isNull);
    },
  );
  test(
    'Staff perspective cannot publish or become a real administrator',
    () async {
      final s = DemoStore()..switchRole(DemoRole.staff);
      final scope = createDemoContainer(s);
      addTearDown(scope.dispose);
      addTearDown(s.dispose);
      expect(scope.read(authRepositoryProvider), isNull);
      expect(scope.read(authControllerProvider).isVerified, false);
      expect(scope.read(communityUserIdProvider), 'demo-staff-01');
      expect(await scope.read(careerRepositoryProvider).canPublish(), false);
    },
  );
  test(
    'Directory filters and pagination use fixture catalogs consistently',
    () async {
      final s = DemoStore();
      addTearDown(s.dispose);
      final r = DemoProfileRepository(s);
      final page = await r.discover(const DirectoryFilter());
      expect(page.length, 21);
      final more = await r.discover(
        const DirectoryFilter(),
        after: page[19].id,
      );
      expect(more.length, 3);
      expect(
        more.any((p) => page.take(20).any((first) => p.id == first.id)),
        false,
      );
      expect(
        (await r.discover(
          const DirectoryFilter(profession: 'Software Engineering'),
        )).every(
          (p) => p.text('professional_domain') == 'Software Engineering',
        ),
        true,
      );
      expect(await r.detail('demo-alumni-24'), isNull);
    },
  );
  test(
    'Requests are shared across roles, idempotent and participant-controlled',
    () async {
      final s = DemoStore();
      addTearDown(s.dispose);
      final r = DemoConnectionsRepository(s);
      await r.send('demo-alumni-08');
      final n = s.connections.length;
      await r.send('demo-alumni-08');
      expect(s.connections.length, n);
      expect((await r.withMember('demo-alumni-08'))!.status, 'pending');
      await expectLater(
        r.transition('demo-link-01', 'accepted'),
        throwsStateError,
      );
      s.switchRole(DemoRole.alumni);
      expect(
        (await r.list(NetworkTab.incoming))
            .any((p) => p.peerId == 'demo-student-01'),
        true,
      );
      await r.transition('demo-link-01', 'accepted');
      s.switchRole(DemoRole.student);
      expect((await r.withMember('demo-alumni-01'))!.status, 'accepted');
      await r.transition('demo-link-01', 'removed');
      expect((await r.withMember('demo-alumni-01'))!.status, 'cancelled');
      await expectLater(r.send(s.actor), throwsStateError);
    },
  );
  test(
    'Mentor scores, evidence and cursor ties remain deterministic',
    () async {
      final s = DemoStore();
      addTearDown(s.dispose);
      final r = DemoMentorRepository(s);
      final first = await r.recommend();
      expect(first.first.score, 100);
      expect(first.first.domains, ['Software Engineering']);
      expect(first.first.skills, ['Dart', 'Flutter', 'SQL']);
      expect(first.first.evidence, 3);
      expect(first.first.id, 'demo-alumni-02');
      final after = await r.recommend(after: first.first);
      expect(after.any((m) => m.id == first.first.id), false);
      await r.save(const MentorGoals());
      expect((await r.recommend()).every((m) => m.score == 0), true);
    },
  );
  test(
    'Mentoring and privacy changes update all role views and map counts',
    () async {
      final s = DemoStore();
      addTearDown(s.dispose);
      final mentors = DemoMentorRepository(s),
          map = DemoMapRepository(s),
          profiles = DemoProfileRepository(s);
      expect((await map.cities()).fold(0, (sum, c) => sum + c.count), 22);
      s.switchRole(DemoRole.alumni);
      s.updatePerson({'mentoring': false, 'directory_visible': false});
      s.switchRole(DemoRole.student);
      expect(
        (await mentors.recommend()).any((m) => m.id == 'demo-alumni-01'),
        false,
      );
      expect(
        (await profiles.discover(const DirectoryFilter()))
            .any((m) => m.id == 'demo-alumni-01'),
        false,
      );
      expect((await map.cities()).fold(0, (sum, c) => sum + c.count), 21);
      final city = (await map.cities(location: 'London')).single;
      expect((await map.members(city.id)).length, city.count);
    },
  );
  test(
    'Career mutations remain local and visible across perspectives',
    () async {
      final s = DemoStore();
      addTearDown(s.dispose);
      final r = DemoCareerRepository(s);
      final input = (await r.detail('demo-post-01'))!.input;
      input['title'] = 'Demo-created internship';
      input['kind'] = 'internship';
      input['status'] = 'published';
      await expectLater(r.save('demo-added', input), throwsStateError);
      s.switchRole(DemoRole.alumni);
      await r.save('demo-added', input);
      await r.save('demo-added', input);
      expect(s.posts.length, 13);
      s.switchRole(DemoRole.student);
      expect(
        (await r.list({'search': 'Demo-created'})).single.title,
        'Demo-created internship',
      );
      await r.report(
        'demo-added',
        'other',
        'Fictional simulated report details.',
      );
      expect(s.reports.length, 1);
      s.switchRole(DemoRole.alumni);
      await r.transition('demo-added', 'archive');
      s.switchRole(DemoRole.student);
      expect(await r.detail('demo-added'), isNull);
    },
  );
  test(
    'Demo reset and serialized restoration keep relationships consistent',
    () async {
      final s = DemoStore();
      addTearDown(s.dispose);
      await DemoConnectionsRepository(s).send('demo-alumni-08');
      s.switchRole(DemoRole.staff);
      final restored = DemoStore.restore(
        jsonDecode(jsonEncode(s.snapshot())) as Map<String, dynamic>,
      );
      addTearDown(restored.dispose);
      expect(restored.role, DemoRole.staff);
      expect(restored.active, true);
      expect(restored.connections.length, 7);
      restored.reset();
      expect(restored.role, DemoRole.student);
      expect(restored.connections.length, 6);
      expect(restored.posts.length, 12);
      expect(restored.connections['demo-link-01']!['status'], 'pending');
    },
  );
  test('Corrupt or unsupported demo state falls back to packaged fixtures', () {
    final s = DemoStore();
    final bad = jsonDecode(jsonEncode(s.snapshot())) as Map<String, dynamic>;
    ((bad['profiles'] as Map)['demo-student-01'] as Map).remove('display_name');
    final restored = DemoStore.restore(bad);
    expect(restored.person['display_name'], 'Mira Rao');
    expect(restored.active, false);
    expect(DemoStore.restore({'version': 999}).profiles.length, 36);
    s.dispose();
    restored.dispose();
  });
}
