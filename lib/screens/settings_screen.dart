// screens/settings_screen.dart
// Settings for auto-lock, auto-backup schedule, device alias, security info, and backup import/export

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/update_service.dart';
import '../services/accent_color_service.dart';
import '../widgets/accent_color_picker_dialog.dart';

import '../providers/auth_provider.dart';
import '../services/backup_service.dart';
import '../services/item_service.dart';
import '../services/lock_service.dart';
import '../services/vault_service.dart';
import '../services/burner_service.dart';
import '../database/schemas.dart';
import '../services/native_security_bridge.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import 'about_screen.dart';
import '../services/app_version_service.dart';

// Providers for Backup & Profile settings
final autoBackupEnabledProvider = StateProvider<bool>((ref) => true);
final autoBackupIntervalDaysProvider = StateProvider<int>((ref) => 120); // Default 4 months


class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {

  bool _screenshotsAllowed = false;

  @override
  void initState() {
    super.initState();
    AccentColorService.currentColor.addListener(_onAccentColorChanged);
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) setState(() => _screenshotsAllowed = prefs.getBool('allow_screenshots') ?? false);
    });
  }

  void _onAccentColorChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _saveAutoBackup(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_backup_enabled', enabled);
    ref.read(autoBackupEnabledProvider.notifier).state = enabled;
  }

  Future<void> _saveBackupInterval(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('auto_backup_interval_days', days);
    ref.read(autoBackupIntervalDaysProvider.notifier).state = days;
  }

  @override
  void dispose() {
    AccentColorService.currentColor.removeListener(_onAccentColorChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final autoLockEnabled = ref.watch(autoLockEnabledProvider);
    final lockTimeout = ref.watch(lockTimeoutProvider);
    final lockService = ref.watch(lockServiceProvider);
    final biometricEnabled = ref.watch(biometricAuthEnabledProvider);

    final autoBackupEnabled = ref.watch(autoBackupEnabledProvider);
    final autoBackupInterval = ref.watch(autoBackupIntervalDaysProvider);
    final authKey = ref.watch(authProvider);

    return ValueListenableBuilder<Color>(
      valueListenable: AccentColorService.currentColor,
      builder: (context, accentColor, _) {
        return Scaffold(
          backgroundColor: AppColors.backgroundZinc,
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
            children: [

          // Appearance Section
          const _SectionHeader(title: 'APPEARANCE & ACCENT COLOR'),
          const _SettingsCard(
            children: [
              AccentColorPickerTile(),
            ],
          ),
          const SizedBox(height: 20),

          // Security Section
          const _SectionHeader(title: 'VAULT SECURITY & AUTO-LOCK'),
          _SettingsCard(
            children: [
              SwitchListTile(
                title: const Text('Biometric Vault Unlock', style: TextStyle(color: AppColors.offWhite, fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Unlock vault with fingerprint or face recognition', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                value: biometricEnabled,
                secondary: AppIcon(AppIcons.fingerprint, color: AppColors.orangeAccent, size: 24),
                activeColor: AppColors.orangeAccent,
                onChanged: (val) => _toggleBiometricAuth(context, ref, val),
              ),
              SwitchListTile(
                title: const Text('Auto-Lock Vault', style: TextStyle(color: AppColors.offWhite, fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Lock vault when idle or app backgrounded', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                value: autoLockEnabled,
                secondary: AppIcon(AppIcons.lockClock, color: AppColors.orangeAccent, size: 24),
                activeColor: AppColors.orangeAccent,
                onChanged: (val) {
                  ref.read(autoLockEnabledProvider.notifier).state = val;
                  LockService.persistEnabled(val);
                  if (!val) lockService.cancelAutoLockTimer();
                },
              ),
              if (autoLockEnabled)
                ListTile(
                  title: const Text('Auto-Lock Timeout', style: TextStyle(color: AppColors.offWhite, fontSize: 14)),
                  subtitle: Text(_formatDuration(lockTimeout), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  leading: AppIcon(AppIcons.timer, color: AppColors.orangeAccent, size: 24),
                  trailing: AppIcon(AppIcons.chevronRight, color: AppColors.textMuted, size: 20),
                  onTap: () => _showTimeoutPicker(context, ref),
                ),
              ListTile(
                title: const Text('Lock Vault Now', style: TextStyle(color: AppColors.offWhite, fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Immediately clear secret key from memory', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                leading: AppIcon(AppIcons.lock, color: AppColors.orangeAccent, size: 24),
                onTap: () => _lockNow(context, ref),
              ),
              SwitchListTile(
                title: const Text('Allow Screenshots', style: TextStyle(color: AppColors.offWhite, fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Disable to prevent screen capture in app switcher', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                value: _screenshotsAllowed,
                activeColor: AppColors.orangeAccent,
                secondary: AppIcon(_screenshotsAllowed ? AppIcons.eye : AppIcons.eyeOff, color: AppColors.orangeAccent, size: 24),
                onChanged: (val) async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('allow_screenshots', val);
                  if (val) {
                    await NativeSecurityBridge.disableSecureFlag();
                  } else {
                    await NativeSecurityBridge.enableSecureFlag();
                  }
                  setState(() => _screenshotsAllowed = val);
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Developer Secrets .env Exporter (Visible only when API keys / Dev secrets > 2)
          if (authKey != null)
            FutureBuilder<List<DecryptedItem>>(
              future: ItemService().getAllItems(authKey),
              builder: (context, snapshot) {
                final allItems = snapshot.data ?? [];
                final devSecrets = allItems.where((i) => i.type == 'developerSecret').toList();
                if (devSecrets.length <= 2) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeader(title: 'DEVELOPER TOOLS & API EXPORT'),
                    _SettingsCard(
                      children: [
                        ListTile(
                          title: const Text('Export API Keys as .env', style: TextStyle(color: AppColors.offWhite, fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text('Format and export ${devSecrets.length} developer secrets to a .env file', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          leading: AppIcon(AppIcons.typeDeveloperSecret, color: AppColors.orangeAccent, size: 24),
                          trailing: AppIcon(AppIcons.chevronRight, color: AppColors.textMuted, size: 20),
                          onTap: () => _showEnvExportDialog(context, devSecrets),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                );
              },
            ),

          // Burner Password Management
          const _SectionHeader(title: 'BURNER / DURESS PASSWORD'),
          _SettingsCard(
            children: [
              FutureBuilder<List<BurnerHash>>(
                future: BurnerService().listBurners(),
                builder: (context, snapshot) {
                  final burners = snapshot.data ?? [];
                  return Column(
                    children: [
                      if (burners.isEmpty)
                        const Padding(padding: EdgeInsets.all(16), child: Text('No burner passwords configured. Add one for emergency vault destruction.', style: TextStyle(color: AppColors.textMuted, fontSize: 12))),
                      ...burners.map((b) => ListTile(
                        leading: AppIcon(AppIcons.fire, color: AppColors.roseAccent, size: 24),
                        title: Text(b.label, style: const TextStyle(color: AppColors.offWhite, fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text('Created ${DateTime.now().difference(b.createdAt).inDays}d ago', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        trailing: IconButton(
                          icon: AppIcon(AppIcons.delete, color: AppColors.roseAccent, size: 18),
                          onPressed: () async { await BurnerService().removeBurner(b.id); if (mounted) setState(() {}); },
                        ),
                      )),
                      ListTile(
                        leading: AppIcon(AppIcons.add, color: AppColors.roseAccent, size: 24),
                        title: const Text('Add Burner Password', style: TextStyle(color: AppColors.roseAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text('Entering this password on unlock destroys ALL vaults', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        onTap: () => _addBurnerPasswordDialog(context),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Automatic Scheduled Backup Section
          const _SectionHeader(title: 'AUTOMATED BACKUP & RECOVERY'),
          _SettingsCard(
            children: [
              SwitchListTile(
                title: const Text('Scheduled Auto-Backup', style: TextStyle(color: AppColors.offWhite, fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Save encrypted backups to /Firewood/downloads', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                value: autoBackupEnabled,
                secondary: AppIcon(AppIcons.cloudUpload, color: AppColors.orangeAccent, size: 24),
                activeColor: AppColors.orangeAccent,
                onChanged: (val) => _saveAutoBackup(val),
              ),
              if (autoBackupEnabled)
                ListTile(
                  title: const Text('Backup Frequency', style: TextStyle(color: AppColors.offWhite, fontSize: 14)),
                  subtitle: Text(_formatIntervalLabel(autoBackupInterval), style: TextStyle(fontSize: 11, color: AppColors.orangeAccent)),
                  leading: AppIcon(AppIcons.timer, color: AppColors.orangeAccent, size: 24),
                  trailing: AppIcon(AppIcons.chevronRight, color: AppColors.textMuted, size: 20),
                  onTap: () => _showBackupIntervalPicker(context),
                ),
              ListTile(
                title: const Text('Export Encrypted Vault Backup', style: TextStyle(color: AppColors.offWhite, fontSize: 14)),
                subtitle: const Text('Save .firewood encrypted file to Downloads', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                leading: AppIcon(AppIcons.download, color: AppColors.orangeAccent, size: 24),
                onTap: () => _exportVault(context, ref),
              ),
              ListTile(
                title: const Text('Import Vault Backup File', style: TextStyle(color: AppColors.offWhite, fontSize: 14)),
                subtitle: const Text('Restore database from .firewood file', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                leading: AppIcon(AppIcons.upload, color: AppColors.orangeAccent, size: 24),
                onTap: () => _importVault(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // App Info & Updates
          const _SectionHeader(title: 'APP INFO & UPDATES'),
          _SettingsCard(
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: UpdateService.hasUpdateAvailable,
                builder: (context, hasUpdate, _) {
                  return ListTile(
                    title: Row(
                      children: [
                        const Text('Check for Updates', style: TextStyle(color: AppColors.offWhite, fontWeight: FontWeight.bold, fontSize: 14)),
                        if (hasUpdate) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      hasUpdate ? 'New update available!' : 'Check if a newer version of Firewood is available',
                      style: TextStyle(fontSize: 11, color: hasUpdate ? AppColors.orangeAccent : AppColors.textMuted),
                    ),
                    leading: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        AppIcon(AppIcons.refresh, color: AppColors.orangeAccent, size: 24),
                        if (hasUpdate)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    trailing: AppIcon(AppIcons.chevronRight, color: AppColors.textMuted, size: 20),
                    onTap: () => _checkForUpdates(context),
                  );
                },
              ),
              ListTile(
                title: const Text('About Firewood & Developers', style: TextStyle(color: AppColors.offWhite, fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('App specs, zero-knowledge architecture & developer info', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                leading: AppIcon(AppIcons.info, color: AppColors.orangeAccent, size: 24),
                trailing: AppIcon(AppIcons.chevronRight, color: AppColors.textMuted, size: 20),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AboutScreen()),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Danger Zone
          const _SectionHeader(title: 'DANGER ZONE'),
          _SettingsCard(
            children: [
              ListTile(
                title: const Text('Delete Vault Data', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Permanently wipe local database and reset vault', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                leading: AppIcon(AppIcons.trash, color: Colors.redAccent, size: 24),
                onTap: () => _confirmDeleteVault(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 32),

          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipOval(
                  child: Image.asset(
                    'assets/FWS.png',
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Firewood ${AppVersionService.fullVersionString}\nZero-Knowledge Password Vault',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
      },
    );
  }



  String _formatDuration(Duration d) {
    if (d.inMinutes < 60) {
      return '${d.inMinutes} minute${d.inMinutes == 1 ? '' : 's'}';
    } else {
      final hours = d.inHours;
      final mins = d.inMinutes % 60;
      return '${hours}h ${mins}m';
    }
  }

  String _formatIntervalLabel(int days) {
    switch (days) {
      case 120: return 'Every 4 Months (Default)';
      case 30: return 'Every Month';
      case 15: return 'Every 15 Days';
      case 7: return 'Every Week';
      case 3: return 'Every 3 Days';
      default: return 'Every $days Days';
    }
  }

  void _showTimeoutPicker(BuildContext context, WidgetRef ref) {
    final currentTimeout = ref.read(lockTimeoutProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceZinc,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Auto-Lock Timeout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.offWhite)),
            const SizedBox(height: 12),
            ...lockTimeoutOptions.map(
              (option) => RadioListTile<Duration>(
                title: Text(_formatDuration(option), style: const TextStyle(color: AppColors.offWhite)),
                value: option,
                groupValue: currentTimeout,
                activeColor: AppColors.orangeAccent,
                onChanged: (val) {
                  if (val != null) {
                    ref.read(lockTimeoutProvider.notifier).state = val;
                    LockService.persistTimeout(val);
                    Navigator.pop(context);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBackupIntervalPicker(BuildContext context) {
    final currentDays = ref.read(autoBackupIntervalDaysProvider);

    const intervals = [
      MapEntry(120, 'Every 4 Months (Default)'),
      MapEntry(30, 'Every Month'),
      MapEntry(15, 'Every 15 Days'),
      MapEntry(7, 'Every Week'),
      MapEntry(3, 'Every 3 Days'),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceZinc,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Backup Frequency', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.offWhite)),
            const SizedBox(height: 12),
            ...intervals.map(
              (entry) => RadioListTile<int>(
                title: Text(entry.value, style: const TextStyle(color: AppColors.offWhite)),
                value: entry.key,
                groupValue: currentDays,
                activeColor: AppColors.orangeAccent,
                onChanged: (val) {
                  if (val != null) {
                    _saveBackupInterval(val);
                    Navigator.pop(context);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _lockNow(BuildContext context, WidgetRef ref) {
    ref.read(authProvider.notifier).state = null;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _requestStoragePermission() async {
    try {
      if (Platform.isAndroid) {
        final storageStatus = await Permission.storage.status;
        if (!storageStatus.isGranted) {
          await Permission.storage.request();
        }
        final manageStatus = await Permission.manageExternalStorage.status;
        if (!manageStatus.isGranted && !manageStatus.isRestricted) {
          await Permission.manageExternalStorage.request();
        }
      }
    } catch (_) {}
  }

  void _exportVault(BuildContext context, WidgetRef ref) async {
    await _requestStoragePermission();
    if (!context.mounted) return;

    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceZinc,
        title: const Text('Master Password', style: TextStyle(color: AppColors.offWhite, fontSize: 16)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: passwordController,
            obscureText: true,
            style: const TextStyle(color: AppColors.offWhite),
            decoration: const InputDecoration(
              labelText: 'Master Password',
              hintText: 'Enter to encrypt export backup file',
            ),
            validator: (v) => v == null || v.isEmpty ? 'Password required' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, passwordController.text);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.orangeAccent, foregroundColor: Colors.white),
            child: const Text('Export'),
          ),
        ],
      ),
    );

    if (password == null || !context.mounted) return;

    try {
      final backupService = BackupService();
      final filePath = await backupService.exportVault(password, null);
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.surfaceZinc,
            title: Row(
              children: [
                AppIcon(AppIcons.checkCircle, color: Colors.greenAccent, size: 24),
                const SizedBox(width: 10),
                const Text('Backup Exported', style: TextStyle(color: AppColors.offWhite, fontSize: 16)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Vault saved to /Firewood/downloads:', style: TextStyle(color: AppColors.offWhite, fontSize: 12)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.cardZinc,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderZinc),
                  ),
                  child: SelectableText(
                    filePath,
                    style: TextStyle(fontFamily: 'Monospace', fontSize: 11, color: AppColors.orangeAccent),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                onPressed: () {
                  // File path is not classified SECRET, but routing through the
                  // canonical helper keeps clipboard TTL uniform (REQ-CLIP-01).
                  ref.read(lockServiceProvider).copySecret(filePath);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Path copied to clipboard')),
                  );
                },
                icon: AppIcon(AppIcons.copy, size: 16, color: AppColors.orangeAccent),
                label: Text('Copy Path', style: TextStyle(color: AppColors.orangeAccent)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.orangeAccent, foregroundColor: Colors.white),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // --- Developer Secrets .env Exporter Dialog ---

  void _showEnvExportDialog(BuildContext context, List<DecryptedItem> devSecrets) {
    final selectedItemIds = devSecrets.map((d) => d.itemId).toSet();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceZinc,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            String generateEnvText() {
              final sb = StringBuffer();
              sb.writeln('# ----------------------------------------');
              sb.writeln('# Firewood Vault — Exported API Keys & Secrets');
              sb.writeln('# Generated: ${DateTime.now().toIso8601String()}');
              sb.writeln('# ----------------------------------------\n');

              for (final secret in devSecrets) {
                if (!selectedItemIds.contains(secret.itemId)) continue;
                final cleanTitle = secret.title
                    .trim()
                    .toUpperCase()
                    .replaceAll(RegExp(r'[^A-Z0-9_]'), '_');

                sb.writeln('# Item: ${secret.title}');
                final fields = Map<String, dynamic>.from(secret.fields);
                fields.removeWhere((k, _) {
                  final lk = k.toLowerCase().replaceAll('_', '');
                  return lk == 'createdat' || lk == 'updatedat' || lk == 'timestamp';
                });

                if (fields.isEmpty) {
                  sb.writeln('${cleanTitle}=""\n');
                  continue;
                }

                for (final entry in fields.entries) {
                  final k = entry.key.trim();
                  final v = entry.value.toString().trim();
                  final cleanKey = k.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9_]'), '_');
                  
                  // If key already contains title prefix, avoid stutter (e.g. STRIPE_STRIPE_KEY)
                  final envKey = cleanKey.startsWith(cleanTitle)
                      ? cleanKey
                      : '${cleanTitle}_$cleanKey';

                  // Escape quotes
                  final escapedVal = v.replaceAll('"', '\\"');
                  sb.writeln('$envKey="$escapedVal"');
                }
                sb.writeln();
              }
              return sb.toString().trim();
            }

            final envContent = generateEnvText();

            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.borderZinc,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          AppIcon(AppIcons.typeDeveloperSecret, color: AppColors.orangeAccent, size: 24),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Export API Keys (.env)',
                              style: TextStyle(
                                color: AppColors.offWhite,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            '${selectedItemIds.length}/${devSecrets.length} Selected',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Select the developer secrets and API credentials to package into standard .env format.',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.roseContainer,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.roseBorder),
                        ),
                        child: const Text(
                          'Warning: the exported file contains live secrets in PLAINTEXT (classification: SECRET-in-plaintext, D-09). Anyone with the file has the keys. Store it securely and delete it when done.',
                          style: TextStyle(color: AppColors.roseOnContainer, fontSize: 11, height: 1.4),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Selection List
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.cardZinc,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.borderZinc),
                        ),
                        child: Column(
                          children: devSecrets.map((item) {
                            final isSelected = selectedItemIds.contains(item.itemId);
                            return CheckboxListTile(
                              value: isSelected,
                              title: Text(item.title, style: const TextStyle(color: AppColors.offWhite, fontWeight: FontWeight.w600, fontSize: 13)),
                              subtitle: Text('${item.fields.length} attributes', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                              secondary: AppIcon(AppIcons.key, color: isSelected ? AppColors.orangeAccent : AppColors.textMuted, size: 18),
                              activeColor: AppColors.orangeAccent,
                              checkColor: Colors.white,
                              onChanged: (val) {
                                setModalState(() {
                                  if (val == true) {
                                    selectedItemIds.add(item.itemId);
                                  } else {
                                    selectedItemIds.remove(item.itemId);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Preview
                      const Text(
                        '.ENV PREVIEW',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        height: 160,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderZinc),
                        ),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            envContent.isEmpty ? '# No items selected' : envContent,
                            style: const TextStyle(
                              fontFamily: 'Monospace',
                              fontSize: 11,
                              color: Colors.greenAccent,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: envContent.isEmpty
                                  ? null
                                  : () {
                                      ref.read(lockServiceProvider).copySecret(envContent);
                                      HapticFeedback.selectionClick();
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              AppIcon(AppIcons.checkCircle, color: Colors.greenAccent, size: 18),
                                              const SizedBox(width: 8),
                                              const Text('.env content copied to clipboard (clears in 30s)'),
                                            ],
                                          ),
                                          backgroundColor: AppColors.surfaceZinc,
                                        ),
                                      );
                                    },
                              icon: AppIcon(AppIcons.copy, size: 18, color: AppColors.orangeAccent),
                              label: const Text('Copy .env', style: TextStyle(color: AppColors.offWhite, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: const BorderSide(color: AppColors.borderZinc),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: envContent.isEmpty
                                  ? null
                                  : () async {
                                      await _requestStoragePermission();
                                      try {
                                        final dir = Directory('/storage/emulated/0/Download/Firewood');
                                        if (!await dir.exists()) {
                                          await dir.create(recursive: true);
                                        }
                                        final now = DateTime.now().millisecondsSinceEpoch;
                                        final file = File('${dir.path}/firewood_secrets_$now.env');
                                        await file.writeAsString(envContent);
                                        HapticFeedback.heavyImpact();
                                        if (ctx.mounted) Navigator.pop(ctx);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Saved to ${file.path}'),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.redAccent),
                                          );
                                        }
                                      }
                                    },
                              icon: AppIcon(AppIcons.download, size: 18),
                              label: const Text('Save File', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _toggleBiometricAuth(BuildContext context, WidgetRef ref, bool enable) async {
    if (!enable) {
      await ref.read(biometricAuthEnabledProvider.notifier).setEnabled(false);
      return;
    }

    try {
      final localAuth = LocalAuthentication();
      final canCheck = await localAuth.canCheckBiometrics;
      final isDeviceSupported = await localAuth.isDeviceSupported();

      if (!canCheck && !isDeviceSupported) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Biometrics not available on this device')),
          );
        }
        return;
      }

      final authenticated = await localAuth.authenticate(
        localizedReason: 'Authenticate to enable biometric vault unlock',
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
      );

      if (!authenticated) return;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Biometric authentication failed: $e')),
        );
      }
      return;
    }

    if (!context.mounted) return;

    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceZinc,
        title: const Text('Confirm Master Password', style: TextStyle(color: AppColors.offWhite, fontSize: 16)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: passwordController,
            obscureText: true,
            style: const TextStyle(color: AppColors.offWhite),
            decoration: const InputDecoration(
              labelText: 'Master Password',
              hintText: 'Enter password to link with biometrics',
            ),
            validator: (v) => v == null || v.isEmpty ? 'Password required' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, passwordController.text);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.orangeAccent, foregroundColor: Colors.white),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (password == null || !context.mounted) return;

    try {
      await VaultService().unlock(password);
      // Canonical biometric path (ADR-003): Keystore wrapping only. Any
      // failure surfaces to the user — no silent raw-password fallback.
      await NativeSecurityBridge.createWrappingKey();
      final wrapped = await NativeSecurityBridge.wrapMasterPassword(password);
      if (!wrapped) {
        throw Exception('Keystore wrapping failed on this device');
      }
      // Migration complete: remove any legacy raw-password entry.
      try {
        await const FlutterSecureStorage().delete(key: 'biometric_master_password');
      } catch (_) {}
      await ref.read(biometricAuthEnabledProvider.notifier).setEnabled(true);
      if (context.mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric vault login enabled successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not enable biometric unlock (wrong password or unsupported device).'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _importVault(BuildContext context, WidgetRef ref) async {
    await _requestStoragePermission();
    if (!context.mounted) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['firewood', 'json'],
    );

    if (result == null || result.files.single.path == null || !context.mounted) return;
    final filePath = result.files.single.path!;

    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceZinc,
        title: const Text('Import Vault Backup', style: TextStyle(color: AppColors.offWhite, fontSize: 16)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter the master password used to encrypt this backup file:', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                style: const TextStyle(color: AppColors.offWhite),
                decoration: const InputDecoration(
                  labelText: 'Backup Password',
                  hintText: 'Enter password',
                ),
                validator: (v) => v == null || v.isEmpty ? 'Password required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, passwordController.text);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.orangeAccent, foregroundColor: Colors.white),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (password == null || !context.mounted) return;

    try {
      final currentKey = ref.read(authProvider);
      final backupService = BackupService();
      final vaultName = await backupService.importVault(
        filePath,
        password,
        overwrite: false,
        activeVaultKey: currentKey,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully imported vault: $vaultName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _checkForUpdates(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Checking for updates...')),
    );
    final updateInfo = await UpdateService().checkAppUpdate();
    if (!context.mounted) return;

    if (updateInfo.hasUpdate) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceZinc,
          title: Row(
            children: [
              AppIcon(AppIcons.sparkles, color: AppColors.orangeAccent, size: 24),
              const SizedBox(width: 8),
              const Text('Update Available', style: TextStyle(color: AppColors.offWhite)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Version ${updateInfo.version} is now available.', style: const TextStyle(color: AppColors.offWhite, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(updateInfo.releaseNotes, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Later', style: TextStyle(color: AppColors.textMuted)),
            ),
            if (updateInfo.downloadUrl.isNotEmpty)
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.orangeAccent, foregroundColor: Colors.white),
                child: const Text('Download'),
              ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Firewood is up to date (${AppVersionService.fullVersionString})'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _confirmDeleteVault(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceZinc,
        title: const Text('Delete Vault?', style: TextStyle(color: Colors.redAccent, fontSize: 16)),
        content: const Text('This will delete all local vault data permanently. Verification required.', style: TextStyle(color: AppColors.offWhite)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    final isBiometricEnabled = ref.read(biometricAuthEnabledProvider);
    bool verified = false;

    if (isBiometricEnabled) {
      try {
        final localAuth = LocalAuthentication();
        if (await localAuth.canCheckBiometrics && await localAuth.isDeviceSupported()) {
          verified = await localAuth.authenticate(
            localizedReason: 'Authenticate biometrically to authorize vault deletion',
            options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
          );
        }
      } catch (_) {}
    }

    if (!verified && context.mounted) {
      final passwordController = TextEditingController();
      final formKey = GlobalKey<FormState>();

      final password = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surfaceZinc,
          title: const Text('Verify Master Password', style: TextStyle(color: Colors.redAccent, fontSize: 16)),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: passwordController,
              obscureText: true,
              style: const TextStyle(color: AppColors.offWhite),
              decoration: const InputDecoration(
                labelText: 'Master Password',
                hintText: 'Enter password to confirm vault deletion',
              ),
              validator: (v) => v == null || v.isEmpty ? 'Password required' : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, passwordController.text);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              child: const Text('Confirm Delete'),
            ),
          ],
        ),
      );

      if (password != null) {
        try {
          await VaultService().unlock(password);
          verified = true;
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Incorrect master password. Vault deletion aborted.'), backgroundColor: Colors.redAccent),
            );
          }
          return;
        }
      }
    }

    if (!verified) return;

    await const FlutterSecureStorage().delete(key: 'biometric_master_password');
    await VaultService().burnAllVaults();
    ref.read(authProvider.notifier).state = null;

    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  // --- Burner Dialog ---

  void _addBurnerPasswordDialog(BuildContext context) {
    final pwCtrl = TextEditingController();
    final labelCtrl = TextEditingController(text: 'Burner Code');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceZinc,
        title: Row(children: [AppIcon(AppIcons.fire, color: AppColors.roseAccent, size: 20), const SizedBox(width: 8), const Text('Add Burner Password', style: TextStyle(color: AppColors.offWhite))]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Entering this password on the unlock screen will permanently destroy ALL vault data. Export a backup first if you need recovery.', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const SizedBox(height: 12),
          TextField(controller: labelCtrl, style: const TextStyle(color: AppColors.offWhite), decoration: const InputDecoration(labelText: 'Label (optional)')),
          const SizedBox(height: 8),
          TextField(controller: pwCtrl, obscureText: true, autofocus: true, style: const TextStyle(color: AppColors.offWhite), decoration: const InputDecoration(labelText: 'Burner Password (min 8 chars)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
          FilledButton(
            onPressed: () async {
              if (pwCtrl.text.length < 8) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Burner password must be at least 8 characters')));
                return;
              }
              try {
                await BurnerService().addBurnerPassword(pwCtrl.text, label: labelCtrl.text.trim().isEmpty ? 'Burner Code' : labelCtrl.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.roseAccent),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // --- Helpers ---

}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
    child: Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: AppColors.textMuted)),
  );
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: AppColors.surfaceZinc, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.borderZinc.withValues(alpha: 0.5))),
    child: Column(children: children),
  );
}
