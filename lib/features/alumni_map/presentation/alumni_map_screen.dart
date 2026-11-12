import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/one_widgets.dart';

class AlumniMapScreen extends StatelessWidget {
  const AlumniMapScreen({super.key});
  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      const FeatureHeader(
        eyebrow: 'A community without borders',
        title: 'Global alumni map',
        description: 'A place for shared beginnings, wherever life takes you. This is an illustrative map placeholder; no real locations are displayed.',
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Icon(Icons.public, size: 140, color: OneColors.blue),
              const SizedBox(height: 24),
              const Text(
                'Across cities. Across generations.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: const [
                  Chip(label: Text('Sample: Bengaluru')),
                  Chip(label: Text('Sample: Pune')),
                  Chip(label: Text('Sample: London')),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Location sharing will always require consent.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
