import 'dart:io';
import 'dart:convert';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final captures = <String>[];
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      if (!RegExp(r'^[a-z0-9_-]+$').hasMatch(name)) return false;
      final directory = Directory('build/task12b/integration-screenshots');
      await directory.create(recursive: true);
      await File('${directory.path}/$name.png').writeAsBytes(bytes);
      captures.add(name);
      return true;
    },
    responseDataCallback: (_) async {
      await File(
        'build/task12b/integration-summary.json',
      ).writeAsString(jsonEncode({'completed': true, 'screenshots': captures}));
    },
  );
}
