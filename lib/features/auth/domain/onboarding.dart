enum AccountKind { student, alumni }

class CatalogEntry {
  const CatalogEntry({
    required this.id,
    required this.name,
    this.institutionId,
    this.countryCode,
  });
  final String id;
  final String name;
  final String? institutionId;
  final String? countryCode;
}

class OnboardingOptions {
  const OnboardingOptions({
    required this.institutions,
    required this.departments,
    required this.skills,
    required this.cities,
  });
  final List<CatalogEntry> institutions;
  final List<CatalogEntry> departments;
  final List<CatalogEntry> skills;
  final List<CatalogEntry> cities;
}

class OnboardingInput {
  const OnboardingInput({
    required this.displayName,
    required this.kind,
    required this.institutionId,
    required this.departmentId,
    required this.joiningYear,
    required this.graduationYear,
    required this.interests,
    required this.skillIds,
    this.designation = '',
    this.cityId,
    this.directoryVisible = false,
    this.mapOptIn = false,
    this.company = '',
    this.professionalDomain = '',
    this.biography = '',
    this.degree = '',
    this.mentoring = false,
  });
  final String displayName;
  final AccountKind kind;
  final String institutionId;
  final String departmentId;
  final int joiningYear;
  final int graduationYear;
  final String designation;
  final List<String> interests;
  final List<String> skillIds;
  final String? cityId;
  final bool directoryVisible;
  final bool mapOptIn;
  final String company, professionalDomain, biography, degree;
  final bool mentoring;
  factory OnboardingInput.fromJson(Map<String, dynamic> j) => OnboardingInput(
    displayName: j['display_name'] as String? ?? '',
    kind: j['kind'] == 'alumni' ? AccountKind.alumni : AccountKind.student,
    institutionId: j['institution_id'] as String? ?? '',
    departmentId: j['department_id'] as String? ?? '',
    joiningYear: j['joining_year'] as int? ?? 0,
    graduationYear: j['graduation_year'] as int? ?? 0,
    interests: (j['interests'] as List? ?? []).cast<String>(),
    skillIds: (j['skill_ids'] as List? ?? []).cast<String>(),
    designation: j['designation'] as String? ?? '',
    cityId: j['city_id'] as String?,
    directoryVisible: j['directory_visible'] == true,
    mapOptIn: j['map_opt_in'] == true,
    company: j['company'] as String? ?? '',
    professionalDomain: j['professional_domain'] as String? ?? '',
    biography: j['biography'] as String? ?? '',
    degree: j['degree'] as String? ?? '',
    mentoring: j['mentoring'] == true,
  );
  Map<String, dynamic> toJson() => {
    'display_name': displayName.trim(),
    'kind': kind.name,
    'institution_id': institutionId,
    'department_id': departmentId,
    'joining_year': joiningYear,
    'graduation_year': graduationYear,
    'interests': interests,
    'skill_ids': skillIds,
    'designation': designation.trim(),
    'city_id': cityId,
    'directory_visible': directoryVisible,
    'map_opt_in': mapOptIn,
    'company': company.trim(),
    'professional_domain': professionalDomain.trim(),
    'biography': biography.trim(),
    'degree': degree.trim(),
    'mentoring': mentoring,
  };
  String? validate({int? currentYear}) {
    final year = currentYear ?? DateTime.now().year;
    if (company.length > 120 ||
        professionalDomain.length > 120 ||
        degree.length > 120 ||
        biography.length > 1000) {
      return 'Professional fields must be at most 120 characters; biography at most 1000.';
    }
    if (displayName.trim().length < 2 || displayName.trim().length > 80) {
      return 'Display name must contain 2–80 characters.';
    }
    if (institutionId.isEmpty || departmentId.isEmpty) {
      return 'Select your institution and department.';
    }
    if (joiningYear < 1950 ||
        joiningYear > year ||
        graduationYear < joiningYear ||
        graduationYear > year + 8 ||
        (kind == AccountKind.alumni && graduationYear > year)) {
      return 'Check joining and graduation years for your account type.';
    }
    if (designation.length > 120) {
      return 'Designation must be at most 120 characters.';
    }
    if (interests.isEmpty ||
        interests.length > 10 ||
        interests.any((v) => v.trim().isEmpty || v.trim().length > 80)) {
      return 'Add 1–10 career interests, each at most 80 characters.';
    }
    if (skillIds.isEmpty ||
        skillIds.length > 20 ||
        skillIds.toSet().length != skillIds.length) {
      return 'Select 1–20 distinct skills.';
    }
    if (mapOptIn && !directoryVisible) {
      return 'Enable directory visibility before opting into the map.';
    }
    if (mapOptIn && (cityId == null || cityId!.isEmpty)) {
      return 'Select a city before opting into the map.';
    }
    return null;
  }

  Map<String, Object?> toRpc() => {
    'p_display_name': displayName.trim(),
    'p_kind': kind.name,
    'p_institution': institutionId,
    'p_department': departmentId,
    'p_joining_year': joiningYear,
    'p_graduation_year': graduationYear,
    'p_designation': designation.trim(),
    'p_interests': interests.map((s) => s.trim()).toList(),
    'p_skills': skillIds,
    'p_city': cityId,
    'p_directory_visible': directoryVisible,
    'p_map_opt_in': mapOptIn,
  };
}
