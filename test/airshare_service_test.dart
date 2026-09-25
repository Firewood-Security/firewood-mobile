import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import '../lib/services/airshare_service.dart';

void main() {
  late AirShareService service;

  setUp(() {
    service = AirShareService();
  });

  test('AirShare generates and parses Spark URI correctly', () async {
    final keyPair = await service.generateKeyPair();
    final pk = await keyPair.extractPublicKey();
    final nonce = service.generateNonce(12);

    final uri = service.createSparkUri(
      publicKey: pk,
      nonce: nonce,
      deviceName: 'Redmi-Mobile',
    );

    expect(uri.startsWith('firewood://spark?'), isTrue);
    expect(uri.contains('name=Redmi-Mobile'), isTrue);

    final parsed = service.parseSparkUri(uri);
    expect(parsed.deviceName, equals('Redmi-Mobile'));
    expect(parsed.nonce, equals(nonce));
    expect(parsed.publicKey.bytes, equals(pk.bytes));
  });

  test('AirShare generates identical 4-digit Flame Code across peers', () async {
    final aliceKp = await service.generateKeyPair();
    final alicePk = await aliceKp.extractPublicKey();

    final bobKp = await service.generateKeyPair();
    final bobPk = await bobKp.extractPublicKey();

    final nonce = service.generateNonce(12);

    final aliceSecret = await service.computeSharedSecret(
      localKeyPair: aliceKp,
      remotePublicKey: bobPk,
    );

    final bobSecret = await service.computeSharedSecret(
      localKeyPair: bobKp,
      remotePublicKey: alicePk,
    );

    final aliceCode = await service.deriveFlameCode(
      sharedSecret: aliceSecret,
      salt: nonce,
    );

    final bobCode = await service.deriveFlameCode(
      sharedSecret: bobSecret,
      salt: nonce,
    );

    expect(aliceCode, equals(bobCode));
    expect(aliceCode.length, equals(4));
    expect(int.tryParse(aliceCode), isNotNull);
  });

  test('AirShare payload encryption and decryption in volatile RAM', () async {
    final aliceKp = await service.generateKeyPair();
    final bobKp = await service.generateKeyPair();
    final bobPk = await bobKp.extractPublicKey();

    final nonce = service.generateNonce(12);
    final secret = await service.computeSharedSecret(
      localKeyPair: aliceKp,
      remotePublicKey: bobPk,
    );
    final sessionKey = await service.deriveSessionKey(
      sharedSecret: secret,
      salt: nonce,
    );

    const originalPayload = AirSharePayload(
      kind: AirShareKind.credential,
      title: 'Mobile Secure Item',
      data: {
        'username': 'alice@firewood.internal',
        'password': 'VaultSecure2026!Password',
      },
      rawBytes: [],
    );

    final encrypted = await service.encryptPayload(
      payload: originalPayload,
      sessionKey: sessionKey,
    );

    expect(encrypted.isNotEmpty, isTrue);

    final decrypted = await service.decryptPayload(
      encryptedBytes: encrypted,
      sessionKey: sessionKey,
    );

    expect(decrypted.title, equals('Mobile Secure Item'));
    expect(decrypted.data['username'], equals('alice@firewood.internal'));
    expect(decrypted.data['password'], equals('VaultSecure2026!Password'));
  });
}
