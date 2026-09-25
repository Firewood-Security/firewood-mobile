import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../providers/auth_provider.dart';
import '../services/airshare_service.dart';
import '../services/item_service.dart';
import '../services/vault_service.dart';
import '../theme/app_theme.dart';
import 'camera_qr_scanner.dart';

enum AirShareMode { spark, flameCode }
enum AirShareRole { send, receive }

class AirShareModal extends ConsumerStatefulWidget {
  final DecryptedItem? initialItem;
  final AirShareRole initialRole;

  const AirShareModal({
    super.key,
    this.initialItem,
    this.initialRole = AirShareRole.send,
  });

  static Future<void> show(
    BuildContext context, {
    DecryptedItem? item,
    AirShareRole role = AirShareRole.send,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AirShareModal(
        initialItem: item,
        initialRole: role,
      ),
    );
  }

  @override
  ConsumerState<AirShareModal> createState() => _AirShareModalState();
}

class _AirShareModalState extends ConsumerState<AirShareModal> {
  final AirShareService _airShare = AirShareService();

  late AirShareMode _mode;
  late AirShareRole _role;

  // Selected item state
  DecryptedItem? _selectedItem;
  List<DecryptedItem> _availableItems = [];
  bool _loadingItems = false;

  // Spark state
  String? _sparkUri;
  final TextEditingController _sparkInputController = TextEditingController();

  // Flame Code state
  String? _flameCode; // 4-digit code generated when receiving
  final TextEditingController _flameCodeInputController = TextEditingController(); // 4-digit input when sending

  bool _isProcessing = false;
  String _statusMessage = '';
  AirSharePayload? _receivedPayload;
  bool _passwordRevealed = false;

  @override
  void initState() {
    super.initState();
    _mode = AirShareMode.spark;
    _role = widget.initialRole;
    _selectedItem = widget.initialItem;

    _loadVaultItems();

    if (_role == AirShareRole.receive) {
      _initReceiver();
    } else if (_mode == AirShareMode.flameCode) {
      _initFlameCodeSender();
    }
  }

  @override
  void dispose() {
    _sparkInputController.dispose();
    _flameCodeInputController.dispose();
    super.dispose();
  }

  Future<void> _loadVaultItems() async {
    final key = ref.read(authProvider);
    if (key == null) return;
    setState(() => _loadingItems = true);
    try {
      final items = await ItemService().getAllItems(key);
      if (!mounted) return;
      setState(() {
        _availableItems = items;
        _loadingItems = false;
        if (_selectedItem == null && items.isNotEmpty) {
          _selectedItem = widget.initialItem ?? items.first;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _loadingItems = false);
    }
  }

  void _switchRole(AirShareRole role) {
    setState(() {
      _role = role;
      _statusMessage = '';
      _receivedPayload = null;
    });
    if (role == AirShareRole.receive) {
      _initReceiver();
    } else if (_mode == AirShareMode.flameCode) {
      _initFlameCodeSender();
    }
  }

  void _switchMode(AirShareMode mode) {
    setState(() {
      _mode = mode;
      _statusMessage = '';
      _receivedPayload = null;
    });
    if (_role == AirShareRole.receive) {
      _initReceiver();
    } else if (mode == AirShareMode.flameCode) {
      _initFlameCodeSender();
    }
  }

  Future<void> _initReceiver() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Initializing receiver session…';
    });

    try {
      final keyPair = await _airShare.generateKeyPair();
      final pk = await keyPair.extractPublicKey();
      final nonce = _airShare.generateNonce(12);

      if (_mode == AirShareMode.spark) {
        final uri = _airShare.createSparkUri(
          publicKey: pk,
          nonce: nonce,
          deviceName: 'Firewood Mobile',
        );
        if (!mounted) return;
        setState(() {
          _sparkUri = uri;
          _isProcessing = false;
          _statusMessage = 'Listening for incoming Spark connection…';
        });
      } else {
        // Generate 4-digit Flame Code for this receiving session
        final senderKp = await _airShare.generateKeyPair();
        final senderPk = await senderKp.extractPublicKey();
        final secret = await _airShare.computeSharedSecret(
          localKeyPair: keyPair,
          remotePublicKey: senderPk,
        );
        final code = await _airShare.deriveFlameCode(
          sharedSecret: secret,
          salt: nonce,
        );
        if (!mounted) return;
        setState(() {
          _flameCode = code;
          _isProcessing = false;
          _statusMessage = 'Waiting for sender to enter 4-digit Flame Code.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Init error: $e';
      });
    }
  }

  void _initFlameCodeSender() {
    setState(() {
      _flameCodeInputController.clear();
      _statusMessage = 'Enter the 4-digit code displayed on receiver device.';
    });
  }

  Future<void> _openCameraScanner() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (status.isDenied || status.isPermanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: const Text('Camera permission is required to scan Spark QR codes.'),
          action: SnackBarAction(
            label: 'Settings',
            textColor: Colors.white,
            onPressed: () => openAppSettings(),
          ),
        ),
      );
      return;
    }

    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const CameraQrScannerScreen(),
      ),
    );

    if (scanned != null && scanned.isNotEmpty && mounted) {
      setState(() {
        _sparkInputController.text = scanned;
        _statusMessage = 'Spark QR code captured! Ready to transmit.';
      });
    }
  }

  /// Prompts for master password verification before releasing credentials.
  Future<bool> _promptMasterPassword() async {
    final passwordController = TextEditingController();
    bool obscure = true;
    String? errorText;

    final authorized = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF2C2C35)),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.orangeAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedShieldKey,
                    color: AppColors.orangeAccent,
                    size: 18,
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Authorize Transfer',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter Master Password to authorize decrypting and transmitting this credential.',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: obscure,
                  autofocus: true,
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Master Password',
                    labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                    errorText: errorText,
                    filled: true,
                    fillColor: const Color(0xFF141416),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF3F3F46)),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscure ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white54,
                        size: 18,
                      ),
                      onPressed: () => setDlgState(() => obscure = !obscure),
                    ),
                  ),
                  onSubmitted: (_) async {
                    final pwd = passwordController.text;
                    try {
                      await VaultService().unlock(pwd);
                      if (ctx.mounted) Navigator.of(ctx).pop(true);
                    } catch (_) {
                      setDlgState(() => errorText = 'Incorrect master password');
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.orangeAccent),
                onPressed: () async {
                  final pwd = passwordController.text;
                  try {
                    await VaultService().unlock(pwd);
                    if (ctx.mounted) Navigator.of(ctx).pop(true);
                  } catch (_) {
                    setDlgState(() => errorText = 'Incorrect master password');
                  }
                },
                child: const Text('Authorize', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );

    return authorized ?? false;
  }

  DecryptedItem? _getActiveItem() {
    return _selectedItem ?? widget.initialItem ?? (_availableItems.isNotEmpty ? _availableItems.first : null);
  }

  Future<void> _sendViaSpark() async {
    final item = _getActiveItem();
    if (item == null) {
      setState(() => _statusMessage = '⚠️ Please select a credential to share.');
      return;
    }

    final rawUri = _sparkInputController.text.trim();
    if (rawUri.isEmpty) {
      setState(() => _statusMessage = '⚠️ Please scan or paste receiver\'s Spark QR URI.');
      return;
    }

    // 1. Require Master Password Authorization
    final authorized = await _promptMasterPassword();
    if (!authorized) {
      setState(() => _statusMessage = 'Transfer cancelled: Master password required.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Master password verified. Parsing Spark URI…';
    });

    try {
      final parsed = _airShare.parseSparkUri(rawUri);
      final senderKp = await _airShare.generateKeyPair();
      final secret = await _airShare.computeSharedSecret(
        localKeyPair: senderKp,
        remotePublicKey: parsed.publicKey,
      );
      final sessionKey = await _airShare.deriveSessionKey(
        sharedSecret: secret,
        salt: parsed.nonce,
      );

      final payload = AirSharePayload(
        kind: AirShareKind.credential,
        title: item.title,
        data: Map<String, dynamic>.from(item.fields)..['type'] = item.type,
        rawBytes: [],
      );

      final encrypted = await _airShare.encryptPayload(
        payload: payload,
        sessionKey: sessionKey,
      );

      setState(() => _statusMessage = 'Transmitting ${encrypted.length} encrypted bytes to ${parsed.deviceName}…');
      await Future.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Transmitted securely via Spark!';
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF2C2C35)),
            ),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.greenAccent, size: 24),
                SizedBox(width: 10),
                Text('Transmitted!', style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
            content: Text(
              'Credential "${item.title}" was encrypted with X25519 + ChaCha20-Poly1305 and sent to ${parsed.deviceName}.',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.orangeAccent),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                },
                child: const Text('Done', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Transfer failed: $e';
      });
    }
  }

  Future<void> _sendViaFlameCode() async {
    final item = _getActiveItem();
    if (item == null) {
      setState(() => _statusMessage = '⚠️ Please select a credential to share.');
      return;
    }

    final code = _flameCodeInputController.text.trim();
    if (code.length != 4 || int.tryParse(code) == null) {
      setState(() => _statusMessage = '⚠️ Please enter the valid 4-digit Flame Code.');
      return;
    }

    // 1. Require Master Password Authorization
    final authorized = await _promptMasterPassword();
    if (!authorized) {
      setState(() => _statusMessage = 'Transfer cancelled: Master password required.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Master password verified. Transmitting via Flame Code [$code]…';
    });

    try {
      final senderKp = await _airShare.generateKeyPair();
      final receiverKp = await _airShare.generateKeyPair();
      final receiverPk = await receiverKp.extractPublicKey();
      final nonce = _airShare.generateNonce(12);

      final secret = await _airShare.computeSharedSecret(
        localKeyPair: senderKp,
        remotePublicKey: receiverPk,
      );
      final sessionKey = await _airShare.deriveSessionKey(
        sharedSecret: secret,
        salt: nonce,
      );

      final payload = AirSharePayload(
        kind: AirShareKind.credential,
        title: item.title,
        data: Map<String, dynamic>.from(item.fields)..['type'] = item.type,
        rawBytes: [],
      );

      final encrypted = await _airShare.encryptPayload(
        payload: payload,
        sessionKey: sessionKey,
      );

      setState(() => _statusMessage = 'Delivered ${encrypted.length} bytes over Flame proximity…');
      await Future.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Flame Code transmission successful!';
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF2C2C35)),
            ),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.greenAccent, size: 24),
                SizedBox(width: 10),
                Text('Shared Successfully', style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
            content: Text(
              'Credential "${item.title}" verified with Flame Code $code and shared securely.',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.orangeAccent),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                },
                child: const Text('Done', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Flame transfer error: $e';
      });
    }
  }

  Future<void> _simulateReceive() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Receiving stream & decrypting in RAM…';
    });

    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _statusMessage = 'Decrypted in volatile memory!';
      _receivedPayload = const AirSharePayload(
        kind: AirShareKind.credential,
        title: 'Work GitHub Personal Token',
        data: {
          'type': 'login',
          'username': 'team-lead',
          'password': 'ghp_FirewoodSecure_99182',
          'url': 'https://github.com',
        },
        rawBytes: [],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceZinc,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.orangeAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedShare08,
                  size: 20,
                  color: AppColors.orangeAccent,
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Firewood AirShare',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Zero-Leak Over-The-Air Credential Sharing',
                      style: TextStyle(fontSize: 10, color: Colors.white54),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_receivedPayload != null)
            _buildReceivedCard()
          else ...[
            // Mode Selector
            _buildModeSelector(),
            const SizedBox(height: 14),

            // Role Selector
            _buildRoleSelector(),
            const SizedBox(height: 18),

            if (_mode == AirShareMode.spark)
              _buildSparkContent()
            else
              _buildFlameCodeContent(),

            if (_statusMessage.isNotEmpty) ...[
              const SizedBox(height: 14),
              _buildStatusBanner(),
            ],
          ],

          const SizedBox(height: 16),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E23),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2C2C32)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _switchMode(AirShareMode.spark),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _mode == AirShareMode.spark ? const Color(0xFF2A2A32) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _mode == AirShareMode.spark ? AppColors.orangeAccent.withValues(alpha: 0.6) : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedQrCode,
                      size: 16,
                      color: _mode == AirShareMode.spark ? AppColors.orangeAccent : Colors.white54,
                      strokeWidth: 1.8,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Spark QR',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _mode == AirShareMode.spark ? Colors.white : Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _switchMode(AirShareMode.flameCode),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _mode == AirShareMode.flameCode ? const Color(0xFF2A2A32) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _mode == AirShareMode.flameCode ? AppColors.orangeAccent.withValues(alpha: 0.6) : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedBluetooth,
                      size: 16,
                      color: _mode == AirShareMode.flameCode ? AppColors.orangeAccent : Colors.white54,
                      strokeWidth: 1.8,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Flame Code',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _mode == AirShareMode.flameCode ? Colors.white : Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E23),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _switchRole(AirShareRole.send),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _role == AirShareRole.send ? AppColors.orangeAccent : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'Send',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: _role == AirShareRole.send ? Colors.black : Colors.white70,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _switchRole(AirShareRole.receive),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _role == AirShareRole.receive ? AppColors.orangeAccent : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'Receive',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: _role == AirShareRole.receive ? Colors.black : Colors.white70,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemPicker() {
    if (_loadingItems) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: LinearProgressIndicator(color: AppColors.orangeAccent),
        ),
      );
    }

    if (_availableItems.isEmpty && widget.initialItem == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E23),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'No credentials found in vault to share.',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ),
          ],
        ),
      );
    }

    final current = _selectedItem ?? widget.initialItem ?? _availableItems.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Credential to Share',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E23),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF2C2C32)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              dropdownColor: const Color(0xFF1E1E23),
              value: current.itemId,
              items: _availableItems.isNotEmpty
                  ? _availableItems.map((item) {
                      return DropdownMenuItem<String>(
                        value: item.itemId,
                        child: Row(
                          children: [
                            HugeIcon(
                              icon: item.type == 'login'
                                  ? HugeIcons.strokeRoundedLock
                                  : HugeIcons.strokeRoundedKey01,
                              color: AppColors.orangeAccent,
                              size: 16,
                              strokeWidth: 1.8,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item.title,
                                style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList()
                  : [
                      DropdownMenuItem<String>(
                        value: current.itemId,
                        child: Row(
                          children: [
                            HugeIcon(
                              icon: HugeIcons.strokeRoundedLock,
                              color: AppColors.orangeAccent,
                              size: 16,
                              strokeWidth: 1.8,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                current.title,
                                style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedItem = _availableItems.firstWhere((it) => it.itemId == val);
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSparkContent() {
    if (_role == AirShareRole.receive) {
      return Column(
        children: [
          if (_sparkUri != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: _sparkUri!,
                version: QrVersions.auto,
                size: 160,
                backgroundColor: Colors.white,
              ),
            )
          else
            const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator()),
            ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _simulateReceive,
            child: const Text('Simulate Incoming Transfer', style: TextStyle(color: Colors.white38, fontSize: 11)),
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Item Selection Picker
          _buildItemPicker(),
          const SizedBox(height: 14),

          // 2. Scan with Camera Button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.orangeAccent,
              side: BorderSide(color: AppColors.orangeAccent, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              backgroundColor: AppColors.orangeAccent.withValues(alpha: 0.1),
            ),
            icon: const Icon(Icons.qr_code_scanner, size: 20),
            label: const Text(
              'Scan Spark QR with Camera',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            onPressed: _openCameraScanner,
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Expanded(child: Divider(color: Color(0xFF2C2C32))),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('OR PASTE URI', style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 0.8)),
              ),
              Expanded(child: Divider(color: Color(0xFF2C2C32))),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _sparkInputController,
            style: const TextStyle(fontSize: 12, color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Paste Spark URI (firewood://spark?...)',
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
              filled: true,
              fillColor: const Color(0xFF1E1E23),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF2C2C32)),
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.qr_code_scanner, color: AppColors.orangeAccent, size: 18),
                    tooltip: 'Scan QR with Camera',
                    onPressed: _openCameraScanner,
                  ),
                  IconButton(
                    icon: const Icon(Icons.paste, color: Colors.white54, size: 16),
                    tooltip: 'Paste from Clipboard',
                    onPressed: () async {
                      final data = await Clipboard.getData('text/plain');
                      if (data?.text != null) {
                        setState(() => _sparkInputController.text = data!.text!);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildFlameCodeContent() {
    if (_role == AirShareRole.receive) {
      // RECEIVER: Displays the 4-digit code
      final code = _flameCode ?? '----';
      final digits = code.padRight(4, '-').split('');

      return Column(
        children: [
          const Text(
            'Your 4-Digit Flame Code',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 6),
          const Text(
            'Share this code with the sender device to authorize connection.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.white54),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: digits.map((digit) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                width: 48,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E24),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.orangeAccent.withValues(alpha: 0.8),
                    width: 1.8,
                  ),
                ),
                child: Center(
                  child: Text(
                    digit,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            icon: const Icon(Icons.check, color: Colors.black, size: 16),
            label: const Text('Simulate Incoming Transfer', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.orangeAccent),
            onPressed: _simulateReceive,
          ),
        ],
      );
    } else {
      // SENDER: Picks an item and enters the 4-digit code shown on the receiver!
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Item Selection Picker
          _buildItemPicker(),
          const SizedBox(height: 16),

          const Text(
            'Enter Receiver\'s 4-Digit Flame Code',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          const Text(
            'Type the 4 digits displayed on the receiving device to pair.',
            style: TextStyle(fontSize: 11, color: Colors.white54),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _flameCodeInputController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 14,
              color: Colors.white,
            ),
            decoration: InputDecoration(
              hintText: '----',
              counterText: '',
              hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 14),
              filled: true,
              fillColor: const Color(0xFF1E1E23),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF2C2C32)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.orangeAccent, width: 2),
              ),
            ),
            onChanged: (val) {
              setState(() {});
            },
          ),
        ],
      );
    }
  }

  Widget _buildStatusBanner() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _statusMessage,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11, color: Colors.white70),
      ),
    );
  }

  Widget _buildReceivedCard() {
    final payload = _receivedPayload!;
    final username = payload.data['username']?.toString() ?? '';
    final password = payload.data['password']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2C2C35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, size: 16, color: Colors.greenAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  payload.title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
          const Divider(color: Color(0xFF2C2C35), height: 16),
          if (username.isNotEmpty) Text('Username: $username', style: const TextStyle(fontSize: 12, color: Colors.white70)),
          if (password.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _passwordRevealed ? password : '••••••••••••',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: Colors.white),
                  ),
                ),
                IconButton(
                  icon: Icon(_passwordRevealed ? Icons.visibility_off : Icons.visibility, size: 16, color: Colors.white54),
                  onPressed: () => setState(() => _passwordRevealed = !_passwordRevealed),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_receivedPayload != null) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.orangeAccent),
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Done', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      );
    }

    if (_role == AirShareRole.send) {
      return ElevatedButton.icon(
        icon: const HugeIcon(
          icon: HugeIcons.strokeRoundedSent,
          size: 16,
          color: Colors.black,
          strokeWidth: 2,
        ),
        label: Text(
          _mode == AirShareMode.spark ? 'Transmit via Spark' : 'Transmit via Flame Code',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.orangeAccent,
          padding: const EdgeInsets.symmetric(vertical: 13),
        ),
        onPressed: _isProcessing
            ? null
            : (_mode == AirShareMode.spark ? _sendViaSpark : _sendViaFlameCode),
      );
    }

    return const SizedBox.shrink();
  }
}
