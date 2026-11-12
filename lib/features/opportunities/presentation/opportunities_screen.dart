import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/nexus_widgets.dart';
import '../data/sample_opportunities.dart';
import '../domain/opportunity_preview.dart';

class OpportunitiesScreen extends ConsumerWidget {
  const OpportunitiesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => PageBody(
    children: [
      const FeatureHeader(
        eyebrow: 'Take your next step',
        title: 'Career opportunities',
        description: 'Explore the future careers board. All listings below are samples; applications are not available.',
      ),
      for (final opportunity in ref.watch(sampleOpportunitiesProvider))
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: OpportunityCard(opportunity: opportunity),
        ),
    ],
  );
}

class OpportunityCard extends StatelessWidget {
  const OpportunityCard({required this.opportunity, super.key});
  final OpportunityPreview opportunity;
  @override
  Widget build(BuildContext context) => InfoCard(
    icon: Icons.work_outline,
    title: opportunity.title,
    description: '${opportunity.type}\n${opportunity.location}',
  );
}
