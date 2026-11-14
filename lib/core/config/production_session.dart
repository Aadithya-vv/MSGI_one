import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend_config.dart';
import '../../features/auth/domain/auth_repository.dart';

class ProductionSession {
  ProductionSession(
    this.config, {
    this.client,
    this.error,
    this.started = false,
    this.initializing,
  });
  final BackendConfig config;
  final SupabaseClient? client;
  final String? error;
  final bool started;
  final Future<Supabase>? initializing;
  static Future<ProductionSession> open({
    bool detectSessionInUri = true,
  }) async {
    final config = BackendConfig.fromEnvironment();
    if (config.problem != null) return ProductionSession(config);
    final opening = Supabase.initialize(
      debug: false,
      url: config.url,
      publishableKey: config.publishableKey,
      authOptions: FlutterAuthClientOptions(
        detectSessionInUri: detectSessionInUri,
      ),
    );
    try {
      final sdk = await opening.timeout(const Duration(seconds: 20));
      return ProductionSession(
        config,
        client: sdk.client,
        started: true,
        initializing: opening,
      );
    } catch (_) {
      return ProductionSession(
        config,
        error: 'Backend initialization failed. Check the development setup and restart the app.',
        started: true,
        initializing: opening,
      );
    }
  }

  static Future<ProductionSession> fromGateway() =>
      open(detectSessionInUri: false);
  Future<void> handleAuthEntry(Uri uri) async {
    if (client == null) return;
    try {
      await client!.auth
          .getSessionFromUrl(uri)
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const AuthFailure('Authentication link unavailable or expired.');
    }
  }

  Future<void> close() async {
    if (!started) return;
    try {
      await Supabase.instance.dispose();
    } catch (_) {
      final sdk = await initializing!.timeout(const Duration(seconds: 20));
      await sdk.dispose();
    }
  }
}
