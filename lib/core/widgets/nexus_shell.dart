import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../routing/app_routes.dart';
import 'nexus_widgets.dart';

class NexusShell extends StatelessWidget {
  const NexusShell({required this.location, required this.child, super.key});
  final String location;
  final Widget child;
  static const destinations = [
    AppRoutes.home,
    AppRoutes.discover,
    AppRoutes.map,
    AppRoutes.network,
    AppRoutes.profile,
  ];
  @override
  Widget build(BuildContext context) {
    final index = destinations.indexOf(location);
    return Scaffold(
      appBar: AppBar(title: const BrandMark()),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 4, 24, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: PreviewBadge(),
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index < 0 ? 0 : index,
        onDestinationSelected: (value) => context.go(destinations[value]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(icon: Icon(Icons.search), label: 'Discover'),
          NavigationDestination(
            icon: Icon(Icons.public_outlined),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            label: 'Network',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
