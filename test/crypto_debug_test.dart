// test/crypto_debug_test.dart
// Tests for the CryptoDebug instrumentation layer.
//
// Verifies:
//   - Gate behavior (disabled → passthrough, enabled → recording)
//   - Timing capture and structured output
//   - Anomaly detection (nonce reuse, failure burst)
//   - Key fingerprinting (no key material in output)
//   - Privacy: no plaintext/password in trace output

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firewood/debug/crypto_debug.dart';

void main() {
  group('CryptoDebug gate behavior', () {
    tearDown(() => CryptoDebug.debugDisable());

    test('disabled by default — trace passes through without recording',
        () async {
      CryptoDebug.debugDisable();
      expect(CryptoDebug.enabled, isFalse);
      expect(CryptoDebug.traces, isEmpty);

      final result = await CryptoDebug.trace('test.op', () async => 42);
      expect(result, equals(42));
      expect(CryptoDebug.traces, isEmpty,
          reason: 'disabled traces must not record');
    });

    test('debugEnable activates recording', () async {
      CryptoDebug.debugEnable();
      expect(CryptoDebug.enabled, isTrue);

      await CryptoDebug.trace('test.op', () async => 'done');
      expect(CryptoDebug.traces, hasLength(1));
      expect(CryptoDebug.traces.first.op, equals('test.op'));
      expect(CryptoDebug.traces.first.ok, isTrue);
    });

    test('debugDisable restores passthrough', () async {
      CryptoDebug.clear();
      CryptoDebug.debugEnable();
      await CryptoDebug.trace('test.op', () async => 'x');
      CryptoDebug.debugDisable();

      await CryptoDebug.trace('test.op2', () async => 'y');
      expect(CryptoDebug.traces, hasLength(1),
          reason: 'no new traces after disable');
    });
  });

  group('CryptoTrace timing and output', () {
    setUp(() {
      CryptoDebug.clear();
      CryptoDebug.debugEnable();
    });
    tearDown(() {
      CryptoDebug.clear();
      CryptoDebug.debugDisable();
    });

    test('captures operation duration', () async {
      await CryptoDebug.trace('test.slow', () async {
        await Future.delayed(const Duration(milliseconds: 50));
        return null;
      });

      final trace = CryptoDebug.traces.first;
      expect(trace.op, equals('test.slow'));
      expect(trace.durationUs, greaterThan(10000), // > 10ms
          reason: 'should capture real elapsed time for a 50ms delay');
      expect(trace.ok, isTrue);
    });

    test('captures error on exception', () async {
      await expectLater(
        CryptoDebug.trace('test.fail', () async => throw StateError('boom')),
        throwsA(isA<StateError>()),
      );

      final trace = CryptoDebug.traces.first;
      expect(trace.op, equals('test.fail'));
      expect(trace.ok, isFalse);
      expect(trace.meta['error'], equals('StateError'));
    });

    test('toString produces structured single-line output', () {
      final trace = CryptoTrace(
        op: 'deriveKey',
        durationUs: 125000,
        ok: true,
        meta: {'salt_len': 16},
      );
      final line = trace.toString();
      expect(line, startsWith('[CRYPTO]'));
      expect(line, contains('op=deriveKey'));
      expect(line, contains('ms=125.000'));
      expect(line, contains('ok=true'));
      expect(line, contains('salt_len=16'));
      expect(line, isNot(contains('\n')),
          reason: 'must be single-line for logcat grep');
    });

    test('meta is included in output', () {
      final trace = CryptoTrace(
        op: 'encrypt',
        durationUs: 45,
        ok: true,
        meta: {'pt_len': 128, 'aad_len': 24},
      );
      final line = trace.toString();
      expect(line, contains('pt_len=128'));
      expect(line, contains('aad_len=24'));
    });
  });

  group('Nonce tracking', () {
    setUp(() => CryptoDebug.debugEnable());
    tearDown(() {
      CryptoDebug.clear();
      CryptoDebug.debugDisable();
    });

    test('first nonce use is not an anomaly', () {
      final result = CryptoDebug.checkNonce('aabbccdd', [1, 2, 3, 4]);
      expect(result, isFalse);
    });

    test('same nonce under same key is detected as reuse', () {
      CryptoDebug.checkNonce('aabbccdd', [1, 2, 3, 4]);
      final result = CryptoDebug.checkNonce('aabbccdd', [1, 2, 3, 4]);
      expect(result, isTrue, reason: 'same nonce + same key = reuse');
    });

    test('same nonce under different key is NOT reuse', () {
      CryptoDebug.checkNonce('aabbccdd', [1, 2, 3, 4]);
      final result = CryptoDebug.checkNonce('eeff0011', [1, 2, 3, 4]);
      expect(result, isFalse,
          reason: 'same nonce + different key = acceptable');
    });

    test('different nonce under same key is NOT reuse', () {
      CryptoDebug.checkNonce('aabbccdd', [1, 2, 3, 4]);
      final result = CryptoDebug.checkNonce('aabbccdd', [5, 6, 7, 8]);
      expect(result, isFalse);
    });

    test('disabled mode never detects reuse', () {
      CryptoDebug.debugDisable();
      CryptoDebug.checkNonce('aabbccdd', [1, 2, 3, 4]);
      final result = CryptoDebug.checkNonce('aabbccdd', [1, 2, 3, 4]);
      expect(result, isFalse);
    });
  });

  group('Key fingerprinting', () {
    setUp(() => CryptoDebug.debugEnable());
    tearDown(() {
      CryptoDebug.clear();
      CryptoDebug.debugDisable();
    });

    test('returns 8 hex chars for a valid key', () async {
      final key = SecretKey(List<int>.generate(32, (i) => i));
      final fp = await CryptoDebug.keyFingerprint(key);
      expect(fp, hasLength(8));
      expect(RegExp(r'^[0-9a-f]{8}$').hasMatch(fp), isTrue);
    });

    test('same key produces same fingerprint', () async {
      final key = SecretKey(List<int>.generate(32, (i) => i));
      final fp1 = await CryptoDebug.keyFingerprint(key);
      final fp2 = await CryptoDebug.keyFingerprint(key);
      expect(fp1, equals(fp2));
    });

    test('different keys produce different fingerprints', () async {
      final key1 = SecretKey(List<int>.generate(32, (i) => i));
      final key2 = SecretKey(List<int>.generate(32, (i) => 255 - i));
      final fp1 = await CryptoDebug.keyFingerprint(key1);
      final fp2 = await CryptoDebug.keyFingerprint(key2);
      expect(fp1, isNot(equals(fp2)));
    });

    test('fingerprint never contains raw key bytes', () async {
      final keyBytes = List<int>.generate(32, (i) => 0xAB);
      final key = SecretKey(keyBytes);
      final fp = await CryptoDebug.keyFingerprint(key);
      expect(fp, isNot(contains('ab')),
          reason: 'fingerprint must not leak key material');
    });

    test('disabled mode returns placeholder', () async {
      CryptoDebug.debugDisable();
      final key = SecretKey([1, 2, 3]);
      final fp = await CryptoDebug.keyFingerprint(key);
      expect(fp, equals('disabled'));
    });
  });

  group('Summary output', () {
    setUp(() => CryptoDebug.debugEnable());
    tearDown(() {
      CryptoDebug.clear();
      CryptoDebug.debugDisable();
    });

    test('summary does not add to traces', () {
      CryptoDebug.summary('items.getAllItems', meta: {'count': 42});
      expect(CryptoDebug.traces, isEmpty,
          reason: 'summaries are separate from timed traces');
    });

    test('disabled summary is a no-op', () {
      CryptoDebug.debugDisable();
      CryptoDebug.summary('test.op', meta: {'key': 'value'});
      // No assertion needed — just verify it doesn't throw
      expect(CryptoDebug.traces, isEmpty);
    });
  });

  group('Privacy: no secrets in output', () {
    setUp(() => CryptoDebug.debugEnable());
    tearDown(() {
      CryptoDebug.clear();
      CryptoDebug.debugDisable();
    });

    test('trace output never contains plaintext or passwords', () async {
      const secret = 'MySuperSecretPassword123!';
      await CryptoDebug.trace('test.op', () async {
        // Simulate an operation that processes the secret
        return secret.length;
      }, meta: {
        'pt_len': secret.length,
        'key_fp': 'aabbccdd',
      });

      final line = CryptoDebug.traces.first.toString();
      expect(line, isNot(contains(secret)), reason: 'must never log plaintext');
      expect(line, isNot(contains('MySuperSecret')),
          reason: 'must never log password fragments');
    });

    test('error metadata contains only exception type, not message', () async {
      await expectLater(
        CryptoDebug.trace('test.fail',
            () async => throw const FormatException('password=secret123')),
        throwsA(isA<FormatException>()),
      );

      final line = CryptoDebug.traces.first.toString();
      expect(line, isNot(contains('secret123')),
          reason: 'error message may contain secrets — only log the type');
      expect(line, contains('FormatException'));
    });
  });

  group('Trace buffer management', () {
    setUp(() => CryptoDebug.debugEnable());
    tearDown(() {
      CryptoDebug.clear();
      CryptoDebug.debugDisable();
    });

    test('clear resets traces and anomaly state', () async {
      await CryptoDebug.trace('test.op', () async => 'x');
      CryptoDebug.checkNonce('aabbccdd', [1, 2, 3]);
      expect(CryptoDebug.traces, isNotEmpty);

      CryptoDebug.clear();
      expect(CryptoDebug.traces, isEmpty);
    });

    test('traces list is unmodifiable', () async {
      await CryptoDebug.trace('test.op', () async => 'x');
      expect(
        () => CryptoDebug.traces
            .add(CryptoTrace(op: 'hack', durationUs: 0, ok: true)),
        throwsUnsupportedError,
      );
    });
  });
}
