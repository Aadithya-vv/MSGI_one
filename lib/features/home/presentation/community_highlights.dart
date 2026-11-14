import '../../profile/data/profile_providers.dart';
import '../../../core/routing/community_navigation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/one_widgets.dart';
import '../../../core/widgets/consumer_widgets.dart';
import '../../mentorship/data/mentor_providers.dart';
import '../../mentorship/domain/mentor_repository.dart';
import '../../opportunities/data/career_providers.dart';
import '../../opportunities/domain/career_repository.dart';

final featuredMentorsProvider =
    FutureProvider.autoDispose<List<MentorRecommendation>>((ref) {
      ref.watch(profileRevisionProvider);
      return ref.watch(mentorRepositoryProvider).recommend();
    });
final recentCareersProvider = FutureProvider.autoDispose<List<CareerPost>>((
  ref,
) {
  ref.watch(profileRevisionProvider);
  return ref.watch(careerRepositoryProvider).list({
    'status': 'published',
    'sort': 'recent',
  });
});

class CommunityQuickLinks extends StatelessWidget {
  const CommunityQuickLinks({super.key});
  @override
  Widget build(BuildContext context) => QuickFilters(
    children: [
      for (final item in const [
        ('/discover', 'Discover alumni', Icons.people_outline),
        ('/mentors', 'Find a mentor', Icons.school_outlined),
        ('/opportunities', 'Opportunities', Icons.work_outline),
        ('/map', 'Global alumni map', Icons.public),
      ])
        SizedBox(
          width: MediaQuery.textScalerOf(context).scale(88).clamp(88, 140),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => openCommunityDestination(context, item.$1),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: OneColors.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(item.$3, color: OneColors.blue),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.$2,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
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
        onPressed: () => openCommunityDestination(context, '/mentors'),
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
                      onPressed: () =>
                          openMemberProfile(context, rows.first.id),
                      child: const Text('Meet this mentor'),
                    ),
                  ),
          ),
      SectionHeading(
        'Recent opportunities',
        action: 'View all',
        onPressed: () => openCommunityDestination(context, '/opportunities'),
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
                              onPressed: () async {
                                await context.push<void>(
                                  '/opportunities/${p.id}',
                                );
                                if (context.mounted) {
                                  ref.invalidate(recentCareersProvider);
                                }
                              },
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
