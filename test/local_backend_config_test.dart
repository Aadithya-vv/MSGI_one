import 'package:flutter_test/flutter_test.dart';
import 'package:msgi_one/core/config/backend_config.dart';

void main() {
  test('local testing permits only opted-in loopback HTTP', () {
    const key = 'sb_publishable_TEST_ONLY_NOT_A_LIVE_KEY';
    expect(
      const BackendConfig(
        url: 'http://127.0.0.1:55321',
        publishableKey: key,
      ).problem,
      const bool.fromEnvironment('LOCAL_AUTH_TESTING') ? isNull : isNotNull,
    );
    for (final host in ['localhost', '192.168.1.10', 'example.invalid']) {
      expect(
        BackendConfig(url: 'http://$host:55321', publishableKey: key).problem,
        isNotNull,
      );
    }
  });
}
