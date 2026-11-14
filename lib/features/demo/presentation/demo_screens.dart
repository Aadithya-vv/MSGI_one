import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/one_widgets.dart';
import '../domain/demo_store.dart';
import '../../home/presentation/community_highlights.dart';

class DemoHomeScreen extends StatelessWidget {
  const DemoHomeScreen({super.key, required this.store});
  final DemoStore store;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => PageBody(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, ${store.person['display_name']}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${store.role.label} perspective',
                    style: const TextStyle(
                      color: OneColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ProfileAvatar(store.person['display_name'] as String),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [OneColors.navy, OneColors.blue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ONE COMMUNITY. INFINITE CONNECTIONS.',
                style: TextStyle(
                  color: OneColors.gold,
                  fontSize: 10,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your next chapter starts\nwith a connection.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => context.go('/discover'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: OneColors.navy,
                ),
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('Discover alumni'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const CommunityQuickLinks(),
        const SizedBox(height: 12),
        const CommunityHighlights(),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in [
              ('/network', 'My network', Icons.people_outline),
              ('/profile', 'My demo profile', Icons.person_outline),
              ('/community', 'Students and faculty', Icons.groups_outlined),
            ])
              OutlinedButton.icon(
                onPressed: () => context.go(item.$1),
                icon: Icon(item.$3),
                label: Text(item.$2),
              ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    ),
  );
}

class DemoOwnProfileScreen extends StatelessWidget {
  const DemoOwnProfileScreen({super.key, required this.store});
  final DemoStore store;
  Future<void> _edit(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => _DemoProfileEditDialog(store: store),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final p = store.person;
      return PageBody(
        children: [
          FeatureHeader(
            eyebrow: 'Fictional ${store.role.label} profile',
            title: p['display_name'] as String,
            description: '${p['institution']}\n${p['department']}',
          ),
          Text(
            p['designation'] as String,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text('${p['company']}\n${p['professional_domain']}\n${p['degree']}'),
          const SectionHeading('Professional story'),
          Text(p['biography'] as String),
          const SectionHeading('Skills'),
          Wrap(
            spacing: 8,
            children: [
              for (final id in (p['skill_ids'] as List).cast<String>())
                Chip(label: Text(DemoStore.skillName(id))),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => _edit(context),
            child: const Text('Edit demo profile'),
          ),
          if (store.role == DemoRole.alumni) ...[
            Material(
              color: Colors.transparent,
              child: SwitchListTile(
                title: const Text('Demo mentoring availability'),
                subtitle: const Text(
                  'Updates recommendations when exploring other perspectives.',
                ),
                value: p['mentoring'] as bool,
                onChanged: (v) => store.updatePerson({'mentoring': v}),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: SwitchListTile(
                title: const Text('Demo directory visibility'),
                value: p['directory_visible'] as bool,
                onChanged: (v) => store.updatePerson({'directory_visible': v}),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: SwitchListTile(
                title: const Text('Demo map consent'),
                value: p['map_opt_in'] as bool,
                onChanged: p['directory_visible'] == true
                    ? (v) => store.updatePerson({'map_opt_in': v})
                    : null,
              ),
            ),
          ],
          if (store.role == DemoRole.staff)
            const Text(
              'Staff is a community perspective, not an administrator. There are no membership-review or privileged controls in this demo.',
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.go('/mentors'),
            child: const Text('Explore mentorship'),
          ),
        ],
      );
    },
  );
}

class DemoCommunityScreen extends StatefulWidget {
  const DemoCommunityScreen({super.key, required this.store});
  final DemoStore store;
  @override
  State<DemoCommunityScreen> createState() => _DemoCommunityScreenState();
}

class _DemoCommunityScreenState extends State<DemoCommunityScreen> {
  final _query = TextEditingController();
  String _role = 'all';
  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final people = widget.store.profiles.values
        .where(
          (p) =>
              p['directory_visible'] == true &&
              (_role == 'all' || p['role'] == _role) &&
              (p['display_name'] as String).toLowerCase().contains(
                _query.text.toLowerCase(),
              ),
        )
        .toList();
    return PageBody(
      children: [
        const FeatureHeader(
          eyebrow: 'Fictional institutional network',
          title: 'Students and faculty',
          description: 'Find shared interests across the community.',
        ),
        TextField(
          controller: _query,
          decoration: const InputDecoration(
            labelText: 'Search sample community',
          ),
          onChanged: (_) => setState(() {}),
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final r in ['all', 'student', 'alumni', 'staff'])
              ChoiceChip(
                label: Text(r == 'all' ? 'All people' : r),
                selected: _role == r,
                onSelected: (_) => setState(() => _role = r),
              ),
          ],
        ),
        if (people.isEmpty)
          const EmptyState(
            title: 'No sample people found',
            message: 'Try another name or role.',
          ),
        for (final p in people)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InfoCard(
              icon: Icons.person_outline,
              title: p['display_name'] as String,
              description: '${p['designation']}\n${p['institution']}',
              trailing: TextButton(
                onPressed: () => context.go('/alumni/${p['user_id']}'),
                child: const Text('View sample profile'),
              ),
            ),
          ),
      ],
    );
  }
}

class _DemoProfileEditDialog extends StatefulWidget {
  const _DemoProfileEditDialog({required this.store});
  final DemoStore store;
  @override
  State<_DemoProfileEditDialog> createState() => _DemoProfileEditDialogState();
}

class _DemoProfileEditDialogState extends State<_DemoProfileEditDialog> {
  late final _name = TextEditingController(
        text: widget.store.person['display_name'] as String,
      ),
      _bio = TextEditingController(
        text: widget.store.person['biography'] as String,
      );
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit fictional profile'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Demo display name'),
              maxLength: 70,
              validator: (s) => (s ?? '').trim().length < 2
                  ? 'Enter at least two characters.'
                  : null,
            ),
            TextFormField(
              controller: _bio,
              decoration: const InputDecoration(
                labelText: 'Fictional biography',
              ),
              maxLength: 1000,
              minLines: 3,
              maxLines: 6,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          final name = _name.text.trim();
          widget.store.updatePerson({
            'display_name': name,
            'biography': _bio.text.trim(),
          });
          Navigator.pop(context);
        },
        child: const Text('Save demo profile'),
      ),
    ],
  );
}
