import '../../auth/domain/onboarding.dart';

enum CatalogKind { institutions, departments, skills, cities }

abstract class CatalogRepository {
  Future<List<CatalogEntry>> search(
    CatalogKind kind, {
    String query = '',
    String? institutionId,
    int page = 0,
  });
}
