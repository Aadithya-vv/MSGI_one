import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/academic_catalog.dart';
import '../../auth/application/auth_providers.dart';

/// Real scopes use authenticated database catalogs; demo overrides stay isolated.
final academicCatalogsProvider = Provider<List<InstitutionAcademicCatalog>>((
  ref,
) {
  final options = ref.watch(onboardingOptionsProvider).asData?.value;
  if (options == null) return const [];
  return options.institutions
      .map(
        (institution) => InstitutionAcademicCatalog(
          id: institution.id,
          name: institution.name,
          programmes: options.programmes
              .where((p) => p.institutionId == institution.id)
              .map(
                (p) => AcademicProgramme(
                  p.id,
                  p.name,
                  p.level == 'postgraduate'
                      ? ProgrammeLevel.postgraduate
                      : ProgrammeLevel.undergraduate,
                  institution.id,
                ),
              )
              .toList(),
          departments: options.departments
              .where((d) => d.institutionId == institution.id)
              .map((d) => AcademicDepartment(d.id, d.name, institution.id))
              .toList(),
        ),
      )
      .toList();
});
