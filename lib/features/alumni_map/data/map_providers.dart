import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_providers.dart';
import '../domain/map_repository.dart';

class SupabaseAlumniMapRepository implements AlumniMapRepository {
  SupabaseAlumniMapRepository(this.client);
  final SupabaseClient client;
  @override
  Future<List<CityCluster>> cities({
    String location = '',
    String domain = '',
    String? after,
  }) async {
    final rows = await client
        .rpc(
          'alumni_city_clusters',
          params: {
            'p_location': location.trim(),
            'p_domain': domain.trim(),
            'p_after': after,
            'p_limit': 101,
          },
        )
        .timeout(const Duration(seconds: 20));
    return (rows as List)
        .map(
          (r) => CityCluster(
            id: r['city_id'] as String,
            name: r['city'] as String,
            country: r['country_code'] as String,
            latitude: (r['latitude'] as num).toDouble(),
            longitude: (r['longitude'] as num).toDouble(),
            count: (r['alumni_count'] as num).toInt(),
          ),
        )
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> members(
    String city, {
    String domain = '',
    String? after,
  }) async {
    final rows = await client
        .rpc(
          'map_city_members',
          params: {
            'p_city': city,
            'p_domain': domain.trim(),
            'p_after': after,
            'p_limit': 21,
          },
        )
        .timeout(const Duration(seconds: 20));
    return (rows as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
  }
}

final alumniMapRepositoryProvider = Provider<AlumniMapRepository>((ref) {
  final c = ref.watch(supabaseClientProvider);
  if (c == null) throw StateError('Backend unavailable');
  return SupabaseAlumniMapRepository(c);
});
