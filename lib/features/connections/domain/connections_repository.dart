enum NetworkTab { incoming, outgoing, accepted }

class ProfessionalConnection {
  const ProfessionalConnection({
    required this.id,
    required this.peerId,
    required this.status,
    required this.incoming,
    required this.available,
    this.name,
    this.company,
    this.eligible = true,
  });
  final String id, peerId, status;
  final bool incoming, available, eligible;
  final String? name, company;
}

abstract class ConnectionsRepository {
  Future<List<ProfessionalConnection>> list(NetworkTab tab, {String? after});
  Future<ProfessionalConnection?> withMember(String peer);
  Future<void> send(String peer);
  Future<void> transition(String id, String action);
}
