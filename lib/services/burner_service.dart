// services/burner_service.dart
// Burner (panic) password management for multi-vault Firewood.

import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import '../database/isar_service.dart';
import '../database/schemas.dart';
import 'vault_service.dart';

class BurnerService {
  final IsarService _isarService = IsarService();
  final VaultService _vaultService = VaultService();

  /// Legacy static salt (F-019). Retained ONLY as a verification fallback for
  /// rows created before ADR-006 (salt == null). Never use for new hashes.
  @visibleForTesting
  static final List<int> legacyStaticSalt =
      List<int>.generate(16, (i) => (i * 7 + 3) % 256);

  static List<int> _newSalt() {
    final r = Random.secure();
    return List<int>.generate(16, (_) => r.nextInt(256));
  }

  Future<String> _hashWithSalt(String password, List<int> salt) async {
    final argon2 = Argon2id(memory: 65536, iterations: 3, parallelism: 4, hashLength: 32);
    final hash = await argon2.deriveKeyFromPassword(password: password, nonce: salt);
    return base64Encode(await hash.extractBytes());
  }

  /// Minimum aligned with the master-password policy (ADR-006): a duress code
  /// must not be weaker than the password it destroys.
  Future<bool> addBurnerPassword(String password, {String label = 'Burner Code'}) async {
    if (password.length < 8) throw BurnerException('Burner password must be at least 8 characters');

    final isar = await _isarService.instance;
    final salt = _newSalt();
    final hashBase64 = await _hashWithSalt(password, salt);

    // Check duplicate (in-memory filter)
    final all = await isar.burnerHashs.where().findAll();
    if (all.any((b) => b.passwordHash == hashBase64)) {
      throw BurnerException('This burner password is already registered');
    }

    final burner = BurnerHash()
      ..passwordHash = hashBase64
      ..salt = salt
      ..label = label
      ..createdAt = DateTime.now();
    await isar.writeTxn(() async => isar.burnerHashs.put(burner));
    return true;
  }

  Future<bool> isBurnerPassword(String password) async {
    final isar = await _isarService.instance;
    final burners = await isar.burnerHashs.where().findAll();
    if (burners.isEmpty) return false;

    for (final b in burners) {
      // New rows: per-entry salt. Legacy rows (salt == null/empty): static
      // fallback until replaced (ADR-006 migration window).
      final saltsToTry = (b.salt != null && b.salt!.isNotEmpty)
          ? [b.salt!]
          : [legacyStaticSalt];
      for (final s in saltsToTry) {
        if (await _hashWithSalt(password, s) == b.passwordHash) return true;
      }
    }
    return false;
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
