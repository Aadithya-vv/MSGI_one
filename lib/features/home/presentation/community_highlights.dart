import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/one_widgets.dart';
import '../../mentorship/data/mentor_providers.dart';
import '../../mentorship/domain/mentor_repository.dart';
import '../../opportunities/data/career_providers.dart';
import '../../opportunities/domain/career_repository.dart';

final featuredMentorsProvider =
    FutureProvider.autoDispose<List<MentorRecommendation>>(
      (ref) => ref.watch(mentorRepositoryProvider).recommend(),
    );
final recentCareersProvider = FutureProvider.autoDispose<List<CareerPost>>(
  (ref) => ref.watch(careerRepositoryProvider).list({
    'status': 'published',
    'sort': 'recent',
  }),
);

class CommunityQuickLinks extends StatelessWidget {
  const CommunityQuickLinks({super.key});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 600;
      final columns =
          constraints.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.5
          ? 1
          : wide
          ? 4
          : 2;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final item in const [
            (
              '/discover',
              'Discover alumni',
              'Find shared beginnings',
              Icons.search,
            ),
            (
              '/mentors',
              'Find a mentor',
              'Learn from experience',
              Icons.school_outlined,
            ),
            (
              '/opportunities',
              'Career Bridge',
              'Your next opportunity',
              Icons.work_outline,
            ),
            (
              '/map',
              'Global alumni map',
              'One worldwide community',
              Icons.public,
            ),
          ])
            SizedBox(
              width: (constraints.maxWidth - 12 * (columns - 1)) / columns,
              child: Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => context.go(item.$1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(item.$4, color: OneColors.blue),
                        const SizedBox(height: 12),
                        Text(
                          item.$2,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.$3,
                          style: const TextStyle(
                            color: OneColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

/// Both the real dashboard and isolated demo consume their injected repositories.
class CommunityHighlights extends ConsumerWidget {
  const CommunityHighlights({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SectionHeading(
        'Featured mentor',
        action: 'View all',
        onPressed: () => context.go('/mentors'),
      ),
      ref
          .watch(featuredMentorsProvider)
          .when(
            loading: () => const LoadingState(message: 'Finding your mentors…'),
            error: (_, _) => EmptyState(
              title: 'Mentors unavailable',
              message: 'Your access or connection may have changed.',
              action: TextButton(
                onPressed: () => ref.invalidate(featuredMentorsProvider),
                child: const Text('Retry mentors'),
              ),
            ),
            data: (rows) => rows.isEmpty
                ? const EmptyState(
                    title: 'Your next mentor is ahead',
                    message:
                        'Update your goals or check back as mentors opt in.',
                    icon: Icons.school_outlined,
                  )
                : InfoCard(
                    icon: Icons.person_outline,
                    title: rows.first.name,
                    description:
                        [
                              rows.first.data['designation'],
                              rows.first.data['company'],
                            ]
                            .whereType<String>()
                            .where((s) => s.isNotEmpty)
                            .join(' · '),
                    trailing: TextButton(
                      onPressed: () => context.go('/alumni/${rows.first.id}'),
                      child: const Text('Meet this mentor'),
                    ),
                  ),
          ),
      SectionHeading(
        'Recent opportunities',
        action: 'View all',
        onPressed: () => context.go('/opportunities'),
      ),
      ref
          .watch(recentCareersProvider)
          .when(
            loading: () =>
                const LoadingState(message: 'Loading opportunities…'),
            error: (_, _) => EmptyState(
              title: 'Opportunities unavailable',
              message: 'Check your connection and try again.',
              action: TextButton(
                onPressed: () => ref.invalidate(recentCareersProvider),
                child: const Text('Retry opportunities'),
              ),
            ),
            data: (rows) => rows.isEmpty
                ? const EmptyState(
                    title: 'New doors will open',
                    message: 'Shared opportunities will appear here.',
                    icon: Icons.work_outline,
                  )
                : Column(
                    children: [
                      for (final p in rows.take(2))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InfoCard(
                            icon: Icons.work_outline,
                            title: p.title,
                            description:
                                '${p.data['organization'] ?? ''} · ${p.data['remote'] == true ? 'Remote' : p.data['location_text'] ?? ''}',
                            trailing: TextButton(
                              onPressed: () =>
                                  context.go('/opportunities/${p.id}'),
                              child: const Text('View opportunity'),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
    ],
  );
}
