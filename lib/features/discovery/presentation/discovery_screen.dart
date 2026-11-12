import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/nexus_widgets.dart';
import '../data/sample_alumni.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});
  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final people = ref.watch(filteredSampleAlumniProvider(_query));
    return PageBody(
      children: [
        const FeatureHeader(
          eyebrow: 'Find common ground',
          title: 'Discover alumni',
          description: 'Search this small sample directory by career or city. Verified MSGI alumni and advanced filters will be added later.',
        ),
        TextField(
          key: const Key('alumni-search'),
          onChanged: (value) => setState(() => _query = value),
          decoration: const InputDecoration(
            labelText: 'Search sample alumni',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 20),
        if (people.isEmpty)
          const EmptyState(
            title: 'No sample matches',
            message: 'Try a city such as Pune or a field such as research.',
            icon: Icons.search_off,
          ),
        for (final person in people)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InfoCard(
              icon: Icons.person_outline,
              title: person.name,
              description:
                  '${person.field} · ${person.city}\nSample profile · Not a real member',
            ),
          ),
      ],
    );
  }
}
