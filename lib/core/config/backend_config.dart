import 'package:flutter/foundation.dart';

class BackendConfig {
  const BackendConfig({this.url = '', this.publishableKey = ''});
  factory BackendConfig.fromEnvironment() => const BackendConfig(
    url: String.fromEnvironment('SUPABASE_URL'),
    publishableKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  );
  final String url;
  final String publishableKey;
  String? get problem {
    if (url.isEmpty || publishableKey.isEmpty) {
      return 'Supply SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY after the backend has been reviewed.';
    }
    final uri = Uri.tryParse(url);
    if (uri == null ||
        (uri.scheme != 'https' &&
            !(kDebugMode &&
                const bool.fromEnvironment('LOCAL_AUTH_TESTING') &&
                uri.scheme == 'http' &&
                uri.host == '127.0.0.1')) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      return 'The backend URL must be an HTTPS project origin without credentials, query parameters, or a custom path.';
    }
    if (!RegExp(r'^sb_publishable_[A-Za-z0-9_-]{20,}$')
        .hasMatch(publishableKey)) {
      return 'Only a publishable key is supported. Never bundle a secret or service-role key.';
    }
    return null;
  }
}
