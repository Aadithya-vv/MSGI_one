import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/config/app_config.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/one_widgets.dart';
import '../application/auth_providers.dart';
import '../domain/auth_repository.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({
    super.key,
    this.signup = false,
    this.recovery = false,
    this.reset = false,
  });
  final bool signup;
  final bool recovery;
  final bool reset;
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _notice;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_form.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Check the highlighted fields before continuing.'),
        ),
      );
      return;
    }
    final repository = ref.read(authRepositoryProvider);
    if (repository == null) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final controller = ref.read(authControllerProvider.notifier);
      if (widget.recovery) {
        await controller.requestPasswordReset(_email.text);
        if (mounted) {
          setState(
            () => _notice = 'If an account exists for this email, recovery instructions will be sent.',
          );
        }
      } else if (widget.reset) {
        await controller.updatePassword(_password.text);
      } else if (widget.signup) {
        await controller.signUp(_email.text, _password.text);
        if (mounted) {
          setState(
            () => _notice = 'Check your inbox to confirm your email before signing in. Institutional verification is still required.',
          );
        }
      } else {
        await controller.signIn(_email.text, _password.text);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _notice = 'Unable to complete the request. Check your details and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(authRepositoryProvider) != null && !_busy;
    final title = widget.recovery
        ? 'Recover your password'
        : widget.reset
        ? 'Choose a new password'
        : widget.signup
        ? 'Join ${AppConfig.name}'
        : 'Welcome back';
    return Scaffold(
      appBar: AppBar(
        leading: widget.reset
            ? null
            : BackButton(onPressed: () => context.go(AppRoutes.welcome)),
        title: Text(
          widget.signup
              ? 'Sign up'
              : widget.recovery || widget.reset
              ? 'Password recovery'
              : 'Log in',
        ),
      ),
      body: SafeArea(
        child: PageBody(
          children: [
            FeatureHeader(
              eyebrow: AppConfig.tagline,
              title: title,
              description: 'Sign-in establishes your account identity. Only institutional approval grants community access.',
            ),
            Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!widget.reset)
                    TextFormField(
                      key: const Key('auth-email'),
                      controller: _email,
                      enabled: enabled,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      autocorrect: false,
                      validator: AuthValidation.email,
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                    ),
                  if (!widget.reset) const SizedBox(height: 16),
                  if (!widget.recovery)
                    TextFormField(
                      key: const Key('auth-password'),
                      controller: _password,
                      enabled: enabled,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      validator: AuthValidation.password,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        helperText: 'Use 12–128 characters.',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                  if (widget.signup || widget.reset) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('auth-confirm'),
                      controller: _confirm,
                      enabled: enabled,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      validator: (value) =>
                          value == _password.text && value!.isNotEmpty
                          ? null
                          : 'Passwords must match.',
                      decoration: const InputDecoration(
                        labelText: 'Confirm password',
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: enabled ? _submit : null,
                    child: Text(
                      _busy
                          ? 'Please wait…'
                          : widget.recovery
                          ? 'Send recovery instructions'
                          : widget.reset
                          ? 'Update password'
                          : widget.signup
                          ? 'Create account'
                          : 'Log in',
                    ),
                  ),
                  if (_notice != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Semantics(liveRegion: true, child: Text(_notice!)),
                    ),
                ],
              ),
            ),
            if (!widget.recovery && !widget.reset) ...[
              TextButton(
                onPressed: () => context.go(
                  widget.signup ? AppRoutes.login : AppRoutes.signup,
                ),
                child: Text(
                  widget.signup
                      ? 'Already have an account? Log in'
                      : 'Create an account',
                ),
              ),
              if (!widget.signup)
                TextButton(
                  onPressed: () => context.go(AppRoutes.recover),
                  child: const Text('Forgot password?'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
