class MentorGoals {
  const MentorGoals({
    this.interests = const [],
    this.domains = const [],
    this.existing = const [],
    this.learning = const [],
    this.objectives = const [],
    this.skillNames = const {},
  });
  final List<String> interests, domains, existing, learning, objectives;
  final Map<String, String> skillNames;
  factory MentorGoals.fromJson(Map<String, dynamic> r) => MentorGoals(
    interests: strings(r['career_interests']),
    domains: strings(r['target_domains']),
    existing: strings(r['existing_skill_ids']),
    learning: strings(r['learning_skill_ids']),
    objectives: strings(r['objectives']),
    skillNames: Map<String, String>.from(r['skill_names'] as Map? ?? {}),
  );
  Map<String, dynamic> toJson() => {
    'career_interests': interests,
    'target_domains': domains,
    'existing_skill_ids': existing,
    'learning_skill_ids': learning,
    'objectives': objectives,
  };
}

List<String> strings(dynamic value) => (value as List? ?? []).cast<String>();

class MentorRecommendation {
  MentorRecommendation(Map<String, dynamic> row) : data = Map.unmodifiable(row);
  final Map<String, dynamic> data;
  String get id => data['user_id'] as String;
  String get name => data['display_name'] as String;
  int get score => (data['score'] as num).toInt();
  int get evidence => (data['evidence_count'] as num).toInt();
  num get rank => data['rank_value'] as num;
  List<String> get skills => strings(data['shared_skills']);
  List<String> get domains => strings(data['matching_domains']);
  List<String> get interests => strings(data['shared_interests']);
  String? get connectionStatus => data['connection_status'] as String?;
  List<String> get reasons => [
    if (domains.isNotEmpty)
      'Works in your target domain: ${domains.join(', ')}',
    if (skills.isNotEmpty) 'Relevant skills: ${skills.join(', ')}',
    if (interests.isNotEmpty)
      'Shared career interests: ${interests.join(', ')}',
    'Open to mentorship',
  ];
}

abstract class MentorRepository {
  Future<MentorGoals> goals();
  Future<void> save(MentorGoals goals);
  Future<List<MentorRecommendation>> recommend({
    String domain = '',
    bool unconnected = false,
    String sort = 'relevance',
    MentorRecommendation? after,
  });
  Future<void> block(String peer, bool blocked);
}
