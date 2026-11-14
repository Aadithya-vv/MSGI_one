/// User-supplied institutional reference information. IDs are internal application
/// identifiers, not official college codes or hosted database UUIDs.
enum ProgrammeLevel { undergraduate, postgraduate }

class AcademicProgramme {
  const AcademicProgramme(this.id, this.name, this.level, this.institutionId);
  final String id, name, institutionId;
  final ProgrammeLevel level;
}

class AcademicDepartment {
  const AcademicDepartment(this.id, this.name, this.institutionId);
  final String id, name, institutionId;
}

class InstitutionAcademicCatalog {
  const InstitutionAcademicCatalog({
    required this.id,
    required this.name,
    required this.programmes,
    required this.departments,
    this.shortName = '',
  });
  final String id, name, shortName;
  final List<AcademicProgramme> programmes;
  final List<AcademicDepartment> departments;
  AcademicProgramme? programme(String? id) =>
      programmes.where((p) => p.id == id).firstOrNull;
}

abstract final class MsecCatalog {
  static const id = 'msec';
  static const name = 'Meenakshi Sundararajan Engineering College (MSEC)';
  static const scienceHumanitiesId = 'msec-dept-science-humanities';
  static const catalog = InstitutionAcademicCatalog(
    id: id,
    name: name,
    shortName: 'MSEC',
    programmes: [
      AcademicProgramme(
        'msec-ug-ai-ds',
        'B.Tech. Artificial Intelligence & Data Science',
        ProgrammeLevel.undergraduate,
        id,
      ),
      AcademicProgramme(
        'msec-ug-ai-ml',
        'B.Tech. Artificial Intelligence & Machine Learning',
        ProgrammeLevel.undergraduate,
        id,
      ),
      AcademicProgramme(
        'msec-ug-civil',
        'B.E. Civil Engineering',
        ProgrammeLevel.undergraduate,
        id,
      ),
      AcademicProgramme(
        'msec-ug-cse',
        'B.E. Computer Science and Engineering',
        ProgrammeLevel.undergraduate,
        id,
      ),
      AcademicProgramme(
        'msec-ug-cse-cybersecurity',
        'B.E. Computer Science & Engineering (Cybersecurity)',
        ProgrammeLevel.undergraduate,
        id,
      ),
      AcademicProgramme(
        'msec-ug-eee',
        'B.E. Electrical and Electronics Engineering',
        ProgrammeLevel.undergraduate,
        id,
      ),
      AcademicProgramme(
        'msec-ug-ece',
        'B.E. Electronics and Communication Engineering',
        ProgrammeLevel.undergraduate,
        id,
      ),
      AcademicProgramme(
        'msec-ug-it',
        'B.Tech. Information Technology',
        ProgrammeLevel.undergraduate,
        id,
      ),
      AcademicProgramme(
        'msec-ug-mechanical',
        'B.E. Mechanical Engineering',
        ProgrammeLevel.undergraduate,
        id,
      ),
      AcademicProgramme(
        'msec-pg-cs',
        'M.E. Computer Science',
        ProgrammeLevel.postgraduate,
        id,
      ),
      AcademicProgramme(
        'msec-pg-construction',
        'M.E. Construction Engineering and Management',
        ProgrammeLevel.postgraduate,
        id,
      ),
      AcademicProgramme(
        'msec-pg-embedded',
        'M.E. Embedded Systems and Technologies',
        ProgrammeLevel.postgraduate,
        id,
      ),
      AcademicProgramme(
        'msec-pg-energy',
        'M.E. Energy Engineering',
        ProgrammeLevel.postgraduate,
        id,
      ),
    ],
    departments: [
      AcademicDepartment(scienceHumanitiesId, 'Science and Humanities', id),
    ],
  );
}
