import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_providers.dart';
import '../domain/mentor_repository.dart';

class SupabaseMentorRepository implements MentorRepository {
  SupabaseMentorRepository(this.client);
  final SupabaseClient client;
  Future<dynamic> _rpc(String name, [Map<String, dynamic> params = const {}]) =>
      client.rpc(name, params: params).timeout(const Duration(seconds: 20));
  @override
  Future<MentorGoals> goals() async => MentorGoals.fromJson(
    Map<String, dynamic>.from(await _rpc('my_mentor_goals') as Map),
  );
  @override
  Future<void> save(MentorGoals goals) async {
    await _rpc('save_mentor_goals', {'p_input': goals.toJson()});
  }

  @override
  Future<void> block(String peer, bool blocked) async {
    await _rpc('set_mentor_block', {'p_peer': peer, 'p_block': blocked});
  }

  @override
  Future<List<MentorRecommendation>> recommend({
    String domain = '',
    bool unconnected = false,
    String sort = 'relevance',
    MentorRecommendation? after,
  }) async {
    final rows = await _rpc('recommend_mentors', {
      'p_domain': domain,
      'p_unconnected': unconnected,
      'p_sort': sort,
      'p_after_rank': after?.rank,
      'p_after_id': after?.id,
      'p_limit': 21,
    });
    return (rows as List)
        .map((r) => MentorRecommendation(Map<String, dynamic>.from(r as Map)))
        .toList();
  }
}

final mentorRepositoryProvider = Provider<MentorRepository>((ref) {
  ref.watch(authControllerProvider.select((s) => s.userId));
  final client = ref.watch(supabaseClientProvider);
  if (client == null) throw StateError('Backend unavailable');
  return SupabaseMentorRepository(client);
});
