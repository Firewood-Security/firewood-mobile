// screens/p2p_share_screen.dart
// Offline P2P Share Screen – sender side with SAS display + mutual verification
//
// REFINED FLOW:
//  1. Sender selects item or full vault
//  2. Sender scans for nearby devices (BLE/Wi-Fi)
//  3. Sender selects target device
//  4. Biometric verification gate
//  5. X25519 handshake + encrypted transfer
//  6. SAS code displayed: sender reads it aloud; receiver confirms match
//  7. Transfer completes; items NEVER decrypted on sender for full vault

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../p2p/transfer_models.dart';
import '../p2p/transport_adapter.dart';
import '../providers/auth_provider.dart';
import '../providers/p2p_provider.dart';
import '../database/isar_service.dart';
import '../database/schemas.dart';
import '../services/item_service.dart';
import '../services/p2p_size_limit_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_3d_button.dart';
import '../services/p2p_permission_service.dart';
import '../services/biometric_service.dart';
import '../services/device_identity_service.dart';
import '../services/native_security_bridge.dart';

class P2PShareScreen extends ConsumerStatefulWidget {
  const P2PShareScreen({super.key});

  @override
  ConsumerState<P2PShareScreen> createState() => _P2PShareScreenState();
}

class _P2PShareScreenState extends ConsumerState<P2PShareScreen> {
  final ItemService _itemService = ItemService();
  final List<DiscoveredPeer> _discoveredPeers = [];
  DecryptedItem? _selectedItem;
  bool _shareFullVault = false;
  bool _isTransferring = false;
  String? _statusText;
  String? _sasCode;
  bool _preferWifi = false;
  bool _wifiAvailable = false;
  bool _wifiEnabled = false;
  bool _bluetoothEnabled = true;

  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _startDiscovery();
  }

  Future<void> _refreshDevices() async {
    if (_isRefreshing) return;
    HapticFeedback.lightImpact();

    setState(() {
      _isRefreshing = true;
      _discoveredPeers.clear();
      _statusText = 'Rescanning for nearby Firewood devices...';
    });

    try {
      await _startDiscovery();
    } finally {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) setState(() => _isRefreshing = false);
        });
      }
    }
  }

  void _showRadioPrompt(String radio) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$radio is turned off. Enable it in device Settings to use this transport.'),
        backgroundColor: AppColors.surfaceZinc,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          textColor: AppColors.orangeAccent,
          onPressed: () {},
        ),
      ),
    );
  }

  List<DiscoveredPeer> get _filteredPeers {
    // Show all discovered peers (LAN and Bluetooth) so none are hidden from user
    return List.unmodifiable(_discoveredPeers);
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'login': return Icons.login;
      case 'card': return Icons.credit_card;
      case 'identity': return Icons.badge_outlined;
      case 'note': return Icons.note_outlined;
      default: return Icons.lock_outline;
    }
  }

  Future<void> _startDiscovery() async {
    final granted = await P2PPermissionService.requestP2PPermissions();
    if (!granted) {
      if (mounted) {
        setState(() => _statusText = 'Bluetooth & Location permissions required for P2P transfer');
      }
      return;
    }

    final p2p = ref.read(p2pServiceProvider);
    final ourDeviceId = await DeviceIdentityService.getDeviceId();

    // Check radio & network states
    final lanAvailable = await LanSocketTransport.isLanAvailable();
    final wifiOn = await NativeSecurityBridge.isWifiEnabled();
    final btOn = await NativeSecurityBridge.isBluetoothEnabled();
    if (mounted) {
      setState(() {
        _wifiAvailable = lanAvailable || wifiOn;
        _wifiEnabled = wifiOn || lanAvailable;
        _bluetoothEnabled = btOn;
      });
    }

    try {
      await p2p.sessionManager.startDiscovery(
        onPeerFound: (peer) {
          if (peer.id == ourDeviceId) return;

          // Track WiFi availability
          if (peer.ipAddress != null && !_wifiAvailable) {
            setState(() => _wifiAvailable = true);
          }

          final index = _discoveredPeers.indexWhere(
              (p) => p.id == peer.id || (peer.ipAddress != null && p.ipAddress == peer.ipAddress));
          if (index == -1) {
            setState(() => _discoveredPeers.add(peer));
          } else {
            setState(() => _discoveredPeers[index] = peer);
          }
        },
      );
    } catch (e) {
      if (mounted) setState(() => _statusText = 'Discovery Error: $e');
    }
  }

  Future<void> _initiateTransfer(DiscoveredPeer peer) async {
    final key = ref.read(authProvider);
    if (key == null) return;

    if (!_shareFullVault && _selectedItem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an item or select Full Vault option')),
      );
      return;
    }

    // Size limit check
    if (!_shareFullVault && _selectedItem != null) {
      final jsonStr = jsonEncode(_selectedItem!.fields);
      final byteSize = utf8.encode(jsonStr).length;
      final sizeErr = P2PSizeLimitService.validatePayloadSize(byteSize);
      if (sizeErr != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(sizeErr), backgroundColor: Colors.redAccent),
        );
        return;
      }
    }

    // Biometric verification gate (FIX GAP 7)
    final authenticated = await BiometricAuthService.authenticateUser(
      reason: 'Scan biometrics to confirm sending ${_shareFullVault ? "vault" : "credential"} to ${peer.name}',
    );
    if (!authenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('P2P Transfer canceled: Biometric verification required')),
        );
      }
      return;
    }

    setState(() {
      _isTransferring = true;
      _statusText = 'Connecting to ${peer.name}...';
    });

    final p2p = ref.read(p2pServiceProvider);

    try {
      String? sasCode;

      if (_shareFullVault) {
        final isarService = IsarService();
        final isar = await isarService.instance;
        final defaultVaults = await isar.vaults.where().findAll();
        final activeVaultId = defaultVaults.isNotEmpty ? defaultVaults.first.vaultId : '';
        final result = await p2p.shareVault(key: key, vaultId: activeVaultId, peer: peer);
        sasCode = result.sasCode;
      } else {
        final result = await p2p.shareItem(key: key, itemId: _selectedItem!.itemId, peer: peer);
        sasCode = result.sasCode;
      }

      if (mounted) {
        // Display SAS code for mutual verification (FIX GAP 3)
        final confirmed = await _showSasConfirmationDialog(sasCode, peer.name);
        if (confirmed) {
          setState(() => _statusText = 'Transfer complete!');
          HapticFeedback.heavyImpact();
        } else {
          setState(() => _statusText = 'Transfer cancelled: SAS codes did not match');
          HapticFeedback.heavyImpact();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transfer failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isTransferring = false);
    }
  }

  /// Display SAS confirmation dialog – both users MUST verbally confirm.
  Future<bool> _showSasConfirmationDialog(String sasCode, String peerName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceZinc,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderZinc),
        ),
        title: Row(
          children: [
            const Icon(Icons.verified_user, color: AppColors.orangeAccent, size: 24),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Verify Transfer', style: TextStyle(color: AppColors.offWhite, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Share this 5-digit SAS code with',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            Text(
              peerName,
              style: const TextStyle(color: AppColors.offWhite, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.orangeContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.orangeAccent.withValues(alpha: 0.5)),
              ),
              child: Text(
                sasCode,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                  fontFamily: 'monospace',
                  color: AppColors.orangeAccent,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ask the receiver to read back this code.\nIf the codes match, both devices are securely connected.\nIf they differ, CANCEL the transfer immediately.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel Transfer', style: TextStyle(color: Colors.redAccent)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.orangeAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Codes Match – Confirm'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final key = ref.watch(authProvider);
    final transferState = ref.watch(connectionStateProvider).value ?? TransferState.idle;
    final progress = ref.watch(transferProgressProvider).value ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Banner
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
                  decoration: BoxDecoration(
                    color: AppColors.orangeContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.wifi_tethering, color: AppColors.orangeAccent, size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Offline Encrypted P2P Transfer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.offWhite)),
                      SizedBox(height: 4),
                      Text('End-to-end encrypted. Receiver needs your master password.', style: TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.3)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Transfer Mode
          const Text('1. SELECT WHAT TO SHARE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: AppColors.textMuted)),
          const SizedBox(height: 10),
          SwitchListTile(
            title: const Text('Share Full Encrypted Vault', style: TextStyle(color: AppColors.offWhite, fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: const Text('Sends encrypted vault blobs. Receiver must enter your master password to decrypt.', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
            value: _shareFullVault,
            activeColor: AppColors.orangeAccent,
            onChanged: (val) => setState(() => _shareFullVault = val),
          ),
          const SizedBox(height: 8),

          if (!_shareFullVault && key != null)
            FutureBuilder<List<DecryptedItem>>(
              future: _itemService.getAllItems(key),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final items = snapshot.data!;
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No credentials in vault to share.', style: TextStyle(color: AppColors.textMuted)),
                  );
                }
                return DropdownButtonFormField<DecryptedItem>(
                  value: _selectedItem,
                  dropdownColor: AppColors.inputZinc,
                  isExpanded: true,
                  borderRadius: BorderRadius.circular(14),
                  menuMaxHeight: 300,
                  style: const TextStyle(color: AppColors.offWhite, fontSize: 13),
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: AppColors.inputZinc,
                    labelText: 'Select Credential Item',
                    prefixIcon: Icon(Icons.security, color: AppColors.orangeAccent),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                      borderSide: BorderSide(color: AppColors.borderZinc),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                      borderSide: BorderSide(color: AppColors.borderZinc),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                      borderSide: BorderSide(color: AppColors.orangeAccent, width: 1.5),
                    ),
                  ),
                  items: items.map((item) {
                    return DropdownMenuItem(
                      value: item,
                      child: Row(children: [
                        Container(
                          width: 28, height: 28,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceZinc,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(_iconForType(item.type), size: 14, color: AppColors.orangeAccent),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(item.title,
                                style: const TextStyle(color: AppColors.offWhite, fontSize: 13, fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(item.type.toUpperCase(),
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ]),
                    );
                  }).toList(),
                  selectedItemBuilder: (context) => items.map((item) {
                    return Text(item.title,
                      style: const TextStyle(color: AppColors.offWhite, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    );
                  }).toList(),
                  onChanged: (item) => setState(() => _selectedItem = item),
                );
              },
            ),

          const SizedBox(height: 24),

          // Transport Toggle: WiFi / Bluetooth
          const Text('2. TRANSPORT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: AppColors.textMuted)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _TransportOption(
                  icon: Icons.bluetooth,
                  label: 'Bluetooth',
                  subtitle: _bluetoothEnabled ? 'No network needed' : 'Bluetooth is OFF',
                  isSelected: !_preferWifi,
                  enabled: _bluetoothEnabled,
                  onTap: _bluetoothEnabled
                      ? () => setState(() => _preferWifi = false)
                      : () => _showRadioPrompt('Bluetooth'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TransportOption(
                  icon: Icons.wifi,
                  label: 'Wi-Fi LAN',
                  subtitle: (!_wifiEnabled && !_wifiAvailable) ? 'WiFi is OFF' : 'Faster transfers',
                  isSelected: _preferWifi,
                  enabled: _wifiEnabled || _wifiAvailable,
                  onTap: (_wifiEnabled || _wifiAvailable)
                      ? () => setState(() => _preferWifi = true)
                      : () => _showRadioPrompt('WiFi'),
                ),
              ),
            ],
          ),
          // Radio-off prompt
          if (!_wifiEnabled && !_bluetoothEnabled)
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.orangeContainer.withValues(alpha: 0.3),
                border: Border.all(color: AppColors.orangeBorder.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber, size: 16, color: AppColors.orangeAccent),
                const SizedBox(width: 8),
                const Expanded(child: Text('Enable WiFi or Bluetooth to discover nearby devices', style: TextStyle(color: AppColors.orangeOnContainer, fontSize: 11))),
              ]),
            ),
          const SizedBox(height: 24),

          // Discovery
          Row(
            children: [
              const Text('3. NEARBY DEVICES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: AppColors.textMuted)),
              const Spacer(),
              IconButton(
                icon: _isRefreshing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.orangeAccent,
                        ),
                      )
                    : const Icon(Icons.refresh, color: AppColors.orangeAccent, size: 18),
                onPressed: _isRefreshing ? null : _refreshDevices,
                tooltip: 'Rescan Nearby Devices',
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_isTransferring)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceZinc, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.orangeAccent.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  if (_sasCode != null) ...[
                    const Text('SAS Verification Code', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(_sasCode!, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 6, fontFamily: 'monospace', color: AppColors.orangeAccent)),
                    const SizedBox(height: 12),
                  ],
                  Text(_statusText ?? 'Transferring...', style: const TextStyle(color: AppColors.offWhite, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: progress, color: AppColors.orangeAccent, backgroundColor: AppColors.cardZinc),
                  const SizedBox(height: 8),
                  Text('State: ${transferState.name.toUpperCase()}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            )
          else if (_filteredPeers.isEmpty)
            Container(
              width: double.infinity, padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: AppColors.surfaceZinc, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.borderZinc.withValues(alpha: 0.4))),
              child: Column(
                children: [
                  if (_discoveredPeers.isNotEmpty && _filteredPeers.isEmpty) ...[
                    const Icon(Icons.wifi_off, size: 36, color: AppColors.textMuted),
                    const SizedBox(height: 14),
                    Text('No ${_preferWifi ? 'WiFi' : 'Bluetooth'} devices found', style: const TextStyle(color: AppColors.offWhite, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('Try switching to ${_preferWifi ? 'Bluetooth' : 'WiFi'}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  ] else ...[
                    const SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.orangeAccent)),
                    const SizedBox(height: 14),
                    const Text('Scanning for nearby Firewood devices...', style: TextStyle(color: AppColors.offWhite, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    const Text('Open the Receive tab on the target device', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  ],
                ],
              ),
            )
          else
            ..._filteredPeers.map((peer) => Card(
              color: AppColors.surfaceZinc, margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: AppColors.borderZinc.withValues(alpha: 0.5))),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _preferWifi ? Colors.blueAccent.withValues(alpha: 0.15) : AppColors.orangeContainer, borderRadius: BorderRadius.circular(10)), child: Icon(_preferWifi ? Icons.wifi : Icons.bluetooth, color: _preferWifi ? Colors.blueAccent : AppColors.orangeAccent, size: 20)),
                title: Text(peer.name, style: const TextStyle(color: AppColors.offWhite, fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text('${_preferWifi ? 'WiFi LAN' : 'Bluetooth'} • SAS verified after transfer', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                trailing: App3DButton(label: 'Send', icon: Icons.send, variant: App3DButtonVariant.primary, height: 36, fontSize: 12, onPressed: () => _initiateTransfer(peer)),
              ),
            )),

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
                if (_statusText != null)
                  Text('• $_statusText', style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TransportOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool enabled;

  const _TransportOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isSelected,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final active = isSelected && enabled;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: active ? AppColors.orangeContainer : AppColors.surfaceZinc,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active
                ? AppColors.orangeAccent.withValues(alpha: 0.7)
                : AppColors.borderZinc.withValues(alpha: 0.5),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: enabled
                  ? (active ? AppColors.orangeAccent : AppColors.textMuted)
                  : AppColors.textMuted.withValues(alpha: 0.3),
              size: 22,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: enabled ? AppColors.offWhite : AppColors.textMuted.withValues(alpha: 0.4),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: enabled ? AppColors.textMuted : AppColors.textMuted.withValues(alpha: 0.3),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
