import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/backend_config.dart';
import 'features/auth/application/auth_providers.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = BackendConfig.fromEnvironment();
  SupabaseClient? client;
  String? error;
  if (config.problem == null) {
    try {
      await Supabase.initialize(
        url: config.url,
        publishableKey: config.publishableKey,
      ).timeout(const Duration(seconds: 20));
      client = Supabase.instance.client;
    } catch (_) {
      error = 'Backend initialization failed. Check the development setup and restart the app.';
    }
  }
  runApp(
    ProviderScope(
      overrides: [
        backendConfigProvider.overrideWithValue(config),
        backendInitializationErrorProvider.overrideWithValue(error),
        supabaseClientProvider.overrideWithValue(client),
      ],
      child: const OneApp(),
    ),
  );
}
