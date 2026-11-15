class MembershipCandidate {
  const MembershipCandidate({
    required this.id,
    required this.name,
    required this.claimedKind,
    required this.institutionId,
    required this.departmentId,
    required this.joiningYear,
    required this.graduationYear,
    this.programme = '',
    this.affiliation = '',
    this.institution = '',
    this.department = '',
    this.revision,
    this.status = 'pending',
    this.requestKind,
    this.professional = '',
  });
  final String id, name, claimedKind, institutionId;
  final String? departmentId;
  final int? joiningYear, graduationYear;
  final String programme, affiliation, institution, department;
  final String? revision, requestKind;
  final String status, professional;
}

enum ReviewDecision { verified, rejected, suspended, reinstate, correction }

class MembershipReview {
  const MembershipReview({
    required this.userId,
    required this.decision,
    required this.reason,
    this.verifiedKind,
    this.revision,
    this.requestId,
    this.category = 'record_checked',
  });
  final String userId, reason;
  final ReviewDecision decision;
  final String? verifiedKind;
  final String? revision, requestId;
  final String category;
  String? validate(String? reviewerId) {
    if (userId == reviewerId) return 'You cannot review your own membership.';
    if (reason.trim().isEmpty || reason.trim().length > 1000) {
      return 'Enter an audit reason of 1–1000 characters.';
    }
    if ((decision == ReviewDecision.verified ||
            decision == ReviewDecision.reinstate) &&
        !['student', 'alumni', 'staff'].contains(verifiedKind)) {
      return 'Choose the independently verified membership type.';
    }
    if (decision != ReviewDecision.verified &&
        decision != ReviewDecision.reinstate &&
        verifiedKind != null) {
      return 'Only approval assigns a verified membership type.';
    }
    return null;
  }
}

abstract class AdministrationRepository {
  Future<List<MembershipCandidate>> pending({int limit = 30});
  Future<void> review(MembershipReview input);
  Future<Map<String, dynamic>> context() =>
      Future.error(StateError('Administrator authorization unavailable'));
  Future<List<MembershipCandidate>> members({
    String status = 'pending',
    String? kind,
    int offset = 0,
  }) => pending();
  Future<List<Map<String, dynamic>>> history(String userId, {int offset = 0}) =>
      Future.error(StateError('History unavailable'));
  Future<List<Map<String, dynamic>>> reports({
    String status = 'open',
    int offset = 0,
  }) => Future.error(StateError('Reports unavailable'));
  Future<void> moderate(
    Map<String, dynamic> report,
    String status,
    String note,
    String requestId,
  ) => Future.error(StateError('Moderation unavailable'));
}
