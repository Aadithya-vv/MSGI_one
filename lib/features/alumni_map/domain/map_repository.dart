class CityCluster {
  const CityCluster({
    required this.id,
    required this.name,
    required this.country,
    required this.latitude,
    required this.longitude,
    required this.count,
  });
  final String id, name, country;
  final double latitude, longitude;
  final int count;
}

abstract class AlumniMapRepository {
  Future<List<CityCluster>> cities({
    String location = '',
    String domain = '',
    String? after,
  });
  Future<List<Map<String, dynamic>>> members(
    String city, {
    String domain = '',
    String? after,
  });
}
