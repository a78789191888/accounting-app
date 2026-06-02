import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class LedgerStore {
  LedgerStore({SharedPreferences? preferences}) : _preferences = preferences;

  static const _storageKey = 'dsmfh_accounting_ledger_v1';

  SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  Future<LedgerData> load() async {
    final encoded = (await _prefs).getString(_storageKey);
    if (encoded == null || encoded.isEmpty) {
      return LedgerData.empty();
    }

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is Map<String, Object?>) {
        return LedgerData.fromJson(decoded);
      }
      if (decoded is Map) {
        return LedgerData.fromJson(Map<String, Object?>.from(decoded));
      }
    } on FormatException {
      return LedgerData.empty();
    }

    return LedgerData.empty();
  }

  Future<void> save(LedgerData data) async {
    await (await _prefs).setString(_storageKey, jsonEncode(data.toJson()));
  }
}
