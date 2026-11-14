import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

abstract class DemoPersistence {
  Future<Map<String, dynamic>?> read();
  Future<void> write(Map<String, dynamic> value);
}

class PreferencesDemoPersistence implements DemoPersistence {
  static const key = 'msgi_one.competition_demo.v1';
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  @override
  Future<Map<String, dynamic>?> read() async {
    final raw = await _preferences.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(Map<String, dynamic> value) =>
      _preferences.setString(key, jsonEncode(value));
}
