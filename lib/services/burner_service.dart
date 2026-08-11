// services/burner_service.dart
// Burner (panic) password management for multi-vault Firewood.

import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:isar/isar.dart';
import '../database/isar_service.dart';
import '../database/schemas.dart';
import 'vault_service.dart';

class BurnerService {
  final IsarService _isarService = IsarService();
  final VaultService _vaultService = VaultService();

  static final List<int> _burnerSalt = List<int>.generate(16, (i) => (i * 7 + 3) % 256);

  Future<bool> addBurnerPassword(String password, {String label = 'Burner Code'}) async {
    if (password.length < 6) throw BurnerException('Burner password must be at least 6 characters');

    final isar = await _isarService.instance;
    final argon2 = Argon2id(memory: 65536, iterations: 3, parallelism: 4, hashLength: 32);
    final hash = await argon2.deriveKeyFromPassword(password: password, nonce: _burnerSalt);
    final hashBase64 = base64Encode(await hash.extractBytes());

    // Check duplicate (in-memory filter)
    final all = await isar.burnerHashs.where().findAll();
    if (all.any((b) => b.passwordHash == hashBase64)) {
      throw BurnerException('This burner password is already registered');
    }

    final burner = BurnerHash()..passwordHash = hashBase64..label = label..createdAt = DateTime.now();
    await isar.writeTxn(() async => isar.burnerHashs.put(burner));
    return true;
  }

  Future<bool> isBurnerPassword(String password) async {
    final isar = await _isarService.instance;
    final burners = await isar.burnerHashs.where().findAll();
    if (burners.isEmpty) return false;

    final argon2 = Argon2id(memory: 65536, iterations: 3, parallelism: 4, hashLength: 32);
    final hash = await argon2.deriveKeyFromPassword(password: password, nonce: _burnerSalt);
    final hashBase64 = base64Encode(await hash.extractBytes());
    return burners.any((b) => b.passwordHash == hashBase64);
  }

  Future<bool> executeBurn() async {
    await _vaultService.burnAllVaults();
    return true;
  }

  Future<List<BurnerHash>> listBurners() async {
    final isar = await _isarService.instance;
    return isar.burnerHashs.where().findAll();
  }

  Future<void> removeBurner(int id) async {
    final isar = await _isarService.instance;
    await isar.writeTxn(() async {
      final item = await isar.burnerHashs.get(id);
      if (item != null) await isar.burnerHashs.delete(id);
    });
  }

  Future<void> removeAllBurners() async {
    final isar = await _isarService.instance;
    await isar.writeTxn(() async {
      final all = await isar.burnerHashs.where().findAll();
      await isar.burnerHashs.deleteAll(all.map((b) => b.id).toList());
    });
  }
}

class BurnerException implements Exception {
  final String message;
  BurnerException(this.message);
  @override
  String toString() => 'BurnerException: $message';
}
