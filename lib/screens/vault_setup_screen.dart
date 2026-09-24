// screens/vault_setup_screen.dart
// First launch: create master password with strength indicator (Non-scrollable, Minimalist)

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/vault_service.dart';
import '../services/backup_service.dart';
import '../providers/auth_provider.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/app_button.dart';

class VaultSetupScreen extends ConsumerStatefulWidget {
  const VaultSetupScreen({super.key});

  @override
  ConsumerState<VaultSetupScreen> createState() => _VaultSetupScreenState();
}

class _VaultSetupScreenState extends ConsumerState<VaultSetupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  
  final _vaultService = VaultService();
  final _backupService = BackupService();
  
  bool _isLoading = false;
  bool _isImporting = false;
  String? _error;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

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

      if (filePath == null && file.bytes == null) {
        throw Exception('Could not access selected file');
      }

      // Check extension from name or path
      final isFirewoodExt = fileName.toLowerCase().endsWith('.firewood') ||
          (filePath != null && filePath.toLowerCase().endsWith('.firewood'));

      if (!isFirewoodExt) {
        if (mounted) {
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
        builder: (context) {
          bool obscureModalPassword = true;
          return StatefulBuilder(
            builder: (context, setModalState) {
              return AlertDialog(
                backgroundColor: AppColors.surfaceZinc,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.borderZinc),
                ),
                title: Row(
                  children: [
                    AppIcon(AppIcons.upload, color: AppColors.orangeAccent, size: 22),
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
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter the master password used for "$fileName":',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Form(
                      key: formKey,
                      child: TextFormField(
                        controller: passwordController,
                        obscureText: obscureModalPassword,
                        autofocus: true,
                        style: const TextStyle(color: AppColors.offWhite),
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: 'Backup Password',
                          prefixIcon: AppIcon(AppInputIcons.lock, size: 20),
                          suffixIcon: IconButton(
                            icon: AppIcon(
                              obscureModalPassword ? AppInputIcons.eyeOff : AppInputIcons.eye,
                              size: 18,
                            ),
                            onPressed: () => setModalState(() => obscureModalPassword = !obscureModalPassword),
                          ),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Password required' : null,
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
                  ),
                  FilledButton(
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        Navigator.pop(context, passwordController.text);
                      }
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: const Text('Restore Vault'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (password == null || !mounted) return;

      setState(() => _isImporting = true);

      final targetPath = filePath ?? fileName;
      final importedVaultName = await _backupService.importVault(
        targetPath,
        password,
        overwrite: true,
      );

      final key = await _vaultService.unlock(password);
      ref.read(authProvider.notifier).state = key;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully imported vault: $importedVaultName'),
            backgroundColor: AppColors.orangeAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceAll('BackupException: ', '');
        setState(() => _error = 'Import failed: $errorMsg');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $errorMsg'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  int _calculatePasswordStrength(String password) {
    int score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'[a-z]'))) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) score++;
    return score.clamp(0, 5);
  }

  String _getStrengthLabel(int score) {
    switch (score) {
      case 0: return 'Very Weak';
      case 1: return 'Weak';
      case 2: return 'Fair';
      case 3: return 'Good';
      case 4: return 'Strong';
      case 5: return 'Very Strong';
      default: return 'Weak';
    }
  }

  Color _getStrengthColor(int score) {
    switch (score) {
      case 0:
      case 1: return Colors.redAccent;
      case 2: return Colors.orangeAccent;
      case 3: return Colors.amber;
      case 4: return Colors.lightGreenAccent;
      case 5: return Colors.greenAccent;
      default: return Colors.redAccent;
    }
  }

  Future<void> _createVault() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _vaultService.createVault(
        _passwordController.text,
        vaultName: 'Primary Vault',
      );

      // Auto-unlock - authProvider state update triggers _AuthGate to transition to HomeScreen
      final key = await _vaultService.unlock(_passwordController.text);
      ref.read(authProvider.notifier).state = key;
    } on VaultException catch (e) {
      setState(() => _error = e.message);
      HapticFeedback.heavyImpact();
    } catch (e) {
      setState(() => _error = 'Failed to create vault. Please try again.');
      HapticFeedback.heavyImpact();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final strength = _calculatePasswordStrength(_passwordController.text);

    return Scaffold(
      backgroundColor: AppColors.backgroundZinc,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.orangeAccent.withValues(alpha: 0.5),
                              width: 2,
                            ),
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/FWS.png',
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Firewood',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.offWhite,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Create master password to setup vault',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textMuted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),

                    // Form
                    Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Master Password Input
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: AppColors.offWhite, fontSize: 14),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              labelText: 'Master Password *',
                              prefixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 42),
                              prefixIcon: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: AppIcon(AppInputIcons.lock, size: 18, color: AppColors.textMuted),
                              ),
                              suffixIcon: IconButton(
                                icon: AppIcon(
                                  _obscurePassword ? AppInputIcons.eyeOff : AppInputIcons.eye,
                                  size: 18,
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              fillColor: AppColors.surfaceZinc,
                            ),
                            validator: (v) {
                              if (v == null || v.length < 8) {
                                return 'Minimum 8 characters required';
                              }
                              return null;
                            },
                            textInputAction: TextInputAction.next,
                            onChanged: (_) => setState(() {}),
                          ),

                          // Password strength indicator
                          if (_passwordController.text.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            _PasswordStrengthBar(
                              strength: strength,
                              label: _getStrengthLabel(strength),
                              color: _getStrengthColor(strength),
                            ),
                          ],

                          const SizedBox(height: 12),

                          // Confirm Password Input
                          TextFormField(
                            controller: _confirmController,
                            obscureText: _obscureConfirm,
                            style: const TextStyle(color: AppColors.offWhite, fontSize: 14),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              labelText: 'Confirm Password *',
                              prefixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 42),
                              prefixIcon: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: AppIcon(AppInputIcons.lockClock, size: 18, color: AppColors.textMuted),
                              ),
                              suffixIcon: IconButton(
                                icon: AppIcon(
                                  _obscureConfirm ? AppInputIcons.eyeOff : AppInputIcons.eye,
                                  size: 18,
                                ),
                                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                              ),
                              fillColor: AppColors.surfaceZinc,
                            ),
                            validator: (v) {
                              if (v != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _createVault(),
                          ),

                          // Error Display
                          if (_error != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: cs.errorContainer.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  AppIcon(AppIcons.alertCircle, color: cs.onErrorContainer, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: TextStyle(color: cs.onErrorContainer, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Actions Section
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Create Vault Button
                        AppButton(
                          label: _isLoading ? 'Creating Vault...' : 'Create Vault',
                          icon: AppIcons.shield,
                          variant: AppButtonVariant.primary,
                          isLoading: _isLoading,
                          fullWidth: true,
                          height: 52,
                          onPressed: (_isLoading || _isImporting) ? null : _createVault,
                        ),

                        const SizedBox(height: 12),

                        // Divider
                        Row(
                          children: [
                            Expanded(child: Divider(color: AppColors.borderZinc.withValues(alpha: 0.6))),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: Text(
                                'OR',
                                style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ),
                            Expanded(child: Divider(color: AppColors.borderZinc.withValues(alpha: 0.6))),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Import Backup Button
                        AppButton(
                          label: _isImporting ? 'Importing Backup...' : 'Import Backup (.firewood)',
                          icon: AppIcons.upload,
                          variant: AppButtonVariant.secondary,
                          isLoading: _isImporting,
                          fullWidth: true,
                          height: 48,
                          onPressed: (_isLoading || _isImporting) ? null : _importBackup,
                        ),
                      ],
                    ),

                    // Footnote
                    Text(
                      'Protected by Argon2id & XChaCha20-Poly1305 zero-knowledge encryption',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.textMuted.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordStrengthBar extends StatelessWidget {
  final int strength;
  final String label;
  final Color color;

  const _PasswordStrengthBar({
    required this.strength,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Strength: $label',
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: List.generate(5, (index) {
            final isActive = index < strength;
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: index < 4 ? 4 : 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: isActive
                      ? color
                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}