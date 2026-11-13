class MembershipCandidate {
  const MembershipCandidate({
    required this.id,
    required this.name,
    required this.claimedKind,
    required this.institutionId,
    required this.departmentId,
    required this.joiningYear,
    required this.graduationYear,
  });
  final String id, name, claimedKind, institutionId, departmentId;
  final int joiningYear, graduationYear;
}

enum ReviewDecision { verified, rejected, suspended }

class MembershipReview {
  const MembershipReview({
    required this.userId,
    required this.decision,
    required this.reason,
    this.verifiedKind,
  });
  final String userId, reason;
  final ReviewDecision decision;
  final String? verifiedKind;
  String? validate(String? reviewerId) {
    if (userId == reviewerId) return 'You cannot review your own membership.';
    if (reason.trim().isEmpty || reason.trim().length > 1000) {
      return 'Enter an audit reason of 1–1000 characters.';
    }
    if (decision == ReviewDecision.verified &&
        !['student', 'alumni'].contains(verifiedKind)) {
      return 'Choose the independently verified membership type.';
    }
    if (decision != ReviewDecision.verified && verifiedKind != null) {
      return 'Only approval assigns a verified membership type.';
    }
    return null;
  }
}

abstract class AdministrationRepository {
  Future<List<MembershipCandidate>> pending({int limit = 30});
  Future<void> review(MembershipReview input);
}
