// SHA-256 authenticity checks for downloaded release artifacts.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:firewood/services/update_service.dart';

void main() {
  group('UpdateService.verifySha256', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('fw_sha_');
    });

    tearDown(() async {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    });

    test('accepts a file whose digest matches', () async {
      final f = File('${dir.path}/artifact.apk');
      await f.writeAsString('hello');
      // sha256("hello")
      const expected =
          '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824';
      expect(await UpdateService.verifySha256(f.path, expected), isTrue);
      expect(await UpdateService.verifySha256(f.path, expected.toUpperCase()),
          isTrue);
    });

    test('rejects a wrong digest', () async {
      final f = File('${dir.path}/artifact.apk');
      await f.writeAsString('hello');
      const wrong =
          '0000000000000000000000000000000000000000000000000000000000000000';
      expect(await UpdateService.verifySha256(f.path, wrong), isFalse);
    });

    test('fails closed on missing file or empty expectation', () async {
      expect(await UpdateService.verifySha256('${dir.path}/nope.apk', 'abc'),
          isFalse);
      final f = File('${dir.path}/artifact.apk');
      await f.writeAsString('hello');
      expect(await UpdateService.verifySha256(f.path, '   '), isFalse);
    });
  });
}
