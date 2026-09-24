// screens/credential_view_screen.dart
// Protected screen to view credentials with Biometric / Master Password verification and Identity document support

import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../models/item_type.dart';
import '../services/item_service.dart';
import '../services/lock_service.dart';
import '../services/vault_service.dart';
import '../services/native_security_bridge.dart';
import 'package:hugeicons/hugeicons.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import 'item_detail_screen.dart';

class CredentialViewScreen extends ConsumerStatefulWidget {
  final SecretKey secretKey;
  final ItemService itemService;
  final DecryptedItem item;

  const CredentialViewScreen({
    super.key,
    required this.secretKey,
    required this.itemService,
    required this.item,
  });

  @override
  ConsumerState<CredentialViewScreen> createState() => _CredentialViewScreenState();
}

class _CredentialViewScreenState extends ConsumerState<CredentialViewScreen>
    with SingleTickerProviderStateMixin {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final VaultService _vaultService = VaultService();
  final _passwordController = TextEditingController();

  late DecryptedItem _currentItem;
  bool _isUnlocked = false;
  bool _isAuthenticating = false;
  String? _authError;
  bool _canCheckBiometrics = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final Set<String> _revealedFields = {};

  @override
  void initState() {
    super.initState();
    _currentItem = widget.item;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _checkBiometricsSupport();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricsSupport() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      if (mounted) {
        setState(() {
          _canCheckBiometrics = canCheck && isDeviceSupported;
        });
      }
      if (_canCheckBiometrics) {
        _authenticateBiometric();
      }
    } catch (_) {
      if (mounted) setState(() => _canCheckBiometrics = false);
    }
  }

  Future<void> _authenticateBiometric() async {
    setState(() {
      _isAuthenticating = true;
      _authError = null;
    });

    try {
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Scan biometrics to view ${_currentItem.title} credentials',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (didAuthenticate && mounted) {
        HapticFeedback.mediumImpact();
        setState(() {
          _isUnlocked = true;
          _isAuthenticating = false;
        });
        _animationController.forward();
      } else {
        if (mounted) {
          setState(() {
            _isAuthenticating = false;
            _authError = 'Biometric authentication canceled or failed';
          });
        }
      }
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
          _authError = 'Biometric error: ${e.message ?? e.code}';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
          _authError = 'Authentication failed';
        });
      }
    }
  }

  Future<void> _authenticatePassword() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) return;

    // Rate limiting covers every authN entry point (REQ-AUTH-02), not just
    // the unlock screen.
    try {
      final lockout = await NativeSecurityBridge.getLockoutStatus();
      if (lockout.isLockedOut && mounted) {
        setState(() {
          _isAuthenticating = false;
          _authError = 'Too many failed attempts. Wait ${lockout.lockoutRemainingMs ~/ 1000}s.';
        });
        return;
      }
    } catch (_) {}

    setState(() {
      _isAuthenticating = true;
      _authError = null;
    });

    try {
      await _vaultService.unlock(password);
      try {
        await NativeSecurityBridge.resetFailedAttempts();
      } catch (_) {}
      if (mounted) {
        HapticFeedback.mediumImpact();
        setState(() {
          _isUnlocked = true;
          _isAuthenticating = false;
        });
        _animationController.forward();
      }
    } on VaultException catch (e) {
      try {
        await NativeSecurityBridge.recordFailedUnlockAttempt();
      } catch (_) {}
      if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() {
          _isAuthenticating = false;
          _authError = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() {
          _isAuthenticating = false;
          _authError = 'Invalid master password';
        });
      }
    }
  }

  Future<void> _openEditScreen() async {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (!_isUnlocked) {
      if (_canCheckBiometrics) {
        await _authenticateBiometric();
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Please unlock credential first to edit')),
        );
        return;
      }
    }

    if (!_isUnlocked) return;

    await nav.push(
      MaterialPageRoute(
        builder: (_) => ItemDetailScreen(
          secretKey: widget.secretKey,
          itemService: widget.itemService,
          existingItem: _currentItem,
        ),
      ),
    );

    // Refresh current item after edit
    try {
      final items = await widget.itemService.getAllItems(widget.secretKey);
      final updated = items.firstWhere(
        (it) => it.itemId == _currentItem.itemId,
        orElse: () => _currentItem,
      );
      if (mounted) {
        setState(() {
          _currentItem = updated;
        });
      }
    } catch (_) {}
  }

  void _copyToClipboard(String label, String value) {
    if (value.isNotEmpty) {
      ref.read(lockServiceProvider).copySecret(value);
      HapticFeedback.selectionClick();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              AppIcon(AppIcons.checkCircle, color: Colors.greenAccent, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('Copied $label (clears in 30s)')),
            ],
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showImageDialog(String base64Image) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullscreenImageViewer(base64Image: base64Image),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemType = ItemTypeExt.fromString(_currentItem.type);

    return Scaffold(
      backgroundColor: AppColors.backgroundZinc,
      appBar: AppBar(
        title: Text(_currentItem.title),
        actions: [
          IconButton(
            icon: AppIcon(HugeIcons.strokeRoundedEdit01, size: 20),
            tooltip: 'Edit Credential',
            onPressed: _openEditScreen,
          ),
        ],
      ),
      body: _isUnlocked ? _buildCredentialDetails(itemType) : _buildLockPrompt(itemType),
    );
  }

  Widget _buildLockPrompt(ItemType itemType) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(
                AppIcons.shield,
                size: 64,
              ),
              const SizedBox(height: 24),
              Text(
                'Protected Credential',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.offWhite,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Verify your identity to unlock and view saved details for "${_currentItem.title}"',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textMuted,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              if (_authError != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      AppIcon(AppIcons.alertCircle, color: Colors.redAccent, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _authError!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              if (_canCheckBiometrics) ...[
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: _isAuthenticating ? null : _authenticateBiometric,
                    icon: _isAuthenticating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : AppIcon(HugeIcons.strokeRoundedFingerPrint, size: 22),
                    label: const Text('Scan Biometrics to Unlock'),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Expanded(child: Divider(color: AppColors.borderZinc)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('OR USE PASSWORD',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    Expanded(child: Divider(color: AppColors.borderZinc)),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Master Password',
                  prefixIcon: AppIcon(AppInputIcons.lock),
                ),
                onSubmitted: (_) => _authenticatePassword(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _isAuthenticating ? null : _authenticatePassword,
                  icon: AppIcon(HugeIcons.strokeRoundedLockPassword, color: AppColors.orangeAccent, size: 20),
                  label: const Text('Unlock with Master Password',
                      style: TextStyle(color: AppColors.offWhite, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.borderZinc),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCredentialDetails(ItemType itemType) {
    final fields = Map<String, dynamic>.from(_currentItem.fields);
    final String? idImage = fields.remove('id_image')?.toString();
    // Exclude metadata timestamps since they are shown exclusively in the Metadata section
    fields.removeWhere((k, _) {
      final clean = k.toLowerCase().replaceAll(' ', '').replaceAll('_', '');
      return clean == 'createdat' || clean == 'updatedat' || clean == 'timestamp';
    });

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
        children: [
          // Header Card
          Card(
            color: AppColors.surfaceZinc,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.borderZinc),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.orangeContainer,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.orangeBorder),
                    ),
                    child: AppIcon(
                      _getTypeIcon(itemType),
                      size: 32,
                      color: AppColors.orangeAccent,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentItem.title,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.offWhite,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.cardZinc,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.borderZinc),
                          ),
                          child: Text(
                            itemType.label.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.orangeAccent,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Quick Action Bar
          Row(
            children: [
              if (fields.containsKey('username')) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copyToClipboard('Username', fields['username'].toString()),
                    icon: AppIcon(HugeIcons.strokeRoundedUser, size: 16, color: AppColors.orangeAccent),
                    label: const Text('User', style: TextStyle(fontSize: 12, color: AppColors.offWhite)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: const BorderSide(color: AppColors.borderZinc),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (fields.containsKey('password')) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copyToClipboard('Password', fields['password'].toString()),
                    icon: AppIcon(HugeIcons.strokeRoundedKey01, size: 16, color: AppColors.orangeAccent),
                    label: const Text('Pass', style: TextStyle(fontSize: 12, color: AppColors.offWhite)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: const BorderSide(color: AppColors.borderZinc),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              Expanded(
                child: FilledButton.icon(
                  onPressed: _openEditScreen,
                  icon: AppIcon(HugeIcons.strokeRoundedEdit01, size: 16),
                  label: const Text('Edit', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ID Document Image preview if present
          if (idImage != null) ...[
            Text(
              'IDENTITY DOCUMENT ATTACHMENT',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textMuted,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _showImageDialog(idImage),
              child: Card(
                color: AppColors.surfaceZinc,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.borderZinc),
                ),
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Image.memory(
                      base64Decode(idImage),
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                    Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppIcon(AppIcons.search, color: Colors.white, size: 14),
                          const SizedBox(width: 6),
                          const Text('Tap to expand', style: TextStyle(color: Colors.white, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          Text(
            'DECRYPTED CREDENTIALS',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.textMuted,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),

          // Stored fields
          ...fields.entries.map((entry) {
            final key = entry.key;
            final val = entry.value.toString();
            final isSensitive = key.toLowerCase().contains('password') ||
                key.toLowerCase().contains('cvv') ||
                key.toLowerCase().contains('pin') ||
                key.toLowerCase().contains('secret') ||
                key.toLowerCase().contains('id_number');
            final isRevealed = _revealedFields.contains(key);

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: AppColors.surfaceZinc,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.borderZinc),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          key.replaceAll('_', ' ').toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textMuted,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const Spacer(),
                        if (isSensitive)
                          IconButton(
                            icon: AppIcon(
                              isRevealed ? AppInputIcons.eyeOff : AppInputIcons.eye,
                              size: 18,
                              color: AppColors.textMuted,
                            ),
                            onPressed: () {
                              setState(() {
                                if (isRevealed) {
                                  _revealedFields.remove(key);
                                } else {
                                  _revealedFields.add(key);
                                }
                              });
                            },
                          ),
                        IconButton(
                          icon: AppIcon(AppInputIcons.copy, size: 18, color: AppColors.orangeAccent),
                          onPressed: () => _copyToClipboard(key, val),
                          tooltip: 'Copy $key',
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      isSensitive && !isRevealed ? '••••••••••••••••' : val,
                      style: TextStyle(
                        fontSize: 15,
                        fontFamily: isSensitive && !isRevealed ? null : 'Monospace',
                        fontWeight: FontWeight.w600,
                        color: AppColors.offWhite,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 12),
          Text(
            'METADATA & TIMESTAMPS',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.textMuted,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceZinc,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderZinc.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    AppIcon(AppIcons.calendar, size: 16, color: AppColors.textMuted),
                    const SizedBox(width: 8),
                    const Text('Created At', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    const Spacer(),
                    Text(_formatDateTime(_currentItem.createdAt), style: const TextStyle(fontSize: 12, color: AppColors.offWhite, fontWeight: FontWeight.w600)),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(color: AppColors.borderZinc, height: 1),
                ),
                Row(
                  children: [
                    AppIcon(AppIcons.history, size: 16, color: AppColors.textMuted),
                    const SizedBox(width: 8),
                    const Text('Last Updated', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    const Spacer(),
                    Text(_formatDateTime(_currentItem.updatedAt), style: TextStyle(fontSize: 12, color: AppColors.orangeAccent, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final year = dt.year;
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = (dt.hour % 12 == 0 ? 12 : dt.hour % 12).toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$year-$month-$day  $hour:$minute $ampm';
  }

  dynamic _getTypeIcon(ItemType type) {
    switch (type) {
      case ItemType.login:
        return AppIcons.typeLogin;
      case ItemType.card:
        return AppIcons.typeCard;
      case ItemType.identity:
        return AppIcons.typeIdentity;
      case ItemType.note:
        return AppIcons.typeNote;
      case ItemType.developerSecret:
        return AppIcons.typeDeveloperSecret;
    }
  }
}

class _FullscreenImageViewer extends StatefulWidget {
  final String base64Image;
  const _FullscreenImageViewer({required this.base64Image});

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  final TransformationController _transformationController = TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    if (_transformationController.value != Matrix4.identity()) {
      _transformationController.value = Matrix4.identity();
      HapticFeedback.lightImpact();
    } else {
      final position = _doubleTapDetails?.localPosition ?? Offset.zero;
      _transformationController.value = Matrix4.identity()
        ..translate(-position.dx * 1.5, -position.dy * 1.5)
        ..scale(2.5);
      HapticFeedback.mediumImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.8),
        elevation: 0,
        leading: IconButton(
          icon: AppIcon(AppIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Identity Document Preview', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: AppIcon(HugeIcons.strokeRoundedRefresh, color: Colors.white70),
            tooltip: 'Reset Zoom',
            onPressed: () {
              _transformationController.value = Matrix4.identity();
              HapticFeedback.selectionClick();
            },
          ),
        ],
      ),
      body: GestureDetector(
        onDoubleTapDown: (details) => _doubleTapDetails = details,
        onDoubleTap: _handleDoubleTap,
        child: Center(
          child: InteractiveViewer(
            transformationController: _transformationController,
            minScale: 1.0,
            maxScale: 4.0,
            child: Image.memory(
              base64Decode(widget.base64Image),
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        ),
      ),
    );
  }
}
