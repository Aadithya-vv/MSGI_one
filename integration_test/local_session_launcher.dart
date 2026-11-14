// Standalone debug entry for a real Android process restart acceptance check.
// Not used by the production launcher or the competition release.
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:msgi_one/core/config/backend_config.dart';
import 'package:msgi_one/core/config/production_session.dart';
import 'package:msgi_one/features/demo/presentation/experience_root.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const stamp = String.fromEnvironment('TASK11_STAMP');
  if (!const bool.fromEnvironment('LOCAL_AUTH_TESTING') ||
      BackendConfig.fromEnvironment().url != 'http://127.0.0.1:55321' ||
      !RegExp(r'^\d+$').hasMatch(stamp)) {
    throw StateError('Dedicated isolated local session acceptance required');
  }
  runApp(
    ExperienceRoot(
      openProduction: () => ProductionSession.open(
        detectSessionInUri: false,
        localStorage: SharedPreferencesLocalStorage(
          persistSessionKey: 'msgi_one.task11a.auth.$stamp',
        ),
      ),
    ),
  );
}
