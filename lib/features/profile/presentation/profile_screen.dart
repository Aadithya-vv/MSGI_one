import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/one_widgets.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => PageBody(
    children: [
      const FeatureHeader(
        eyebrow: 'Your story belongs here',
        title: 'Your profile',
        description: 'Your account has verified community access. Professional feature content remains labelled samples until directory integration.',
      ),
      const InfoCard(
        icon: Icons.badge_outlined,
        title: 'A profile with purpose',
        description: 'Future verified profiles will bring together your institution, graduation year, profession, interests, and mentorship preferences.',
      ),
      const SizedBox(height: 24),
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
