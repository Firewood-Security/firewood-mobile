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
  bool _isInitialized = false;

  Future<Isar> get instance async {
    if (_isar != null) return _isar!;
    if (_isInitialized) {
      // Wait for initialization if in progress
      while (_isar == null) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      return _isar!;
    }
    return _initialize();
  }

  Future<Isar> _initialize() async {
    _isInitialized = true;
    try {
      final dir = await getApplicationDocumentsDirectory();
      _isar = await Isar.open(
        [VaultSchema, SecureItemSchema, BurnerHashSchema],
        directory: dir.path,
        // NO encryptionKey - we handle encryption manually at item level
      );
      return _isar!;
    } catch (e) {
      _isInitialized = false;
      rethrow;
    }
  }

  Future<void> close() async {
    await _isar?.close();
    _isar = null;
    _isInitialized = false;
  }

  Future<void> deleteDatabase() async {
    await close();
    final dir = await getApplicationDocumentsDirectory();
    final dbFile = File('${dir.path}/isar');
    if (await dbFile.exists()) {
      await dbFile.delete();
    }
  }
}
