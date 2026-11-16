import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import '../config/app_config.dart';
import 'app_logo.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.light = false, this.prominent = false});
  final bool light;
  final bool prominent;
  @override
  Widget build(BuildContext context) => prominent
      ? const Center(child: AppLogo())
      : Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(size: 44, emblemOnly: true, decorative: true),
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
  const PageBody({
    required this.children,
    super.key,
    this.itemCount = 0,
    this.itemBuilder,
    this.footer = const [],
  });
  final List<Widget> children;
  final int itemCount;
  final IndexedWidgetBuilder? itemBuilder;
  final List<Widget> footer;
  @override
  Widget build(BuildContext context) {
    if (itemBuilder != null) {
      final horizontal = MediaQuery.sizeOf(context).width > OneSpace.maxWidth
          ? (MediaQuery.sizeOf(context).width - OneSpace.maxWidth) / 2 + 16
          : 16.0;
      return Material(
        type: MaterialType.transparency,
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: horizontal),
              sliver: SliverList.builder(
                itemCount: itemCount,
                itemBuilder: itemBuilder!,
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 24),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: footer,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Material(
      type: MaterialType.transparency,
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: OneSpace.maxWidth),
            child: Padding(
              padding: EdgeInsets.all(
                MediaQuery.sizeOf(context).width < 400 ? 16 : OneSpace.large,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.action, this.onPressed});
  final String title;
  final String? action;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 12),
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
          letterSpacing: 1.4,
          fontSize: 11,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        title,
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.8),
      ),
      const SizedBox(height: 8),
      Text(
        description,
        style: const TextStyle(
          color: OneColors.muted,
          height: 1.45,
          fontSize: 13,
        ),
      ),
      const SizedBox(height: 20),
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

/// Initials are derived only from the already-authorized display name.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar(this.name, {super.key, this.size = 44});
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .take(2);
    final initials = parts
        .map((s) => String.fromCharCode(s.runes.first))
        .join()
        .toUpperCase();
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [OneColors.navy, OneColors.blue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(size * .32),
        ),
        child: Text(
          initials.isEmpty ? 'M' : initials,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * .34,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class SkillTags extends StatelessWidget {
  const SkillTags(this.skills, {super.key});
  final List<String> skills;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final skill in skills)
          Chip(
            label: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: (constraints.maxWidth - 48).clamp(1, double.infinity),
              ),
              child: Text(skill, softWrap: true),
            ),
          ),
      ],
    ),
  );
}

class StatusNotice extends StatelessWidget {
  const StatusNotice(this.message, {super.key});
  final String? message;
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 160),
    child: message == null
        ? const SizedBox.shrink()
        : Semantics(
            key: ValueKey(message),
            liveRegion: true,
            child: Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8EFF9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: OneColors.blue),
                  const SizedBox(width: 12),
                  Expanded(child: Text(message!)),
                ],
              ),
            ),
          ),
  );
}

/// Shared, scrollable sheet stays above the keyboard and respects large text.
Future<T?> showFilterSheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useRootNavigator: true,
  useSafeArea: true,
  showDragHandle: true,
  backgroundColor: OneColors.background,
  builder: (context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .86,
      ),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Close filters',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            builder(context),
          ],
        ),
      ),
    ),
  ),
);
