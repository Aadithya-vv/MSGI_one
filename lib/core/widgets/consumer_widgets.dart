import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'one_widgets.dart';

class CompactSearch extends StatelessWidget {
  const CompactSearch({
    super.key,
    required this.controller,
    required this.label,
    required this.onSearch,
    this.onFilters,
    this.filterCount = 0,
    this.fieldKey,
  });
  final TextEditingController controller;
  final String label;
  final VoidCallback onSearch;
  final VoidCallback? onFilters;
  final int filterCount;
  final Key? fieldKey;
  @override
  Widget build(BuildContext context) => TextField(
    key: fieldKey,
    controller: controller,
    maxLength: 100,
    textInputAction: TextInputAction.search,
    onSubmitted: (_) => onSearch(),
    decoration: InputDecoration(
      hintText: label,
      labelText: label,
      counterText: '',
      floatingLabelBehavior: FloatingLabelBehavior.never,
      prefixIcon: IconButton(
        tooltip: 'Search',
        onPressed: onSearch,
        icon: const Icon(Icons.search),
      ),
      suffixIcon: onFilters == null
          ? null
          : IconButton(
              tooltip: filterCount == 0
                  ? 'Filters'
                  : 'Filters ($filterCount active)',
              onPressed: onFilters,
              icon: Badge(
                isLabelVisible: filterCount > 0,
                label: Text('$filterCount'),
                child: const Icon(Icons.tune),
              ),
            ),
    ),
  );
}

class QuickFilters extends StatelessWidget {
  const QuickFilters({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final child in children)
          Padding(padding: const EdgeInsets.only(right: 8), child: child),
      ],
    ),
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill(
    this.label, {
    super.key,
    this.icon,
    this.color = OneColors.blue,
  });
  final String label;
  final IconData? icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Wrap(
      spacing: 5,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (icon != null) Icon(icon, size: 15, color: color),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class PersonCard extends StatelessWidget {
  const PersonCard({
    super.key,
    required this.name,
    required this.headline,
    required this.onProfile,
    this.education = '',
    this.skills = const [],
    this.footer,
    this.indicator,
  });
  final String name, headline, education;
  final List<String> skills;
  final VoidCallback onProfile;
  final Widget? footer, indicator;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onProfile,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProfileAvatar(name, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        if (headline.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              headline,
                              style: const TextStyle(
                                color: OneColors.muted,
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (education.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                education,
                style: const TextStyle(color: OneColors.muted, fontSize: 12),
              ),
            ),
          if (indicator != null)
            Padding(padding: const EdgeInsets.only(top: 10), child: indicator!),
          if (skills.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: SkillTags(skills.take(3).toList()),
            ),
          if (footer != null) ...[const SizedBox(height: 8), footer!],
        ],
      ),
    ),
  );
}

class FeedHeading extends StatelessWidget {
  const FeedHeading(
    this.title, {
    super.key,
    this.subtitle,
    this.action,
    this.leading,
  });
  final String title;
  final String? subtitle;
  final Widget? action, leading;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ?leading,
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            ?action,
          ],
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              subtitle!,
              style: const TextStyle(color: OneColors.muted, fontSize: 12),
            ),
          ),
      ],
    ),
  );
}

class FeedSkeleton extends StatelessWidget {
  const FeedSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading results',
    liveRegion: true,
    child: ExcludeSemantics(
      child: Column(
        children: [
          const LinearProgressIndicator(),
          const SizedBox(height: 12),
          for (var i = 0; i < 2; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      for (final width in [.9, .65, .4])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: FractionallySizedBox(
                            widthFactor: width,
                            alignment: Alignment.centerLeft,
                            child: Container(
                              height: 12,
                              decoration: BoxDecoration(
                                color: OneColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
