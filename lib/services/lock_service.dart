// services/lock_service.dart
// Auto-lock timer and secure clipboard management

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  // Clear clipboard after delay
  void scheduleClipboardClear() {
    _clipboardTimer?.cancel();
    _clipboardTimer = Timer(_clipboardClearDelay, () {
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