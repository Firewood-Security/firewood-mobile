// widgets/bundle_settings_sheet.dart
// Modal sheet for managing bundle settings, renaming, emptying, and deleting bundles
// Enforces security rule: Bundle must be completely empty before it can be deleted.

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../services/bundle_service.dart';
import '../services/csv_import_service.dart';
import '../services/item_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_icons.dart';
import '../theme/app_feedback.dart';

class BundleSettingsSheet extends StatefulWidget {
  final SecretKey secretKey;
  final String bundleName;
  final List<DecryptedItem> items;
  final ValueChanged<String>? onRenamed;
  final VoidCallback? onEmptied;
  final VoidCallback? onDeleted;

  const BundleSettingsSheet({
    super.key,
    required this.secretKey,
    required this.bundleName,
    required this.items,
    this.onRenamed,
    this.onEmptied,
    this.onDeleted,
  });

  static Future<void> show({
    required BuildContext context,
    required SecretKey secretKey,
    required String bundleName,
    required List<DecryptedItem> items,
    ValueChanged<String>? onRenamed,
    VoidCallback? onEmptied,
    VoidCallback? onDeleted,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BundleSettingsSheet(
        secretKey: secretKey,
        bundleName: bundleName,
        items: items,
        onRenamed: onRenamed,
        onEmptied: onEmptied,
        onDeleted: onDeleted,
      ),
    );
  }

  @override
  State<BundleSettingsSheet> createState() => _BundleSettingsSheetState();
}

class _BundleSettingsSheetState extends State<BundleSettingsSheet> {
  final ItemService _itemService = ItemService();
  late String _currentName;
  late List<DecryptedItem> _currentItems;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _currentName = widget.bundleName;
    _currentItems = List.from(widget.items);
  }

  Future<void> _renameBundle() async {
    final controller = TextEditingController(text: _currentName);
    final formKey = GlobalKey<FormState>();

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceZinc,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderZinc),
        ),
        title: Row(
          children: [
            AppIcon(
              HugeIcons.strokeRoundedEdit02,
              color: AppColors.orangeAccent,
              size: 20,
            ),
            const SizedBox(width: 10),
            const Text(
              'Rename Bundle',
              style: TextStyle(
                color: AppColors.offWhite,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter a new name for this credential bundle. All assigned items will be updated automatically.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: AppColors.offWhite, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Bundle Name',
                  prefixIcon: AppIcon(HugeIcons.strokeRoundedFolder01,
                      size: 18, color: AppColors.textMuted),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Bundle name cannot be empty';
                  }
                  if (val.trim().toLowerCase() == _currentName.toLowerCase()) {
                    return 'Enter a different name';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orangeAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: const Text('Save Name'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && mounted) {
      setState(() => _isProcessing = true);
      try {
        await BundleService.renameBundle(_currentName, newName);

        // Update all assigned items
        for (final item in _currentItems) {
          final updatedFields = Map<String, dynamic>.from(item.fields);
          updatedFields['bundle'] = newName;
          await _itemService.updateItem(
            key: widget.secretKey,
            itemId: item.itemId,
            newFields: updatedFields,
          );
        }

        if (mounted) {
          setState(() {
            _currentName = newName;
            _isProcessing = false;
          });
          widget.onRenamed?.call(newName);
          AppToast.show(
            context,
            message: 'Bundle renamed to "$newName"',
            type: ToastType.success,
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isProcessing = false);
          AppToast.show(
            context,
            message: 'Failed to rename bundle: $e',
            type: ToastType.error,
          );
        }
      }
    }
  }

  Future<void> _importCsv() async {
    HapticFeedback.lightImpact();
    final result = await CsvImportService().pickAndImportCsv(
      context: context,
      secretKey: widget.secretKey,
      targetBundle: _currentName,
    );
    if (result != null && result.importedCount > 0 && mounted) {
      Navigator.pop(context);
      widget.onRenamed?.call(_currentName);
    }
  }

  Future<void> _emptyBundle() async {
    final count = _currentItems.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceZinc,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderZinc),
        ),
        title: Row(
          children: [
            AppIcon(
              HugeIcons.strokeRoundedFolderMinus,
              color: AppColors.orangeAccent,
              size: 22,
            ),
            const SizedBox(width: 10),
            const Text(
              'Empty Bundle',
              style: TextStyle(
                color: AppColors.offWhite,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to unassign all $count credentials from "$_currentName"?\n\n'
          'The credentials will remain safe in your vault. Their bundle tag will be removed so this bundle becomes empty and eligible for deletion.',
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orangeAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Empty Bundle'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isProcessing = true);
      try {
        for (final item in _currentItems) {
          final updatedFields = Map<String, dynamic>.from(item.fields);
          updatedFields['bundle'] = '';
          await _itemService.updateItem(
            key: widget.secretKey,
            itemId: item.itemId,
            newFields: updatedFields,
          );
        }

        if (mounted) {
          setState(() {
            _currentItems.clear();
            _isProcessing = false;
          });
          widget.onEmptied?.call();
          AppToast.show(
            context,
            message: 'Bundle emptied ($count credentials unassigned)',
            type: ToastType.success,
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isProcessing = false);
          AppToast.show(
            context,
            message: 'Failed to empty bundle: $e',
            type: ToastType.error,
          );
        }
      }
    }
  }

  Future<void> _deleteBundle() async {
    // ENFORCE RULE: Bundle MUST be empty to delete
    if (_currentItems.isNotEmpty) {
      HapticFeedback.heavyImpact();
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceZinc,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.roseAccent),
          ),
          title: const Row(
            children: [
              AppIcon(
                HugeIcons.strokeRoundedAlert02,
                color: AppColors.roseAccent,
                size: 22,
              ),
              SizedBox(width: 10),
              Text(
                'Deletion Blocked',
                style: TextStyle(
                  color: AppColors.offWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            'Rule Violation: A bundle must be completely empty before it can be deleted.\n\n'
            'Bundle "$_currentName" currently contains ${_currentItems.length} credential(s).\n\n'
            'Please tap "Empty Bundle" to unassign them, or remove them manually first.',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surfaceZinc,
                foregroundColor: AppColors.offWhite,
                side: const BorderSide(color: AppColors.borderZinc),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Understood'),
            ),
          ],
        ),
      );
      return;
    }

    // Bundle is empty, proceed with deletion confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceZinc,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.roseAccent),
        ),
        title: const Row(
          children: [
            AppIcon(
              HugeIcons.strokeRoundedDelete02,
              color: AppColors.roseAccent,
              size: 22,
            ),
            SizedBox(width: 10),
            Text(
              'Delete Bundle',
              style: TextStyle(
                color: AppColors.offWhite,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete the empty bundle "$_currentName"?\n\n'
          'This action cannot be undone.',
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.roseAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isProcessing = true);
      try {
        await BundleService.deleteBundle(_currentName);
        if (mounted) {
          Navigator.pop(context); // Close sheet
          widget.onDeleted?.call();
          AppToast.show(
            context,
            message: 'Bundle "$_currentName" deleted successfully',
            type: ToastType.success,
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isProcessing = false);
          AppToast.show(
            context,
            message: 'Failed to delete bundle: $e',
            type: ToastType.error,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeAccent = Theme.of(context).colorScheme.primary;
    final isEmpty = _currentItems.isEmpty;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF14161D),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: AppColors.borderZinc, width: 1),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderZinc,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.offWhite,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'BUNDLE SETTINGS • ZERO-KNOWLEDGE ENCRYPTED',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const AppIcon(AppIcons.close,
                    color: AppColors.textMuted, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Status & Rule Info Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isEmpty
                  ? AppColors.mintAccent.withValues(alpha: 0.08)
                  : AppColors.orangeContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isEmpty
                    ? AppColors.mintAccent.withValues(alpha: 0.3)
                    : AppColors.orangeBorder,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppIcon(
                      isEmpty
                          ? HugeIcons.strokeRoundedCheckmarkCircle02
                          : HugeIcons.strokeRoundedInformationCircle,
                      size: 16,
                      color: isEmpty
                          ? AppColors.mintAccent
                          : AppColors.orangeAccent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isEmpty
                          ? 'STATUS: EMPTY BUNDLE (0 ITEMS)'
                          : 'STATUS: ACTIVE (${_currentItems.length} ITEMS)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: isEmpty
                            ? AppColors.mintAccent
                            : AppColors.orangeAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  isEmpty
                      ? 'This bundle is currently empty. It meets the deletion rule and can be safely deleted, or you can add new credentials to it.'
                      : 'Security Rule: A bundle must be empty (0 items) before it can be deleted. Use "Empty Bundle" below to unassign all credentials without deleting them.',
                  style: const TextStyle(
                    color: AppColors.offWhite,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_isProcessing)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            // Option 1: Bulk Import from CSV
            _SettingsTile(
              icon: HugeIcons.strokeRoundedFileImport,
              iconColor: AppColors.orangeAccent,
              title: 'Bulk Import from CSV',
              subtitle:
                  'Import credentials from a CSV file directly into "$_currentName"',
              onTap: _importCsv,
            ),
            const SizedBox(height: 8),

            // Option 2: Rename Bundle
            _SettingsTile(
              icon: HugeIcons.strokeRoundedEdit02,
              iconColor: activeAccent,
              title: 'Rename Bundle',
              subtitle: 'Change bundle name across all assigned credentials',
              onTap: _renameBundle,
            ),
            const SizedBox(height: 8),

            // Option 2: Empty Bundle (Unassign Items)
            if (!isEmpty) ...[
              _SettingsTile(
                icon: HugeIcons.strokeRoundedFolderMinus,
                iconColor: AppColors.orangeAccent,
                title: 'Empty Bundle',
                subtitle:
                    'Unassign ${_currentItems.length} items (credentials stay safe in vault)',
                onTap: _emptyBundle,
              ),
              const SizedBox(height: 8),
            ],

            // Option 3: Delete Bundle
            _SettingsTile(
              icon: isEmpty
                  ? HugeIcons.strokeRoundedDelete02
                  : HugeIcons.strokeRoundedLockKey,
              iconColor: isEmpty ? AppColors.roseAccent : AppColors.textMuted,
              title: 'Delete Bundle',
              subtitle: isEmpty
                  ? 'Permanently delete this empty bundle'
                  : 'Locked: Must be empty before deletion (Contains ${_currentItems.length} items)',
              isDestructive: isEmpty,
              onTap: _deleteBundle,
            ),
          ],
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final dynamic icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceZinc,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDestructive
              ? AppColors.roseAccent.withValues(alpha: 0.3)
              : AppColors.borderZinc.withValues(alpha: 0.6),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: AppIcon(icon, size: 18, color: iconColor),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isDestructive
                              ? AppColors.roseAccent
                              : AppColors.offWhite,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                AppIcon(
                  AppIcons.chevronRight,
                  size: 14,
                  color: isDestructive
                      ? AppColors.roseAccent
                      : AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
