// services/csv_import_service.dart
// Universal bulk CSV importer supporting Bitwarden, Chrome, Firefox, 1Password,
// LastPass, KeePass, and standard CSV formats into Firewood zero-knowledge vault.

import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme/app_feedback.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import 'lock_service.dart';
import 'bundle_service.dart';
import 'item_service.dart';

class ImportedCsvItem {
  final String title;
  final String type; // 'login', 'card', 'identity', 'note', 'developerSecret'
  final Map<String, dynamic> fields;

  const ImportedCsvItem({
    required this.title,
    required this.type,
    required this.fields,
  });
}

class CsvImportResult {
  final int totalCount;
  final int importedCount;
  final List<String> errors;

  const CsvImportResult({
    required this.totalCount,
    required this.importedCount,
    this.errors = const [],
  });

  bool get isSuccess => importedCount > 0 && errors.isEmpty;
}

class CsvImportService {
  final ItemService _itemService = ItemService();

  /// Parse a CSV text content into structured [ImportedCsvItem]s.
  /// If [targetBundle] is specified, all imported items receive this bundle assignment.
  List<ImportedCsvItem> parseCsv(String csvContent, {String? targetBundle}) {
    final rows = parseCsvRows(csvContent);
    if (rows.isEmpty) return const [];

    final firstRow = rows.first.map((c) => c.toLowerCase().trim()).toList();

    // Check if first row is a header
    final headerCandidates = [
      'title',
      'name',
      'url',
      'username',
      'user',
      'login',
      'password',
      'pass',
      'folder',
      'group',
      'notes',
      'account',
      'card',
      'secret'
    ];
    final bool hasHeader =
        firstRow.any((col) => headerCandidates.any((hc) => col.contains(hc)));

    List<String> header;
    List<List<String>> dataRows;

    if (hasHeader) {
      header = firstRow;
      dataRows = rows.skip(1).toList();
    } else {
      // Synthesize default header for headerless CSV: title, username, password, url, notes
      header = ['title', 'username', 'password', 'url', 'notes'];
      dataRows = rows;
    }

    final items = <ImportedCsvItem>[];

    for (final row in dataRows) {
      if (row.isEmpty || !row.any((c) => c.trim().isNotEmpty)) continue;

      final rowMap = <String, String>{};
      for (int c = 0; c < header.length && c < row.length; c++) {
        rowMap[header[c]] = row[c].trim();
      }

      final title =
          _findFirst(rowMap, ['title', 'name', 'item_name', 'account']) ??
              (row.isNotEmpty && row[0].trim().isNotEmpty
                  ? row[0].trim()
                  : 'Imported Credential');
      final username = _findFirst(rowMap, [
        'username',
        'login_username',
        'login name',
        'email',
        'user',
        'login'
      ]);
      final password =
          _findFirst(rowMap, ['password', 'login_password', 'secret', 'pass']);
      final url = _findFirst(rowMap, [
        'url',
        'login_uri',
        'website',
        'web site',
        'uri',
        'link',
        'formactionorigin'
      ]);
      final notes = _findFirst(rowMap,
          ['notes', 'note', 'comment', 'comments', 'extra', 'httprealm']);
      final totp =
          _findFirst(rowMap, ['totp', 'login_totp', 'otp', 'authenticator']);

      // Card specific
      final cardholder = _findFirst(rowMap, [
        'cardholder',
        'cardholder_name',
        'cardholder name',
        'name_on_card',
        'name on card'
      ]);
      final cardNumber = _findFirst(rowMap, [
        'card_number',
        'card number',
        'number',
        'credit_card',
        'credit card'
      ]);
      final expiry = _findFirst(rowMap,
          ['expiry', 'exp', 'expiration', 'exp_date', 'expiration date']);
      final cvv =
          _findFirst(rowMap, ['cvv', 'cvc', 'security_code', 'security code']);

      // Bundle from CSV column
      final csvBundle =
          _findFirst(rowMap, ['bundle', 'folder', 'grouping', 'group']);

      final rawType =
          _findFirst(rowMap, ['type', 'category'])?.toLowerCase() ?? '';

      String type = 'login';
      if (rawType.contains('card') || cardNumber != null) {
        type = 'card';
      } else if (rawType.contains('note') ||
          (password == null &&
              username == null &&
              notes != null &&
              notes.isNotEmpty)) {
        type = 'note';
      } else if (rawType.contains('identity')) {
        type = 'identity';
      } else if (rawType.contains('key') ||
          rawType.contains('api') ||
          rawType.contains('token')) {
        type = 'developerSecret';
      }

      final fields = <String, dynamic>{};
      if (username != null && username.isNotEmpty)
        fields['username'] = username;
      if (password != null && password.isNotEmpty)
        fields['password'] = password;
      if (url != null && url.isNotEmpty) fields['url'] = url;
      if (notes != null && notes.isNotEmpty) {
        fields['notes'] = notes;
        if (type == 'note') fields['content'] = notes;
      }
      if (totp != null && totp.isNotEmpty) fields['totp_secret'] = totp;

      if (cardholder != null && cardholder.isNotEmpty)
        fields['cardholder'] = cardholder;
      if (cardNumber != null && cardNumber.isNotEmpty) {
        fields['card_number'] = cardNumber;
        fields['number'] = cardNumber;
      }
      if (expiry != null && expiry.isNotEmpty) fields['expiry'] = expiry;
      if (cvv != null && cvv.isNotEmpty) fields['cvv'] = cvv;

      // Assign bundle: prioritize caller targetBundle, otherwise fallback to CSV folder tag
      if (targetBundle != null && targetBundle.trim().isNotEmpty) {
        fields['bundle'] = targetBundle.trim();
      } else if (csvBundle != null && csvBundle.trim().isNotEmpty) {
        fields['bundle'] = csvBundle.trim();
      }

      // Retain unmapped columns as custom fields
      final standardKeys = {
        'title',
        'name',
        'item_name',
        'account',
        'username',
        'login_username',
        'login name',
        'email',
        'user',
        'login',
        'password',
        'login_password',
        'secret',
        'pass',
        'url',
        'login_uri',
        'website',
        'web site',
        'uri',
        'link',
        'formactionorigin',
        'notes',
        'note',
        'comment',
        'comments',
        'extra',
        'httprealm',
        'totp',
        'login_totp',
        'otp',
        'authenticator',
        'cardholder',
        'cardholder_name',
        'cardholder name',
        'name_on_card',
        'name on card',
        'card_number',
        'card number',
        'number',
        'credit_card',
        'credit card',
        'expiry',
        'exp',
        'expiration',
        'exp_date',
        'expiration date',
        'cvv',
        'cvc',
        'security_code',
        'security code',
        'type',
        'folder',
        'category',
        'bundle',
        'grouping',
        'group',
      };

      rowMap.forEach((k, v) {
        if (!standardKeys.contains(k) && v.isNotEmpty) {
          fields[k] = v;
        }
      });

      items.add(ImportedCsvItem(
        title: title.isEmpty ? 'Imported Credential' : title,
        type: type,
        fields: fields,
      ));
    }

    return items;
  }

  /// Full-featured interactive file picker and bulk import pipeline.
  Future<CsvImportResult?> pickAndImportCsv({
    required BuildContext context,
    required SecretKey secretKey,
    String? targetBundle,
  }) async {
    // Hold the foreground-flow guard across the WHOLE pipeline — picker,
    // parse, confirmation and the encrypted writes — not just the picker:
    // the import itself generates no pointer events, so an idle timeout
    // armed by the confirm tap would otherwise fire mid-import and dump
    // the user back to the lock screen (LockService postpones foreground
    // idle locks while a flow is open; a real background exit still locks
    // through the bounded idle timer).
    LockService.beginForegroundFlow();
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );

      final path = picked?.files.single.path;
      if (path == null) return null;

      final file = File(path);
      if (!await file.exists()) {
        if (context.mounted) {
          AppToast.show(context,
              message: 'Selected file could not be found',
              type: ToastType.error);
        }
        return null;
      }

      final content = await file.readAsString();
      final items = parseCsv(content, targetBundle: targetBundle);

      if (items.isEmpty) {
        if (context.mounted) {
          AppToast.show(
            context,
            message: 'No valid credentials detected in the selected CSV',
            type: ToastType.error,
          );
        }
        return const CsvImportResult(totalCount: 0, importedCount: 0);
      }

      if (!context.mounted) return null;

      // Show confirmation dialog before importing
      final confirmed = await _showConfirmationDialog(
        context: context,
        fileName: picked!.files.single.name,
        items: items,
        targetBundle: targetBundle,
      );

      if (confirmed != true || !context.mounted) return null;

      // Execute bulk import with a progress dialog
      return await _executeImport(
        context: context,
        secretKey: secretKey,
        items: items,
        targetBundle: targetBundle,
      );
    } catch (e) {
      if (context.mounted) {
        AppToast.show(
          context,
          message: 'CSV import error: ${e.toString()}',
          type: ToastType.error,
        );
      }
      return null;
    } finally {
      LockService.endForegroundFlow();
    }
  }

  Future<bool?> _showConfirmationDialog({
    required BuildContext context,
    required String fileName,
    required List<ImportedCsvItem> items,
    String? targetBundle,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        final previewItems = items.take(4).toList();
        final hasBundle = targetBundle != null && targetBundle.isNotEmpty;

        return AlertDialog(
          backgroundColor: AppColors.surfaceZinc,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: AppColors.borderZinc.withValues(alpha: 0.6),
            ),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.orangeAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: AppIcon(
                  HugeIcons.strokeRoundedFileImport,
                  color: AppColors.orangeAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Confirm Bulk Import',
                  style: TextStyle(
                    color: AppColors.offWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Found ${items.length} credential${items.length == 1 ? '' : 's'} in "$fileName".',
                  style: const TextStyle(
                    color: AppColors.offWhite,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                if (hasBundle) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.cardZinc,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.borderZinc.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AppIcon(
                          HugeIcons.strokeRoundedFolder01,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Assigning all to bundle: $targetBundle',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text(
                  'PREVIEW OF DETECTED ITEMS:',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131317),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.borderZinc.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    children: [
                      ...previewItems.map((it) {
                        final user = it.fields['username']?.toString() ?? '';
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              AppIcon(
                                HugeIcons.strokeRoundedCheckmarkCircle02,
                                size: 14,
                                color: AppColors.orangeAccent,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  it.title,
                                  style: const TextStyle(
                                    color: AppColors.offWhite,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (user.isNotEmpty)
                                Text(
                                  user,
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        );
                      }),
                      if (items.length > previewItems.length) ...[
                        const Divider(color: AppColors.borderZinc, height: 12),
                        Text(
                          '+ ${items.length - previewItems.length} more items',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orangeAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Import ${items.length} Items',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<CsvImportResult> _executeImport({
    required BuildContext context,
    required SecretKey secretKey,
    required List<ImportedCsvItem> items,
    String? targetBundle,
  }) async {
    int imported = 0;
    final errors = <String>[];

    // Show a loading dialog
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppColors.surfaceZinc,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Row(
            children: [
              CircularProgressIndicator(color: AppColors.orangeAccent),
              const SizedBox(width: 20),
              const Expanded(
                child: Text(
                  'Encrypting & importing credentials…',
                  style: TextStyle(color: AppColors.offWhite, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      // Ensure target bundle is registered if assigned
      if (targetBundle != null && targetBundle.trim().isNotEmpty) {
        await BundleService.registerBundle(targetBundle.trim());
      }

      for (final it in items) {
        try {
          await _itemService.addItem(
            key: secretKey,
            type: it.type,
            title: it.title,
            fields: it.fields,
          );
          imported++;
        } catch (e) {
          errors.add('Failed "${it.title}": $e');
        }
      }
    } finally {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
      }
    }

    if (context.mounted) {
      HapticFeedback.lightImpact();
      AppToast.show(
        context,
        message:
            'Successfully imported $imported credential${imported == 1 ? '' : 's'}',
        type: ToastType.success,
      );
    }

    return CsvImportResult(
      totalCount: items.length,
      importedCount: imported,
      errors: errors,
    );
  }

  /// Parses CSV content character-by-character to correctly handle quotes,
  /// embedded commas, and escaped quotes.
  static List<List<String>> parseCsvRows(String content) {
    final rows = <List<String>>[];
    final currentRow = <String>[];
    final currentCell = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < content.length; i++) {
      final char = content[i];

      if (char == '"') {
        if (inQuotes && i + 1 < content.length && content[i + 1] == '"') {
          // Escaped quote ("")
          currentCell.write('"');
          i++; // Skip second quote
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        currentRow.add(currentCell.toString());
        currentCell.clear();
      } else if ((char == '\n' || char == '\r') && !inQuotes) {
        if (char == '\r' && i + 1 < content.length && content[i + 1] == '\n') {
          i++; // Skip \n in \r\n
        }
        currentRow.add(currentCell.toString());
        currentCell.clear();
        if (currentRow.any((c) => c.trim().isNotEmpty)) {
          rows.add(List.from(currentRow));
        }
        currentRow.clear();
      } else {
        currentCell.write(char);
      }
    }

    currentRow.add(currentCell.toString());
    if (currentRow.any((c) => c.trim().isNotEmpty)) {
      rows.add(currentRow);
    }

    return rows;
  }

  static String? _findFirst(Map<String, String> map, List<String> candidates) {
    for (final c in candidates) {
      if (map.containsKey(c) && map[c]!.isNotEmpty) {
        return map[c];
      }
    }
    return null;
  }
}
