import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

void returnToCommunityParent(BuildContext context, String fallback) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}

Future<void> openMemberProfile(BuildContext context, String id) async {
  await context.push<void>('/alumni/${Uri.encodeComponent(id)}');
}

void openCommunityDestination(BuildContext context, String path) {
  if (const ['/mentors', '/opportunities', '/community'].contains(path)) {
    context.push<void>(path);
  } else {
    context.go(path);
  }
}

/// A direct subpage/deep link still has an intentional community parent.
/// Pushed pages use the actual originating route, including Android system Back.
class CommunityReturnScope extends StatelessWidget {
  const CommunityReturnScope({
    super.key,
    required this.fallback,
    required this.child,
  });
  final String fallback;
  final Widget child;
  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: context.canPop(),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) context.go(fallback);
    },
    child: child,
  );
}
