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
import 'package:hugeicons/hugeicons.dart';

import '../services/backup_service.dart';
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

  Future<String?> _promptPassword(String title, {String hint = 'Password'}) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
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
            child: const Text('Cancel', style: TextStyle(color: Color(0xFFA1A1AA))),
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
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;

    final password = await _promptPassword(
      'Set transfer password',
      hint: 'Share this password with the receiver out of band.',
    );
    if (password == null) return;

    setState(() {
      _stage = _P2pStage.working;
      _title = 'Sending ${result.files.single.name}';
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
      final safeName = result.files.single.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

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
          if (mounted) setState(() => _progress = total == 0 ? 0 : sent / total);
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

      final savePath = await FilePicker.platform.getDirectoryPath();
      if (savePath == null) {
        _reset();
        return;
      }
      final file = File('$savePath/${received.fileName}');
      await file.writeAsBytes(received.bytes, flush: true);

      if (!mounted) return;
      setState(() {
        _stage = _P2pStage.done;
        _progress = 1;
        _result = 'Saved ${received.fileName} to $savePath';
      });
    } catch (e) {
      _fail(e);
    }
  }

  // ---------- build ----------

  @override
  Widget build(BuildContext context) {
    final busy = _stage == _P2pStage.working;

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF18181B),
        title: const Text('P2P Sharing'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Bluetooth Sharing',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Send and receive .firewood files between Firewood devices via BLE.',
              style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 13),
            ),
            const SizedBox(height: 24),

            // AirShare (Spark QR & 4-Digit Flame Code) Hero Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E24),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5533D).withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5533D).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.bolt, color: Color(0xFFE5533D), size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AirShare (Spark & Flame)',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Spark QR + 4-Digit Flame Code',
                              style: TextStyle(color: Color(0xFFE5533D), fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Over-the-air zero-leak credential transfer. Ephemeral X25519 & ChaCha20-Poly1305 with volatile in-RAM decryption.',
                    style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 11, height: 1.3),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const HugeIcon(
                            icon: HugeIcons.strokeRoundedUpload04,
                            size: 15,
                            color: Colors.black,
                            strokeWidth: 2,
                          ),
                          label: const Text('Send Item', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE5533D),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onPressed: () => AirShareModal.show(context, role: AirShareRole.send),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const HugeIcon(
                            icon: HugeIcons.strokeRoundedDownload04,
                            size: 15,
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                          label: const Text('Receive', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF3F3F46)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onPressed: () => AirShareModal.show(context, role: AirShareRole.receive),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Sender card
            _SharingCard(
              leadingIcon: const HugeIcon(
                icon: HugeIcons.strokeRoundedUpload04,
                color: Color(0xFFFF9163),
                size: 24,
                strokeWidth: 1.8,
              ),
              title: 'Sender',
              description: 'Scan for nearby Firewood devices and send an encrypted vault or file.',
              buttons: [
                _ActionButton(
                  label: 'Send Vault',
                  leadingIcon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedFolderSecurity,
                    color: Colors.white,
                    size: 18,
                    strokeWidth: 1.8,
                  ),
                  primary: true,
                  enabled: !busy,
                  onPressed: _prepareVaultAndScan,
                ),
                const SizedBox(height: 8),
                _ActionButton(
                  label: 'Send File',
                  leadingIcon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedFile01,
                    color: Colors.white70,
                    size: 18,
                    strokeWidth: 1.8,
                  ),
                  enabled: !busy,
                  onPressed: _prepareFileAndScan,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Receiver card
            _SharingCard(
              leadingIcon: const HugeIcon(
                icon: HugeIcons.strokeRoundedDownload04,
                color: Color(0xFFFF9163),
                size: 24,
                strokeWidth: 1.8,
              ),
              title: 'Receiver',
              description: 'Advertise and wait for an incoming transfer from any Firewood device.',
              buttons: [
                _ActionButton(
                  label: 'Receive Vault',
                  leadingIcon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedInbox,
                    color: Colors.white,
                    size: 18,
                    strokeWidth: 1.8,
                  ),
                  primary: true,
                  enabled: !busy,
                  onPressed: _receive,
                ),
              ],
            ),

            // Discovered peers
            if (_devices.isNotEmpty) ...[
              const SizedBox(height: 24),
              _DeviceList(
                devices: _devices,
                onSelect: _sendTo,
                onCancel: _reset,
              ),
            ],

            if (_stage != _P2pStage.idle) ...[
              const SizedBox(height: 24),
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

            const SizedBox(height: 16),
            const Text(
              'App-to-app only — both devices must be running Firewood.',
              style: TextStyle(color: Color(0xFF71717A), fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

enum _P2pStage { idle, working, done, error }

// --- Shared widgets (same visual language as desktop) ---

class _SharingCard extends StatelessWidget {
  final Widget leadingIcon;
  final String title;
  final String description;
  final List<Widget> buttons;

  const _SharingCard({
    required this.leadingIcon,
    required this.title,
    required this.description,
    required this.buttons,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3F3F46)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFF5722).withAlpha(31),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFF5722).withAlpha(89)),
            ),
            child: Center(child: leadingIcon),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(description,
              style: const TextStyle(
                  color: Color(0xFFA1A1AA), fontSize: 12, height: 1.4)),
          const SizedBox(height: 16),
          ...buttons,
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Widget leadingIcon;
  final bool primary;
  final bool enabled;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.leadingIcon,
    required this.onPressed,
    this.primary = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: leadingIcon,
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              primary ? const Color(0xFFFF5722) : const Color(0xFF18181B),
          disabledBackgroundColor: const Color(0xFF242427),
          foregroundColor: Colors.white,
          disabledForegroundColor: const Color(0xFF71717A),
          side: BorderSide(
            color: primary
                ? const Color(0xFFFF5722)
                : const Color(0xFF3F3F46),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

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
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3F3F46)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Nearby devices',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(
                onPressed: onCancel,
                child: const Text('Cancel', style: TextStyle(color: Color(0xFFA1A1AA))),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ...devices.map(
            (d) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.bluetooth, color: Color(0xFFFF9163)),
              title: Text(
                d.name,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              subtitle: Text(
                '${d.rssi} dBm',
                style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 11),
              ),
              trailing: const Icon(Icons.chevron_right, color: Color(0xFFA1A1AA)),
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
        ? const Color(0xFF22C55E)
        : stage == _P2pStage.error
            ? const Color(0xFFEF4444)
            : const Color(0xFFFF9163);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(102)),
      ),
      child: Row(
        children: [
          if (isWorking)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
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
                  isWorking ? title : (isDone ? 'Transfer complete' : 'Transfer failed'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  isWorking ? step : result,
                  style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12),
                ),
                if (showProgress) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: const Color(0xFF3F3F46),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFFFF5722)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          if (!isWorking)
            ElevatedButton(
              onPressed: isDone ? onDone : onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF242427),
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFF3F3F46)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(isDone ? 'Done' : 'Close'),
            )
          else if (onCancel != null)
            TextButton(
              onPressed: onCancel,
              child: const Text('Cancel', style: TextStyle(color: Color(0xFFA1A1AA))),
            ),
        ],
      ),
    );
  }
}
