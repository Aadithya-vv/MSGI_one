import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/domain/onboarding.dart';
import '../domain/catalog_repository.dart';

class SupabaseCatalogRepository implements CatalogRepository {
  SupabaseCatalogRepository(this.client);
  final SupabaseClient client;
  @override
  Future<List<CatalogEntry>> search(
    CatalogKind kind, {
    String query = '',
    String? institutionId,
    int page = 0,
  }) async {
    var request = client.from(kind.name).select();
    if (kind == CatalogKind.institutions ||
        kind == CatalogKind.departments ||
        kind == CatalogKind.programmes) {
      request = request.eq('active', true);
    }
    if ((kind == CatalogKind.departments || kind == CatalogKind.programmes) &&
        institutionId != null) {
      request = request.eq('institution_id', institutionId);
    }
    if (query.trim().isNotEmpty) {
      request = request.ilike(
        'name',
        '%${query.trim().replaceAll('%', '').replaceAll('_', '')}%',
      );
    }
    final rows = await request
        .order('name')
        .order('id')
        .range(page * 50, page * 50 + 49)
        .timeout(const Duration(seconds: 20));
    return rows
        .map(
          (r) => CatalogEntry(
            id: r['id'] as String,
            name: r['name'] as String,
            institutionId: r['institution_id'] as String?,
            countryCode: r['country_code'] as String?,
            level: r['level'] as String?,
            catalogKey: r['catalog_key'] as String?,
          ),
        )
        .toList();
  }
}
