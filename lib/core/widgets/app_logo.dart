import 'package:material_ui/material_ui.dart';

/// The owner's approved bitmap artwork. Never tint or stretch it.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 220,
    this.emblemOnly = false,
    this.decorative = false,
  });

  static const originalAsset = 'assets/branding/msgi-one-logo-original.png';
  static const emblemAsset = 'assets/branding/msgi-one-emblem.png';
  final double size;
  final bool emblemOnly;
  final bool decorative;

  @override
  Widget build(BuildContext context) => Image.asset(
    emblemOnly ? emblemAsset : originalAsset,
    width: size,
    height: size,
    fit: BoxFit.contain,
    semanticLabel: decorative ? null : 'MSGI One',
    excludeFromSemantics: decorative,
    filterQuality: FilterQuality.medium,
  );
}
