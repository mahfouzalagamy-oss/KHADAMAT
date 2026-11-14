import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CustomerRequestDraftStore {
  CustomerRequestDraftStore(String serviceId, String? userId)
      : _key = 'khadamat.request.v1.${userId ?? 'guest'}.$serviceId';

  final String _key;
  final _prefs = SharedPreferencesAsync();

  Future<Map<String, dynamic>?> read() async {
    final raw = await _prefs.getString(_key);
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw);
      return data is Map<String, dynamic> ? data : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> save(Map<String, Object?> draft) =>
      _prefs.setString(_key, jsonEncode(draft));

  Future<void> clear() => _prefs.remove(_key);
}
