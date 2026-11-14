import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/one_widgets.dart';
import 'community_highlights.dart';
import '../../profile/data/profile_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => PageBody(
    children: [
      Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [OneColors.navy, OneColors.blue],
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
                  color: OneColors.gold,
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
            ref
                .watch(ownProfileProvider)
                .when(
                  data: (p) => p == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            'Hello, ${p.input.displayName}\n${p.input.kind.name == 'student' ? 'Student' : 'Alumni'} community',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: Colors.white),
                          ),
                        ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
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
                backgroundColor: OneColors.gold,
                foregroundColor: OneColors.navy,
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
        label: 'Search alumni',
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => context.go(AppRoutes.discover),
            child: const Padding(
              padding: EdgeInsets.all(18),
              child: Row(
                children: [
                  Icon(Icons.search, color: OneColors.blue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Find alumni, careers, or shared interests',
                      style: TextStyle(color: OneColors.muted),
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
      const CommunityQuickLinks(),
      const CommunityHighlights(),
      const SizedBox(height: 24),
    ],
  );
}
