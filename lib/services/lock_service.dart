// services/lock_service.dart
// Auto-lock timer and secure clipboard management

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import 'native_security_bridge.dart';

const List<Duration> lockTimeoutOptions = [
  Duration(seconds: 30),
  Duration(minutes: 1),
  Duration(minutes: 5),
  Duration(minutes: 15),
  Duration(minutes: 30),
];

class LockService {
  /// Depth of app-initiated *foreground* system flows in progress — file
  /// pick/save dialogs, OS permission prompts, re-auth biometric prompts.
  /// While one is open the user has NOT left the app (the system UI simply
  /// took focus/top-resumed), so a pause arriving in that window must arm
  /// the idle timer instead of locking — otherwise every import/export/
  /// attach flow would dump the user back to the lock screen mid-action
  /// (the auth policy requires verification *entering* those flows, not a
  /// lock while performing them). Static because services without a
  /// Riverpod reference (backup/csv import) must be able to open a flow.
  static int _foregroundFlowDepth = 0;

  // Timestamp of the last endForegroundFlow() that closed the outermost
  // flow. The lifecycle `resumed` for a system flow is delivered AFTER the
  // flow's future completes (the picker result races the engine's resume
  // event), so a resume landing just after the flow closed must still be
  // treated as part of it — see the grace check in onAppResumed().
  static DateTime? _foregroundFlowEndedAt;

  // Grace window for those late flow resumes. Short and bounded: it only
  // skips the stale-pause clock check on the resume itself, never a pause.
  static const Duration _foregroundFlowGrace = Duration(seconds: 3);

  static void beginForegroundFlow() {
    _foregroundFlowDepth++;
    _foregroundFlowEndedAt = null;
  }

  static void endForegroundFlow() {
    if (_foregroundFlowDepth > 0) {
      _foregroundFlowDepth--;
      if (_foregroundFlowDepth == 0) {
        _foregroundFlowEndedAt = DateTime.now();
      }
    }
  }

  static bool get inForegroundFlow => _foregroundFlowDepth > 0;

  static const Duration _defaultLockTimeout = Duration(minutes: 5);
  static const Duration _clipboardClearDelay = Duration(seconds: 30);

  /// Default absolute session cap ("logged time exceeded" → logout).
  static const Duration defaultSessionTimeout = Duration(hours: 1);

  /// Choices offered by the Session Timeout settings picker.
  static const List<Duration> sessionTimeoutOptions = [
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(hours: 1),
    Duration(hours: 2),
    Duration(hours: 4),
  ];

  Timer? _lockTimer;
  Timer? _clipboardTimer;
  Duration _lockTimeout = _defaultLockTimeout;
  bool _isEnabled = true;

  // Absolute session cap: every unlock opens a fresh window of
  // [_sessionTimeout]; expiry logs out through the same idempotent lock
  // path as the idle timer ("logout when logged time exceeded").
  Timer? _sessionTimer;
  Duration _sessionTimeout = defaultSessionTimeout;

  // "Lock in Recent Apps" option (default ON — secure out of the box;
  // users who dislike locking on every app switch can turn it off): when
  // ON, leaving the foreground — recents tray, home, screen off, app
  // switch — locks immediately even before the auto-lock timeout, so the
  // tray can only ever show the lock screen. It only qualifies the
  // auto-lock-ON background path: with auto-lock OFF the exit always
  // locks (that setting's own contract), option or not.
  bool _lockOnBackground = true;

  // Timestamp of the last REAL background exit (paused/detached). Used only
  // by onAppResumed's staleness check — it is set on pause and cleared on
  // resume, so a later resume with no pause in between (a system overlay
  // dismissing, e.g. a biometric prompt) can never consult a stale timestamp
  // and lock spuriously.
  DateTime? _pausedAt;

  // Whether the app is currently in the background (set on pause, cleared on
  // resume). Tells apart "the user wandered off during a system flow" —
  // backgrounded, the bounded idle lock must still fire — from "import work
  // running untouched in the foreground behind an open flow", where the idle
  // timeout is postponed instead (see _onIdleTimeout).
  bool _backgrounded = false;

  // Called when the app actually leaves the foreground (paused/detached).
  // NOT called for transient `inactive` focus loss — see app.dart.
  void onAppPaused() {
    _backgrounded = true;
    _pausedAt = DateTime.now();
    if (_foregroundFlowDepth > 0) {
      // App-initiated system flow in progress (file picker, permission or
      // re-auth prompt): arm the idle timer — honoring the background-exit
      // contract's spirit — but do NOT lock, so the pending action can
      // complete. A pause longer than the timeout still locks via the
      // timer, so this is a bounded exemption, never an open window.
      _startLockTimer();
      return;
    }
    if (_lockOnBackground) {
      // "Lock in Recent Apps" ON: background exit locks at once — before
      // the idle timeout — so the recents tray never shows vault content.
      _triggerAutoLock();
      return;
    }
    // "Lock in Recent Apps" OFF (user setting): do NOT lock on background
    // exit. Respect the user's choice — the toggle is the single authority
    // for background locking. Auto-lock governs only the inactivity timer.
    if (_isEnabled) {
      _startLockTimer();
    }
    // Auto-lock OFF + recents OFF: no background lock, no idle timer.
    // The vault stays open until manual lock, session cap, or logout.
  }

  // Called when app becomes active (foregrounded)
  void onAppResumed() {
    final pausedAt = _pausedAt;
    _pausedAt = null;
    _backgrounded = false;
    // A resume belonging to a foreground flow — whether delivered while the
    // flow is still open or within the grace window after it closed (the
    // engine sends `resumed` after the picker future completes) — must never
    // consult the pause recorded when the flow opened: that pause was
    // synthetic (the system picker merely took focus), so judging it as a
    // real background exit would lock the vault right as an import finished
    // and dump the user back to the login screen. The flow's own pause is
    // still bounded: it armed the idle timer, and a backgrounded idle timer
    // fires normally in _onIdleTimeout.
    final flowEndedAt = _foregroundFlowEndedAt;
    if (_foregroundFlowDepth > 0 ||
        (flowEndedAt != null &&
            DateTime.now().difference(flowEndedAt) < _foregroundFlowGrace)) {
      cancelAutoLockTimer();
      return;
    }
    if (!_isEnabled) {
      // A foreground-flow pause arms the idle timer even when auto-lock is
      // OFF — cancel it now that the user is back, or it would fire while
      // they actively use the vault.
      cancelAutoLockTimer();
      return;
    }
    // Locked only if the app was backgrounded LONGER than the timeout.
    // No pause in between => nothing to judge (never lock on focus alone).
    if (pausedAt != null &&
        DateTime.now().difference(pausedAt) >= _lockTimeout) {
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
    _lockTimer = Timer(_lockTimeout, _onIdleTimeout);
  }

  void _resetLockTimer() {
    if (!_isEnabled) return;
    cancelAutoLockTimer();
    _lockTimer = Timer(_lockTimeout, _onIdleTimeout);
  }

  // Idle-timeout edge. Inside an app-initiated flow the app receives no
  // pointer events: a bulk CSV/vault import legitimately runs untouched
  // behind its progress dialog, so locking on schedule would dump the
  // in-progress action back to the lock screen (the reported
  // import-lands-on-login bug). While such a flow runs IN THE FOREGROUND
  // the timeout is postponed one window at a time instead. The exemption
  // stays bounded: a real background exit (app actually hidden — user
  // wandered off during the flow) still locks through here at the timeout,
  // and the absolute session cap locks unconditionally regardless.
  void _onIdleTimeout() {
    if (_foregroundFlowDepth > 0 && !_backgrounded) {
      _startLockTimer();
      return;
    }
    _triggerAutoLock();
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
  ///
  /// V-017: the clip is placed through the native wrapper so it is marked
  /// `EXTRA_IS_SENSITIVE` (masked in Android's clipboard preview). The plain
  /// Flutter path is only a fallback when the platform channel is unavailable
  /// (unit tests, hosts without the bridge) — TTL semantics are identical.
  Future<void> copySecret(String text, {Duration? ttl}) async {
    try {
      await NativeSecurityBridge.setClipboardText(text);
    } on MissingPluginException {
      await Clipboard.setData(ClipboardData(text: text));
    } on PlatformException {
      await Clipboard.setData(ClipboardData(text: text));
    }
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
  bool get lockOnBackground => _lockOnBackground;
  bool get hasActiveSession => _sessionTimer?.isActive ?? false;

  // --- Absolute session cap ("perform logout if logged time exceeded") ---

  /// Starts (or restarts) the session window — called on every unlock
  /// edge. Expiry fires the same idempotent auto-lock callback.
  void startSession() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer(_sessionTimeout, _triggerAutoLock);
  }

  /// Ends the session window — called on every lock/logout edge.
  void endSession() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
  }

  void setSessionTimeout(Duration timeout) {
    _sessionTimeout = timeout;
    // Apply a new cap to the session that is already running.
    if (hasActiveSession) startSession();
  }

  void setLockOnBackground(bool enabled) {
    _lockOnBackground = enabled;
  }

  // --- Persisted settings (REQ-SESS-01) ---
  // Only values from [lockTimeoutOptions] are honored on load; anything else
  // falls back to the default so corrupt/foreign prefs can never set
  // an absurd timeout (e.g., Duration.zero disabling lock silently).

  static const _kTimeoutKey = 'lock_timeout_seconds';
  static const _kEnabledKey = 'lock_enabled';
  static const _kSessionKey = 'session_timeout_minutes';
  static const _kLockOnBgKey = 'lock_on_background';

  static Future<
      ({
        Duration timeout,
        bool enabled,
        Duration session,
        bool lockOnBackground
      })> loadPersisted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final secs = prefs.getInt(_kTimeoutKey);
      final timeout =
          (secs != null && lockTimeoutOptions.any((d) => d.inSeconds == secs))
              ? Duration(seconds: secs)
              : _defaultLockTimeout;
      final enabled = prefs.getBool(_kEnabledKey) ?? true;
      // Same fail-safe rule as the idle timeout: only an offered option is
      // honored, anything else falls back to the 1h default.
      final sessionMins = prefs.getInt(_kSessionKey);
      final session = (sessionMins != null &&
              sessionTimeoutOptions.any((d) => d.inMinutes == sessionMins))
          ? Duration(minutes: sessionMins)
          : defaultSessionTimeout;
      final lockOnBackground = prefs.getBool(_kLockOnBgKey) ?? true;
      return (
        timeout: timeout,
        enabled: enabled,
        session: session,
        lockOnBackground: lockOnBackground,
      );
    } catch (_) {
      return (
        timeout: _defaultLockTimeout,
        enabled: true,
        session: defaultSessionTimeout,
        lockOnBackground: true,
      );
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

  static Future<void> persistSessionTimeout(Duration timeout) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kSessionKey, timeout.inMinutes);
    } catch (_) {}
  }

  static Future<void> persistLockOnBackground(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kLockOnBgKey, enabled);
    } catch (_) {}
  }

  void dispose() {
    cancelAutoLockTimer();
    _sessionTimer?.cancel();
    _clipboardTimer?.cancel();
  }
}

// Provider for LockService
final lockServiceProvider = Provider<LockService>((ref) {
  final service = LockService();
  // Set up auto-lock callback
  service.setAutoLockCallback(() {
    // Idempotent lock: one background exit fires several lifecycle events
    // and the timer can race a manual Lock Now — only the unlocked →
    // locked edge does work (app.dart resets the route stack on that edge).
    if (ref.read(authProvider) != null) {
      ref.read(authProvider.notifier).state = null;
    }
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

// Provider for the absolute session cap (persisted) — logout when the
// logged-in time exceeds it, regardless of activity.
final sessionTimeoutProvider =
    StateProvider<Duration>((ref) => LockService.defaultSessionTimeout);

// Provider for the lock-in-recents/background option (persisted) —
// leaving the foreground locks immediately when ON (default); OFF is
// the opt-out back to the auto-lock engine's own background behavior.
final lockOnBackgroundProvider = StateProvider<bool>((ref) => true);
