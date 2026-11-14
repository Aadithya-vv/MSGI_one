import '../../auth/domain/onboarding.dart';

class MemberProfile {
  const MemberProfile(
    this.input, {
    this.institution = '',
    this.department = '',
    this.skills = const [],
  });
  final OnboardingInput input;
  final String institution, department;
  final List<String> skills;
}

class DirectoryFilter {
  const DirectoryFilter({
    this.search = '',
    this.institution,
    this.department,
    this.year,
    this.programme,
    this.profession = '',
    this.skill,
    this.city,
  });
  final String search, profession;
  final String? institution, department, skill, city, programme;
  final int? year;
  Map<String, dynamic> params({String? after, int limit = 21, String? user}) =>
      {
        'p_search': search.trim(),
        'p_institution': institution,
        'p_department': department,
        'p_year': year,
        'p_profession': profession.trim(),
        'p_skill': skill,
        'p_city': city,
        'p_after': after,
        'p_limit': limit,
        'p_user': user,
      };
}

class AlumniProfile {
  AlumniProfile(this.data);
  final Map<String, dynamic> data;
  String get id => data['user_id'] as String;
  String get name => data['display_name'] as String;
  String text(String key) => data[key]?.toString() ?? '';
  List<String> get skills => (data['skills'] as List? ?? []).cast<String>();
  bool get mentoring => data['mentoring'] == true;
}

abstract class ProfileRepository {
  Future<MemberProfile?> own();
  Future<Map<String, dynamic>?> draft();
  Future<void> saveDraft(Map<String, dynamic> content);
  Future<void> save(OnboardingInput input);
  Future<List<AlumniProfile>> discover(DirectoryFilter filter, {String? after});
  Future<AlumniProfile?> detail(String userId);
}
