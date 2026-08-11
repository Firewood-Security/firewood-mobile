// screens/settings_screen.dart
// Settings for auto-lock, auto-backup schedule, device alias, security info, and backup import/export

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/accent_color_service.dart';
import '../services/update_service.dart';

import '../providers/auth_provider.dart';
import '../services/backup_service.dart';
import '../services/lock_service.dart';
import '../services/vault_service.dart';
import '../services/burner_service.dart';
import '../database/schemas.dart';
import '../services/native_security_bridge.dart';
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
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) setState(() => _screenshotsAllowed = prefs.getBool('allow_screenshots') ?? false);
    });
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

    return Scaffold(
      backgroundColor: AppColors.backgroundZinc,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [


          // Appearance Section
          const _SectionHeader(title: 'APPEARANCE & ACCENT COLOR'),
          _SettingsCard(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Accent Theme Color',
                      style: TextStyle(color: AppColors.offWhite, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Select one of 5 curated accent colors (Default: Deep Orange)',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 14),
                    ValueListenableBuilder<Color>(
                      valueListenable: AccentColorService.currentColor,
                      builder: (context, activeColor, _) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: AccentColorService.presets.map((preset) {
                            final isSelected = activeColor.toARGB32() == preset.color.toARGB32();
                            return GestureDetector(
                              onTap: () => AccentColorService.setAccentColor(preset),
                              child: Tooltip(
                                message: preset.name,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: preset.color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected ? Colors.white : Colors.transparent,
                                      width: isSelected ? 3 : 1,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: preset.color.withValues(alpha: 0.5),
                                              blurRadius: 10,
                                              spreadRadius: 2,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: isSelected
                                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                                      : null,
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
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
                secondary: const Icon(Icons.fingerprint, color: AppColors.orangeAccent, size: 24),
                activeColor: AppColors.orangeAccent,
                onChanged: (val) => _toggleBiometricAuth(context, ref, val),
              ),
              SwitchListTile(
                title: const Text('Auto-Lock Vault', style: TextStyle(color: AppColors.offWhite, fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Lock vault when idle or app backgrounded', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                value: autoLockEnabled,
                secondary: const Icon(Icons.lock_clock_outlined, color: AppColors.orangeAccent, size: 24),
                activeColor: AppColors.orangeAccent,
                onChanged: (val) {
                  ref.read(autoLockEnabledProvider.notifier).state = val;
                  if (!val) lockService.cancelAutoLockTimer();
                },
              ),
              if (autoLockEnabled)
                ListTile(
                  title: const Text('Auto-Lock Timeout', style: TextStyle(color: AppColors.offWhite, fontSize: 14)),
                  subtitle: Text(_formatDuration(lockTimeout), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  leading: const Icon(Icons.timer_outlined, color: AppColors.orangeAccent, size: 24),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
                  onTap: () => _showTimeoutPicker(context, ref),
                ),
              ListTile(
                title: const Text('Lock Vault Now', style: TextStyle(color: AppColors.offWhite, fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Immediately clear secret key from memory', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                leading: const Icon(Icons.lock_outline, color: AppColors.orangeAccent, size: 24),
                onTap: () => _lockNow(context, ref),
              ),
              SwitchListTile(
                title: const Text('Allow Screenshots', style: TextStyle(color: AppColors.offWhite, fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Disable to prevent screen capture in app switcher', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                value: _screenshotsAllowed,
                activeColor: AppColors.orangeAccent,
                secondary: Icon(_screenshotsAllowed ? Icons.screenshot : Icons.no_photography, color: AppColors.orangeAccent, size: 24),
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
                        leading: const Icon(Icons.local_fire_department, color: AppColors.roseAccent, size: 24),
                        title: Text(b.label, style: const TextStyle(color: AppColors.offWhite, fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text('Created ${DateTime.now().difference(b.createdAt).inDays}d ago', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppColors.roseAccent, size: 18),
                          onPressed: () async { await BurnerService().removeBurner(b.id); if (mounted) setState(() {}); },
                        ),
                      )),
                      ListTile(
                        leading: const Icon(Icons.add_circle_outline, color: AppColors.roseAccent, size: 24),
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
                secondary: const Icon(Icons.backup_outlined, color: AppColors.orangeAccent, size: 24),
                activeColor: AppColors.orangeAccent,
                onChanged: (val) => _saveAutoBackup(val),
              ),
              if (autoBackupEnabled)
                ListTile(
                  title: const Text('Backup Frequency', style: TextStyle(color: AppColors.offWhite, fontSize: 14)),
                  subtitle: Text(_formatIntervalLabel(autoBackupInterval), style: const TextStyle(fontSize: 11, color: AppColors.orangeAccent)),
                  leading: const Icon(Icons.schedule_outlined, color: AppColors.orangeAccent, size: 24),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
                  onTap: () => _showBackupIntervalPicker(context),
                ),
              ListTile(
                title: const Text('Export Encrypted Vault Backup', style: TextStyle(color: AppColors.offWhite, fontSize: 14)),
                subtitle: const Text('Save .firewood encrypted file to Downloads', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                leading: const Icon(Icons.upload_file_outlined, color: AppColors.orangeAccent, size: 24),
                onTap: () => _exportVault(context, ref),
              ),
              ListTile(
                title: const Text('Import Vault Backup File', style: TextStyle(color: AppColors.offWhite, fontSize: 14)),
                subtitle: const Text('Restore database from .firewood file', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                leading: const Icon(Icons.download_outlined, color: AppColors.orangeAccent, size: 24),
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
                        const Icon(Icons.system_update_outlined, color: AppColors.orangeAccent, size: 24),
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
                    trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
                    onTap: () => _checkForUpdates(context),
                  );
                },
              ),
              ListTile(
                title: const Text('About Firewood & Developers', style: TextStyle(color: AppColors.offWhite, fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('App specs, zero-knowledge architecture & developer info', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                leading: const Icon(Icons.info_outline, color: AppColors.orangeAccent, size: 24),
                trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
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
                leading: const Icon(Icons.delete_forever_outlined, color: Colors.redAccent, size: 24),
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
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }
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
            title: const Row(
              children: [
                Icon(Icons.download_done, color: Colors.greenAccent, size: 24),
                SizedBox(width: 10),
                Text('Backup Exported', style: TextStyle(color: AppColors.offWhite, fontSize: 16)),
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
                    style: const TextStyle(fontFamily: 'Monospace', fontSize: 11, color: AppColors.orangeAccent),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: filePath));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Path copied to clipboard')),
                  );
                },
                icon: const Icon(Icons.copy, size: 16, color: AppColors.orangeAccent),
                label: const Text('Copy Path', style: TextStyle(color: AppColors.orangeAccent)),
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

  void _checkForUpdates(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceZinc,
        title: const Text('Checking for Updates', style: TextStyle(color: AppColors.offWhite)),
        content: const Row(children: [CircularProgressIndicator(color: AppColors.orangeAccent), SizedBox(width: 16), Text('Looking for new versions...', style: TextStyle(color: AppColors.textMuted))]),
      ),
    );
  }

  void _importVault(BuildContext context, WidgetRef ref) async {
    await _requestStoragePermission();
    if (!context.mounted) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    if (result == null || result.files.single.path == null || !context.mounted) return;
    final filePath = result.files.single.path!;

    if (!filePath.toLowerCase().endsWith('.firewood')) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid file format. Only .firewood backup files are allowed.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceZinc,
        title: const Text('Import Backup File', style: TextStyle(color: AppColors.offWhite, fontSize: 16)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: passwordController,
            obscureText: true,
            style: const TextStyle(color: AppColors.offWhite),
            decoration: const InputDecoration(
              labelText: 'Backup Master Password',
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
            child: const Text('Import & Restore'),
          ),
        ],
      ),
    );

    if (password == null || !context.mounted) return;

    try {
      final backupService = BackupService();
      final vaultName = await backupService.importVault(filePath, password, overwrite: true);
      // Auto unlock vault with the imported password
      final key = await VaultService().unlock(password);
      ref.read(authProvider.notifier).state = key;

      if (context.mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully restored and unlocked vault: $vaultName'),
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

  Future<void> _toggleBiometricAuth(BuildContext context, WidgetRef ref, bool enable) async {
    const storage = FlutterSecureStorage();
    if (!enable) {
      await storage.delete(key: 'biometric_master_password');
      await ref.read(biometricAuthEnabledProvider.notifier).setEnabled(false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric vault login disabled')),
        );
      }
      return;
    }

    final localAuth = LocalAuthentication();
    final canCheck = await localAuth.canCheckBiometrics;
    final isDeviceSupported = await localAuth.isDeviceSupported();

    if (!canCheck || !isDeviceSupported) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric authentication is not supported or configured on this device.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;

    // Require Master Password verification before enabling biometrics
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceZinc,
        title: const Text('Verify Master Password', style: TextStyle(color: AppColors.offWhite, fontSize: 16)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: passwordController,
            obscureText: true,
            style: const TextStyle(color: AppColors.offWhite),
            decoration: const InputDecoration(
              labelText: 'Master Password',
              hintText: 'Confirm master password to enable biometrics',
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
            child: const Text('Enable Biometrics'),
          ),
        ],
      ),
    );

    if (password == null || !context.mounted) return;

    try {
      await VaultService().unlock(password); // verify password
      await storage.write(key: 'biometric_master_password', value: password);
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
            content: Text('Incorrect master password. Biometric enable failed.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
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

    // Verify identity via Biometrics OR Master Password
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
      // Fallback to Master Password verification
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
        title: Row(children: [const Icon(Icons.local_fire_department, color: AppColors.roseAccent), const SizedBox(width: 8), const Text('Add Burner Password', style: TextStyle(color: AppColors.offWhite))]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Entering this password on the unlock screen will Permanently destroy ALL vault data.', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const SizedBox(height: 12),
          TextField(controller: labelCtrl, style: const TextStyle(color: AppColors.offWhite), decoration: const InputDecoration(labelText: 'Label (optional)')),
          const SizedBox(height: 8),
          TextField(controller: pwCtrl, obscureText: true, autofocus: true, style: const TextStyle(color: AppColors.offWhite), decoration: const InputDecoration(labelText: 'Burner Password (min 6 chars)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
          FilledButton(
            onPressed: () async {
              if (pwCtrl.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Burner password must be at least 6 characters')));
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
