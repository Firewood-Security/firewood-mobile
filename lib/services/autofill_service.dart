// services/autofill_service.dart
// Offline-only Autofill Service bridge for browser forms and app forms.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'item_service.dart';

class AutofillService {
  static const _channel = MethodChannel('com.firewood.vault_security');

  /// Check whether the Android OS supports the Autofill Framework (API 26+)
  static Future<bool> isSupported() async {
    try {
      final res = await _channel.invokeMethod<bool>('isAutofillSupported');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Check whether Firewood is actively selected as the Autofill Provider in Android Settings
  static Future<bool> isEnabled() async {
    try {
      final res = await _channel.invokeMethod<bool>('isAutofillEnabled');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Open the Android system Autofill service picker so the user can select Firewood
  static Future<bool> openSettings() async {
    try {
      final res = await _channel.invokeMethod<bool>('openAutofillSettings');
      return res ?? false;
    } catch (e) {
      debugPrint('Failed to open autofill settings: $e');
      return false;
    }
  }

  /// Securely syncs decrypted items into the local offline Keystore-encrypted store.
  /// 100% offline, zero network usage.
  static Future<void> syncDecryptedItems(List<DecryptedItem> items) async {
    try {
      final entries = <Map<String, dynamic>>[];
      for (final item in items) {
        final username = (item.fields['username'] ??
                item.fields['email'] ??
                item.fields['account'] ??
                '')
            .toString();
        final password =
            (item.fields['password'] ?? item.fields['pin'] ?? '').toString();
        final url =
            (item.fields['url'] ?? item.fields['website'] ?? '').toString();
        final bundle = (item.fields['bundle'] ?? '').toString();

        if (password.isNotEmpty || username.isNotEmpty) {
          entries.add({
            'id': item.itemId,
            'title': item.title,
            'username': username,
            'password': password,
            'url': url,
            'bundle': bundle.isNotEmpty ? bundle : null,
          });
        }
      }
      final jsonStr = jsonEncode(entries);
      await _channel.invokeMethod<bool>('syncAutofillStore', {'json': jsonStr});
    } catch (e) {
      debugPrint('Failed to sync autofill store: $e');
    }
  }

  /// Clears the local offline autofill store when vault locks or on demand
  static Future<void> clear() async {
    try {
      await _channel.invokeMethod<bool>('clearAutofillStore');
    } catch (_) {}
  }
}
