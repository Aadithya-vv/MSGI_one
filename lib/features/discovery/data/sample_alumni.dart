import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/alumni_preview.dart';

final sampleAlumniProvider = Provider<List<AlumniPreview>>(
  (ref) => const [
    AlumniPreview(
      name: 'Sample alumnus A',
      field: 'Software engineering',
      city: 'Bengaluru',
    ),
    AlumniPreview(
      name: 'Sample alumna B',
      field: 'Product design',
      city: 'Pune',
    ),
    AlumniPreview(name: 'Sample alumnus C', field: 'Research', city: 'London'),
  ],
);

final filteredSampleAlumniProvider = Provider.autoDispose
    .family<List<AlumniPreview>, String>(
      (ref, query) => ref
          .watch(sampleAlumniProvider)
          .where((person) => person.matches(query))
          .toList(growable: false),
    );
