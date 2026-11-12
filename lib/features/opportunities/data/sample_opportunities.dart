import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/opportunity_preview.dart';

final sampleOpportunitiesProvider = Provider<List<OpportunityPreview>>(
  (ref) => const [
    OpportunityPreview(
      title: 'Flutter development internship',
      type: 'Sample internship',
      location: 'Remote · Illustrative listing',
    ),
    OpportunityPreview(
      title: 'Build a community project',
      type: 'Sample collaboration',
      location: 'Student team · Illustrative listing',
    ),
  ],
);
