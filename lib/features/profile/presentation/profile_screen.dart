import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/nexus_widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      const FeatureHeader(
        eyebrow: 'Your story belongs here',
        title: 'Your profile',
        description: 'You are exploring a sample preview. No account or personal profile has been created.',
      ),
      const InfoCard(
        icon: Icons.badge_outlined,
        title: 'A profile with purpose',
        description: 'Future verified profiles will bring together your institution, graduation year, profession, interests, and mentorship preferences.',
      ),
      const SizedBox(height: 24),
      OutlinedButton(
        onPressed: () => context.go(AppRoutes.signup),
        child: const Text('View registration preview'),
      ),
      TextButton(
        onPressed: () => context.go(AppRoutes.welcome),
        child: const Text('Back to welcome'),
      ),
    ],
  );
}
