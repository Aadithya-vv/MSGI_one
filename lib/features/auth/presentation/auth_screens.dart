import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/experience_actions.dart';

import '../../../core/config/app_config.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/one_widgets.dart';

class StartupScreen extends StatelessWidget {
  const StartupScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: OneColors.navy,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.hub_outlined, size: 88, color: OneColors.gold),
                const SizedBox(height: 32),
                const Text(
                  AppConfig.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  AppConfig.tagline,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFDEE7F6), fontSize: 16),
                ),
                const SizedBox(height: 40),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: OneColors.gold,
                    foregroundColor: OneColors.navy,
                  ),
                  onPressed: () => context.go(AppRoutes.welcome),
                  child: const Text('Get started'),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Your community, connected.',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: SafeArea(
      child: PageBody(
        children: [
          const BrandMark(),
          if (ref.watch(exploreDemoActionProvider) != null)
            TextButton(
              onPressed: ref.watch(exploreDemoActionProvider),
              child: const Text('Explore Demo'),
            ),
          const SizedBox(height: 48),
          const Icon(
            Icons.diversity_2_outlined,
            size: 120,
            color: OneColors.blue,
          ),
          const SizedBox(height: 32),
          const FeatureHeader(
            eyebrow: 'One community. Endless possibilities.',
            title: 'Your next chapter\nstarts with a connection.',
            description: 'Meet experience with ambition. Discover mentors, shared journeys, and opportunities across the MSGI community.',
          ),
          FilledButton(
            onPressed: () => context.go(AppRoutes.login),
            child: const Text('Log in'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => context.go(AppRoutes.signup),
            child: const Text('Join the community'),
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 24),
          const Text(
            'Secure sign-in and institutional review protect our community. Demo previews stay separate from your real account.',
            textAlign: TextAlign.center,
            style: TextStyle(color: OneColors.muted, height: 1.5),
          ),
        ],
      ),
    ),
  );
}
