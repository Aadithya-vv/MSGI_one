import 'package:app_links/app_links.dart';

import 'auth_callback.dart';

abstract class AuthEntryLinks {
  Future<Uri?> initial();
  Stream<Uri> get events;
}

class PlatformAuthEntryLinks implements AuthEntryLinks {
  final AppLinks _links = AppLinks();
  @override
  Future<Uri?> initial() => _links.getInitialLink();
  @override
  Stream<Uri> get events => _links.uriLinkStream;
}

bool isProductionAuthEntry(Uri uri) {
  final expected = Uri.parse(authCallbackUri);
  return uri.scheme == expected.scheme &&
      uri.host == expected.host &&
      (uri.path == expected.path || uri.path.isEmpty) &&
      uri.userInfo.isEmpty &&
      !uri.hasPort;
}
