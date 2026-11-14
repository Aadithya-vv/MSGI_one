import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/domain/onboarding.dart';
import '../domain/profile_repository.dart';

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this.client);
  final SupabaseClient client;
  String get user =>
      client.auth.currentUser?.id ?? (throw StateError('Sign in required'));
  @override
  Future<MemberProfile?> own() async {
    final row = await client
        .from('profiles')
        .select(
          '*,institutions(name),departments(name),programmes(name),profile_skills(skill_id,skills(name)),mentorship_preferences(available)',
        )
        .eq('user_id', user)
        .maybeSingle()
        .timeout(const Duration(seconds: 20));
    if (row == null) return null;
    final map = Map<String, dynamic>.from(row);
    map['kind'] = row['claimed_kind'];
    map['interests'] = row['career_interests'];
    map['skill_ids'] = (row['profile_skills'] as List)
        .map((s) => s['skill_id'])
        .toList();
    final mentors = row['mentorship_preferences'];
    map['mentoring'] = mentors is Map
        ? mentors['available'] == true
        : mentors is List &&
              mentors.isNotEmpty &&
              mentors.first['available'] == true;
    return MemberProfile(
      OnboardingInput.fromJson(map),
      institution:
          row['institutions']?['name'] as String? ?? 'Institution unavailable',
      department: row['departments']?['name'] as String? ?? '',
      skills: (row['profile_skills'] as List)
          .map((s) => s['skills']['name'] as String)
          .toList(),
    );
  }

  @override
  Future<Map<String, dynamic>?> draft() async {
    final row = await client
        .from('profile_drafts')
        .select('content')
        .eq('user_id', user)
        .maybeSingle()
        .timeout(const Duration(seconds: 20));
    return row == null
        ? null
        : Map<String, dynamic>.from(row['content'] as Map);
  }

  @override
  Future<void> saveDraft(Map<String, dynamic> content) async {
    await client.from('profile_drafts').upsert({
      'user_id': user,
      'content': content,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<void> save(OnboardingInput input) async {
    final problem = input.validate();
    if (problem != null) throw ArgumentError(problem);
    await client
        .rpc('save_member_profile', params: {'p_input': input.toJson()})
        .timeout(const Duration(seconds: 20));
  }

  @override
  Future<List<AlumniProfile>> discover(
    DirectoryFilter filter, {
    String? after,
  }) async {
    final rows = await client
        .rpc(
          'discover_alumni_v2',
          params: {
            ...filter.params(after: after),
            'p_programme': filter.programme,
          },
        )
        .timeout(const Duration(seconds: 20));
    return (rows as List)
        .map((r) => AlumniProfile(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  @override
  Future<AlumniProfile?> detail(String userId) async {
    final rows = await client.rpc(
      'discover_alumni_v2',
      params: const DirectoryFilter().params(user: userId, limit: 1),
    );
    return (rows as List).isEmpty
        ? null
        : AlumniProfile(Map<String, dynamic>.from(rows.first as Map));
  }
}
