// services/file_crypto_service.dart
// Encrypt/decrypt any single file (documents, images, audio, video) plus its
// metadata into a portable .firewood container, protected by the master
// password. The same Argon2id + XChaCha20-Poly1305 pipeline as vault items is
// used, so a .firewood file can be copied anywhere and opened later.
//
// Container layout: fileSalt (16 bytes) || nonce (24 bytes) || ciphertext+MAC
// Plaintext payload: UTF-8 JSON envelope { kind, version, metadata, data(base64) }
//
// The JSON envelope intentionally carries the metadata INSIDE the ciphertext so
// file names, mime types and checksums never touch the disk in the clear.

import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';

import '../security/crypto_service.dart';

/// Metadata that travels with an encrypted file.
class FirewoodFileMetadata {
  final String fileName;
  final String mimeType;
  final int size;
  final String sha256;
  final DateTime createdAt;

  const FirewoodFileMetadata({
    required this.fileName,
    required this.mimeType,
    required this.size,
    required this.sha256,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'fileName': fileName,
        'mimeType': mimeType,
        'size': size,
        'sha256': sha256,
        'createdAt': createdAt.toIso8601String(),
      };

  factory FirewoodFileMetadata.fromJson(Map<String, dynamic> json) {
    return FirewoodFileMetadata(
      fileName: json['fileName']?.toString() ?? 'unnamed',
      mimeType: json['mimeType']?.toString() ?? 'application/octet-stream',
      size: int.tryParse(json['size']?.toString() ?? '') ?? 0,
      sha256: json['sha256']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now().toUtc(),
    );
  }
}

/// A decrypted file and its metadata.
class FirewoodFileContent {
  final FirewoodFileMetadata metadata;
  final List<int> bytes;

  const FirewoodFileContent({required this.metadata, required this.bytes});
}

class FileCryptoService {
  static const String fileExtension = '.firewood';
  static const String _version = '1.0.0';
  static const String _kind = 'firewood-file';
  static const int _saltLength = 16; // Argon2id salt
  static const int _nonceLength = 24; // XChaCha20-Poly1305 nonce
  static const int _macLength = 16; // Poly1305 tag

  final CryptoService _crypto = CryptoService();

  /// Encrypts [bytes] + metadata into a `.firewood` file using [masterPassword].
  /// Returns the metadata and the path of the written container.
  Future<({FirewoodFileMetadata metadata, String path})> encryptFileToFirewood({
    required String masterPassword,
    required List<int> bytes,
    required String fileName,
    String mimeType = 'application/octet-stream',
    String? outputPath,
  }) async {
    if (masterPassword.isEmpty) {
      throw FileCryptoException('Master password is required');
    }
    if (bytes.isEmpty) {
      throw FileCryptoException('File is empty');
    }

    final sha256 = await _sha256Hex(bytes);
    final metadata = FirewoodFileMetadata(
      fileName: fileName,
      mimeType: mimeType,
      size: bytes.length,
      sha256: sha256,
      createdAt: DateTime.now().toUtc(),
    );

    final envelope = jsonEncode({
      'kind': _kind,
      'version': _version,
      'metadata': metadata.toJson(),
      'data': base64Encode(bytes),
    });
    final plaintext = utf8.encode(envelope);

    // Fresh salt + fresh nonce for every file. Never reuse either.
    final fileSalt = _crypto.generateSalt();
    final key = await _crypto.deriveKey(masterPassword, fileSalt);
    final encrypted = await _crypto.encrypt(plaintext, key);

    final output = <int>[
      ...fileSalt,
      ...encrypted.nonce,
      ...encrypted.ciphertext,
    ];

    final path = await _resolveOutputPath(outputPath, fileName);
    await File(path).writeAsBytes(output, flush: true);

    return (metadata: metadata, path: path);
  }

  /// Decrypts a `.firewood` file and verifies its metadata/checksum.
  Future<FirewoodFileContent> decryptFirewoodFile({
    required String masterPassword,
    required String path,
  }) async {
    final file = File(path);
    if (!await file.exists()) {
      throw FileCryptoException('File not found: $path');
    }

    final data = await file.readAsBytes();
    const minimum = _saltLength + _nonceLength + _macLength;
    if (data.length < minimum) {
      throw FileCryptoException('Invalid .firewood file: too small');
    }

    final salt = data.sublist(0, _saltLength);
    final nonce = data.sublist(_saltLength, _saltLength + _nonceLength);
    final ciphertext = data.sublist(_saltLength + _nonceLength);

    final key = await _crypto.deriveKey(masterPassword, salt);

    final List<int> plaintext;
    try {
      plaintext = await _crypto.decrypt(ciphertext, nonce, key);
    } catch (_) {
      throw FileCryptoException(
        'Incorrect password or corrupted .firewood file',
      );
    }

    final Map<String, dynamic> envelope;
    try {
      envelope = jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;
    } catch (_) {
      throw FileCryptoException('Corrupted .firewood file contents');
    }

    if (envelope['kind'] != _kind) {
      throw FileCryptoException(
        'Not a Firewood file container. Use vault import for backups.',
      );
    }

    final metadata = FirewoodFileMetadata.fromJson(
      Map<String, dynamic>.from(envelope['metadata'] as Map? ?? {}),
    );
    final bytes = base64Decode(envelope['data']?.toString() ?? '');

    // The whole payload is already authenticated by Poly1305; this extra
    // checksum also guards against a truncated/edited envelope.
    if (metadata.sha256.isNotEmpty) {
      final actual = await _sha256Hex(bytes);
      if (actual != metadata.sha256) {
        throw FileCryptoException('Integrity check failed (SHA-256 mismatch)');
      }
    }
    if (metadata.size != 0 && metadata.size != bytes.length) {
      throw FileCryptoException('Integrity check failed (size mismatch)');
    }

    return FirewoodFileContent(metadata: metadata, bytes: bytes);
  }

  /// Decrypts a `.firewood` file and writes the original bytes back out.
  /// Returns the path of the extracted file.
  Future<String> extractFirewoodFile({
    required String masterPassword,
    required String path,
    String? outputPath,
  }) async {
    final content = await decryptFirewoodFile(
      masterPassword: masterPassword,
      path: path,
    );
    final target = await _resolveExtractPath(outputPath, content.metadata.fileName);
    await File(target).writeAsBytes(content.bytes, flush: true);
    return target;
  }

  Future<String> _resolveOutputPath(String? outputPath, String fileName) async {
    if (outputPath != null && outputPath.isNotEmpty) {
      return outputPath.toLowerCase().endsWith(fileExtension)
          ? outputPath
          : '$outputPath$fileExtension';
    }
    final dir = await firewoodDirectory();
    final safe = _sanitize(fileName);
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    return '${dir.path}/$safe-$stamp$fileExtension';
  }

  Future<String> _resolveExtractPath(String? outputPath, String fileName) async {
    if (outputPath != null && outputPath.isNotEmpty) return outputPath;
    final dir = await firewoodDirectory();
    return '${dir.path}/${_sanitize(fileName)}';
  }

  String _sanitize(String name) {
    final clean = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return clean.isEmpty ? 'unnamed' : clean;
  }

  /// Public Downloads/Firewood folder, falling back to app documents.
  Future<Directory> firewoodDirectory() async {
    try {
      if (Platform.isAndroid) {
        final downloadDir = Directory('/storage/emulated/0/Download/Firewood');
        if (!await downloadDir.exists()) {
          await downloadDir.create(recursive: true);
        }
        return downloadDir;
      } else if (!Platform.isIOS) {
        final downloads = await getDownloadsDirectory();
        if (downloads != null) {
          final dir = Directory('${downloads.path}/Firewood');
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
          return dir;
        }
      }
    } catch (_) {}
    return await getApplicationDocumentsDirectory();
  }

  Future<String> _sha256Hex(List<int> bytes) async {
    final hash = await Sha256().hash(bytes);
    return hash.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}

class FileCryptoException implements Exception {
  final String message;
  FileCryptoException(this.message);
  @override
  String toString() => 'FileCryptoException: $message';
}
