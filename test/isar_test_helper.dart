// test/isar_test_helper.dart
// Portable Isar native-library resolver (REQ-TEST-01, DEBT-007).
//
// Replaces hardcoded developer-machine absolute paths to libisar.so.
// Resolution order:
//   1. FIREWOOD_ISAR_LIB environment variable (explicit override, CI-friendly).
//   2. Newest `isar_flutter_libs-*` entry under the pub cache
//      ($PUB_CACHE or $HOME/.pub-cache/hosted/pub.dev).
// Throws StateError with actionable guidance when nothing is found.

import 'dart:ffi';
import 'dart:io';
import 'package:isar/isar.dart';

Future<void> initIsarForTests() async {
  final override = Platform.environment['FIREWOOD_ISAR_LIB'];
  final candidates = <String>[
    if (override != null && override.isNotEmpty) override,
    ...await _pubCacheCandidates(),
  ];
  for (final path in candidates) {
    if (File(path).existsSync()) {
      await Isar.initializeIsarCore(libraries: {Abi.linuxX64: path});
      return;
    }
  }
  throw StateError(
    'libisar.so not found. Tried: ${candidates.isEmpty ? "<none>" : candidates.join(", ")}. '
    'Set FIREWOOD_ISAR_LIB to the absolute path of libisar.so from isar_flutter_libs.',
  );
}

Future<List<String>> _pubCacheCandidates() async {
  final env = Platform.environment;
  final pubCache = env['PUB_CACHE'] ??
      (env['HOME'] != null ? "${env['HOME']}/.pub-cache" : null);
  if (pubCache == null) return [];
  final hosted = Directory('$pubCache/hosted/pub.dev');
  if (!await hosted.exists()) return [];
  final hits = <String>[];
  await for (final entity in hosted.list()) {
    if (entity is Directory &&
        entity.path.split(Platform.pathSeparator).last.startsWith('isar_flutter_libs-')) {
      hits.add('${entity.path}/linux/libisar.so');
    }
  }
  hits.sort();
  return hits.reversed.toList(); // newest version first
}
