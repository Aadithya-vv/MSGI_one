import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/academic_catalog.dart';

/// Honest local placeholder until college permission covers APK/Git reuse.
/// No remote image URLs or unofficial crest are substituted for approved media.
class MsecInstitutionIdentity extends StatelessWidget {
  const MsecInstitutionIdentity({super.key, this.campusPreview = false});

  final bool campusPreview;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (campusPreview)
          ColoredBox(
            color: OneColors.navy,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.photo_outlined,
                    color: OneColors.gold,
                    size: 32,
                    semanticLabel: 'Campus photograph placeholder',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A place to connect across generations.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Campus image placeholder · College media approval pending',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                label: 'Official MSEC logo pending approval; placeholder only',
                child: ExcludeSemantics(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: OneColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: OneColors.border),
                    ),
                    child: const Icon(
                      Icons.image_outlined,
                      color: OneColors.muted,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      MsecCatalog.name,
                      style: TextStyle(
                        color: OneColors.navy,
                        fontSize: campusPreview ? 14 : 12,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Chennai · Official crest awaiting permission',
                      style: TextStyle(color: OneColors.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
