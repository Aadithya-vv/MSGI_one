import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/academic_catalog.dart';

/// Text-only institutional context; no unapproved artwork or missing images.
class MsecInstitutionIdentity extends StatelessWidget {
  const MsecInstitutionIdentity({super.key, this.campusPreview = false});

  // Retained for call-site compatibility; selects the prominent welcome style.
  final bool campusPreview;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: EdgeInsets.all(campusPreview ? 20 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            MsecCatalog.name,
            style: TextStyle(
              color: OneColors.navy,
              fontSize: campusPreview ? 16 : 12,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Chennai · Connecting generations through shared knowledge.',
            style: TextStyle(color: OneColors.muted, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    ),
  );
}
