import 'package:msgi_one/features/opportunities/domain/career_repository.dart';

class FakeCareerRepository implements CareerRepository {
  bool fail = false, allowed = true;
  int saves = 0, reports = 0;
  String? lastId, lastExpected, lastAction;
  Map<String, dynamic>? lastFilters;
  CareerPost? lastAfter;
  List<CareerPost> rows = List.generate(
    25,
    (i) => CareerPost({
      'id': 'post-${i.toString().padLeft(3, '0')}',
      'author_id': 'fixture-user',
      'title': 'Synthetic role $i',
      'description': 'An explicitly synthetic career opportunity for tests.',
      'kind': 'job',
      'location_text': 'Synthetic city',
      'external_url': 'https://example.com/apply',
      'status': 'published',
      'professional_domain': 'Engineering',
      'organization': 'Synthetic organization',
      'remote': true,
      'referral': false,
      'audience': 'community',
      'archived': false,
      'created_at': '2026-11-14T00:00:00.000000Z',
      'updated_at': '2026-11-14T00:00:00.000000Z',
      'rank': 0,
      'required_skills': ['Synthetic circuit skill'],
      'skill_ids': ['skill-a'],
      'shared_count': 1,
      'author_name': 'Synthetic author',
      'author_available': true,
    }),
  );
  void check() {
    if (fail) throw StateError('Offline');
  }

  @override
  Future<bool> canPublish() async {
    check();
    return allowed;
  }

  @override
  Future<List<CareerPost>> list(
    Map<String, dynamic> filters, {
    CareerPost? after,
  }) async {
    check();
    lastFilters = Map.from(filters);
    lastAfter = after;
    return rows
        .where(
          (p) =>
              (after == null || p.id.compareTo(after.id) > 0) &&
              ((filters['search'] as String? ?? '').isEmpty ||
                  p.title.contains(filters['search'] as String)),
        )
        .take(21)
        .toList();
  }

  @override
  Future<CareerPost?> detail(String id) async {
    check();
    return rows.where((p) => p.id == id).firstOrNull;
  }

  @override
  Future<String> save(
    String id,
    Map<String, dynamic> input, {
    String? expected,
  }) async {
    check();
    if (!allowed) throw StateError('Denied');
    saves++;
    lastId = id;
    lastExpected = expected;
    final old = await detail(id);
    final base = Map<String, dynamic>.from(old?.data ?? rows.first.data);
    rows.removeWhere((p) => p.id == id);
    rows.add(
      CareerPost({
        ...base,
        ...input,
        'id': id,
        'author_id': 'fixture-user',
        'archived': false,
      }),
    );
    return id;
  }

  @override
  Future<void> transition(String id, String action) async {
    check();
    lastAction = action;
    rows = rows
        .map(
          (p) => p.id == id
              ? CareerPost({
                  ...p.data,
                  'status': 'closed',
                  'archived': action == 'archive',
                })
              : p,
        )
        .toList();
  }

  @override
  Future<void> report(String id, String reason, String details) async {
    check();
    reports++;
  }

  @override
  Future<Map<String, String>> skillNames(List<String> ids) async {
    check();
    return {for (final id in ids) id: 'Synthetic circuit skill'};
  }
}
