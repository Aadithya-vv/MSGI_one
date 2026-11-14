import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/application/auth_providers.dart';

/// Presentation identity only. This never grants membership or API permissions.
/// The isolated demo scope substitutes a fictional ID without changing Auth.
final communityUserIdProvider = Provider<String?>(
  (ref) => ref.watch(authControllerProvider).userId,
);
