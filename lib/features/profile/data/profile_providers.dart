import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../../../core/community_identity.dart';
import '../../catalog/domain/catalog_repository.dart';
import '../../catalog/data/supabase_catalog_repository.dart';
import '../domain/profile_repository.dart';
import '../data/supabase_profile_repository.dart';
import '../../auth/domain/onboarding.dart';

/// In-memory only; survives membership refresh routes, clears on identity change.
final onboardingBufferProvider =
    NotifierProvider<OnboardingBuffer, OnboardingInput?>(OnboardingBuffer.new);

class OnboardingBuffer extends Notifier<OnboardingInput?> {
  @override
  OnboardingInput? build() {
    ref.watch(authControllerProvider.select((s) => s.userId));
    ref.watch(profileRevisionProvider);
    return null;
  }

  void store(OnboardingInput? input) => state = input;
}

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) throw StateError('Backend unavailable');
  return SupabaseCatalogRepository(client);
});
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) throw StateError('Backend unavailable');
  return SupabaseProfileRepository(client);
});
final ownProfileProvider = FutureProvider<MemberProfile?>((ref) {
  ref.watch(communityUserIdProvider);
  ref.watch(profileRevisionProvider);
  return ref.watch(profileRepositoryProvider).own();
});
final profileDraftProvider = FutureProvider<Map<String, dynamic>?>((ref) {
  ref.watch(authControllerProvider.select((s) => s.userId));
  ref.watch(profileRevisionProvider);
  return ref.watch(profileRepositoryProvider).draft();
});
final alumniDetailProvider = FutureProvider.autoDispose
    .family<AlumniProfile?, String>(
      (ref, id) => ref.watch(profileRepositoryProvider).detail(id),
    );

/// A local presentation refresh signal; it grants no backend permissions.
final profileRevisionProvider = NotifierProvider<ProfileRevision, int>(
  ProfileRevision.new,
);

class ProfileRevision extends Notifier<int> {
  @override
  int build() => 0;
  void refresh() => state++;
}
