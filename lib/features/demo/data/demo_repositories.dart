import 'dart:math' as math;

import '../domain/demo_store.dart';
import '../../catalog/domain/academic_catalog.dart';
import '../../auth/domain/onboarding.dart';
import '../../catalog/domain/catalog_repository.dart';
import '../../profile/domain/profile_repository.dart';
import '../../alumni_map/domain/map_repository.dart';
import '../../connections/domain/connections_repository.dart';
import '../../mentorship/domain/mentor_repository.dart';
import '../../opportunities/domain/career_repository.dart';

bool _contains(Object? value, String query) =>
    value.toString().toLowerCase().contains(query.trim().toLowerCase());
List<String> _ids(Map<String, dynamic> p) =>
    (p['skill_ids'] as List).cast<String>();
bool _visible(Map<String, dynamic> p) => p['directory_visible'] == true;
Map<String, dynamic> demoPublicProfile(Map<String, dynamic> p) => {
  ...p,
  'institution_short': MsecCatalog.catalog.shortName,
  'skills': _ids(p).map(DemoStore.skillName).toList(),
  'city': p['map_opt_in'] == true
      ? DemoStore.cities[int.parse((p['city_id'] as String).split('-').last)].$1
      : '',
  'country_code': p['map_opt_in'] == true
      ? DemoStore.cities[int.parse((p['city_id'] as String).split('-').last)].$2
      : '',
};

class DemoCatalogRepository implements CatalogRepository {
  @override
  Future<List<CatalogEntry>> search(
    CatalogKind kind, {
    String query = '',
    String? institutionId,
    int page = 0,
  }) async {
    final rows = switch (kind) {
      CatalogKind.institutions => [
        const CatalogEntry(id: MsecCatalog.id, name: MsecCatalog.name),
      ],
      CatalogKind.departments => [
        for (final d in MsecCatalog.catalog.departments)
          CatalogEntry(id: d.id, name: d.name, institutionId: d.institutionId),
      ],
      CatalogKind.skills => [
        for (var i = 0; i < DemoStore.skillLabels.length; i++)
          CatalogEntry(
            id: DemoStore.skillId(i),
            name: DemoStore.skillLabels[i],
          ),
      ],
      CatalogKind.cities => [
        for (var i = 0; i < DemoStore.cities.length; i++)
          CatalogEntry(
            id: DemoStore.cityId(i),
            name: DemoStore.cities[i].$1,
            countryCode: DemoStore.cities[i].$2,
          ),
      ],
    };
    return rows
        .where(
          (e) =>
              _contains(e.name, query) &&
              (institutionId == null || e.institutionId == institutionId),
        )
        .skip(page * 50)
        .take(50)
        .toList();
  }
}

class DemoProfileRepository implements ProfileRepository {
  DemoProfileRepository(this.store);
  final DemoStore store;
  @override
  Future<MemberProfile?> own() async {
    final p = store.person;
    if (store.role == DemoRole.staff) return null;
    return MemberProfile(
      OnboardingInput.fromJson({
        ...p,
        'kind': store.role.name,
        'interests': p['career_interests'],
      }),
      institution: p['institution'] as String,
      department: p['department'] as String,
      skills: _ids(p).map(DemoStore.skillName).toList(),
    );
  }

  @override
  Future<Map<String, dynamic>?> draft() async =>
      store.goals['profile-draft:${store.actor}'];
  @override
  Future<void> saveDraft(Map<String, dynamic> content) async {
    store.goals['profile-draft:${store.actor}'] = Map.from(content);
    store.changed();
  }

  @override
  Future<void> save(OnboardingInput input) async {
    if (input.validate() != null || store.role == DemoRole.staff) {
      throw StateError('Invalid demo profile');
    }
    store.updatePerson({
      'display_name': input.displayName,
      'biography': input.biography,
      'directory_visible': input.directoryVisible,
      'map_opt_in': input.mapOptIn,
      'mentoring': input.mentoring,
    });
  }

  @override
  Future<List<AlumniProfile>> discover(
    DirectoryFilter f, {
    String? after,
  }) async {
    final rows =
        store.profiles.values
            .where(
              (p) =>
                  p['role'] == 'alumni' &&
                  _visible(p) &&
                  _contains(p['display_name'], f.search) &&
                  _contains(
                    '${p['designation']} ${p['company']} ${p['professional_domain']}',
                    f.profession,
                  ) &&
                  (f.institution == null ||
                      p['institution_id'] == f.institution) &&
                  (f.department == null ||
                      p['department_id'] == f.department) &&
                  (f.year == null || p['graduation_year'] == f.year) &&
                  (f.programme == null || p['programme_id'] == f.programme) &&
                  (f.skill == null || _ids(p).contains(f.skill)) &&
                  (f.city == null ||
                      (p['map_opt_in'] == true && p['city_id'] == f.city)) &&
                  (after == null ||
                      (p['user_id'] as String).compareTo(after) > 0),
            )
            .toList()
          ..sort(
            (a, b) =>
                (a['user_id'] as String).compareTo(b['user_id'] as String),
          );
    return rows
        .take(21)
        .map((p) => AlumniProfile(demoPublicProfile(p)))
        .toList();
  }

  @override
  Future<AlumniProfile?> detail(String userId) async {
    final p = store.profiles[userId];
    return p == null || (!_visible(p) && userId != store.actor)
        ? null
        : AlumniProfile(demoPublicProfile(p));
  }
}

class DemoMapRepository implements AlumniMapRepository {
  DemoMapRepository(this.store);
  final DemoStore store;
  Iterable<Map<String, dynamic>> eligible(String domain) =>
      store.profiles.values.where(
        (p) =>
            p['role'] == 'alumni' &&
            _visible(p) &&
            p['map_opt_in'] == true &&
            _contains(p['professional_domain'], domain),
      );
  @override
  Future<List<CityCluster>> cities({
    String location = '',
    String domain = '',
    String? after,
  }) async => [
    for (var i = 0; i < DemoStore.cities.length; i++)
      if ((after == null || DemoStore.cityId(i).compareTo(after) > 0) &&
          _contains(
            '${DemoStore.cities[i].$1} ${DemoStore.cities[i].$2}',
            location,
          ) &&
          eligible(domain).any((p) => p['city_id'] == DemoStore.cityId(i)))
        CityCluster(
          id: DemoStore.cityId(i),
          name: DemoStore.cities[i].$1,
          country: DemoStore.cities[i].$2,
          latitude: DemoStore.cities[i].$3,
          longitude: DemoStore.cities[i].$4,
          count: eligible(domain)
              .where((p) => p['city_id'] == DemoStore.cityId(i))
              .length,
        ),
  ];
  @override
  Future<List<Map<String, dynamic>>> members(
    String city, {
    String domain = '',
    String? after,
  }) async => eligible(domain)
      .where(
        (p) =>
            p['city_id'] == city &&
            (after == null || (p['user_id'] as String).compareTo(after) > 0),
      )
      .take(21)
      .map(demoPublicProfile)
      .toList();
}

class DemoConnectionsRepository implements ConnectionsRepository {
  DemoConnectionsRepository(this.store);
  final DemoStore store;
  ProfessionalConnection _row(Map<String, dynamic> r) {
    final peer =
            (r['sender'] == store.actor ? r['recipient'] : r['sender'])
                as String,
        p = store.profiles[peer]!;
    return ProfessionalConnection(
      id: r['id'] as String,
      peerId: peer,
      status: r['status'] as String,
      incoming: r['recipient'] == store.actor,
      available: _visible(p),
      name: _visible(p) ? p['display_name'] as String : null,
      company: _visible(p) ? p['company'] as String : null,
    );
  }

  @override
  Future<ProfessionalConnection?> withMember(String peer) async {
    final r = store.relationship(peer);
    return r == null ? null : _row(r);
  }

  @override
  Future<List<ProfessionalConnection>> list(
    NetworkTab tab, {
    String? after,
  }) async {
    final rows =
        store.connections.values
            .where(
              (c) =>
                  (c['sender'] == store.actor ||
                      c['recipient'] == store.actor) &&
                  (after == null || (c['id'] as String).compareTo(after) > 0) &&
                  switch (tab) {
                    NetworkTab.accepted => c['status'] == 'accepted',
                    NetworkTab.incoming =>
                      c['status'] == 'pending' && c['recipient'] == store.actor,
                    NetworkTab.outgoing =>
                      c['status'] == 'pending' && c['sender'] == store.actor,
                  },
            )
            .toList()
          ..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
    return rows.take(21).map(_row).toList();
  }

  @override
  Future<void> send(String peer) async {
    final p = store.profiles[peer];
    if (p == null || peer == store.actor || !_visible(p)) {
      throw StateError('Demo member unavailable');
    }
    final r = store.relationship(peer);
    if (r != null) {
      if (r['status'] == 'rejected') throw StateError('Demo request declined');
      if (r['status'] == 'pending' || r['status'] == 'accepted') return;
      r.addAll({'sender': store.actor, 'recipient': peer, 'status': 'pending'});
    } else {
      final id = 'demo-link-${store.tick++}';
      store.connections[id] = {
        'id': id,
        'sender': store.actor,
        'recipient': peer,
        'status': 'pending',
      };
    }
    store.changed();
  }

  @override
  Future<void> transition(String id, String action) async {
    final r = store.connections[id];
    if (r == null || ![r['sender'], r['recipient']].contains(store.actor)) {
      throw StateError('Demo relationship unavailable');
    }
    if (['accepted', 'rejected'].contains(action) &&
        r['recipient'] != store.actor) {
      throw StateError('Recipient action only');
    }
    if (action == 'cancelled' && r['sender'] != store.actor) {
      throw StateError('Sender action only');
    }
    if (!['accepted', 'rejected', 'cancelled', 'removed'].contains(action)) {
      throw StateError('Unknown action');
    }
    if (r['status'] == action ||
        (action == 'removed' && r['status'] == 'cancelled')) {
      return;
    }
    if ((action == 'removed' && r['status'] != 'accepted') ||
        (action != 'removed' && r['status'] != 'pending')) {
      throw StateError('Stale demo request');
    }
    r['status'] = action == 'removed' ? 'cancelled' : action;
    store.changed();
  }
}

class DemoMentorRepository implements MentorRepository {
  DemoMentorRepository(this.store);
  final DemoStore store;
  @override
  Future<MentorGoals> goals() async {
    final g = store.goals[store.actor];
    return g == null
        ? MentorGoals(
            interests: (store.person['career_interests'] as List)
                .cast<String>(),
            domains: [store.person['professional_domain'] as String],
            existing: _ids(store.person),
            learning: store.role == DemoRole.student
                ? [DemoStore.skillId(5)]
                : [],
            skillNames: {
              for (final id in DemoStore.skillLabels.indexed.map(
                (e) => DemoStore.skillId(e.$1),
              ))
                id: DemoStore.skillName(id),
            },
          )
        : MentorGoals.fromJson({
            ...g,
            'skill_names': {
              for (var i = 0; i < 12; i++)
                DemoStore.skillId(i): DemoStore.skillLabels[i],
            },
          });
  }

  @override
  Future<void> save(MentorGoals g) async {
    if (g.interests.length > 10 ||
        g.domains.length > 10 ||
        g.objectives.length > 10 ||
        g.existing.length > 30 ||
        g.learning.length > 30) {
      throw StateError('Too many demo goals');
    }
    store.goals[store.actor] = g.toJson();
    store.changed();
  }

  @override
  Future<void> block(String peer, bool blocked) async {
    if (peer == store.actor || !store.profiles.containsKey(peer)) {
      throw StateError('Invalid sample member');
    }
    final key = '${store.actor}|$peer';
    blocked ? store.blocks.add(key) : store.blocks.remove(key);
    store.changed();
  }

  @override
  Future<List<MentorRecommendation>> recommend({
    String domain = '',
    bool unconnected = false,
    String sort = 'relevance',
    MentorRecommendation? after,
  }) async {
    final g = await goals(),
        wanted = {...g.existing, ...g.learning},
        interests = g.interests.map((s) => s.trim().toLowerCase()).toSet(),
        domains = g.domains.map((s) => s.trim().toLowerCase()).toSet();
    final rows = <MentorRecommendation>[];
    for (final p in store.profiles.values) {
      final id = p['user_id'] as String, c = store.relationship(id);
      if (id == store.actor ||
          p['role'] != 'alumni' ||
          !_visible(p) ||
          p['mentoring'] != true ||
          !_contains(p['professional_domain'], domain) ||
          store.blocks.contains('${store.actor}|$id') ||
          store.blocks.contains('$id|${store.actor}') ||
          (unconnected && c != null && c['status'] != 'cancelled')) {
        continue;
      }
      final ids = _ids(p),
          shared = wanted.intersection(ids.toSet()),
          pi = (p['career_interests'] as List)
              .cast<String>()
              .map((s) => s.toLowerCase())
              .toSet();
      final matched = interests.intersection(pi);
      final sk = wanted.isNotEmpty && ids.isNotEmpty
          ? shared.length / wanted.length
          : null;
      final dm =
          domains.isNotEmpty && (p['professional_domain'] as String).isNotEmpty
          ? (domains.contains(
                  (p['professional_domain'] as String).toLowerCase(),
                )
                ? 1.0
                : 0.0)
          : null;
      final intr = interests.isNotEmpty && pi.isNotEmpty
          ? matched.length / interests.length
          : null;
      final evidence = [sk, dm, intr].whereType<double>().length;
      final denominator =
          .2 +
          (sk == null ? 0 : .4) +
          (dm == null ? 0 : .3) +
          (intr == null ? 0 : .1);
      final cap = evidence == 1
          ? 65
          : evidence == 2
          ? 85
          : 100;
      final score = (sk ?? 0) + (dm ?? 0) + (intr ?? 0) == 0
          ? 0
          : math.min(
              cap,
              (100 *
                      (.4 * (sk ?? 0) +
                          .3 * (dm ?? 0) +
                          .2 +
                          .1 * (intr ?? 0)) /
                      denominator)
                  .round(),
            );
      final rank =
          (score +
          (sort == 'skills'
              ? (sk ?? 0) * 1000
              : sort == 'domain'
              ? (dm ?? 0) * 1000
              : 0));
      rows.add(
        MentorRecommendation({
          ...p,
          'score': score,
          'evidence_count': evidence,
          'rank_value': rank,
          'shared_skills': shared.map(DemoStore.skillName).toList()..sort(),
          'matching_domains': dm == 1 ? [p['professional_domain']] : <String>[],
          'shared_interests': (p['career_interests'] as List)
              .where((v) => matched.contains((v as String).toLowerCase()))
              .toList(),
          'connection_status': c?['status'],
          'incoming': c?['recipient'] == store.actor,
        }),
      );
    }
    rows.sort((a, b) {
      final rank = b.rank.compareTo(a.rank);
      return rank != 0 ? rank : a.id.compareTo(b.id);
    });
    return rows
        .where(
          (r) =>
              after == null ||
              r.rank < after.rank ||
              (r.rank == after.rank && r.id.compareTo(after.id) > 0),
        )
        .take(21)
        .toList();
  }
}

class DemoCareerRepository implements CareerRepository {
  DemoCareerRepository(this.store);
  final DemoStore store;
  @override
  Future<bool> canPublish() async => store.role == DemoRole.alumni;
  bool _allowed(Map<String, dynamic> p) =>
      p['author_id'] == store.actor ||
      (p['status'] == 'published' &&
          p['archived'] != true &&
          (p['audience'] == 'community' ||
              (store.profiles[p['author_id']]!['institution_id'] ==
                      store.person['institution_id'] &&
                  (p['audience'] == 'institution' ||
                      ((store.person['department_id'] as String).isNotEmpty &&
                          store.profiles[p['author_id']]!['department_id'] ==
                              store.person['department_id'])))));
  CareerPost _row(Map<String, dynamic> p, String sort) {
    final author = store.profiles[p['author_id']]!,
        skills = (p['skill_ids'] as List).cast<String>(),
        shared = skills.toSet().intersection(_ids(store.person).toSet()).length;
    return CareerPost({
      ...p,
      'rank': sort == 'relevance' && skills.isNotEmpty
          ? (100 * shared / skills.length).round()
          : 0,
      'shared_count': shared,
      'required_skills': skills.map(DemoStore.skillName).toList(),
      'author_name': _visible(author) ? author['display_name'] : null,
      'author_available': _visible(author),
    });
  }

  @override
  Future<List<CareerPost>> list(
    Map<String, dynamic> f, {
    CareerPost? after,
  }) async {
    final sort = f['sort'] as String? ?? 'recent';
    final rows = store.posts.values
        .where(
          (p) =>
              _allowed(p) &&
              (f['mine'] != true || p['author_id'] == store.actor) &&
              (f['mine'] == true || p['archived'] != true) &&
              (f['status'] == 'all' ||
                  p['status'] == (f['status'] ?? 'published')) &&
              (f['kind'] == null ||
                  f['kind'] == 'all' ||
                  p['kind'] == f['kind']) &&
              (f['scope'] == null ||
                  f['scope'] == 'all' ||
                  p['audience'] == f['scope']) &&
              (f['remote'] != true || p['remote'] == true) &&
              (f['referral'] != true || p['referral'] == true) &&
              _contains(
                '${p['title']} ${p['description']}',
                f['search'] as String? ?? '',
              ) &&
              _contains(
                p['professional_domain'],
                f['domain'] as String? ?? '',
              ) &&
              _contains(p['location_text'], f['location'] as String? ?? '') &&
              (f['skill'] == null ||
                  (p['skill_ids'] as List).contains(f['skill'])),
        )
        .map((p) => _row(p, sort))
        .toList();
    int compare(CareerPost a, CareerPost b) {
      final r = (b.data['rank'] as num).compareTo(a.data['rank'] as num);
      if (r != 0) return r;
      final t = (b.data['created_at'] as String).compareTo(
        a.data['created_at'] as String,
      );
      return t != 0 ? t : b.id.compareTo(a.id);
    }

    rows.sort(compare);
    return rows
        .where((p) => after == null || compare(p, after) > 0)
        .take(21)
        .toList();
  }

  @override
  Future<CareerPost?> detail(String id) async {
    final p = store.posts[id];
    return p == null || !_allowed(p) ? null : _row(p, 'recent');
  }

  @override
  Future<Map<String, String>> skillNames(List<String> ids) async => {
    for (final id in ids) id: DemoStore.skillName(id),
  };
  @override
  Future<String> save(
    String id,
    Map<String, dynamic> input, {
    String? expected,
  }) async {
    final actor = store.actor;
    if (!await canPublish() || actor != store.actor) {
      throw StateError('Only alumni publish in this simulation');
    }
    final old = store.posts[id];
    if (old != null) {
      if (old['author_id'] != store.actor || old['archived'] == true) {
        throw StateError('Not your demo post');
      }
      if (expected == null) return id;
      if (old['updated_at'] != expected) throw StateError('Reload demo post');
    }
    if ((input['title'] as String).trim().length < 3 ||
        (input['description'] as String).trim().length < 10) {
      throw StateError('Incomplete sample post');
    }
    if ((input['external_url'] as String).isNotEmpty) {
      throw StateError('Demo posts do not publish external application links');
    }
    final time = store.stamp();
    store.posts[id] = {
      ...input,
      'id': id,
      'author_id': store.actor,
      'created_at': old?['created_at'] ?? time,
      'updated_at': time,
      'archived': false,
    };
    store.changed();
    return id;
  }

  @override
  Future<void> transition(String id, String action) async {
    final p = store.posts[id];
    final actor = store.actor;
    if (!await canPublish() ||
        actor != store.actor ||
        p == null ||
        p['author_id'] != store.actor ||
        !['close', 'archive'].contains(action)) {
      throw StateError('Not your demo post');
    }
    p['status'] = 'closed';
    if (action == 'archive') p['archived'] = true;
    p['updated_at'] = store.stamp();
    store.changed();
  }

  @override
  Future<void> report(String id, String reason, String details) async {
    final p = store.posts[id];
    if (p == null ||
        !_allowed(p) ||
        p['author_id'] == store.actor ||
        details.trim().length < 10) {
      throw StateError('Invalid simulated report');
    }
    store.reports['${store.actor}|$id'] = {
      'reporter': store.actor,
      'post': id,
      'reason': reason,
      'details': details,
    };
    store.changed();
  }
}
