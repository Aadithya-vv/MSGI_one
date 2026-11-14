import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/academic_catalog.dart';

/// Null for production until a reviewed backend programme contract exists.
/// Only explicitly composed experiences can expose a programme catalog.
final academicCatalogsProvider = Provider<List<InstitutionAcademicCatalog>>(
  (ref) => const [],
);
