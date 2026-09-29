// P2P sharing screen — send/receive .firewood vaults and files over BLE.
//
// Android ↔ Android is the supported pairing today: the sender scans and connects
// (GATT central), the receiver advertises the Firewood service (GATT peripheral).
// The native layer (BleP2PManager) chunks, flow-controls and reassembles; this
// screen only drives roles, permissions, peer selection and progress.

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/vault_components.dart';
import '../services/backup_service.dart';
import '../services/lock_service.dart';
import '../services/ble_p2p_service.dart';
import '../services/file_crypto_service.dart';
import '../widgets/airshare_modal.dart';

class P2pSharingScreen extends StatefulWidget {
  const P2pSharingScreen({super.key});

  @override
  State<P2pSharingScreen> createState() => _P2pSharingScreenState();
}

class _P2pSharingScreenState extends State<P2pSharingScreen> {
  final BleP2pService _ble = BleP2pService();
  final BackupService _backupService = BackupService();
  final FileCryptoService _fileCrypto = FileCryptoService();

  _P2pStage _stage = _P2pStage.idle;
  String _title = '';
  String _step = '';
  String _result = '';
  double _progress = 0;

  final List<BleDevice> _devices = [];
  ({String fileName, List<int> bytes})? _pendingPayload;
  Directory? _tempDir;
  StreamSubscription<void>? _deviceSub;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _deviceSub = _ble.onDeviceFound.listen(_onDeviceFound);
  }

  @override
  void dispose() {
    _deviceSub?.cancel();
    _ble.dispose();
    super.dispose();
  }

  void _onDeviceFound(BleDevice device) {
    if (device.address.isEmpty) return;
    final existing = _devices.indexWhere((d) => d.address == device.address);
    if (existing >= 0) {
      if (device.rssi > _devices[existing].rssi) {
        setState(() => _devices[existing] = device);
      }
      return;
    }
    setState(() {
      _devices.add(device);
      _devices.sort((a, b) => b.rssi.compareTo(a.rssi));
    });
  }

  // ---------- helpers ----------

  Future<void> _cleanup() async {
    try {
      await _ble.stopScanning();
    } catch (_) {}
    try {
      await _ble.stopAdvertising();
    } catch (_) {}
    try {
      await _ble.shutdown();
    } catch (_) {}
    final dir = _tempDir;
    _tempDir = null;
    if (dir != null) {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    }
  }

  Future<void> _reset() async {
    await _cleanup();
    if (!mounted) return;
    setState(() {
      _stage = _P2pStage.idle;
      _title = '';
      _step = '';
      _result = '';
      _progress = 0;
      _devices.clear();
      _pendingPayload = null;
      _searching = false;
    });
  }

  void _fail(Object error) {
    if (!mounted) return;
    setState(() {
      _stage = _P2pStage.error;
      _result = error.toString();
    });
  }

  Future<String?> _promptPassword(String title,
      {String hint = 'Password'}) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        title: Text(title,
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hint,
              style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Password',
                labelStyle: TextStyle(color: Color(0xFFA1A1AA)),
              ),
              onSubmitted: (v) => Navigator.pop(ctx, v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFFA1A1AA))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5722),
              foregroundColor: Colors.white,
            ),
            child: const Text('Start'),
          ),
        ],
      ),
    );
    return (value == null || value.isEmpty) ? null : value;
  }

  // ---------- sender ----------

  Future<void> _prepareVaultAndScan() async {
    final password = await _promptPassword(
      'Enter master password',
      hint: 'The receiver imports this vault with the same password.',
    );
    if (password == null) return;

    setState(() {
      _stage = _P2pStage.working;
      _title = 'Sending vault';
      _step = 'Preparing encrypted package…';
      _progress = 0;
      _devices.clear();
    });

    try {
      if (!await _ble.isBluetoothEnabled()) {
        throw const BleException('Bluetooth is turned off on this device');
      }
      if (!await _ble.ensurePermissions(BleRole.sender)) {
        throw const BleException('Bluetooth permissions were denied');
      }

      _tempDir = await Directory.systemTemp.createTemp('firewood_p2p_');
      final backupPath = await _backupService.exportVault(
        password,
        '${_tempDir!.path}/vault',
      );
      final bytes = await File(backupPath).readAsBytes();

      setState(() {
        _pendingPayload = (fileName: 'firewood-vault.firewood', bytes: bytes);
        _step = 'Looking for nearby devices…';
      });
      await _ble.startScanning();
      if (mounted) setState(() => _searching = true);
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _prepareFileAndScan() async {
    LockService.beginForegroundFlow();
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(type: FileType.any);
    } finally {
      LockService.endForegroundFlow();
    }
    if (result == null || result.files.isEmpty) return;
    // Hoisted: `result` is assigned in a try block, so its null-promotion
    // does not survive into the setState closure below.
    final pickedFile = result.files.single;
    final path = pickedFile.path;
    if (path == null) return;

    final password = await _promptPassword(
      'Set transfer password',
      hint: 'Share this password with the receiver out of band.',
    );
    if (password == null) return;

    setState(() {
      _stage = _P2pStage.working;
      _title = 'Sending ${pickedFile.name}';
      _step = 'Encrypting file…';
      _progress = 0;
      _devices.clear();
    });

    try {
      if (!await _ble.isBluetoothEnabled()) {
        throw const BleException('Bluetooth is turned off on this device');
      }
      if (!await _ble.ensurePermissions(BleRole.sender)) {
        throw const BleException('Bluetooth permissions were denied');
      }

      final bytes = await File(path).readAsBytes();
      _tempDir = await Directory.systemTemp.createTemp('firewood_p2p_');
      final container = await _fileCrypto.encryptFileToFirewood(
        masterPassword: password,
        bytes: bytes,
        fileName: result.files.single.name,
        outputPath: '${_tempDir!.path}/container',
      );
      final payloadBytes = await File(container.path).readAsBytes();
      final safeName =
          result.files.single.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

      setState(() {
        _pendingPayload = (fileName: '$safeName.firewood', bytes: payloadBytes);
        _step = 'Looking for nearby devices…';
      });
      await _ble.startScanning();
      if (mounted) setState(() => _searching = true);
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _sendTo(BleDevice peer) async {
    final payload = _pendingPayload;
    if (payload == null) return;

    setState(() {
      _devices.clear();
      _searching = false;
      _step = 'Connecting to ${peer.name}…';
      _progress = 0;
    });

    try {
      await _ble.stopScanning();
      await _ble.connect(peer.address);

      setState(() {
        _stage = _P2pStage.working;
        _title = 'Sending to ${peer.name}';
        _step = 'Transferring…';
      });

      await _ble.sendFile(
        address: peer.address,
        fileName: payload.fileName,
        bytes: payload.bytes,
        onProgress: (sent, total) {
          if (mounted)
            setState(() => _progress = total == 0 ? 0 : sent / total);
        },
      );

      await _ble.disconnect(peer.address);
      if (!mounted) return;
      setState(() {
        _stage = _P2pStage.done;
        _progress = 1;
        _result = '${payload.fileName} sent to ${peer.name}.';
        _pendingPayload = null;
      });
    } catch (e) {
      try {
        await _ble.disconnect(peer.address);
      } catch (_) {}
      _fail(e);
    }
  }

  // ---------- receiver ----------

  Future<void> _receive() async {
    setState(() {
      _stage = _P2pStage.working;
      _title = 'Receiving';
      _step = 'Waiting for a nearby device to send…';
      _progress = 0;
    });

    try {
      if (!await _ble.isBluetoothEnabled()) {
        throw const BleException('Bluetooth is turned off on this device');
      }
      if (!await _ble.ensurePermissions(BleRole.receiver)) {
        throw const BleException('Bluetooth permissions were denied');
      }

      final advertising = await _ble.startAdvertising();
      if (!advertising) {
        throw const BleException('Could not start Bluetooth advertising');
      }

      final received = await _ble.receiveFile();
      await _ble.stopAdvertising();

      if (!mounted) return;
      setState(() => _step = 'Saving ${received.fileName}…');

      LockService.beginForegroundFlow();
      String? savePath;
      try {
        savePath = await FilePicker.platform.getDirectoryPath();
      } finally {
        LockService.endForegroundFlow();
      }
      if (savePath == null) {
        _reset();
        return;
      }
      // V-031: the name arrives inside the BLE frame — treat it as hostile.
      // Sanitize to a bare path segment (no separators, no traversal, no
      // leading dot), then assert the joined path stays inside the folder
      // the user picked before writing a single byte.
      final safeName = FileCryptoService.sanitizeFileName(received.fileName);
      if (safeName == '.' ||
          safeName == '..' ||
          safeName.contains('/') ||
          safeName.contains(r'\')) {
        throw const BleException('Peer sent an invalid file name');
      }
      final canonicalBase = await Directory(savePath).resolveSymbolicLinks();
      final file = File('$canonicalBase${Platform.pathSeparator}$safeName');
      // Containment assert (defense in depth if the sanitizer ever loosens):
      if (!file.path.startsWith('$canonicalBase${Platform.pathSeparator}')) {
        throw const BleException('Refusing to write outside the chosen folder');
      }
      await file.writeAsBytes(received.bytes, flush: true);
      final savedDisplay = file.path;

      if (!mounted) return;
      setState(() {
        _stage = _P2pStage.done;
        _progress = 1;
        // Show what was actually written (sanitized name, canonical folder)
        // rather than the peer-supplied label.
        _result = 'Saved $savedDisplay';
      });
    } catch (e) {
      _fail(e);
    }
  }

  void _showAirShareGuide(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceZinc,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.orangeAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedBookOpen01,
                    size: 18,
                    color: AppColors.orangeAccent,
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AirShare Guide',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.offWhite,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Encrypted peer-to-peer sharing',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildGuideStep('1', 'Instant QR Transfer',
                'Sender picks a credential and scans the receiver QR code over local Wi-Fi.'),
            _buildGuideStep('2', 'Offline Bluetooth Vault',
                'Both devices enable Bluetooth to transfer an entire encrypted vault archive without internet.'),
            _buildGuideStep('3', 'Zero-Knowledge Security',
                'Peer-to-peer with ephemeral in-memory encryption (X25519 + ChaCha20). Zero cloud relays.'),
            const SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orangeAccent,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
    );
  }

  Widget _buildGuideStep(String step, String title, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardZinc,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderZinc.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.orangeAccent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.orangeAccent.withValues(alpha: 0.4),
              ),
            ),
            child: Center(
              child: Text(
                step,
                style: TextStyle(
                  color: AppColors.orangeAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.offWhite,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
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
    );
  }

  void _showBluetoothSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceZinc,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.orangeAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedBluetooth,
                    size: 18,
                    color: AppColors.orangeAccent,
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bluetooth Transfer',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.offWhite,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Offline peer-to-peer exchange',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            _buildBluetoothOption(
              icon: HugeIcons.strokeRoundedUpload04,
              title: 'Send Vault',
              subtitle:
                  'Export and transmit encrypted vault to a nearby device',
              onTap: () {
                Navigator.pop(ctx);
                _prepareVaultAndScan();
              },
            ),
            const SizedBox(height: 10),
            _buildBluetoothOption(
              icon: HugeIcons.strokeRoundedDownload04,
              title: 'Receive Vault',
              subtitle:
                  'Listen for incoming vault transfers and save to device',
              onTap: () {
                Navigator.pop(ctx);
                _receive();
              },
            ),
            const SizedBox(height: 10),
            _buildBluetoothOption(
              icon: HugeIcons.strokeRoundedFile01,
              title: 'Send Encrypted File',
              subtitle: 'Encrypt and transfer any file via Bluetooth P2P',
              onTap: () {
                Navigator.pop(ctx);
                _prepareFileAndScan();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBluetoothOption({
    required dynamic icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: AppColors.orangeAccent.withValues(alpha: 0.1),
        highlightColor: AppColors.orangeAccent.withValues(alpha: 0.05),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardZinc,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.borderZinc.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.surfaceZinc,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.borderZinc.withValues(alpha: 0.4),
                  ),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: icon,
                    color: AppColors.orangeAccent,
                    size: 20,
                    strokeWidth: 2,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.offWhite,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                color: AppColors.textMuted,
                size: 16,
                strokeWidth: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- build ----------

  @override
  Widget build(BuildContext context) {
    final busy = _stage == _P2pStage.working;

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: VaultAppBar(
        title: 'AirShare',
        leading: IconButton(
          icon: const AppIcon(AppIcons.arrowLeft,
              color: AppColors.offWhite, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _showAirShareGuide(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceZinc,
                    borderRadius: BorderRadius.circular(8),
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
                        'Guide',
                        style: TextStyle(
                          color: AppColors.offWhite,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. AIRSHARE CARD
            _SharingOptionCard(
              tag: 'WI-FI & QR',
              title: 'AirShare',
              subtitle:
                  'Encrypted credential sync via QR code over local Wi-Fi.',
              icon: HugeIcons.strokeRoundedQrCode,
              busy: busy,
              onTap: () {
                HapticFeedback.lightImpact();
                AirShareModal.show(context);
              },
            ),
            const SizedBox(height: 14),

            // 2. BLUETOOTH CARD
            _SharingOptionCard(
              tag: 'OFFLINE BLE',
              title: 'Bluetooth',
              subtitle:
                  'Direct device-to-device vault and file exchange without Wi-Fi.',
              icon: HugeIcons.strokeRoundedBluetooth,
              busy: busy,
              onTap: () {
                HapticFeedback.lightImpact();
                _showBluetoothSheet(context);
              },
            ),

            // Discovered peers
            if (_devices.isNotEmpty) ...[
              const SizedBox(height: 18),
              _DeviceList(
                devices: _devices,
                onSelect: _sendTo,
                onCancel: _reset,
              ),
            ],

            if (_stage != _P2pStage.idle) ...[
              const SizedBox(height: 18),
              _ProcessingPanel(
                stage: _stage,
                title: _title,
                step: _step,
                result: _result,
                progress: _progress,
                showProgress: busy && _progress > 0,
                onCancel: _searching ? _reset : null,
                onDone: _reset,
                onRetry: _reset,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SharingOptionCard extends StatelessWidget {
  final String tag;
  final String title;
  final String subtitle;
  final dynamic icon;
  final bool busy;
  final VoidCallback onTap;

  const _SharingOptionCard({
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: AppColors.orangeAccent.withValues(alpha: 0.1),
        highlightColor: AppColors.orangeAccent.withValues(alpha: 0.05),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: busy ? 0.6 : 1.0,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardZinc,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.borderZinc.withValues(alpha: 0.6),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceZinc,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.borderZinc.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Center(
                        child: HugeIcon(
                          icon: icon,
                          color: AppColors.orangeAccent,
                          size: 24,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tag,
                            style: GoogleFonts.syncopate(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: AppColors.orangeAccent,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            title,
                            style: const TextStyle(
                              color: AppColors.offWhite,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceZinc,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.borderZinc.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedArrowRight01,
                          color: AppColors.offWhite.withValues(alpha: 0.7),
                          size: 16,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _P2pStage { idle, working, done, error }

// --- Shared widgets ---

class _DeviceList extends StatelessWidget {
  final List<BleDevice> devices;
  final void Function(BleDevice) onSelect;
  final VoidCallback onCancel;

  const _DeviceList({
    required this.devices,
    required this.onSelect,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardZinc,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderZinc),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Nearby Devices',
                  style: TextStyle(
                    color: AppColors.offWhite,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(
                onPressed: onCancel,
                child: const Text('Cancel',
                    style: TextStyle(color: AppColors.textMuted)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ...devices.map(
            (d) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.bluetooth, color: AppColors.orangeAccent),
              title: Text(
                d.name,
                style: const TextStyle(color: AppColors.offWhite, fontSize: 14),
              ),
              subtitle: Text(
                '${d.rssi} dBm',
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
              trailing:
                  const Icon(Icons.chevron_right, color: AppColors.textMuted),
              onTap: () => onSelect(d),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProcessingPanel extends StatelessWidget {
  final _P2pStage stage;
  final String title;
  final String step;
  final String result;
  final double progress;
  final bool showProgress;
  final VoidCallback? onCancel;
  final VoidCallback onDone;
  final VoidCallback onRetry;

  const _ProcessingPanel({
    required this.stage,
    required this.title,
    required this.step,
    required this.result,
    required this.progress,
    required this.showProgress,
    required this.onDone,
    required this.onRetry,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isWorking = stage == _P2pStage.working;
    final isDone = stage == _P2pStage.done;
    final color = isDone
        ? AppColors.mintAccent
        : stage == _P2pStage.error
            ? AppColors.roseAccent
            : AppColors.orangeAccent;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardZinc,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          if (isWorking)
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.orangeAccent,
              ),
            )
          else
            Icon(
              isDone ? Icons.check_circle_outline : Icons.error_outline,
              size: 26,
              color: color,
            ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isWorking
                      ? title
                      : (isDone ? 'Transfer complete' : 'Transfer failed'),
                  style: const TextStyle(
                      color: AppColors.offWhite,
                      fontSize: 15,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  isWorking ? step : result,
                  style:
                      const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                if (showProgress) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: AppColors.surfaceZinc,
                      valueColor:
                          AlwaysStoppedAnimation(AppColors.orangeAccent),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          if (!isWorking)
            ElevatedButton(
              onPressed: isDone ? onDone : onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surfaceZinc,
                foregroundColor: AppColors.offWhite,
                side: const BorderSide(color: AppColors.borderZinc),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(isDone ? 'Done' : 'Close'),
            )
          else if (onCancel != null)
            TextButton(
              onPressed: onCancel,
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
        ],
      ),
    );
  }
}
