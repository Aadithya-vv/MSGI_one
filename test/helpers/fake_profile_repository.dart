import 'package:msgi_one/features/profile/domain/profile_repository.dart';
import 'package:msgi_one/features/auth/domain/onboarding.dart';

class FakeProfileRepository implements ProfileRepository {
  MemberProfile? profile;
  Map<String, dynamic>? savedDraft;
  bool fail = false;
  DirectoryFilter? lastFilter;
  String? lastAfter;
  final people = List.generate(
    25,
    (i) => AlumniProfile({
      'user_id': 'id-${i.toString().padLeft(3, '0')}',
      'display_name': 'Test alumnus $i',
      'institution': 'Test institution',
      'department': 'Test department',
      'graduation_year': 2020,
      'company': 'Test company',
      'skills': ['Test skill'],
      'mentoring': true,
    }),
  );
  @override
  Future<MemberProfile?> own() async {
    if (fail) throw StateError('Offline');
    return profile;
  }

  @override
  Future<Map<String, dynamic>?> draft() async => savedDraft;
  @override
  Future<void> saveDraft(Map<String, dynamic> content) async {
    if (fail) throw StateError('Offline');
    savedDraft = content;
  }

  @override
  Future<void> save(OnboardingInput input) async {
    if (fail) throw StateError('Offline');
    profile = MemberProfile(
      input,
      institution: 'Test institution',
      department: 'Test department',
      skills: ['Test skill'],
    );
    savedDraft = null;
  }

  @override
  Future<List<AlumniProfile>> discover(
    DirectoryFilter filter, {
    String? after,
  }) async {
    if (fail) throw StateError('Offline');
    lastFilter = filter;
    lastAfter = after;
    return people
        .where(
          (p) =>
              (after == null || p.id.compareTo(after) > 0) &&
              p.name.toLowerCase().contains(filter.search.toLowerCase()),
        )
        .take(21)
        .toList();
  }

  @override
  Future<AlumniProfile?> detail(String userId) async =>
      people.where((p) => p.id == userId).firstOrNull;
}
