import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/one_widgets.dart';
import '../../../core/errors/error_state.dart';
import '../data/profile_providers.dart';
import '../../administration/data/administration_providers.dart';
import '../../connections/presentation/connection_controls.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => PageBody(
    children: [
      const FeatureHeader(
        eyebrow: 'Your story belongs here',
        title: 'Your profile',
        description: 'Manage your professional story and visibility. Institutional verification is managed separately.',
      ),
      ref
          .watch(ownProfileProvider)
          .when(
            loading: () => const LoadingState(),
            error: (_, _) => ErrorState(
              message: 'Profile unavailable.',
              onRetry: () => ref.invalidate(ownProfileProvider),
            ),
            data: (profile) => profile == null
                ? const EmptyState(
                    title: 'No profile yet',
                    message: 'Complete your institutional profile to submit it for review.',
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InfoCard(
                        icon: Icons.person_outline,
                        title: profile.input.displayName,
                        description:
                            '${profile.institution}\n${profile.department} · ${profile.input.joiningYear}–${profile.input.graduationYear}',
                      ),
                      const SectionHeading('Career and education'),
                      Text(
                        [
                          profile.input.degree,
                          profile.input.designation,
                          profile.input.company,
                          profile.input.professionalDomain,
                          profile.input.biography,
                        ].where((s) => s.isNotEmpty).join('\n'),
                      ),
                      const SectionHeading('Skills'),
                      Text(profile.skills.join(', ')),
                      Text(
                        profile.input.mentoring
                            ? 'Available for mentoring'
                            : 'Not currently mentoring',
                      ),
                      const SectionHeading('Privacy'),
                      Text(
                        'Directory: ${profile.input.directoryVisible ? 'visible after approval' : 'hidden'}\nMap: ${profile.input.mapOptIn ? 'opted in' : 'hidden'}',
                      ),
                    ],
                  ),
          ),
      FilledButton(
        onPressed: () => context.go(AppRoutes.profileEdit),
        child: const Text('Edit profile and visibility'),
      ),
      ref
          .watch(pendingReviewsProvider)
          .when(
            data: (_) => OutlinedButton(
              onPressed: () => context.go(AppRoutes.administration),
              child: const Text('Review memberships'),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
      OutlinedButton(
        onPressed: () => ref.read(authControllerProvider.notifier).refresh(),
        child: const Text('Refresh account status'),
      ),
      TextButton(
        onPressed: () => context.go(AppRoutes.welcome),
        child: const Text('Back to welcome'),
      ),
      OutlinedButton(
        onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
        child: const Text('Log out'),
      ),
    ],
  );
}

class AlumniDetailScreen extends ConsumerWidget {
  const AlumniDetailScreen({
    super.key,
    required this.userId,
    this.title = 'Alumni profile',
    this.eyebrow = 'Verified alumni',
  });
  final String userId;
  final String title, eyebrow;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      title: Text(title),
      leading: BackButton(onPressed: () => context.go(AppRoutes.discover)),
    ),
    body: SafeArea(
      child: PageBody(
        children: [
          ref
              .watch(alumniDetailProvider(userId))
              .when(
                loading: () => const LoadingState(),
                error: (_, _) => ErrorState(
                  message: 'Profile unavailable or access changed.',
                  onRetry: () => ref.invalidate(alumniDetailProvider(userId)),
                ),
                data: (p) => p == null
                    ? const EmptyState(
                        title: 'Profile unavailable',
                        message: 'This member may no longer be discoverable.',
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FeatureHeader(
                            eyebrow: eyebrow,
                            title: p.name,
                            description:
                                '${p.text('institution')} · ${p.text('department')} · ${p.text('graduation_year')}',
                          ),
                          const SectionHeading('Career and education'),
                          Text(
                            [
                              p.text('degree'),
                              p.text('designation'),
                              p.text('company'),
                              p.text('professional_domain'),
                              p.text('biography'),
                            ].where((s) => s.isNotEmpty).join('\n'),
                          ),
                          const SectionHeading('Skills and expertise'),
                          Wrap(
                            spacing: 8,
                            children: p.skills
                                .map((s) => Chip(label: Text(s)))
                                .toList(),
                          ),
                          if (p.mentoring)
                            const Text('Available for mentoring'),
                          if (p.text('city').isNotEmpty)
                            Text(
                              '${p.text('city')}, ${p.text('country_code')}',
                            ),
                          const SizedBox(height: 16),
                          ConnectionControls(peer: p.id),
                        ],
                      ),
              ),
        ],
      ),
    ),
  );
}
