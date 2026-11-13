import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_providers.dart';
import '../domain/career_repository.dart';

class SupabaseCareerRepository implements CareerRepository {
  SupabaseCareerRepository(this.client);
  final SupabaseClient client;
  Future<dynamic> _rpc(String name, [Map<String, dynamic> params = const {}]) =>
      client.rpc(name, params: params).timeout(const Duration(seconds: 20));
  @override
  Future<bool> canPublish() async => await _rpc('career_can_publish') as bool;
  @override
  Future<List<CareerPost>> list(
    Map<String, dynamic> filters, {
    CareerPost? after,
  }) async {
    final r = await _rpc('career_opportunities', {
      'p_filters': filters,
      'p_after': after?.cursor,
      'p_limit': 21,
    });
    return (r as List)
        .map((v) => CareerPost(Map<String, dynamic>.from(v as Map)))
        .toList();
  }

  @override
  Future<CareerPost?> detail(String id) async {
    final r = await _rpc('career_opportunities', {
      'p_id': id,
      'p_filters': {'status': 'all'},
      'p_limit': 1,
    }) as List;
    return r.isEmpty
        ? null
        : CareerPost(Map<String, dynamic>.from(r.first as Map));
  }

  @override
  Future<String> save(
    String id,
    Map<String, dynamic> input, {
    String? expected,
  }) async => await _rpc('save_career_opportunity', {
    'p_id': id,
    'p_input': input,
    'p_expected': expected,
  }) as String;
  @override
  Future<void> transition(String id, String action) async {
    await _rpc('transition_career_opportunity', {
      'p_id': id,
      'p_action': action,
    });
  }

  @override
  Future<void> report(String id, String reason, String details) async {
    await _rpc('report_career_opportunity', {
      'p_id': id,
      'p_reason': reason,
      'p_details': details,
    });
  }

  @override
  Future<Map<String, String>> skillNames(List<String> ids) async {
    if (ids.isEmpty) return {};
    if (ids.length > 30) throw StateError('Skill bound exceeded');
    final rows = await client
        .from('skills')
        .select('id,name')
        .inFilter('id', ids)
        .timeout(const Duration(seconds: 20));
    return {for (final row in rows) row['id'] as String: row['name'] as String};
  }
}

final careerRepositoryProvider = Provider<CareerRepository>((ref) {
  ref.watch(authControllerProvider.select((s) => s.userId));
  final client = ref.watch(supabaseClientProvider);
  if (client == null) throw StateError('Backend unavailable');
  return SupabaseCareerRepository(client);
});
