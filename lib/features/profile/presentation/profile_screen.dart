import '../../../core/routing/community_navigation.dart';

import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/one_widgets.dart';
import '../../../core/errors/error_state.dart';
import '../data/profile_providers.dart';
import '../../catalog/domain/academic_catalog.dart';
import '../../catalog/presentation/msec_institution_identity.dart';
import '../../administration/data/administration_providers.dart';
import '../../administration/presentation/membership_request_panel.dart';
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
      if (ref.watch(authControllerProvider).isVerified &&
          ref.watch(supabaseClientProvider) != null)
        const MembershipRequestPanel(correction: true),
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
                        description: [
                          profile.institution,
                          if (profile.department.isNotEmpty) profile.department,
                          if (profile.input.affiliation.isNotEmpty)
                            profile.input.affiliation,
                          if (profile.input.graduationYear != 0)
                            '${profile.input.joiningYear == 0 ? '' : '${profile.input.joiningYear}–'}${profile.input.graduationYear}',
                        ].join('\n'),
                      ),
                      const SectionHeading('Career and education'),
                      if (profile.input.institutionId == MsecCatalog.id) ...[
                        const MsecInstitutionIdentity(),
                        const SizedBox(height: 12),
                      ],
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
                      SkillTags(profile.skills),
                      const SizedBox(height: 12),
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
  Widget build(BuildContext context, WidgetRef ref) => CommunityReturnScope(
    fallback: AppRoutes.discover,
    child: Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: BackButton(
          onPressed: () => returnToCommunityParent(context, AppRoutes.discover),
        ),
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
                            Row(
                              children: [
                                ProfileAvatar(p.name, size: 64),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Professional profile',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            FeatureHeader(
                              eyebrow: eyebrow,
                              title: p.name,
                              description:
                                  '${p.text('institution')} · ${p.text('programme').isNotEmpty ? p.text('programme') : p.text('department')} · ${p.text('graduation_year')}',
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
    ),
  );
}
