import 'package:material_ui/material_ui.dart';

import '../widgets/one_widgets.dart';

/// Render safe messages, never raw backend errors or credentials.
class ErrorState extends StatelessWidget {
  const ErrorState({required this.message, super.key, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.error_outline,
    title: 'Something went wrong',
    message: message,
    action: onRetry == null
        ? null
        : FilledButton(onPressed: onRetry, child: const Text('Try again')),
  );
}
