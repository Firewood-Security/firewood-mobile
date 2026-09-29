// screens/settings_screen.dart
// Settings for auto-lock, auto-backup schedule, device alias, security info, and backup import/export

import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/update_service.dart';
import '../services/accent_color_service.dart';
import '../widgets/accent_color_picker_dialog.dart';

import '../providers/auth_provider.dart';
import '../services/backup_service.dart';
import '../services/csv_import_service.dart';
import '../services/item_service.dart';
import '../services/lock_service.dart';
import '../services/reauth_service.dart';
import '../services/vault_service.dart';
import '../services/burner_service.dart';
import '../database/schemas.dart';
import '../services/native_security_bridge.dart';
import 'package:hugeicons/hugeicons.dart';
import '../theme/app_icons.dart';
import '../theme/app_feedback.dart';
import '../theme/app_theme.dart';
import 'about_screen.dart';
import 'p2p_sharing_screen.dart';
import 'update_screen.dart';
import 'password_generator_screen.dart';
import '../services/app_version_service.dart';
import '../widgets/vault_components.dart';
import '../widgets/app_loader.dart';
import '../theme/app_button.dart';
import '../services/autofill_service.dart';
import '../services/notification_service.dart';

// Providers for Backup & Profile settings
final autoBackupEnabledProvider = StateProvider<bool>((ref) => true);
final autoBackupIntervalDaysProvider =
    StateProvider<int>((ref) => 120); // Default 4 months

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _screenshotsAllowed = false;
  bool _notificationsAllowed = true;
  bool _autofillActive = false;

  // Flicker fix: cache futures so rebuilds don't re-fetch and flash loading states.
  Future<List<DecryptedItem>>? _devSecretsFuture;
  Future<List<BurnerHash>>? _burnersFuture;

  @override
  void initState() {
    super.initState();
    AccentColorService.currentColor.addListener(_onAccentColorChanged);
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(() {
          _screenshotsAllowed = prefs.getBool('allow_screenshots') ?? false;
        });
        // Restore the backup prefs into their providers — they start at the
        // declared defaults on every launch, so without this a user's stored
        // "off"/custom interval bounced back to on/120-days visually.
        ref.read(autoBackupEnabledProvider.notifier).state =
            prefs.getBool('auto_backup_enabled') ?? true;
        ref.read(autoBackupIntervalDaysProvider.notifier).state =
            prefs.getInt('auto_backup_interval_days') ?? 120;
      }
    });
    NotificationAlertService.isNotificationsEnabled().then((v) {
      if (mounted) setState(() => _notificationsAllowed = v);
    });
    AutofillService.isEnabled().then((v) {
      if (mounted) setState(() => _autofillActive = v);
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

  Future<void> _openDonate() async {
    final uri = Uri.parse('https://firewood-web.web.app/donate');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final autoLockEnabled = ref.watch(autoLockEnabledProvider);
    final lockTimeout = ref.watch(lockTimeoutProvider);
    final sessionTimeout = ref.watch(sessionTimeoutProvider);
    final lockOnBackground = ref.watch(lockOnBackgroundProvider);
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
          appBar: VaultAppBar(
            leading: IconButton(
              icon: const AppIcon(AppIcons.arrowLeft,
                  color: AppColors.offWhite, size: 22),
              onPressed: () => Navigator.pop(context),
            ),
            title: 'Settings & Tools',
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              // Hero Header with Logo, Version and App Subtitle (100% full width, no outer padding)
              VaultHeroHeader(
                accentColor: accentColor,
                titleContent: Row(
                  children: [
                    Image.asset(
                      'assets/FWS.png',
                      width: 42,
                      height: 42,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Firewood Vault',
                        style: GoogleFonts.syncopate(
                          color: AppColors.offWhite,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.82,
                  children: [
                    // Tool 1: Password Generator
                    VaultToolButton(
                      label: 'Generator',
                      icon: 'assets/icons/cutouts/password-generator.png',
                      accentColor: accentColor,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PasswordGeneratorScreen(),
                          ),
                        );
                      },
                    ),
                    // Tool 2: P2P Share
                    VaultToolButton(
                      label: 'AirShare',
                      icon: 'assets/icons/cutouts/share.png',
                      accentColor: accentColor,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const P2pSharingScreen(),
                          ),
                        );
                      },
                    ),
                    // Tool 3: Export Vault
                    VaultToolButton(
                      label: 'Export',
                      icon: 'assets/icons/cutouts/download.png',
                      accentColor: accentColor,
                      onTap: () => _exportVault(context, ref),
                    ),
                    // Tool 4: Import Vault / Credentials
                    VaultToolButton(
                      label: 'Import',
                      icon: 'assets/icons/cutouts/upload.png',
                      accentColor: accentColor,
                      onTap: () => _showImportOptions(context, ref),
                    ),
                    // Tool 5: Check Update
                    VaultToolButton(
                      label: 'Updates',
                      icon: 'assets/icons/cutouts/refresh.png',
                      accentColor: accentColor,
                      onTap: () => _checkForUpdates(context),
                    ),
                    // Tool 6: About
                    VaultToolButton(
                      label: 'About',
                      icon: 'assets/icons/cutouts/info.png',
                      accentColor: accentColor,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AboutScreen(),
                          ),
                        );
                      },
                    ),
                    // Tool 7: Donate / Support
                    VaultToolButton(
                      label: 'Donate',
                      icon: 'assets/icons/cutouts/globe-network.png',
                      accentColor: accentColor,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _openDonate();
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

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
                    title: const Text('Biometric Vault Unlock',
                        style: TextStyle(
                            color: AppColors.offWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    value: biometricEnabled,
                    secondary: AppIcon(AppIcons.fingerprint,
                        color: AppColors.orangeAccent, size: 22),
                    activeColor: AppColors.orangeAccent,
                    onChanged: (val) => _toggleBiometricAuth(context, ref, val),
                  ),
                  SwitchListTile(
                    title: const Text('Auto-Lock Vault',
                        style: TextStyle(
                            color: AppColors.offWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    value: autoLockEnabled,
                    secondary: AppIcon(AppIcons.lockClock,
                        color: AppColors.orangeAccent, size: 22),
                    activeColor: AppColors.orangeAccent,
                    onChanged: (val) {
                      ref.read(autoLockEnabledProvider.notifier).state = val;
                      LockService.persistEnabled(val);
                      if (!val) lockService.cancelAutoLockTimer();
                    },
                  ),
                  if (autoLockEnabled)
                    ListTile(
                      title: const Text('Auto-Lock Timeout',
                          style: TextStyle(
                              color: AppColors.offWhite, fontSize: 14)),
                      leading: AppIcon(AppIcons.timer,
                          color: AppColors.orangeAccent, size: 20),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_formatDuration(lockTimeout),
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textMuted)),
                          const SizedBox(width: 4),
                          AppIcon(AppIcons.chevronRight,
                              color: AppColors.textMuted, size: 18),
                        ],
                      ),
                      onTap: () => _showTimeoutPicker(context, ref),
                    ),
                  ListTile(
                    title: const Text('Session Timeout',
                        style:
                            TextStyle(color: AppColors.offWhite, fontSize: 14)),
                    leading: AppIcon(AppIcons.timer,
                        color: AppColors.orangeAccent, size: 20),
                    subtitle: const Text(
                        'Logout after this much logged-in time',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textMuted)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_formatDuration(sessionTimeout),
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textMuted)),
                        const SizedBox(width: 4),
                        const AppIcon(AppIcons.chevronRight,
                            color: AppColors.textMuted, size: 18),
                      ],
                    ),
                    onTap: () => _showSessionTimeoutPicker(context, ref),
                  ),
                  SwitchListTile(
                    title: const Text('Lock in Recent Apps',
                        style: TextStyle(
                            color: AppColors.offWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    subtitle: const Text(
                        'Lock when the app leaves the screen (recents tray, home, screen off)',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textMuted)),
                    value: lockOnBackground,
                    secondary: AppIcon(AppIcons.lock,
                        color: AppColors.orangeAccent, size: 22),
                    activeColor: AppColors.orangeAccent,
                    onChanged: (val) {
                      ref.read(lockOnBackgroundProvider.notifier).state = val;
                      LockService.persistLockOnBackground(val);
                    },
                  ),
                  ListTile(
                    title: const Text('Lock Vault Now',
                        style: TextStyle(
                            color: AppColors.offWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    leading: AppIcon(AppIcons.lock,
                        color: AppColors.orangeAccent, size: 20),
                    onTap: () => _lockNow(context, ref),
                  ),
                  SwitchListTile(
                    title: const Text('Allow Screenshots',
                        style: TextStyle(
                            color: AppColors.offWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    value: _screenshotsAllowed,
                    activeColor: AppColors.orangeAccent,
                    secondary: AppIcon(
                        _screenshotsAllowed ? AppIcons.eye : AppIcons.eyeOff,
                        color: AppColors.orangeAccent,
                        size: 22),
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

              // Fast Fill & Autofill Provider (Offline Browser & App Forms)
              const _SectionHeader(title: 'BROWSER & APP FAST FILL (AUTOFILL)'),
              _SettingsCard(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      await AutofillService.openSettings();
                      Future.delayed(const Duration(seconds: 1), () async {
                        final active = await AutofillService.isEnabled();
                        if (mounted) setState(() => _autofillActive = active);
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          AppIcon(HugeIcons.strokeRoundedFlash,
                              color: AppColors.orangeAccent, size: 22),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Android System Autofill',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: AppColors.offWhite,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'System-level fast fill for apps & browsers',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11.5),
                                ),
                              ],
                            ),
                          ),
                          _GuideButton(
                              onTap: () => _showAutofillGuide(context)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _autofillActive
                                  ? AppColors.orangeAccent
                                      .withValues(alpha: 0.15)
                                  : AppColors.cardZinc,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _autofillActive
                                    ? AppColors.orangeAccent
                                        .withValues(alpha: 0.4)
                                    : AppColors.borderZinc,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _autofillActive
                                        ? AppColors.orangeAccent
                                        : AppColors.textMuted,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _autofillActive ? 'Active' : 'Enable',
                                  style: TextStyle(
                                    color: _autofillActive
                                        ? AppColors.orangeAccent
                                        : AppColors.offWhite,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Notification & Security Alerts (Throttled, Offline Only)
              const _SectionHeader(title: 'SECURITY ALERTS & NOTIFICATIONS'),
              _SettingsCard(
                children: [
                  ListTile(
                    leading: AppIcon(HugeIcons.strokeRoundedNotification02,
                        color: AppColors.orangeAccent, size: 22),
                    title: const Text('Allow Notifications',
                        style: TextStyle(
                            color: AppColors.offWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _GuideButton(
                            onTap: () => _showNotificationGuide(context)),
                        const SizedBox(width: 4),
                        Switch(
                          value: _notificationsAllowed,
                          activeColor: AppColors.orangeAccent,
                          onChanged: (val) async {
                            HapticFeedback.lightImpact();
                            await NotificationAlertService
                                .setNotificationsEnabled(val);
                            if (val) {
                              // API 33+: the pref alone shows nothing — ask
                              // the OS for POST_NOTIFICATIONS and wait for
                              // the real answer (the switch previously never
                              // requested it, leaving alerts silently dead).
                              LockService.beginForegroundFlow();
                              bool granted;
                              try {
                                granted = await NotificationAlertService
                                    .requestPermission();
                              } finally {
                                LockService.endForegroundFlow();
                              }
                              if (!granted && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Notification permission denied by Android — '
                                      'security alerts stay off until granted in system settings.',
                                    ),
                                  ),
                                );
                              }
                            }
                            if (mounted) {
                              setState(() => _notificationsAllowed = val);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Developer Secrets .env Exporter (Visible only when API keys / Dev secrets > 2)
              if (authKey != null)
                FutureBuilder<List<DecryptedItem>>(
                  future: _devSecretsFuture ??=
                      ItemService().getAllItems(authKey),
                  builder: (context, snapshot) {
                    final allItems = snapshot.data ?? [];
                    final devSecrets = allItems
                        .where((i) => i.type == 'developerSecret')
                        .toList();
                    if (devSecrets.length <= 2) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionHeader(
                            title: 'DEVELOPER TOOLS & API EXPORT'),
                        _SettingsCard(
                          children: [
                            ListTile(
                              title: const Text('Export API Keys as .env',
                                  style: TextStyle(
                                      color: AppColors.offWhite,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                              leading: AppIcon(AppIcons.typeDeveloperSecret,
                                  color: AppColors.orangeAccent, size: 20),
                              trailing: AppIcon(AppIcons.chevronRight,
                                  color: AppColors.textMuted, size: 18),
                              onTap: () =>
                                  _showEnvExportDialog(context, devSecrets),
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
                    future: _burnersFuture ??= BurnerService().listBurners(),
                    builder: (context, snapshot) {
                      final burners = snapshot.data ?? [];
                      return Column(
                        children: [
                          if (burners.isEmpty)
                            const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('No burner passwords configured.',
                                    style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12))),
                          ...burners.map((b) => ListTile(
                                leading: AppIcon(AppIcons.fire,
                                    color: AppColors.roseAccent, size: 20),
                                title: Text(b.label,
                                    style: const TextStyle(
                                        color: AppColors.offWhite,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                                trailing: IconButton(
                                  icon: AppIcon(HugeIcons.strokeRoundedDelete02,
                                      color: AppColors.roseAccent, size: 20),
                                  onPressed: () async {
                                    await BurnerService().removeBurner(b.id);
                                    if (mounted) setState(() {});
                                  },
                                ),
                              )),
                          ListTile(
                            leading: AppIcon(AppIcons.add,
                                color: AppColors.roseAccent, size: 20),
                            title: const Text('Add Burner Password',
                                style: TextStyle(
                                    color: AppColors.roseAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                            onTap: () => _addBurnerPasswordDialog(context),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Automatic Scheduled Backup Schedule Settings
              const _SectionHeader(title: 'AUTOMATED BACKUP SCHEDULE'),
              _SettingsCard(
                children: [
                  SwitchListTile(
                    title: const Text('Scheduled Auto-Backup',
                        style: TextStyle(
                            color: AppColors.offWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    value: autoBackupEnabled,
                    secondary: AppIcon(AppIcons.cloudUpload,
                        color: AppColors.orangeAccent, size: 22),
                    activeColor: AppColors.orangeAccent,
                    onChanged: (val) => _saveAutoBackup(val),
                  ),
                  if (autoBackupEnabled)
                    ListTile(
                      title: const Text('Backup Frequency',
                          style: TextStyle(
                              color: AppColors.offWhite, fontSize: 14)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          _formatIntervalLabel(autoBackupInterval),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.orangeAccent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      leading: AppIcon(AppIcons.timer,
                          color: AppColors.orangeAccent, size: 20),
                      trailing: const AppIcon(AppIcons.chevronRight,
                          color: AppColors.textMuted, size: 18),
                      onTap: () => _showBackupIntervalPicker(context),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Danger Zone
              const _SectionHeader(title: 'DANGER ZONE'),
              _SettingsCard(
                children: [
                  ListTile(
                    title: const Text('Delete Vault Data',
                        style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    leading: AppIcon(AppIcons.trash,
                        color: Colors.redAccent, size: 20),
                    onTap: () => _confirmDeleteVault(context, ref),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/FWS.png',
                      width: 48,
                      height: 48,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Firewood ${AppVersionService.fullVersionString}\nZero-Knowledge Password Vault',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted),
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
      case 120:
        return 'Every 4 Months (Default)';
      case 30:
        return 'Every Month';
      case 15:
        return 'Every 15 Days';
      case 7:
        return 'Every Week';
      case 3:
        return 'Every 3 Days';
      default:
        return 'Every $days Days';
    }
  }

  void _showSessionTimeoutPicker(BuildContext context, WidgetRef ref) {
    final current = ref.read(sessionTimeoutProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceZinc,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Session Timeout',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.offWhite)),
            const Text('The vault logs out after this much logged-in time',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            const SizedBox(height: 12),
            ...LockService.sessionTimeoutOptions.map(
              (option) => RadioListTile<Duration>(
                title: Text(_formatDuration(option),
                    style: const TextStyle(color: AppColors.offWhite)),
                value: option,
                groupValue: current,
                activeColor: AppColors.orangeAccent,
                onChanged: (val) {
                  if (val != null) {
                    ref.read(sessionTimeoutProvider.notifier).state = val;
                    LockService.persistSessionTimeout(val);
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
            const Text('Auto-Lock Timeout',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.offWhite)),
            const SizedBox(height: 12),
            ...lockTimeoutOptions.map(
              (option) => RadioListTile<Duration>(
                title: Text(_formatDuration(option),
                    style: const TextStyle(color: AppColors.offWhite)),
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
            const Text('Select Backup Frequency',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.offWhite)),
            const SizedBox(height: 12),
            ...intervals.map(
              (entry) => RadioListTile<int>(
                title: Text(entry.value,
                    style: const TextStyle(color: AppColors.offWhite)),
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

  void _showAutofillGuide(BuildContext context) {
    _showFeatureGuideSheet(
      context,
      title: 'Android Autofill Guide',
      icon: HugeIcons.strokeRoundedFlash,
      steps: [
        (
          step: '1',
          heading: 'Enable Provider',
          body:
              'Tap "ENABLE" to open Android System Settings and select Firewood as your Autofill service.',
        ),
        (
          step: '2',
          heading: 'Fast Fill Prompt',
          body:
              'When you tap any username or password field in apps or browsers, Android shows "Open Firewood Vault".',
        ),
        (
          step: '3',
          heading: 'Unlock & Select',
          body:
              'Authenticate with your fingerprint, face, or PIN. Select the matching credential to fill the form.',
        ),
        (
          step: '4',
          heading: '100% Offline & Private',
          body:
              'Credentials are encrypted on your device and never exposed to system dropdowns or third-party servers.',
        ),
      ],
    );
  }

  void _showNotificationGuide(BuildContext context) {
    _showFeatureGuideSheet(
      context,
      title: 'Security Alerts Guide',
      icon: HugeIcons.strokeRoundedNotification02,
      steps: [
        (
          step: '1',
          heading: 'Password Hygiene',
          body:
              'Receive local alerts when stored credentials have weak, reused, or compromised passwords.',
        ),
        (
          step: '2',
          heading: 'Incomplete Credentials',
          body:
              'Helpful reminders if you generated a password or started a form without finishing.',
        ),
        (
          step: '3',
          heading: 'Security & App Updates',
          body:
              'Get notified when new versions or critical security fixes are available.',
        ),
        (
          step: '4',
          heading: 'Local & Offline',
          body:
              'All checks run on-device with zero network trackers. Toggle this switch off anytime to stop all alerts.',
        ),
      ],
    );
  }

  void _showFeatureGuideSheet(
    BuildContext context, {
    required String title,
    required dynamic icon,
    required List<({String step, String heading, String body})> steps,
  }) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surfaceZinc,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom +
              MediaQuery.of(ctx).viewPadding.bottom,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: GoogleFonts.syncopate(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.offWhite,
                  ),
                ),
                const SizedBox(height: 16),
                ...steps.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: AppColors.orangeAccent
                                  .withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.orangeAccent
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                s.step,
                                style: TextStyle(
                                  color: AppColors.orangeAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.heading,
                                  style: const TextStyle(
                                    color: AppColors.offWhite,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  s.body,
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orangeAccent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Got It',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _lockNow(BuildContext context, WidgetRef ref) {
    ref.read(authProvider.notifier).state = null;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _exportVault(BuildContext context, WidgetRef ref) async {
    // Auth policy: exporting writes the whole vault to a file — critical.
    if (!await ReauthService.confirm(context,
        reason: 'Authenticate to export the vault')) {
      return;
    }
    if (!context.mounted) return;
    if (!context.mounted) return;

    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceZinc,
        title: const Text('Master Password',
            style: TextStyle(color: AppColors.offWhite, fontSize: 16)),
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
            validator: (v) =>
                v == null || v.isEmpty ? 'Password required' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, passwordController.text);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orangeAccent,
                foregroundColor: Colors.white,
                shadowColor: AppColors.shade(AppColors.orangeAccent, -0.18)),
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
                AppIcon(AppIcons.checkCircle,
                    color: Colors.greenAccent, size: 34),
                const SizedBox(width: 10),
                const Text('Backup Exported',
                    style: TextStyle(color: AppColors.offWhite, fontSize: 16)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Vault saved to /Firewood/downloads:',
                    style: TextStyle(color: AppColors.offWhite, fontSize: 12)),
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
                    style: TextStyle(
                        fontFamily: 'Monospace',
                        fontSize: 11,
                        color: AppColors.orangeAccent),
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
                icon: AppIcon(HugeIcons.strokeRoundedCopy01,
                    size: 19, color: AppColors.orangeAccent),
                label: Text('Copy Path',
                    style: TextStyle(color: AppColors.orangeAccent)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orangeAccent,
                    foregroundColor: Colors.white,
                    shadowColor:
                        AppColors.shade(AppColors.orangeAccent, -0.18)),
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

  void _showEnvExportDialog(
      BuildContext context, List<DecryptedItem> devSecrets) async {
    // Auth policy: the .env dump carries live secrets in plaintext.
    if (!await ReauthService.confirm(context,
        reason: 'Authenticate to export API keys (.env)')) {
      return;
    }
    if (!context.mounted) return;
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
                  return lk == 'createdat' ||
                      lk == 'updatedat' ||
                      lk == 'timestamp';
                });

                if (fields.isEmpty) {
                  sb.writeln('${cleanTitle}=""\n');
                  continue;
                }

                for (final entry in fields.entries) {
                  final k = entry.key.trim();
                  final v = entry.value.toString().trim();
                  final cleanKey =
                      k.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9_]'), '_');

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
                          AppIcon(AppIcons.typeDeveloperSecret,
                              color: AppColors.orangeAccent, size: 34),
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
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Select the developer secrets and API credentials to package into standard .env format.',
                        style:
                            TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.roseContainer,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.roseBorder),
                        ),
                        child: const Text(
                          'Warning: the exported file contains live secrets in PLAINTEXT (classification: SECRET-in-plaintext, D-09). Anyone with the file has the keys. Store it securely and delete it when done.',
                          style: TextStyle(
                              color: AppColors.roseOnContainer,
                              fontSize: 11,
                              height: 1.4),
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
                            final isSelected =
                                selectedItemIds.contains(item.itemId);
                            return CheckboxListTile(
                              value: isSelected,
                              title: Text(item.title,
                                  style: const TextStyle(
                                      color: AppColors.offWhite,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                              subtitle: Text('${item.fields.length} attributes',
                                  style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11)),
                              secondary: AppIcon(AppIcons.key,
                                  color: isSelected
                                      ? AppColors.orangeAccent
                                      : AppColors.textMuted,
                                  size: 22),
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
                            envContent.isEmpty
                                ? '# No items selected'
                                : envContent,
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
                                      ref
                                          .read(lockServiceProvider)
                                          .copySecret(envContent);
                                      HapticFeedback.selectionClick();
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              AppIcon(AppIcons.checkCircle,
                                                  color: Colors.greenAccent,
                                                  size: 22),
                                              const SizedBox(width: 8),
                                              const Text(
                                                  '.env content copied to clipboard (clears in 30s)'),
                                            ],
                                          ),
                                          backgroundColor:
                                              AppColors.surfaceZinc,
                                        ),
                                      );
                                    },
                              icon: AppIcon(HugeIcons.strokeRoundedCopy01,
                                  size: 22, color: AppColors.orangeAccent),
                              label: const Text('Copy .env',
                                  style: TextStyle(
                                      color: AppColors.offWhite,
                                      fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                side: const BorderSide(
                                    color: AppColors.borderZinc),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: envContent.isEmpty
                                  ? null
                                  : () async {
                                      try {
                                        // Storage Access Framework: no storage
                                        // permission required (Play policy).
                                        final now = DateTime.now()
                                            .millisecondsSinceEpoch;
                                        String? saved;
                                        LockService.beginForegroundFlow();
                                        try {
                                          saved = await FilePicker.platform
                                              .saveFile(
                                            fileName:
                                                'firewood_secrets_$now.env',
                                            bytes: Uint8List.fromList(
                                                utf8.encode(envContent)),
                                          );
                                        } finally {
                                          LockService.endForegroundFlow();
                                        }
                                        if (saved == null) return;
                                        HapticFeedback.heavyImpact();
                                        if (ctx.mounted) Navigator.pop(ctx);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text('Saved to $saved'),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                                content:
                                                    Text('Save failed: $e'),
                                                backgroundColor:
                                                    Colors.redAccent),
                                          );
                                        }
                                      }
                                    },
                              icon: AppIcon(HugeIcons.strokeRoundedDownload01,
                                  size: 22),
                              label: const Text('Save File',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              style: FilledButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
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

  Future<void> _toggleBiometricAuth(
      BuildContext context, WidgetRef ref, bool enable) async {
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
            const SnackBar(
                content: Text('Biometrics not available on this device')),
          );
        }
        return;
      }

      LockService.beginForegroundFlow();
      bool authenticated;
      try {
        authenticated = await localAuth.authenticate(
          localizedReason: 'Authenticate to enable biometric vault unlock',
          options: const AuthenticationOptions(
              stickyAuth: true, biometricOnly: true),
        );
      } finally {
        LockService.endForegroundFlow();
      }

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
        title: const Text('Confirm Master Password',
            style: TextStyle(color: AppColors.offWhite, fontSize: 16)),
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
            validator: (v) =>
                v == null || v.isEmpty ? 'Password required' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, passwordController.text);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orangeAccent,
                foregroundColor: Colors.white,
                shadowColor: AppColors.shade(AppColors.orangeAccent, -0.18)),
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
      // V-015: default AndroidOptions on purpose — must match the mode the
      // legacy entry was written with or the delete silently misses it.
      try {
        await const FlutterSecureStorage()
            .delete(key: 'biometric_master_password');
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
            content: Text(
                'Could not enable biometric unlock (wrong password or unsupported device).'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showImportOptions(BuildContext context, WidgetRef ref) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceZinc,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppColors.borderZinc, width: 1),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.of(ctx).padding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Text(
              'Import into vault',
              style: GoogleFonts.syncopate(
                color: AppColors.offWhite,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Bring credentials from another manager or restore an encrypted backup.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.pop(ctx);
                _importCsvVault(context, ref);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.cardZinc,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.borderZinc.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bulk Import Credentials (CSV)',
                            style: TextStyle(
                              color: AppColors.offWhite,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Chrome, Bitwarden, 1Password, LastPass, or custom CSV',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const AppIcon(AppIcons.chevronRight,
                        color: AppColors.textMuted, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.pop(ctx);
                _importVault(context, ref);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.cardZinc,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.borderZinc.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.orangeAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: AppIcon(
                        HugeIcons.strokeRoundedLockKey,
                        color: AppColors.orangeAccent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Encrypted Backup (.firewood)',
                            style: TextStyle(
                              color: AppColors.offWhite,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Restore complete encrypted vault backup',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const AppIcon(AppIcons.chevronRight,
                        color: AppColors.textMuted, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _importCsvVault(BuildContext context, WidgetRef ref) async {
    final currentKey = ref.read(authProvider);
    if (currentKey == null) {
      if (context.mounted) {
        AppToast.show(context,
            message: 'Vault must be unlocked to import credentials',
            type: ToastType.error);
      }
      return;
    }
    await CsvImportService().pickAndImportCsv(
      context: context,
      secretKey: currentKey,
    );
  }

  void _importVault(BuildContext context, WidgetRef ref) async {
    if (!context.mounted) return;

    // Auth policy: importing overrides credentials in the vault.
    if (!await ReauthService.confirm(context,
        reason: 'Authenticate to import a vault backup')) {
      return;
    }
    if (!context.mounted) return;

    LockService.beginForegroundFlow();
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['firewood', 'json'],
      );
    } finally {
      LockService.endForegroundFlow();
    }

    if (result == null || result.files.single.path == null || !context.mounted)
      return;
    final filePath = result.files.single.path!;

    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceZinc,
        title: const Text('Import Vault Backup',
            style: TextStyle(color: AppColors.offWhite, fontSize: 16)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  'Enter the master password used to encrypt this backup file:',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                style: const TextStyle(color: AppColors.offWhite),
                decoration: const InputDecoration(
                  labelText: 'Backup Password',
                  hintText: 'Enter password',
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Password required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, passwordController.text);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orangeAccent,
                foregroundColor: Colors.white,
                shadowColor: AppColors.shade(AppColors.orangeAccent, -0.18)),
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

  Future<void> _checkForUpdates(BuildContext context) async {
    HapticFeedback.lightImpact();
    AppLoader.show(context, message: 'Checking for app updates...');

    AppUpdateInfo? info;
    try {
      info = await UpdateService().checkAppUpdate();
    } catch (_) {}

    if (!context.mounted) return;
    AppLoader.hide(context);

    if (info != null && info.hasUpdate) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceZinc,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.borderZinc),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.orangeAccent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '1',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Update Available',
                  style: TextStyle(
                    color: AppColors.offWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Version ${info!.version} (Build ${info.buildNumber}) is now available.',
                style: const TextStyle(
                  color: AppColors.offWhite,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (info.releaseNotes.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.cardZinc,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderZinc),
                  ),
                  child: Text(
                    info.releaseNotes,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Later',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
            AppButton(
              label: 'View Update',
              variant: AppButtonVariant.primary,
              height: 38,
              fontSize: 13,
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UpdateScreen()),
                );
              },
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceZinc,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppColors.borderZinc),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
          actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VAULT IS CURRENT',
                style: GoogleFonts.syncopate(
                  color: AppColors.offWhite,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.orangeAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.orangeAccent.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  AppVersionService.fullVersionString,
                  style: TextStyle(
                    color: AppColors.orangeAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'You\'re running the latest release of Firewood. All security patches and features are up to date — no action needed.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              height: 1.55,
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orangeAccent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ).copyWith(
                  elevation: WidgetStateProperty.all(0),
                  overlayColor: WidgetStateProperty.all(
                    Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.orangeAccent.withValues(alpha: 0.55),
                        offset: const Offset(0, 4),
                        blurRadius: 14,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: const Text(
                    'Got It',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  void _confirmDeleteVault(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceZinc,
        title: const Text('Delete Vault?',
            style: TextStyle(color: Colors.redAccent, fontSize: 16)),
        content: const Text(
            'This will delete all local vault data permanently. Verification required.',
            style: TextStyle(color: AppColors.offWhite)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white),
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
        if (await localAuth.canCheckBiometrics &&
            await localAuth.isDeviceSupported()) {
          LockService.beginForegroundFlow();
          try {
            verified = await localAuth.authenticate(
              localizedReason:
                  'Authenticate biometrically to authorize vault deletion',
              options: const AuthenticationOptions(
                  stickyAuth: true, biometricOnly: true),
            );
          } finally {
            LockService.endForegroundFlow();
          }
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
          title: const Text('Verify Master Password',
              style: TextStyle(color: Colors.redAccent, fontSize: 16)),
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
              validator: (v) =>
                  v == null || v.isEmpty ? 'Password required' : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, passwordController.text);
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white),
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
              const SnackBar(
                  content: Text(
                      'Incorrect master password. Vault deletion aborted.'),
                  backgroundColor: Colors.redAccent),
            );
          }
          return;
        }
      }
    }

    if (!verified) return;

    // V-015: default-options delete of the legacy raw-password entry (mode
    // must match the legacy write mode) — dies with the vault data too.
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
        title: Row(children: [
          AppIcon(AppIcons.fire, color: AppColors.roseAccent, size: 24),
          const SizedBox(width: 8),
          const Text('Add Burner Password',
              style: TextStyle(color: AppColors.offWhite))
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
              'Entering this password on the unlock screen will permanently destroy ALL vault data. Export a backup first if you need recovery.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const SizedBox(height: 12),
          TextField(
              controller: labelCtrl,
              style: const TextStyle(color: AppColors.offWhite),
              decoration: const InputDecoration(labelText: 'Label (optional)')),
          const SizedBox(height: 8),
          TextField(
              controller: pwCtrl,
              obscureText: true,
              autofocus: true,
              style: const TextStyle(color: AppColors.offWhite),
              decoration: const InputDecoration(
                  labelText: 'Burner Password (min 8 chars)')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textMuted))),
          FilledButton(
            onPressed: () async {
              if (pwCtrl.text.length < 8) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content:
                        Text('Burner password must be at least 8 characters')));
                return;
              }
              // Auth policy: creating a duress/overriding credential is a
              // critical action — same verification bar as edits, deletes
              // and imports.
              if (!await ReauthService.confirm(ctx,
                  reason: 'Authenticate to add a burner password')) {
                return;
              }
              try {
                await BurnerService().addBurnerPassword(pwCtrl.text,
                    label: labelCtrl.text.trim().isEmpty
                        ? 'Burner Code'
                        : labelCtrl.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.redAccent));
                }
              }
            },
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.roseAccent),
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(title,
            style: GoogleFonts.syncopate(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: AppColors.textMuted)),
      );
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
            color: AppColors.surfaceZinc,
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: AppColors.borderZinc.withValues(alpha: 0.5))),
        child: Column(children: children),
      );
}

class _GuideButton extends StatelessWidget {
  final VoidCallback onTap;

  const _GuideButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.cardZinc,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderZinc),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedInformationCircle,
              size: 14,
              color: AppColors.orangeAccent,
              strokeWidth: 2,
            ),
            const SizedBox(width: 5),
            const Text(
              'How it works',
              style: TextStyle(
                color: AppColors.offWhite,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
