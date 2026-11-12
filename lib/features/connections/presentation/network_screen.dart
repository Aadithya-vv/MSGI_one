import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/nexus_widgets.dart';

class NetworkScreen extends StatelessWidget {
  const NetworkScreen({super.key});
  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      const FeatureHeader(
        eyebrow: 'Stronger together',
        title: 'My network',
        description: 'Meaningful connections begin with a conversation. Connection requests are not active in this preview.',
      ),
      EmptyState(
        title: 'Your community is waiting',
        message: 'There are no real connections in the preview. Explore sample alumni to see what is coming.',
        icon: Icons.people_outline,
        action: FilledButton(
          onPressed: () => context.go(AppRoutes.discover),
          child: const Text('Discover sample alumni'),
        ),
      ),
    ],
  );
}
