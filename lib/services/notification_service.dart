// services/notification_service.dart
// Offline notifications for security alerts, incomplete form reminders, app updates, and tips.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationAlertService {
  static const _channel = MethodChannel('com.firewood.vault_security');

  static const _prefEnabledKey = 'firewood_notifications_enabled';
  static const _prefThrottlePrefix = 'firewood_notif_throttle_';
  static const _prefTipLastKey = 'firewood_notif_last_tip_epoch';

  // Cooldown durations
  static const int _weakPasswordCooldownHours = 24;
  static const int _missingPasswordCooldownHours = 24;
  static const int _tipCooldownDays = 3;

  /// Check if notifications are globally enabled by the user (default: true)
  static Future<bool> isNotificationsEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefEnabledKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Global toggle to enable or stop all notifications
  static Future<void> setNotificationsEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefEnabledKey, enabled);
      if (!enabled) {
        await cancelAllNotifications();
      }
    } catch (e) {
      debugPrint('Failed to set notification preference: $e');
    }
  }

  /// Check if the OS granted notification permission
  static Future<bool> hasPermission() async {
    try {
      final res =
          await _channel.invokeMethod<bool>('hasNotificationPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Requests the Android 13+ POST_NOTIFICATIONS runtime permission and
  /// resolves with the user's actual answer to the system dialog. Without
  /// this the settings switch could only store an app-level pref while the
  /// OS silently blocked every alert (API 33+). Pre-13 there is no runtime
  /// permission — the OS master toggle is reported instead. Fails closed.
  static Future<bool> requestPermission() async {
    try {
      final res =
          await _channel.invokeMethod<bool>('requestNotificationPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Alert user about weak password on a credential (throttled)
  static Future<bool> notifyWeakPassword({
    required String itemTitle,
    required String reason,
  }) async {
    if (!await isNotificationsEnabled()) return false;

    final throttleKey =
        '$_prefThrottlePrefix' 'weak_${itemTitle.toLowerCase().trim()}';
    if (await _isThrottled(
        throttleKey, Duration(hours: _weakPasswordCooldownHours))) {
      return false;
    }

    final id = 1000 + (itemTitle.hashCode.abs() % 1000);
    final title = 'Security Alert: Weak Password';
    // V-020 (L-06): the item title is a credential identifier and never
    // appears in notification text — shade/lock screen are shared surfaces.
    // The tapped notification opens Firewood, where the credential is visible.
    final message =
        "A credential has a weak password ($reason). Open Firewood to generate a stronger passkey or password.";

    final ok = await _show(
        id: id, channelId: 'firewood_alerts', title: title, message: message);
    if (ok) {
      await _recordTimestamp(throttleKey);
    }
    return ok;
  }

  /// Alert user about an incomplete credential with no password ("finish the form") (throttled)
  static Future<bool> notifyMissingPassword({
    required String itemTitle,
  }) async {
    if (!await isNotificationsEnabled()) return false;

    final throttleKey =
        '$_prefThrottlePrefix' 'nopass_${itemTitle.toLowerCase().trim()}';
    if (await _isThrottled(
        throttleKey, Duration(hours: _missingPasswordCooldownHours))) {
      return false;
    }

    final id = 2000 + (itemTitle.hashCode.abs() % 1000);
    final title = 'Finish the Form: Password Missing';
    // V-020 (L-06): same rule as notifyWeakPassword — no credential title in
    // the text; itemTitle only feeds the throttle key and notification id.
    const message =
        "A credential is missing a password. Tap to open Firewood and finish the form.";

    final ok = await _show(
        id: id, channelId: 'firewood_alerts', title: title, message: message);
    if (ok) {
      await _recordTimestamp(throttleKey);
    }
    return ok;
  }

  /// Alert user about an available verified app update (once per version)
  static Future<bool> notifyAppUpdate({
    required String version,
  }) async {
    if (!await isNotificationsEnabled()) return false;

    final throttleKey = '$_prefThrottlePrefix' 'update_$version';
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(throttleKey) == true) {
      return false;
    }

    final id = 3001;
    final title = 'Firewood Update Available';
    final message =
        "Firewood v$version is ready to install with offline security enhancements.";

    final ok = await _show(
        id: id, channelId: 'firewood_updates', title: title, message: message);
    if (ok) {
      await prefs.setBool(throttleKey, true);
    }
    return ok;
  }

  /// Gentle rotating security tips (at most once every 3 days)
  static Future<bool> notifySecurityTip({
    required String tipText,
  }) async {
    if (!await isNotificationsEnabled()) return false;

    final prefs = await SharedPreferences.getInstance();
    final lastEpoch = prefs.getInt(_prefTipLastKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final minInterval = Duration(days: _tipCooldownDays).inMilliseconds;

    if (now - lastEpoch < minInterval) {
      return false;
    }

    final id = 4001;
    final title = 'Firewood Security Tip';
    final ok = await _show(
        id: id, channelId: 'firewood_alerts', title: title, message: tipText);
    if (ok) {
      await prefs.setInt(_prefTipLastKey, now);
    }
    return ok;
  }

  /// Cancel all active notifications
  static Future<void> cancelAllNotifications() async {
    try {
      await _channel.invokeMethod<bool>('cancelAllNotifications');
    } catch (_) {}
  }

  // --- Private Helpers ---

  static Future<bool> _show({
    required int id,
    required String channelId,
    required String title,
    required String message,
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('showNotification', {
        'id': id,
        'channelId': channelId,
        'title': title,
        'message': message,
      });
      return res ?? false;
    } catch (e) {
      debugPrint('Failed to show notification: $e');
      return false;
    }
  }

  static Future<bool> _isThrottled(String key, Duration cooldown) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastTime = prefs.getInt(key);
      if (lastTime == null) return false;
      final diff = DateTime.now().millisecondsSinceEpoch - lastTime;
      return diff < cooldown.inMilliseconds;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _recordTimestamp(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(key, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }
}
