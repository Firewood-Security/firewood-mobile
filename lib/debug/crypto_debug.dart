// debug/crypto_debug.dart
// Hardware-level crypto flow instrumentation for wireless debugging sessions.
//
// TRIPLE GATE — never active in production:
//   1. kDebugMode          — compile-time; tree-shaken in release builds
//   2. CRYPTO_METRICS      — --dart-define=CRYPTO_METRICS=true (opt-in)
//   3. _runtimeEnabled     — set at startup after a native wireless-debug check
//
// OUTPUT: structured single-line records to debugPrint → adb logcat.
//   [CRYPTO]       op=deriveKey  ms=125.0  fp=a1b2c3d4  ok=true
//   [CRYPTO-ANOM]  nonce_reuse   fp=a1b2c3d4  nonce=0102…
//   [CRYPTO-HEAP]  op=unlock     rssΔ=+12MB  rss=180MB
//
// PRIVACY: never logs plaintext, passwords, or key bytes. Only timing,
// sizes, SHA-256 key fingerprints (8 hex chars), and nonces (non-secret).

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

/// A single recorded crypto operation.
class CryptoTrace {
  final String op;
  final int durationUs;
  final bool ok;
  final Map<String, dynamic> meta;
  final DateTime timestamp;

  CryptoTrace({
    required this.op,
    required this.durationUs,
    required this.ok,
    this.meta = const {},
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  double get durationMs => durationUs / 1000.0;

  @override
  String toString() {
    final buf = StringBuffer(
        '[CRYPTO] op=$op ms=${durationMs.toStringAsFixed(3)} ok=$ok');
    meta.forEach((k, v) => buf.write(' $k=$v'));
    return buf.toString();
  }
}

/// Debug-only crypto flow metrics collector.
///
/// Usage:
/// ```dart
/// final result = await CryptoDebug.trace('deriveKey', () async {
///   return _argon2.deriveKeyFromPassword(...);
/// }, meta: {'salt_len': salt.length});
/// ```
class CryptoDebug {
  CryptoDebug._();

  // ── Gates ──────────────────────────────────────────────────────────────

  static const bool _buildFlag =
      bool.fromEnvironment('CRYPTO_METRICS', defaultValue: false);

  static bool _runtimeEnabled = false;

  /// Test-only override that bypasses all gates.
  static bool _testOverride = false;

  /// True only when ALL gates pass (or test override is active).
  static bool get enabled =>
      _testOverride || (kDebugMode && _buildFlag && _runtimeEnabled);

  /// Called once at startup after the native wireless-debug check.
  static void setRuntimeEnabled(bool value) {
    _runtimeEnabled = value;
    if (value && kDebugMode && _buildFlag) {
      debugPrint('[CRYPTO-INIT] metrics enabled (wireless debugging detected)');
    }
  }

  /// Test-only: force-enable metrics regardless of gates.
  static void debugEnable() {
    _testOverride = true;
    _runtimeEnabled = true;
  }

  /// Test-only: restore gate behavior.
  static void debugDisable() {
    _testOverride = false;
    _runtimeEnabled = false;
  }

  // ── Recording ──────────────────────────────────────────────────────────

  static final List<CryptoTrace> _traces = [];
  static const int _maxTraces = 500;
  static final Queue<CryptoTrace> _recent = Queue();

  /// All recorded traces (bounded).
  static List<CryptoTrace> get traces => List.unmodifiable(_recent);

  /// Clears the trace buffer.
  static void clear() {
    _recent.clear();
    _traces.clear();
    _nonceSeen.clear();
    _failureStreak = 0;
  }

  // ── Anomaly detection state ────────────────────────────────────────────

  static final Set<String> _nonceSeen = <String>{};
  static const int _maxNonces = 10000;
  static int _failureStreak = 0;
  static const int _failureBurstThreshold = 5;
  static const int _slowKdfThresholdUs = 2000000; // 2 seconds
  static const int _slowAeadThresholdUs = 100000; // 100 ms

  // ── Timing wrapper ─────────────────────────────────────────────────────

  /// Wraps [fn] with timing, anomaly detection, and structured logging.
  static Future<T> trace<T>(
    String op,
    Future<T> Function() fn, {
    Map<String, dynamic> meta = const {},
  }) async {
    if (!enabled) return fn();

    final sw = Stopwatch()..start();
    final rssBefore = _rss();
    try {
      final result = await fn();
      sw.stop();
      final rssAfter = _rss();

      final traceMeta = <String, dynamic>{...meta};
      if (rssBefore > 0 && rssAfter > 0) {
        final delta = rssAfter - rssBefore;
        traceMeta['rss_delta_mb'] = (delta / 1048576).toStringAsFixed(1);
        traceMeta['rss_mb'] = (rssAfter / 1048576).toStringAsFixed(0);
      }

      _record(CryptoTrace(
        op: op,
        durationUs: sw.elapsedMicroseconds,
        ok: true,
        meta: traceMeta,
      ));

      // Anomaly: slow KDF
      if (op.contains('deriveKey') || op.contains('argon')) {
        if (sw.elapsedMicroseconds > _slowKdfThresholdUs) {
          _anomaly('slow_kdf', {
            'op': op,
            'ms': (sw.elapsedMicroseconds / 1000).toStringAsFixed(0),
            'threshold_ms': (_slowKdfThresholdUs / 1000).toStringAsFixed(0),
          });
        }
      }

      // Anomaly: slow AEAD
      if (op.contains('encrypt') || op.contains('decrypt')) {
        if (sw.elapsedMicroseconds > _slowAeadThresholdUs) {
          _anomaly('slow_aead', {
            'op': op,
            'ms': (sw.elapsedMicroseconds / 1000).toStringAsFixed(1),
          });
        }
      }

      _failureStreak = 0;
      return result;
    } catch (e) {
      sw.stop();
      final rssAfter = _rss();
      final traceMeta = <String, dynamic>{
        ...meta,
        'error': e.runtimeType.toString(),
      };
      if (rssBefore > 0 && rssAfter > 0) {
        traceMeta['rss_delta_mb'] =
            ((rssAfter - rssBefore) / 1048576).toStringAsFixed(1);
      }

      _record(CryptoTrace(
        op: op,
        durationUs: sw.elapsedMicroseconds,
        ok: false,
        meta: traceMeta,
      ));

      // Anomaly: decryption failure burst (possible brute force or corruption)
      if (op.contains('decrypt') ||
          op.contains('unlock') ||
          op.contains('verify')) {
        _failureStreak++;
        if (_failureStreak >= _failureBurstThreshold) {
          _anomaly('failure_burst', {
            'streak': _failureStreak,
            'op': op,
            'error': e.runtimeType.toString(),
          });
        }
      }

      rethrow;
    }
  }

  // ── Nonce tracking ─────────────────────────────────────────────────────

  /// Checks for nonce reuse under the same key fingerprint.
  /// Returns true if this nonce was seen before (anomaly).
  static bool checkNonce(String keyFp, List<int> nonce) {
    if (!enabled) return false;
    final id = '$keyFp:${base64Encode(nonce)}';
    if (_nonceSeen.contains(id)) {
      _anomaly('nonce_reuse', {'fp': keyFp, 'nonce': _hex(nonce)});
      return true;
    }
    if (_nonceSeen.length >= _maxNonces) _nonceSeen.clear();
    _nonceSeen.add(id);
    return false;
  }

  // ── Key fingerprinting ─────────────────────────────────────────────────

  /// SHA-256 fingerprint of key bytes, truncated to 8 hex chars.
  /// NEVER logs the key itself — only a non-reversible identifier.
  static Future<String> keyFingerprint(SecretKey key) async {
    if (!enabled) return 'disabled';
    try {
      final bytes = await key.extractBytes();
      final hash = await Sha256().hash(bytes);
      return _hex(hash.bytes.sublist(0, 4));
    } catch (_) {
      return 'unknown';
    }
  }

  // ── Bulk operation summaries ───────────────────────────────────────────

  /// Logs a summary for bulk operations (e.g., getAllItems).
  static void summary(String op, {Map<String, dynamic> meta = const {}}) {
    if (!enabled) return;
    final buf = StringBuffer('[CRYPTO-SUMMARY] op=$op');
    meta.forEach((k, v) => buf.write(' $k=$v'));
    debugPrint(buf.toString());
  }

  // ── Internal ───────────────────────────────────────────────────────────

  static void _record(CryptoTrace t) {
    if (_recent.length >= _maxTraces) _recent.removeFirst();
    _recent.addLast(t);
    debugPrint(t.toString());
  }

  static void _anomaly(String type, Map<String, dynamic> meta) {
    final buf = StringBuffer('[CRYPTO-ANOM] type=$type');
    meta.forEach((k, v) => buf.write(' $k=$v'));
    debugPrint(buf.toString());
  }

  static int _rss() {
    try {
      return ProcessInfo.currentRss;
    } catch (_) {
      return 0;
    }
  }

  static String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
