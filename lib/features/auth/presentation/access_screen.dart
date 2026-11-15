import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/config/experience_actions.dart';

import '../../../core/widgets/one_widgets.dart';
import '../application/auth_providers.dart';
import '../domain/auth_repository.dart';
import '../../administration/presentation/membership_request_panel.dart';

class AccessScreen extends ConsumerWidget {
  const AccessScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(authControllerProvider);
    final (title, message) = switch (access.phase) {
      AccessPhase.configurationRequired => (
        'Development setup required',
        ref.watch(backendInitializationErrorProvider) ??
            ref.watch(backendConfigProvider).problem ??
            'Backend initialization is unavailable. Restart after setup.',
      ),
      AccessPhase.pending => (
        'Verification pending',
        'Your profile has been submitted. A trusted institutional administrator must approve membership before community access.',
      ),
      AccessPhase.rejected => (
        'Membership not approved',
        'Your institutional review was not approved. Contact the college through its official channel for clarification.',
      ),
      AccessPhase.suspended => (
        'Membership suspended',
        'Community access is suspended. Contact the college through its official channel for review.',
      ),
      _ => (
        'Access check unavailable',
        access.notice ?? 'Your membership could not be verified. Community access stays closed until a fresh check succeeds.',
      ),
    };
    return Scaffold(
      appBar: AppBar(title: const BrandMark()),
      body: SafeArea(
        child: PageBody(
          children: [
            if (ref.watch(exploreDemoActionProvider) != null)
              TextButton(
                onPressed: ref.watch(exploreDemoActionProvider),
                child: const Text('Explore Demo'),
              ),
            if (ref.watch(appEntryActionProvider) != null)
              TextButton(
                onPressed: ref.watch(appEntryActionProvider),
                child: const Text('Back to app entry'),
              ),
            if (access.phase == AccessPhase.loading)
              const LoadingState(
                message: 'Checking your session and membership…',
              )
            else ...[
              EmptyState(
                title: title,
                message: message,
                icon: Icons.verified_user_outlined,
              ),
              if (access.phase == AccessPhase.rejected ||
                  access.phase == AccessPhase.suspended)
                const MembershipRequestPanel(),
              if (access.phase == AccessPhase.configurationRequired)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Text(
                    'No hosted backend has been connected by this task. Review docs/supabase-setup.md before supplying real public project configuration. Never bundle privileged keys.',
                  ),
                ),
              if (access.phase != AccessPhase.configurationRequired) ...[
                if (access.phase == AccessPhase.pending) ...[
                  TextButton(
                    onPressed: () => context.go(AppRoutes.ownProfile),
                    child: const Text('View your submitted profile'),
                  ),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.profileEdit),
                    child: const Text('Edit pending profile'),
                  ),
                ],
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).refresh(),
                  child: const Text('Refresh membership status'),
                ),
                TextButton(
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).signOut(),
                  child: const Text('Log out'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class AuthLifecycleRefresh extends ConsumerStatefulWidget {
  const AuthLifecycleRefresh({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<AuthLifecycleRefresh> createState() =>
      _AuthLifecycleRefreshState();
}

class _AuthLifecycleRefreshState extends ConsumerState<AuthLifecycleRefresh>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(authControllerProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
