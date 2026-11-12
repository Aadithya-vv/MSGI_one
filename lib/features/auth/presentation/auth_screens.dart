import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/one_widgets.dart';

class StartupScreen extends StatelessWidget {
  const StartupScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: OneColors.navy,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.hub_outlined, size: 88, color: OneColors.gold),
                const SizedBox(height: 32),
                const Text(
                  AppConfig.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  AppConfig.tagline,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFDEE7F6), fontSize: 16),
                ),
                const SizedBox(height: 40),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: OneColors.gold,
                    foregroundColor: OneColors.navy,
                  ),
                  onPressed: () => context.go(AppRoutes.welcome),
                  child: const Text('Get started'),
                ),
                const SizedBox(height: 24),
                const PreviewBadge(),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: PageBody(
        children: [
          const BrandMark(),
          const SizedBox(height: 48),
          const Icon(
            Icons.diversity_2_outlined,
            size: 120,
            color: OneColors.blue,
          ),
          const SizedBox(height: 32),
          const FeatureHeader(
            eyebrow: 'One community. Endless possibilities.',
            title: 'Your next chapter\nstarts with a connection.',
            description: 'Meet experience with ambition. Discover mentors, shared journeys, and opportunities across the MSGI community.',
          ),
          FilledButton(
            onPressed: () => context.go(AppRoutes.login),
            child: const Text('Log in'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => context.go(AppRoutes.signup),
            child: const Text('Join the community'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.go(AppRoutes.home),
            child: const Text('Explore sample dashboard'),
          ),
          const SizedBox(height: 24),
          const Text(
            'Foundation preview · Registration and authentication are not available yet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: OneColors.muted, height: 1.5),
          ),
        ],
      ),
    ),
  );
}

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key, this.signup = false});
  final bool signup;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: BackButton(onPressed: () => context.go(AppRoutes.welcome)),
      title: Text(signup ? 'Sign up' : 'Log in'),
    ),
    body: SafeArea(
      child: PageBody(
        children: [
          FeatureHeader(
            eyebrow: 'Where generations connect',
            title: signup ? 'Join ${AppConfig.name}' : 'Welcome back',
            description:
                'This is a preview of the future ${signup ? 'registration' : 'login'} experience. No credentials are collected or sent.',
          ),
          const TextField(
            enabled: false,
            decoration: InputDecoration(
              labelText: 'Email address',
              prefixIcon: Icon(Icons.mail_outline),
            ),
          ),
          const SizedBox(height: 16),
          const TextField(
            enabled: false,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 24),
          const EmptyState(
            title: 'Secure access is coming next',
            message: 'Account verification and secure sign-in will be added in the authentication phase.',
            icon: Icons.verified_user_outlined,
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => context.go(AppRoutes.home),
            child: const Text('Explore sample dashboard'),
          ),
          TextButton(
            onPressed: () =>
                context.go(signup ? AppRoutes.login : AppRoutes.signup),
            child: Text(signup ? 'View login preview' : 'View signup preview'),
          ),
        ],
      ),
    ),
  );
}
