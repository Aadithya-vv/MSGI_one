import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/one_widgets.dart';
import '../data/sample_mentors.dart';
import '../domain/mentor_preview.dart';

class MentorshipScreen extends ConsumerWidget {
  const MentorshipScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => PageBody(
    children: [
      const FeatureHeader(
        eyebrow: 'Learn across generations',
        title: 'Mentor recommendations',
        description: 'A preview of future mentorship. These sample profiles are not real people or personalized recommendations.',
      ),
      for (final mentor in ref.watch(sampleMentorsProvider))
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: MentorCard(mentor: mentor),
        ),
      const EmptyState(
        title: 'Your path, guided by experience',
        message: 'Personalized matching and mentor requests will become available after verified profiles and secure backend integration.',
        icon: Icons.auto_awesome_outlined,
      ),
    ],
  );
}

class MentorCard extends StatelessWidget {
  const MentorCard({required this.mentor, super.key});
  final MentorPreview mentor;
  @override
  Widget build(BuildContext context) => InfoCard(
    icon: Icons.person_outline,
    title: mentor.name,
    description: '${mentor.role}\n${mentor.focus}',
    trailing: const Text(
      'SAMPLE PROFILE',
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
      ),
    ),
  );
}
