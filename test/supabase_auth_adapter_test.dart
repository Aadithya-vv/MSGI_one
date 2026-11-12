import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:msgi_one/core/config/auth_callback.dart';
import 'package:msgi_one/features/auth/data/supabase_auth_repository.dart';
import 'package:msgi_one/features/auth/domain/auth_repository.dart';

void main() {
  for (final recovery in [false, true]) {
    test(
      '${recovery ? 'Recovery' : 'Signup'} sends the mobile callback and hides server errors',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final client = SupabaseClient(
          'http://127.0.0.1:${server.port}',
          'test-only-not-a-real-key',
          authOptions: AuthClientOptions(
            autoRefreshToken: false,
            pkceAsyncStorage: _MemoryStorage(),
          ),
        );
        addTearDown(() async {
          await client.dispose();
          await server.close(force: true);
        });
        final received = <Uri>[];
        final payloads = <Map<String, dynamic>>[];
        server.listen((request) async {
          received.add(request.uri);
          payloads.add(
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>,
          );
          request.response.statusCode = 400;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({'msg': 'private backend detail'}));
          await request.response.close();
        });
        final repository = SupabaseAuthRepository(client);
        await expectLater(
          recovery
              ? repository.requestPasswordReset(' fixture@example.invalid ')
              : repository.signUp(
                  ' fixture@example.invalid ',
                  'test-only-password',
                ),
          throwsA(isA<AuthFailure>()),
        );
        expect(
          received.single.path,
          recovery ? '/auth/v1/recover' : '/auth/v1/signup',
        );
        expect(received.single.queryParameters['redirect_to'], authCallbackUri);
        expect(payloads.single['email'], 'fixture@example.invalid');
        expect(payloads.single.containsKey('role'), isFalse);
        expect(payloads.single.containsKey('verified'), isFalse);
      },
    );
  }
}

class _MemoryStorage extends GotrueAsyncStorage {
  final _values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => _values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    _values.remove(key);
  }
}
