// services/device_identity_service.dart
// Provides persistent unique device ID and customizable peer alias for P2P networking

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceIdentityService {
  static const String _keyDeviceId = 'device_id';
  static const String _keyPeerAlias = 'peer_alias';

  /// Get or create a persistent unique device ID for this participant
  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_keyDeviceId);
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = 'dev-${const Uuid().v4().substring(0, 8)}';
      await prefs.setString(_keyDeviceId, deviceId);
    }
    return deviceId;
  }

  /// Get the user-configured peer alias from Settings
  static Future<String> getDeviceAlias() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPeerAlias) ?? 'Firewood Device';
  }

  /// Save custom device peer alias
  static Future<void> setDeviceAlias(String alias) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPeerAlias, alias);
  }
}
