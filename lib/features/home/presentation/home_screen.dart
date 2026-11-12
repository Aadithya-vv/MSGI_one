import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/nexus_widgets.dart';
import '../../mentorship/data/sample_mentors.dart';
import '../../mentorship/presentation/mentorship_screen.dart';
import '../../opportunities/data/sample_opportunities.dart';
import '../../opportunities/presentation/opportunities_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => PageBody(
    children: [
      Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [NexusColors.navy, NexusColors.blue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.waving_hand_outlined,
                  color: NexusColors.gold,
                  size: 18,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'YOUR COMMUNITY, RECONNECTED',
                    style: TextStyle(
                      color: Color(0xFFE0E9F8),
                      fontSize: 10,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Welcome to your\nMSGI community.',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Different generations. Shared beginnings.\nFind the people who help you move forward.',
              style: TextStyle(color: Color(0xFFE0E9F8), height: 1.6),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go(AppRoutes.discover),
              style: FilledButton.styleFrom(
                backgroundColor: NexusColors.gold,
                foregroundColor: NexusColors.navy,
              ),
              child: const Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Icon(Icons.explore_outlined),
                  Text('Explore the community'),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Semantics(
        button: true,
        label: 'Search sample alumni',
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => context.go(AppRoutes.discover),
            child: const Padding(
              padding: EdgeInsets.all(18),
              child: Row(
                children: [
                  Icon(Icons.search, color: NexusColors.blue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Find alumni, careers, or shared interests',
                      style: TextStyle(color: NexusColors.muted),
                    ),
                  ),
                  Icon(Icons.arrow_forward, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
      const SectionHeading('Make your next connection'),
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 640
              ? 4
              : constraints.maxWidth < 280
              ? 1
              : 2;
          final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final feature in const [
                (
                  Icons.school_outlined,
                  'Find a mentor',
                  'Learn from experience',
                  AppRoutes.mentors,
                ),
                (
                  Icons.work_outline,
                  'Career opportunities',
                  'Discover your next step',
                  AppRoutes.opportunities,
                ),
                (
                  Icons.public_outlined,
                  'Alumni around you',
                  'Explore a wider world',
                  AppRoutes.map,
                ),
                (
                  Icons.people_outline,
                  'My network',
                  'Grow together',
                  AppRoutes.network,
                ),
              ])
                SizedBox(
                  width: width,
                  child: _QuickCard(
                    icon: feature.$1,
                    title: feature.$2,
                    subtitle: feature.$3,
                    path: feature.$4,
                  ),
                ),
            ],
          );
        },
      ),
      SectionHeading(
        'Featured mentor',
        action: 'View all',
        onPressed: () => context.go(AppRoutes.mentors),
      ),
      MentorCard(mentor: ref.watch(sampleMentorsProvider).first),
      SectionHeading(
        'Open new doors',
        action: 'View all',
        onPressed: () => context.go(AppRoutes.opportunities),
      ),
      OpportunityCard(
        opportunity: ref.watch(sampleOpportunitiesProvider).first,
      ),
      const SizedBox(height: 24),
      const Text(
        'Illustrative content only. No real profiles, recommendations, or vacancies are shown.',
        style: TextStyle(color: NexusColors.muted, fontSize: 12, height: 1.6),
      ),
      const SizedBox(height: 12),
    ],
  );
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.path,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String path;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => context.go(path),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: NexusColors.blue, size: 28),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, height: 1.4),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                color: NexusColors.muted,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
