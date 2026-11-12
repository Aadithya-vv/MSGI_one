class AlumniPreview {
  const AlumniPreview({
    required this.name,
    required this.field,
    required this.city,
  });
  final String name;
  final String field;
  final String city;

  bool matches(String query) =>
      '$name $field $city'.toLowerCase().contains(query.trim().toLowerCase());
}
