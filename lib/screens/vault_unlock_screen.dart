// screens/vault_unlock_screen.dart
// Firewood Vault Unlock Screen: Master password entry with seamless duress/burner detection.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/auth_provider.dart';
import '../services/vault_service.dart';
import '../services/burner_service.dart';
import '../services/backup_service.dart';
import '../services/native_security_bridge.dart';
import '../theme/app_icons.dart';
import '../services/app_version_service.dart';
import 'package:hugeicons/hugeicons.dart';
import '../theme/app_theme.dart';
import '../theme/app_button.dart';
import 'vault_setup_screen.dart';

const _secureStorage = FlutterSecureStorage();
const _biometricPasswordKey = 'biometric_master_password';

class VaultUnlockScreen extends ConsumerStatefulWidget {
  const VaultUnlockScreen({super.key});

  @override
  ConsumerState<VaultUnlockScreen> createState() => _VaultUnlockScreenState();
}

class _VaultUnlockScreenState extends ConsumerState<VaultUnlockScreen>
    with SingleTickerProviderStateMixin {
  final _vaultService = VaultService();
  final _burnerService = BurnerService();
  final _backupService = BackupService();

  late TextEditingController _passwordController;
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isImporting = false;
  bool _isBurning = false;
  String? _error;
  bool _biometricTriggered = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _passwordController = TextEditingController();
    _fadeController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final hasVault = await _vaultService.hasAnyVault();
      if (!mounted) return;

      if (!hasVault) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const VaultSetupScreen()),
          (route) => false,
        );
        return;
      }

      final isBiometricEnabled = ref.read(biometricAuthEnabledProvider);
      if (isBiometricEnabled) {
        _authenticateBiometricUnlock();
      } else {
        try {
          final storedPwd =
              await _secureStorage.read(key: _biometricPasswordKey);
          if (storedPwd != null && storedPwd.isNotEmpty && mounted) {
            _authenticateBiometricUnlock();
          }
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- Biometric ---

  Future<void> _authenticateBiometricUnlock() async {
    if (_biometricTriggered) return;
    _biometricTriggered = true;

    if (mounted) setState(() {});

    final localAuth = LocalAuthentication();
    try {
      final canCheck = await localAuth.canCheckBiometrics;
      if (!canCheck || !await localAuth.isDeviceSupported()) {
        _biometricTriggered = false;
        if (mounted) setState(() {});
        return;
      }
      final didAuth = await localAuth.authenticate(
        localizedReason: 'Scan fingerprint or face to unlock Firewood',
        options:
            const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
      );
      if (didAuth && mounted) {
        HapticFeedback.mediumImpact();
        String? password;
        try {
          password = await NativeSecurityBridge.unwrapMasterPassword();
        } catch (_) {}
        if (password == null || password.isEmpty) {
          try {
            password = await _secureStorage.read(key: _biometricPasswordKey);
          } catch (_) {}
        }
        if (password != null && password.isNotEmpty) {
          _passwordController.text = password;
          await _unlock();
        } else {
          _biometricTriggered = false;
          if (mounted) {
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content:
                      Text('Biometrics verified. Enter your master password.')),
            );
          }
        }
      } else {
        _biometricTriggered = false;
        if (mounted) setState(() {});
      }
    } catch (_) {
      _biometricTriggered = false;
      if (mounted) setState(() {});
    }
  }

  // --- Unlock & Burner Detection ---

  Future<void> _unlock() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) return;

    // Check lockout rate limiting
    final lockout = await NativeSecurityBridge.getLockoutStatus();
    if (lockout.isLockedOut) {
      setState(() => _error =
          'Too many failed attempts. Wait ${lockout.lockoutRemainingMs ~/ 1000}s.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1. Check if the entered password matches any registered burner (duress) code
      final isBurner = await _burnerService.isBurnerPassword(password);
      if (isBurner) {
        await _handleBurnerDetected();
        return;
      }

      // 2. Perform regular vault unlock
      final key = await _vaultService.unlock(password);
      ref.read(authProvider.notifier).state = key;

      // Ensure Keystore wrapping is current (ADR-003, canonical biometric
      // path). A device that cannot wrap gets biometric disabled with notice
      // instead of a silent raw-password downgrade.
      if (ref.read(biometricAuthEnabledProvider)) {
        bool wrapped = false;
        try {
          wrapped = await NativeSecurityBridge.wrapMasterPassword(password);
          if (!wrapped) {
            await NativeSecurityBridge.createWrappingKey();
            wrapped = await NativeSecurityBridge.wrapMasterPassword(password);
          }
        } catch (_) {
          wrapped = false;
        }
        if (wrapped) {
          // Migration complete: drop any legacy raw-password entry.
          try {
            await _secureStorage.delete(key: _biometricPasswordKey);
          } catch (_) {}
        } else if (mounted) {
          await ref
              .read(biometricAuthEnabledProvider.notifier)
              .setEnabled(false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Biometric unlock unavailable on this device and was disabled.')),
          );
        }
      }

      _passwordController.clear();
      await NativeSecurityBridge.resetFailedAttempts();

      if (mounted) {
        HapticFeedback.lightImpact();
        // authProvider state update triggers _AuthGate to render HomeScreen without double route pushes
      }
    } on VaultException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
      HapticFeedback.heavyImpact();
      await NativeSecurityBridge.recordFailedUnlockAttempt();
    } catch (e) {
      setState(() {
        _error = 'Failed to unlock: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleBurnerDetected() async {
    setState(() {
      _isBurning = true;
      _error = null;
      _passwordController.clear();
    });

    await Future.delayed(const Duration(milliseconds: 600));

    try {
      await _burnerService.executeBurn();
      ref.read(authProvider.notifier).state = null;

      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All vault data has been permanently destroyed.'),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 4),
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const VaultSetupScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBurning = false;
          _isLoading = false;
          _error = 'Burn execution failed: $e';
        });
      }
    }
  }

  // --- Import Backup ---

  Future<void> _importBackup() async {
    setState(() => _error = null);
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

      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        dialogTitle: 'Select .firewood Backup File',
      );
      if (result == null || result.files.isEmpty || !mounted) return;
      final file = result.files.single;
      final filePath = file.path;
      final fileName = file.name;
      if (filePath == null && file.bytes == null)
        throw Exception('Could not access selected file');

      if (!fileName.toLowerCase().endsWith('.firewood')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Only .firewood backup files are supported.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      final pwdCtrl = TextEditingController();
      final formKey = GlobalKey<FormState>();
      final password = await showDialog<String>(
        context: context,
        builder: (ctx) {
          bool obscure = true;
          return StatefulBuilder(builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: AppColors.surfaceZinc,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.borderZinc),
              ),
              title: Row(children: [
                AppIcon(HugeIcons.strokeRoundedUpload01,
                    color: AppColors.orangeAccent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Import Vault Backup',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.offWhite,
                        ),
                  ),
                ),
              ]),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter master password for "$fileName":',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 12),
                  Form(
                    key: formKey,
                    child: TextFormField(
                      controller: pwdCtrl,
                      obscureText: obscure,
                      autofocus: true,
                      style: const TextStyle(color: AppColors.offWhite),
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: 'Backup Password',
                        prefixIcon: AppIcon(AppInputIcons.lock, size: 20),
                        suffixIcon: IconButton(
                          icon: AppIcon(
                              obscure
                                  ? AppInputIcons.eyeOff
                                  : AppInputIcons.eye,
                              size: 18),
                          onPressed: () =>
                              setModalState(() => obscure = !obscure),
                        ),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Password required' : null,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel',
                      style: TextStyle(color: AppColors.textMuted)),
                ),
                FilledButton(
                  onPressed: () {
                    if (formKey.currentState!.validate())
                      Navigator.pop(ctx, pwdCtrl.text);
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  child: const Text('Restore Vault'),
                ),
              ],
            );
          });
        },
      );

      pwdCtrl.dispose();
      if (password == null || !mounted) return;

      setState(() => _isImporting = true);
      final targetPath = filePath ?? fileName;
      final importedVaultName = await _backupService
          .importVault(targetPath, password, overwrite: true);

      final key = await _vaultService.unlock(password);
      ref.read(authProvider.notifier).state = key;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Imported vault: $importedVaultName'),
              backgroundColor: AppColors.orangeAccent),
        );
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error =
            'Import failed: ${e.toString().replaceAll('BackupException: ', '')}');
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBiometricEnabled = ref.watch(biometricAuthEnabledProvider);

    ref.listen<bool>(biometricAuthEnabledProvider, (prev, next) {
      if (next && !_biometricTriggered) _authenticateBiometricUnlock();
    });

    return Scaffold(
      backgroundColor: AppColors.backgroundZinc,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          // Content scrolls in the expanded area; the attribution footer is
          // pinned to the bottom edge of the screen.
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo & Brand Header
                        Center(
                          child: Column(
                            children: [
                              Image.asset(
                                'assets/FWS.png',
                                width: 72,
                                height: 72,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Firewood',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.offWhite,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Error banner
                        if (_error != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.roseContainer,
                              border: Border.all(color: AppColors.roseBorder),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                AppIcon(AppIcons.alertCircle,
                                    color: AppColors.roseAccent, size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(
                                      color: AppColors.roseOnContainer,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Biometric Button (if enabled)
                        if (isBiometricEnabled)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _authenticateBiometricUnlock,
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: AppColors.periwinkleContainer
                                        .withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: AppColors.periwinkleBorder
                                            .withValues(alpha: 0.6)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      AppIcon(
                                        AppIcons.fingerprint,
                                        color: _biometricTriggered
                                            ? AppColors.orangeAccent
                                            : AppColors.periwinkleAccent,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        _biometricTriggered
                                            ? 'Verifying biometrics...'
                                            : 'Unlock with Biometrics',
                                        style: TextStyle(
                                          color: AppColors.periwinkleOnContainer
                                              .withValues(alpha: 0.9),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // --- MAIN MASTER PASSWORD UNLOCK CARD ---
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceZinc,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.borderZinc,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 18),
                              TextField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                enabled: !_isLoading && !_isBurning,
                                autofocus: true,
                                style: const TextStyle(
                                    color: AppColors.offWhite, fontSize: 14),
                                textInputAction: TextInputAction.done,
                                onSubmitted: (val) {
                                  if (val.isNotEmpty) _unlock();
                                },
                                decoration: InputDecoration(
                                  isDense: true,
                                  hintText: 'Master password',
                                  hintStyle: const TextStyle(
                                      color: AppColors.textMuted, fontSize: 13),
                                  prefixIconConstraints: const BoxConstraints(
                                      minWidth: 42, minHeight: 42),
                                  prefixIcon: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    child: AppIcon(AppInputIcons.key,
                                        size: 18, color: AppColors.textMuted),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: AppIcon(
                                      _obscurePassword
                                          ? AppInputIcons.eyeOff
                                          : AppInputIcons.eye,
                                      size: 18,
                                      color: AppColors.textMuted,
                                    ),
                                    onPressed: () => setState(() =>
                                        _obscurePassword = !_obscurePassword),
                                  ),
                                  fillColor: AppColors.inputZinc,
                                  filled: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: AppColors.orangeAccent,
                                        width: 1.2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              AppButton(
                                label: 'Unlock Vault',
                                icon: HugeIcons.strokeRoundedArrowRight01,
                                variant: AppButtonVariant.primary,
                                isLoading: _isLoading || _isBurning,
                                loadingLabel: _isBurning
                                    ? 'Processing...'
                                    : 'Unlocking...',
                                fullWidth: true,
                                height: 48,
                                onPressed:
                                    _isLoading || _isBurning ? null : _unlock,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Import Backup Action Button
                        SizedBox(
                          height: 46,
                          child: OutlinedButton.icon(
                            onPressed: _isImporting ? null : _importBackup,
                            icon: _isImporting
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.orangeAccent),
                                  )
                                : AppIcon(HugeIcons.strokeRoundedUpload01,
                                    size: 18, color: AppColors.orangeAccent),
                            label: Text(
                              _isImporting
                                  ? 'Importing...'
                                  : 'Import Backup (.firewood)',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.offWhite,
                                  fontWeight: FontWeight.w500),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: AppColors.surfaceZinc,
                              side:
                                  const BorderSide(color: AppColors.borderZinc),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Attribution footer pinned to the bottom of the screen.
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 14),
                child: Text(
                  'ZERO-KNOWLEDGE · OFFLINE ONLY · ${AppVersionService.fullVersionString} (BUILD ${AppVersionService.buildNumber})',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: AppColors.textMuted.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
