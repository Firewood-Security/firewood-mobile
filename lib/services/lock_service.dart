// services/lock_service.dart
// Auto-lock timer and secure clipboard management

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';

const List<Duration> lockTimeoutOptions = [
  Duration(seconds: 30),
  Duration(minutes: 1),
  Duration(minutes: 5),
  Duration(minutes: 15),
  Duration(minutes: 30),
];

class LockService {
  static const Duration _defaultLockTimeout = Duration(minutes: 5);
  static const Duration _clipboardClearDelay = Duration(seconds: 30);

  Timer? _lockTimer;
  Timer? _clipboardTimer;
  Duration _lockTimeout = _defaultLockTimeout;
  bool _isEnabled = true;
  DateTime? _lastActivity;

  // Called when app becomes inactive (backgrounded)
  void onAppPaused() {
    if (!_isEnabled) return;
    _lastActivity = DateTime.now();
    _startLockTimer();
  }

  // Called when app becomes active (foregrounded)
  void onAppResumed() {
    if (!_isEnabled) return;
    // Check elapsed time since last activity – if exceeded timeout, lock immediately
    if (_lastActivity != null &&
        DateTime.now().difference(_lastActivity!) >= _lockTimeout) {
      _triggerAutoLock();
      return;
    }
    cancelAutoLockTimer();
  }

  // Called when user interacts with the app
  void onUserInteraction() {
    if (!_isEnabled) return;
    _resetLockTimer();
  }

  void _startLockTimer() {
    cancelAutoLockTimer();
    _lockTimer = Timer(_lockTimeout, () {
      _triggerAutoLock();
    });
  }

  void _resetLockTimer() {
    if (!_isEnabled) return;
    cancelAutoLockTimer();
    _lockTimer = Timer(_lockTimeout, () {
      _triggerAutoLock();
    });
  }

  void cancelAutoLockTimer() {
    _lockTimer?.cancel();
    _lockTimer = null;
  }

  void _triggerAutoLock() {
    if (_onAutoLock != null) {
      _onAutoLock!();
    }
  }

  // Callback for auto-lock
  VoidCallback? _onAutoLock;
  void setAutoLockCallback(VoidCallback callback) {
    _onAutoLock = callback;
  }

  // Clear clipboard after delay (legacy entry point; prefer [copySecret]).
  void scheduleClipboardClear() {
    _clipboardTimer?.cancel();
    _clipboardTimer = Timer(_clipboardClearDelay, () {
      Clipboard.setData(const ClipboardData(text: ''));
    });
  }

  /// Canonical secret-copy path (REQ-CLIP-01): every copy of sensitive or
  /// user-copied text MUST go through this method so clipboard TTL is uniform.
  /// [ttl] defaults to 30 s; pass [Duration.zero] only for non-sensitive text
  /// with an explicit comment at the call site.
  Future<void> copySecret(String text, {Duration? ttl}) async {
    await Clipboard.setData(ClipboardData(text: text));
    _clipboardTimer?.cancel();
    _clipboardTimer = Timer(ttl ?? _clipboardClearDelay, () {
      Clipboard.setData(const ClipboardData(text: ''));
    });
  }

  void cancelClipboardClear() {
    _clipboardTimer?.cancel();
  }

  // Settings
  void setLockTimeout(Duration timeout) {
    _lockTimeout = timeout;
    _resetLockTimer();
  }

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!enabled) {
      cancelAutoLockTimer();
    } else {
      _resetLockTimer();
    }
  }

  Duration get lockTimeout => _lockTimeout;
  bool get isEnabled => _isEnabled;

  // --- Persisted settings (REQ-SESS-01) ---
  // Only values from [lockTimeoutOptions] are honored on load; anything else
  // falls back to the default so corrupt/foreign prefs can never set
  // an absurd timeout (e.g., Duration.zero disabling lock silently).

  static const _kTimeoutKey = 'lock_timeout_seconds';
  static const _kEnabledKey = 'lock_enabled';

  static Future<({Duration timeout, bool enabled})> loadPersisted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final secs = prefs.getInt(_kTimeoutKey);
      final timeout = (secs != null &&
              lockTimeoutOptions.any((d) => d.inSeconds == secs))
          ? Duration(seconds: secs)
          : _defaultLockTimeout;
      final enabled = prefs.getBool(_kEnabledKey) ?? true;
      return (timeout: timeout, enabled: enabled);
    } catch (_) {
      return (timeout: _defaultLockTimeout, enabled: true);
    }
  }

  static Future<void> persistTimeout(Duration timeout) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kTimeoutKey, timeout.inSeconds);
    } catch (_) {}
  }

  static Future<void> persistEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEnabledKey, enabled);
    } catch (_) {}
  }

  void dispose() {
    cancelAutoLockTimer();
    _clipboardTimer?.cancel();
  }
}

// Provider for LockService
final lockServiceProvider = Provider<LockService>((ref) {
  final service = LockService();
  // Set up auto-lock callback
  service.setAutoLockCallback(() {
    ref.read(authProvider.notifier).state = null;
  });
  ref.onDispose(() => service.dispose());
  return service;
});

// Provider for lock timeout setting (persisted)
final lockTimeoutProvider = StateProvider<Duration>((ref) {
  return const Duration(minutes: 5);
});

// Provider for auto-lock enabled setting
final autoLockEnabledProvider = StateProvider<bool>((ref) => true);