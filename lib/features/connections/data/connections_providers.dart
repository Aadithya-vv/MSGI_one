import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_providers.dart';
import '../domain/connections_repository.dart';

ProfessionalConnection _connection(Map<String, dynamic> r) =>
    ProfessionalConnection(
      id: r['connection_id'] as String,
      peerId: r['peer_id'] as String,
      status: r['status'] as String,
      incoming: r['incoming'] as bool,
      available: r['profile_available'] as bool,
      eligible: r['peer_eligible'] as bool,
      name: r['display_name'] as String?,
      company: r['company'] as String?,
    );

class SupabaseConnectionsRepository implements ConnectionsRepository {
  SupabaseConnectionsRepository(this.client);
  final SupabaseClient client;
  @override
  Future<List<ProfessionalConnection>> list(
    NetworkTab tab, {
    String? after,
  }) async {
    final rows = await client
        .rpc(
          'network_connections',
          params: {'p_tab': tab.name, 'p_after': after, 'p_limit': 21},
        )
        .timeout(const Duration(seconds: 20));
    return (rows as List)
        .map((r) => _connection(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  @override
  Future<ProfessionalConnection?> withMember(String peer) async {
    final rows = await client
        .rpc(
          'network_connections',
          params: {'p_tab': 'all', 'p_peer': peer, 'p_limit': 1},
        )
        .timeout(const Duration(seconds: 20));
    return (rows as List).isEmpty
        ? null
        : _connection(Map<String, dynamic>.from(rows.first as Map));
  }

  @override
  Future<void> send(String peer) async {
    await client
        .rpc('request_connection', params: {'p_recipient': peer})
        .timeout(const Duration(seconds: 20));
  }

  @override
  Future<void> transition(String id, String action) async {
    await client
        .rpc('manage_connection', params: {'p_id': id, 'p_action': action})
        .timeout(const Duration(seconds: 20));
  }
}

final connectionsRepositoryProvider = Provider<ConnectionsRepository>((ref) {
  final c = ref.watch(supabaseClientProvider);
  if (c == null) throw StateError('Backend unavailable');
  return SupabaseConnectionsRepository(c);
});
final connectionWithProvider = FutureProvider.autoDispose
    .family<ProfessionalConnection?, String>((ref, peer) {
      ref.watch(authControllerProvider);
      return ref.watch(connectionsRepositoryProvider).withMember(peer);
    });
final networkRevisionProvider = NotifierProvider<NetworkRevision, int>(
  NetworkRevision.new,
);

class NetworkRevision extends Notifier<int> {
  @override
  int build() => 0;
  void refresh() => state++;
}
