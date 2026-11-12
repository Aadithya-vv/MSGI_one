import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/mentor_preview.dart';

final sampleMentorsProvider = Provider<List<MentorPreview>>(
  (ref) => const [
    MentorPreview(
      name: 'Sample mentor A',
      role: 'Engineering · Bengaluru',
      focus: 'Career direction & technology',
    ),
    MentorPreview(
      name: 'Sample mentor B',
      role: 'Product design · Pune',
      focus: 'Portfolios & creative careers',
    ),
  ],
);
