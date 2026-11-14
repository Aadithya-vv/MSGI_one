import 'dart:io';
import 'dart:convert';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final captured = <String>[];
  await integrationDriver(
    onScreenshot:
        (String name, List<int> bytes, [Map<String, Object?>? args]) async {
          if (!RegExp(r'^[a-z0-9_-]+$').hasMatch(name)) return false;
          await Directory('build/task08/screenshots').create(recursive: true);
          await File('build/task08/screenshots/$name.png').writeAsBytes(bytes);
          captured.add(name);
          return true;
        },
    responseDataCallback: (data) async {
      await File(
        'build/task08/demo-driver-summary.json',
      ).writeAsString(jsonEncode({'screenshots': captured, 'completed': true}));
    },
  );
}
