import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:msgi_one/core/config/backend_config.dart';
import 'package:msgi_one/core/config/production_session.dart';
import 'package:msgi_one/core/config/auth_entry_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:msgi_one/core/routing/app_routes.dart';
import 'package:msgi_one/features/demo/presentation/experience_root.dart';
import 'package:msgi_one/features/auth/domain/onboarding.dart';
import 'package:msgi_one/features/catalog/domain/academic_catalog.dart';

class ObservedSession extends ProductionSession {
  ObservedSession(this.delegate)
    : super(
        delegate.config,
        client: delegate.client,
        error: delegate.error,
        started: delegate.started,
        initializing: delegate.initializing,
      );
  final ProductionSession delegate;
  final closed = Completer<void>();
  @override
  Future<void> close() async {
    try {
      await delegate.close();
    } finally {
      if (!closed.isCompleted) closed.complete();
    }
  }
}

// Model a launcher restart during widget/SDK recreation; do not replay an old
// process's getInitialLink. Live callbacks still use the real Android stream.
class LauncherRestartLinks implements AuthEntryLinks {
  final _platform = PlatformAuthEntryLinks();
  @override
  Future<Uri?> initial() async => null;
  @override
  Stream<Uri> get events => _platform.events;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Local real signup, Android confirmation callbacks and three-role onboarding',
    (tester) async {
      const stamp = String.fromEnvironment('TASK11_STAMP');
      if (stamp.isEmpty ||
          BackendConfig.fromEnvironment().url != 'http://127.0.0.1:55321' ||
          !const bool.fromEnvironment('LOCAL_AUTH_TESTING')) {
        throw StateError('Dedicated isolated local run required');
      }
      tester.testTextInput.register();
      addTearDown(tester.testTextInput.unregister);
      Future<void> ready(Finder finder) async {
        for (var i = 0; i < 300; i++) {
          await tester.pump(const Duration(milliseconds: 150));
          if (finder.evaluate().isNotEmpty) return;
        }
        throw StateError('Expected local onboarding screen unavailable');
      }

      Future<void> tap(Finder finder) async {
        await ready(finder);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tester.ensureVisible(finder.first);
        await tester.pumpAndSettle();
        await tester.tap(finder.first);
        await tester.pumpAndSettle();
      }

      Future<void> enter(String label, String value) async {
        final finder = find.widgetWithText(TextFormField, label);
        await ready(finder);
        await tester.ensureVisible(finder);
        await tester.enterText(finder, value);
        await tester.pumpAndSettle();
      }

      Future<void> authFields(
        String email,
        String password, {
        bool signup = false,
      }) async {
        await ready(find.byKey(const Key('auth-email')));
        await tester.enterText(find.byKey(const Key('auth-email')), email);
        await tester.enterText(
          find.byKey(const Key('auth-password')),
          password,
        );
        if (signup) {
          await tester.enterText(
            find.byKey(const Key('auth-confirm')),
            password,
          );
        }
      }

      Future<void> pending() => ready(find.text('Verification pending'));
      ObservedSession? latest;
      Future<ProductionSession> open() async {
        final session = await ProductionSession.open(
          detectSessionInUri: false,
          localStorage: SharedPreferencesLocalStorage(
            persistSessionKey: 'msgi_one.task11a.auth.$stamp',
          ),
        );
        return latest = ObservedSession(session);
      }

      runApp(ExperienceRoot(openProduction: open));
      await tap(find.text('Create an account'));
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      for (final kind in AccountKind.values) {
        if (kind != AccountKind.student) {
          await tap(find.text('Create an account'));
        }
        await ready(find.byKey(const Key('signup-account-kind')));
        await tap(find.byKey(const Key('signup-account-kind')));
        await tap(
          find.text(switch (kind) {
            AccountKind.student => 'Student',
            AccountKind.alumni => 'Alumni',
            AccountKind.staff => 'Faculty / Staff',
          }).last,
        );
        final email = 'task11a-android-${kind.name}-$stamp@example.test',
            password = 'Local-Synthetic-$stamp-${kind.name}!';
        await authFields(email, password, signup: true);
        await tap(find.widgetWithText(FilledButton, 'Create account'));
        await ready(find.textContaining('Check your inbox to confirm'));
        // Host helper opens the actual Android intent from the matching local email.
        // No email address, password, link or token is written to diagnostics.
        debugPrint('TASK11_CONFIRM_${kind.name}');
        await ready(find.widgetWithText(AppBar, 'Complete your profile'));
        await enter('Display name', '[SYNTHETIC LOCAL] Android ${kind.name}');
        await tap(
          find.widgetWithText(DropdownButtonFormField<String>, 'Institution'),
        );
        await tap(find.text(MsecCatalog.name).last);
        if (kind != AccountKind.staff) {
          await tap(
            find.widgetWithText(
              DropdownButtonFormField<String>,
              'Degree programme',
            ),
          );
          await tap(find.text('B.E. Civil Engineering').last);
          if (kind == AccountKind.student) await enter('Joining year', '2024');
          await enter(
            'Graduation year (actual or expected)',
            kind == AccountKind.student ? '2028' : '2020',
          );
        } else {
          expect(
            find.widgetWithText(TextFormField, 'Joining year'),
            findsNothing,
          );
          await enter(
            'Institutional affiliation (if no department selected)',
            'Synthetic academic support',
          );
        }
        await enter(
          'Professional designation (if applicable)',
          'Synthetic engineer',
        );
        await enter('Career interests (comma separated)', 'Engineering');
        if (kind != AccountKind.staff) {
          await tap(
            find.widgetWithText(FilterChip, '[SYNTHETIC LOCAL] Programming'),
          );
        }
        await tap(find.text('Save progress privately'));
        await tap(find.text('Submit for institutional review'));
        await pending();
        await binding.takeScreenshot('task11_${kind.name}_pending');
        await tap(find.text('View your submitted profile'));
        await ready(find.text('[SYNTHETIC LOCAL] Android ${kind.name}'));
        if (kind != AccountKind.staff) {
          expect(find.textContaining('B.E. Civil Engineering'), findsWidgets);
        }
        expect(find.text('Review memberships'), findsNothing);
        await tap(find.text('Log out'));
        await authFields(email, password);
        await tap(find.widgetWithText(FilledButton, 'Log in'));
        await pending();
        await tap(find.text('View your submitted profile'));
        await ready(find.text('[SYNTHETIC LOCAL] Android ${kind.name}'));
        await tap(find.text('Log out'));
      }
      final email = 'task11a-android-staff-$stamp@example.test';
      await tap(find.text('Forgot password?'));
      await ready(find.byKey(const Key('auth-email')));
      await tester.enterText(find.byKey(const Key('auth-email')), email);
      await tap(
        find.widgetWithText(FilledButton, 'Send recovery instructions'),
      );
      await ready(find.textContaining('If an account exists'));
      debugPrint('TASK11_RECOVERY');
      await ready(find.text('Choose a new password'));
      final password = 'Local-Updated-$stamp!';
      await tester.enterText(find.byKey(const Key('auth-password')), password);
      await tester.enterText(find.byKey(const Key('auth-confirm')), password);
      await tap(find.widgetWithText(FilledButton, 'Update password'));
      await pending();
      await tap(find.text('Log out'));
      await authFields(email, password);
      await tap(find.widgetWithText(FilledButton, 'Log in'));
      await pending();
      final closing = latest!.closed.future;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await closing;
      runApp(
        ExperienceRoot(openProduction: open, links: LauncherRestartLinks()),
      );
      await tap(find.text('Sign in to real community'));
      await pending();
      expect(find.byKey(const Key('auth-password')), findsNothing);
      await binding.takeScreenshot('task11_restored_pending_session');
      // Route attempts must stay closed even after successful email confirmation.
      GoRouter.of(tester.element(find.text('Verification pending')))
          .go(AppRoutes.discover);
      await tester.pumpAndSettle();
      await pending();
      debugPrint('TASK11_INVALID');
      await ready(find.text('Access check unavailable'));
      expect(tester.takeException(), isNull);
      await binding.takeScreenshot('task11_invalid_callback_closed');
    },
  );
}
