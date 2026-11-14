import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:msgi_one/features/demo/data/demo_persistence.dart';
import 'package:msgi_one/core/config/auth_entry_links.dart';

class MemoryDemoPersistence implements DemoPersistence {
  Map<String, dynamic>? value;
  bool fail = false;
  int writes = 0;
  @override
  Future<Map<String, dynamic>?> read() async {
    if (fail) throw StateError('Storage unavailable');
    return value == null
        ? null
        : jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
  }

  @override
  Future<void> write(Map<String, dynamic> data) async {
    if (fail) throw StateError('Storage unavailable');
    writes++;
    value = jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
  }
}

class TestAuthEntryLinks implements AuthEntryLinks {
  TestAuthEntryLinks({this.first});
  final Uri? first;
  final controller = StreamController<Uri>.broadcast();
  @override
  Future<Uri?> initial() async => first;
  @override
  Stream<Uri> get events => controller.stream;
  Future<void> close() => controller.close();
}

class RejectDemoHttp extends HttpOverrides {
  int requests = 0;
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    requests++;
    throw StateError('No network allowed in demo tests');
  }
}
