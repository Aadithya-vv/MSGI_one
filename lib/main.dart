import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/production_session.dart';
import 'features/auth/application/auth_providers.dart';

import 'app.dart';
import 'features/demo/presentation/experience_root.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ExperienceRoot());
}

/// Explicit production entry for existing local backend integration scenarios.
/// The presentation launcher never invokes it just to explore the demo.
Future<void> startProduction() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = await ProductionSession.open();
  runApp(
    ProviderScope(
      overrides: [
        backendConfigProvider.overrideWithValue(session.config),
        backendInitializationErrorProvider.overrideWithValue(session.error),
        supabaseClientProvider.overrideWithValue(session.client),
      ],
      child: const OneApp(),
    ),
  );
}
