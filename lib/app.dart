import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/access_screen.dart';

class OneApp extends ConsumerWidget {
  const OneApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => AuthLifecycleRefresh(
    child: MaterialApp.router(
      title: AppConfig.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: ref.watch(appRouterProvider),
    ),
  );
}
