import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/domain/profile_repository.dart';
import '../../profile/data/profile_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/auth_repository.dart';

class DirectoryPage {
  const DirectoryPage(
    this.people, {
    this.hasMore = false,
    this.moreError = false,
    this.loadingMore = false,
  });
  final List<AlumniProfile> people;
  final bool hasMore, moreError, loadingMore;
}

final directoryProvider =
    AsyncNotifierProvider.autoDispose<DirectoryController, DirectoryPage>(
      DirectoryController.new,
    );

class DirectoryController extends AsyncNotifier<DirectoryPage> {
  DirectoryFilter _filter = const DirectoryFilter();
  int _generation = 0;
  bool _paging = false;
  @override
  Future<DirectoryPage> build() async {
    _generation++;
    ref.onDispose(() => _generation++);
    final access = ref.watch(authControllerProvider);
    if (!access.isVerified) {
      throw const AuthFailure('Verified membership required');
    }
    final rows = await ref.watch(profileRepositoryProvider).discover(_filter);
    return DirectoryPage(rows.take(20).toList(), hasMore: rows.length > 20);
  }

  Future<void> search(DirectoryFilter filter) async {
    final generation = ++_generation;
    _filter = filter;
    _paging = false;
    state = const AsyncLoading();
    try {
      final rows = await ref.read(profileRepositoryProvider).discover(filter);
      if (ref.mounted && generation == _generation) {
        state = AsyncData(
          DirectoryPage(rows.take(20).toList(), hasMore: rows.length > 20),
        );
      }
    } catch (e, st) {
      if (ref.mounted && generation == _generation) state = AsyncError(e, st);
    }
  }

  Future<void> next() async {
    final page = state.asData?.value;
    if (_paging || page == null || !page.hasMore || page.people.isEmpty) return;
    _paging = true;
    state = AsyncData(
      DirectoryPage(page.people, hasMore: true, loadingMore: true),
    );
    final generation = _generation;
    try {
      final rows = await ref
          .read(profileRepositoryProvider)
          .discover(_filter, after: page.people.last.id);
      if (ref.mounted && generation == _generation) {
        state = AsyncData(
          DirectoryPage([
            ...page.people,
            ...rows.take(20),
          ], hasMore: rows.length > 20),
        );
      }
    } catch (_) {
      if (ref.mounted && generation == _generation) {
        state = AsyncData(
          DirectoryPage(page.people, hasMore: true, moreError: true),
        );
      }
    } finally {
      if (generation == _generation) _paging = false;
    }
  }
}
