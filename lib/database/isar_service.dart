// database/isar_service.dart
// Singleton Isar instance - NO encryption key (we encrypt manually)

import 'dart:io';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'schemas.dart';

class IsarService {
  static final IsarService _instance = IsarService._internal();
  factory IsarService() => _instance;
  IsarService._internal();

  Isar? _isar;

  /// In-flight open shared by every concurrent caller. Replaces the old
  /// 10 ms `Future.delayed` polling loop: `_AuthGate.build` creates a fresh
  /// `hasAnyVault()` future on every rebuild, and each duplicate caller used
  /// to spin its own polling timer — one armed in the final frame before
  /// teardown stays pending forever ("A Timer is still pending"), and a
  /// failed open used to spin those timers for the lifetime of the process.
  /// Awaiting one shared future needs no timers at all.
  Future<Isar>? _opening;

  Future<Isar> get instance async {
    if (_isar != null) return _isar!;
    return _opening ??= _open();
  }

  Future<Isar> _open() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _isar = await Isar.open(
        [VaultSchema, SecureItemSchema, BurnerHashSchema],
        directory: dir.path,
        // NO encryptionKey - we handle encryption manually at item level
      );
      return _isar!;
    } finally {
      // Success: `_isar` is set. Failure: clear the shared future so the
      // next caller can retry instead of being handed a permanently
      // failed one.
      _opening = null;
    }
  }

  Future<void> close() async {
    await _isar?.close();
    _isar = null;
    _opening = null;
  }

  /// V-009: deletes the database FILES — closing first so an open handle can
  /// never resurrect deleted content, and so page slack dies with the file
  /// (row-level `clear()` leaves it behind). The next [instance] access
  /// recreates an empty database. Only `.isar`/`.isar.lock` files are
  /// removed; everything else in the app documents dir is untouched.
  Future<void> wipeDatabaseFiles() async {
    await close();
    final dir = await getApplicationDocumentsDirectory();
    try {
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (name.endsWith('.isar') || name.endsWith('.isar.lock')) {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  Future<void> deleteDatabase() => wipeDatabaseFiles();
}
