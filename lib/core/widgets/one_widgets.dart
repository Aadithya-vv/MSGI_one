import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import '../config/app_config.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.light = false});
  final bool light;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: OneColors.gold,
          borderRadius: BorderRadius.circular(13),
        ),
        child: const Icon(Icons.hub_outlined, color: OneColors.navy, size: 26),
      ),
      const SizedBox(width: 12),
      Flexible(
        child: Text(
          AppConfig.name,
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            letterSpacing: -.6,
            color: light ? Colors.white : OneColors.navy,
          ),
        ),
      ),
    ],
  );
}

class PreviewBadge extends StatelessWidget {
  const PreviewBadge({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF3CE),
      borderRadius: BorderRadius.circular(30),
    ),
    child: const Text(
      'SAMPLE PREVIEW',
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
      ),
    ),
  );
}

class PageBody extends StatelessWidget {
  const PageBody({required this.children, super.key});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: OneSpace.maxWidth),
        child: Padding(
          padding: const EdgeInsets.all(OneSpace.large),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    ),
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.action, this.onPressed});
  final String title;
  final String? action;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 28, bottom: 14),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (action != null)
          TextButton(onPressed: onPressed, child: Text(action!)),
      ],
    ),
  );
}

class FeatureHeader extends StatelessWidget {
  const FeatureHeader({
    required this.eyebrow,
    required this.title,
    required this.description,
    super.key,
  });
  final String eyebrow;
  final String title;
  final String description;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        eyebrow.toUpperCase(),
        style: const TextStyle(
          color: OneColors.blue,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
          fontSize: 11,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        title,
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.8),
      ),
      const SizedBox(height: 12),
      Text(
        description,
        style: const TextStyle(color: OneColors.muted, height: 1.6),
      ),
      const SizedBox(height: 24),
    ],
  );
}

class InfoCard extends StatelessWidget {
  const InfoCard({
    required this.icon,
    required this.title,
    required this.description,
    super.key,
    this.trailing,
  });
  final IconData icon;
  final String title;
  final String description;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: OneColors.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: OneColors.blue),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(color: OneColors.muted, height: 1.5),
                ),
                if (trailing != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: trailing!,
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    required this.message,
    super.key,
    this.icon = Icons.inbox_outlined,
    this.action,
  });
  final String title;
  final String message;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Icon(icon, size: 44, color: OneColors.blue),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: OneColors.muted, height: 1.5),
          ),
          if (action != null)
            Padding(padding: const EdgeInsets.only(top: 20), child: action!),
        ],
      ),
    ),
  );
}

class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.message = 'Loading your community…'});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center),
      ],
    ),
  );
}
