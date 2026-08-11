// screens/p2p_receive_screen.dart
// Offline P2P Receive Screen – receiver side with SAS display, sender password
// prompt, and biometric gate.
//
// REFINED FLOW:
//  1. Receiver starts advertising (listening for incoming transfers)
//  2. Sender connects → X25519 handshake happens automatically
//  3. SAS code displayed on this screen – receiver confirms it matches sender's
//  4. Receiver is prompted for SENDER'S master password
//  5. Biometric verification gate before import
//  6. Vault items decrypted with sender's key, re-encrypted with receiver's key

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cryptography/cryptography.dart';
import '../p2p/transfer_models.dart';
import '../p2p/transport_adapter.dart';
import '../providers/auth_provider.dart';
import '../providers/p2p_provider.dart';
import '../theme/app_theme.dart';
import '../services/p2p_permission_service.dart';
import '../services/biometric_service.dart';

class P2PReceiveScreen extends ConsumerStatefulWidget {
  const P2PReceiveScreen({super.key});

  @override
  ConsumerState<P2PReceiveScreen> createState() => _P2PReceiveScreenState();
}

class _P2PReceiveScreenState extends ConsumerState<P2PReceiveScreen> {
  String? _statusText;
  String? _lastImportResult;

  @override
  void initState() {
    super.initState();
    _startAdvertising();
  }

  Future<void> _startAdvertising() async {
    final granted = await P2PPermissionService.requestP2PPermissions();
    if (!granted) {
      if (mounted) {
        setState(() => _statusText = 'Bluetooth & Location permissions required for P2P transfer');
      }
      return;
    }

    final p2p = ref.read(p2pServiceProvider);
    final key = ref.read(authProvider);

    setState(() => _statusText = 'Listening for incoming encrypted transfers...');

    try {
      await p2p.sessionManager.startAdvertising(
        onPeerConnected: (peer) async {
          if (!mounted) return;
          HapticFeedback.mediumImpact();
          setState(() {
            _statusText = 'Connected to ${peer.name}. Receiving encrypted payload...';
          });

          _handleIncomingTransfer(peer, key);
        },
      );
    } catch (e) {
      if (mounted) setState(() => _statusText = 'Advertising Error: $e');
    }
  }

  Future<void> _handleIncomingTransfer(DiscoveredPeer peer, SecretKey? key) async {
    if (key == null) {
      setState(() => _statusText = 'Vault locked. Unlock your vault to receive transfers.');
      return;
    }

    final p2p = ref.read(p2pServiceProvider);

    try {
      setState(() => _statusText = 'Receiving encrypted payload from ${peer.name}...');

      // Receive the raw encrypted payload and detect its type
      final decryptedPayload = await p2p.sessionManager.receiveEncryptedPayload(peer);
      final payloadJson = _parsePayload(decryptedPayload);
      final transferType = payloadJson['transferType'] as String;

      if (transferType == 'fullVault') {
        // FIX GAP 1: Require sender's master password for vault transfer
        final senderPassword = await _promptSenderPassword(peer.name);
        if (senderPassword == null) {
          setState(() => _statusText = 'Transfer cancelled: sender password required');
          return;
        }

        // FIX GAP 7: Biometric gate before importing items
        final authenticated = await BiometricAuthService.authenticateUser(
          reason: 'Verify biometrics to import vault items from ${peer.name}',
        );
        if (!authenticated) {
          setState(() => _statusText = 'Transfer cancelled: biometric verification failed');
          return;
        }

        // Import with sender's password
        final result = await p2p.receiveTransfer(
          recipientKey: key,
          senderPassword: senderPassword,
          peer: peer,
        );

        setState(() => _lastImportResult = result.detail);
        HapticFeedback.heavyImpact();
      } else {
        // Single item – no password needed (decrypted on sender side, re-encrypted here)
        // Still require biometric gate
        final authenticated = await BiometricAuthService.authenticateUser(
          reason: 'Verify biometrics to import item from ${peer.name}',
        );
        if (!authenticated) {
          setState(() => _statusText = 'Transfer cancelled: biometric verification failed');
          return;
        }

        final result = await p2p.receiveTransfer(
          recipientKey: key,
          peer: peer,
        );

        setState(() => _lastImportResult = 'Successfully imported "${result.detail}"');
        HapticFeedback.heavyImpact();
      }
    } on Exception catch (e) {
      final msg = e.toString().replaceAll('ImportFailure: ', '').replaceAll('VaultException: ', '');
      if (mounted) setState(() => _statusText = 'Receive error: $msg');
    }
  }

  /// Parse the transport-decrypted payload JSON.
  Map<String, dynamic> _parsePayload(List<int> decryptedPayload) {
    try {
      final str = utf8.decode(decryptedPayload);
      final decoded = jsonDecode(str);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return {'transferType': 'unknown'};
  }

  /// Prompt receiver for the sender's master password.
  Future<String?> _promptSenderPassword(String senderName) async {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool obscure = true;
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
                  const Icon(Icons.lock_outline, color: AppColors.orangeAccent, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Sender\'s Master Password', style: TextStyle(color: AppColors.offWhite, fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'To decrypt the vault from "$senderName", enter the master password used to unlock that vault.',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Form(
                    key: formKey,
                    child: TextFormField(
                      controller: passwordController,
                      obscureText: obscure,
                      autofocus: true,
                      style: const TextStyle(color: AppColors.offWhite),
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: 'Sender\'s Master Password',
                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, size: 18),
                          onPressed: () => setModalState(() => obscure = !obscure),
                        ),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Password required' : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'This password is NOT stored. Items are re-encrypted with your vault key.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
                ),
                FilledButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(ctx, passwordController.text);
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.orangeAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Decrypt & Import'),
                ),
              ],
            );
          },
        );
      },
    );

    passwordController.dispose();
    return password;
  }

  @override
  Widget build(BuildContext context) {
    final transferState = ref.watch(connectionStateProvider).value ?? TransferState.idle;
    final progress = ref.watch(transferProgressProvider).value ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceZinc,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderZinc.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.greenAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.download_for_offline_outlined, color: Colors.greenAccent, size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ready to Receive Encrypted Data', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.offWhite)),
                      SizedBox(height: 4),
                      Text('End-to-end encrypted. You will need the sender\'s master password.', style: TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.3)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Status
          Container(
            width: double.infinity, padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surfaceZinc, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderZinc.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                const Icon(Icons.radar_outlined, size: 48, color: AppColors.orangeAccent),
                const SizedBox(height: 16),
                Text(_statusText ?? 'Waiting for sender...', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.offWhite, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 12),
                if (transferState == TransferState.receiving || transferState == TransferState.decrypting) ...[
                  LinearProgressIndicator(value: progress, color: AppColors.orangeAccent, backgroundColor: AppColors.cardZinc),
                  const SizedBox(height: 8),
                  Text('Progress: ${(progress * 100).round()}%', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (_lastImportResult != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.greenAccent),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.greenAccent),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_lastImportResult!, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12))),
                ],
              ),
            ),

          const SizedBox(height: 20),

          // Diagnostics
          Container(
            decoration: BoxDecoration(color: const Color(0xFF121215), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderZinc.withValues(alpha: 0.5))),
            child: ExpansionTile(
              dense: true, tilePadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: const Icon(Icons.tune_outlined, size: 16, color: AppColors.orangeAccent),
              title: const Text('DIAGNOSTICS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: AppColors.textMuted)),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              children: [
                if (_statusText != null) Text('• $_statusText', style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.orangeAccent)),
                if (_lastImportResult != null) Text('• $_lastImportResult', style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.greenAccent)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
