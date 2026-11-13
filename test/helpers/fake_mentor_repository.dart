import 'package:msgi_one/features/mentorship/domain/mentor_repository.dart';
import 'package:msgi_one/features/catalog/domain/catalog_repository.dart';
import 'package:msgi_one/features/auth/domain/onboarding.dart';

class FakeMentorCatalog implements CatalogRepository {
  @override
  Future<List<CatalogEntry>> search(
    CatalogKind kind, {
    String query = '',
    String? institutionId,
    int page = 0,
  }) async => page > 0
      ? []
      : [const CatalogEntry(id: 'skill-a', name: 'Synthetic circuit skill')];
}

class FakeMentorRepository implements MentorRepository {
  bool fail = false;
  MentorGoals value = const MentorGoals(
    interests: ['Research'],
    domains: ['Embedded Systems'],
  );
  String? lastDomain, lastSort, lastAfter;
  bool? lastUnconnected;
  final hidden = <String>{};
  List<MentorRecommendation> people = List.generate(
    25,
    (i) => MentorRecommendation({
      'user_id': 'id-${i.toString().padLeft(3, '0')}',
      'display_name': 'Synthetic mentor $i',
      'score': 85,
      'evidence_count': 2,
      'rank_value': 85,
      'institution': 'Synthetic institute',
      'company': 'Synthetic organization',
      'designation': 'Engineer',
      'professional_domain': 'Embedded Systems',
      'shared_skills': ['Circuit design'],
      'matching_domains': ['Embedded Systems'],
      'shared_interests': [],
      'connection_status': null,
      'incoming': false,
    }),
  );
  @override
  Future<MentorGoals> goals() async {
    if (fail) throw StateError('Offline');
    return value;
  }

  @override
  Future<void> save(MentorGoals goals) async {
    if (fail) throw StateError('Offline');
    value = goals;
  }

  @override
  Future<void> block(String peer, bool blocked) async {
    if (fail) throw StateError('Offline');
    blocked ? hidden.add(peer) : hidden.remove(peer);
  }

  @override
  Future<List<MentorRecommendation>> recommend({
    String domain = '',
    bool unconnected = false,
    String sort = 'relevance',
    MentorRecommendation? after,
  }) async {
    lastDomain = domain;
    lastSort = sort;
    lastAfter = after?.id;
    lastUnconnected = unconnected;
    if (fail) throw StateError('Offline');
    return people
        .where(
          (m) =>
              !hidden.contains(m.id) &&
              (after == null || m.id.compareTo(after.id) > 0) &&
              (domain.isEmpty ||
                  (m.data['professional_domain'] as String).contains(domain)),
        )
        .take(21)
        .toList();
  }
}
