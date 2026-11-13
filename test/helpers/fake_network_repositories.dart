import 'package:msgi_one/features/alumni_map/domain/map_repository.dart';
import 'package:msgi_one/features/connections/domain/connections_repository.dart';

class FakeAlumniMapRepository implements AlumniMapRepository {
  bool fail = false;
  List<CityCluster> rows = [
    const CityCluster(
      id: 'city',
      name: 'Synthetic test city',
      country: 'IN',
      latitude: 20,
      longitude: 0,
      count: 2,
    ),
  ];
  final domains = <String>[];
  @override
  Future<List<CityCluster>> cities({
    String location = '',
    String domain = '',
    String? after,
  }) async {
    if (fail) throw StateError('Offline');
    domains.add(domain);
    return rows;
  }

  @override
  Future<List<Map<String, dynamic>>> members(
    String city, {
    String domain = '',
    String? after,
  }) async {
    if (fail) throw StateError('Offline');
    domains.add(domain);
    return [
      {
        'user_id': 'id-001',
        'display_name': 'Synthetic city alumna',
        'designation': 'Engineer',
        'company': 'Synthetic company',
      },
    ];
  }
}

class FakeConnectionsRepository implements ConnectionsRepository {
  bool fail = false;
  int sends = 0;
  final actions = <String>[];
  ProfessionalConnection? value;
  @override
  Future<List<ProfessionalConnection>> list(
    NetworkTab tab, {
    String? after,
  }) async {
    if (fail) throw StateError('Offline');
    final c = value;
    if (c == null || after != null) return [];
    return (tab == NetworkTab.accepted && c.status == 'accepted') ||
            (tab == NetworkTab.incoming &&
                c.status == 'pending' &&
                c.incoming) ||
            (tab == NetworkTab.outgoing && c.status == 'pending' && !c.incoming)
        ? [c]
        : [];
  }

  @override
  Future<ProfessionalConnection?> withMember(String peer) async {
    if (fail) throw StateError('Offline');
    return value;
  }

  @override
  Future<void> send(String peer) async {
    if (fail) throw StateError('Offline');
    sends++;
    value = ProfessionalConnection(
      id: 'relationship',
      peerId: peer,
      status: 'pending',
      incoming: false,
      available: true,
      name: 'Synthetic peer',
    );
  }

  @override
  Future<void> transition(String id, String action) async {
    if (fail) throw StateError('Offline');
    actions.add(action);
    final c = value!;
    value = ProfessionalConnection(
      id: c.id,
      peerId: c.peerId,
      status: action == 'removed' ? 'cancelled' : action,
      incoming: c.incoming,
      available: c.available,
      name: c.name,
    );
  }
}
