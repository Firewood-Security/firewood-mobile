import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:permission_handler/permission_handler.dart';

import '../providers/auth_provider.dart';
import '../services/airshare_service.dart';
import '../services/item_service.dart';
import '../services/lock_service.dart';
import '../services/reauth_service.dart';
import '../services/vault_service.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import 'animated_qr_display.dart';
import 'camera_qr_scanner.dart';

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
  }) async {
    // Auth policy: starting a SEND is a critical action; receive and
    // guide flows open without prompting.
    if (role == AirShareRole.send &&
        !await ReauthService.confirm(context,
            reason: 'Authenticate to share via AirShare')) {
      return;
    }
    if (!context.mounted) return;
    // V-019: FLAG_SECURE is intentionally NOT dropped while this sheet is
    // open. It protects the whole window — clearing it to "share" the QR
    // would expose everything behind the sheet in screenshots/recents, and
    // the `.then` re-enable could fail and leave the flag off (or fight the
    // user's screenshot policy). A QR code is read by the other device's
    // camera directly, which FLAG_SECURE does not affect. The explicit
    // opt-out remains the Settings screenshot toggle, enforced natively.
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.88,
        child: AirShareModal(
          initialItem: item,
          initialRole: role,
        ),
      ),
    );
  }

  @override
  ConsumerState<AirShareModal> createState() => _AirShareModalState();
}

class _AirShareModalState extends ConsumerState<AirShareModal> {
  final AirShareService _airShare = AirShareService();

  late AirShareRole _role;
  late final PageController _rolePageController;

  // Selected item state (Send mode)
  DecryptedItem? _selectedItem;
  List<DecryptedItem> _availableItems = [];
  bool _loadingItems = false;

  // Receiver state
  String? _sparkUri;

  /// V-022: one listener per advertised candidate address (same port) —
  /// the receiver never opens a wildcard (anyIPv4) socket.
  final List<HttpServer> _receiverServers = [];

  /// V-005: per-session token the sender must present (x-firewood-token).
  String _sessionToken = '';

  /// V-005: exactly one payload may ever be accepted per listener session.
  bool _transferAccepted = false;

  // Sender state
  final TextEditingController _sparkInputController = TextEditingController();
  bool _showManualInput = false;

  // Shared state
  bool _isProcessing = false;
  bool _isSavingQr = false;
  String _statusMessage = '';
  AirSharePayload? _receivedPayload;
  bool _passwordRevealed = false;

  @override
  void initState() {
    super.initState();
    _role = widget.initialRole;
    _rolePageController = PageController(
      initialPage: widget.initialRole == AirShareRole.send ? 0 : 1,
    );
    _selectedItem = widget.initialItem;

    _loadVaultItems();

    if (_role == AirShareRole.receive) {
      _initReceiver();
    }
  }

  @override
  void dispose() {
    _rolePageController.dispose();
    _sparkInputController.dispose();
    _stopReceiverServer();
    super.dispose();
  }

  Future<void> _stopReceiverServer() async {
    for (final server in _receiverServers) {
      try {
        await server.close(force: true);
      } catch (_) {}
    }
    _receiverServers.clear();
  }

  /// Constant-time comparison of the presented transfer token (V-005).
  static bool _tokensMatch(String a, String b) {
    if (a.isEmpty || a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < b.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  /// All usable local IPv4 addresses, best candidate first.
  ///
  /// A device can own several at once (home/office Wi-Fi `192.168.x`, phone
  /// hotspot `192.168.43.x`, tether, VPN…). Advertising every one of them and
  /// letting the sender walk the list avoids the EHOSTUNREACH (errno 113)
  /// that occurred when only the first — and often unroutable — address was
  /// put into the Spark QR.
  Future<List<String>> _getLocalIpAddresses() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      final candidates = <String>[];
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.isLoopback || addr.isLinkLocal) continue;
          if (!candidates.contains(addr.address)) candidates.add(addr.address);
        }
      }

      int score(String a) {
        if (a.startsWith('192.168.')) return 0; // LAN / hotspot
        if (a.startsWith('10.')) return 1; // LAN
        if (a.startsWith('172.')) return 2; // LAN
        return 3; // anything else
      }

      candidates.sort((a, b) => score(a).compareTo(score(b)));
      return candidates;
    } catch (_) {}
    return const [];
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

  void _switchRole(AirShareRole role, {bool animatePage = true}) {
    if (_role == role) return;
    setState(() {
      _role = role;
      _statusMessage = '';
      _receivedPayload = null;
    });

    if (role == AirShareRole.receive) {
      _initReceiver();
    } else {
      _stopReceiverServer();
    }

    if (animatePage && _rolePageController.hasClients) {
      final targetPage = role == AirShareRole.send ? 0 : 1;
      if (_rolePageController.page?.round() != targetPage) {
        _rolePageController.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  Future<void> _initReceiver() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Starting local receiver listener…';
    });

    try {
      final keyPair = await _airShare.generateKeyPair();
      final pk = await keyPair.extractPublicKey();
      final nonce = _airShare.generateNonce(12);

      // V-005: mint a fresh 32-byte session token for this receiver session.
      // It travels only inside the scanned QR (firewood://spark?tkn=…), so a
      // passive LAN sniffer who only sees the POST cannot replay it.
      final rng = Random.secure();
      _sessionToken =
          base64UrlEncode(List<int>.generate(32, (_) => rng.nextInt(256)));
      _transferAccepted = false;

      await _stopReceiverServer();
      final localIps = await _getLocalIpAddresses();

      // V-022: never bind the wildcard address. One listener per ADVERTISED
      // candidate (all sharing a single port) keeps the socket surface
      // exactly equal to the address list handed to the sender — traffic
      // can only arrive where the QR says it can. With no candidate there
      // is nothing to advertise, so no listener is opened at all (a
      // wildcard socket would only widen exposure; the status message
      // below already tells the user to join Wi-Fi).
      var port = 0;
      if (localIps.isNotEmpty) {
        final primary =
            await HttpServer.bind(InternetAddress(localIps.first), 0);
        port = primary.port;
        _receiverServers.add(primary);
        for (final ip in localIps.skip(1)) {
          try {
            _receiverServers
                .add(await HttpServer.bind(InternetAddress(ip), port));
          } catch (_) {
            // Candidate vanished or the port raced — the sender walks the
            // advertised list and simply skips an address that refuses.
          }
        }
      }

      for (final server in _receiverServers) {
        server.listen((HttpRequest request) async {
          if (request.method == 'POST') {
            // V-022: exactly one documented endpoint exists. Other POST
            // paths get a generic 404 before any parsing or auth feedback.
            if (request.uri.path != '/airshare/transfer') {
              request.response
                ..statusCode = HttpStatus.notFound
                ..close();
              return;
            }

            // V-005: authenticate the sender — constant-time token compare.
            final provided = request.headers.value('x-firewood-token') ?? '';
            if (!_tokensMatch(provided, _sessionToken)) {
              request.response
                ..statusCode = HttpStatus.unauthorized
                ..write('unauthorized')
                ..close();
              return;
            }

            // V-005: single-shot — first accepted payload wins; everything
            // after it is refused so a second device cannot overwrite or
            // race the accepted credential.
            if (_transferAccepted) {
              request.response
                ..statusCode = HttpStatus.conflict
                ..write('transfer already completed')
                ..close();
              return;
            }
            _transferAccepted = true;

            try {
              // V-022: 64 KB cap, counted while streaming — neither a lying
              // content-length nor chunked encoding can exhaust memory
              // (credentials payloads are a few hundred bytes).
              const maxBodyBytes = 64 * 1024;
              if (request.contentLength > maxBodyBytes) {
                throw const _OversizedBody();
              }
              final builder = <int>[];
              var received = 0;
              await for (final chunk in request) {
                received += chunk.length;
                if (received > maxBodyBytes) {
                  throw const _OversizedBody();
                }
                builder.addAll(chunk);
              }
              final content = utf8.decode(builder);
              final data = jsonDecode(content) as Map<String, dynamic>;
              final senderPkBase64 = data['senderPk'] as String;
              final cipherTextBase64 = data['ciphertext'] as String;

              final senderPk = SimplePublicKey(
                base64Url.decode(senderPkBase64),
                type: KeyPairType.x25519,
              );
              final encryptedBytes = base64Decode(cipherTextBase64);

              final secret = await _airShare.computeSharedSecret(
                localKeyPair: keyPair,
                remotePublicKey: senderPk,
              );
              final sessionKey = await _airShare.deriveSessionKey(
                sharedSecret: secret,
                salt: nonce,
              );

              final payload = await _airShare.decryptPayload(
                encryptedBytes: encryptedBytes,
                sessionKey: sessionKey,
              );

              request.response
                ..statusCode = HttpStatus.ok
                ..headers.contentType = ContentType.json
                ..write(jsonEncode({'status': 'ok'}))
                ..close();

              if (!mounted) return;
              HapticFeedback.heavyImpact();
              setState(() {
                _receivedPayload = payload;
                _statusMessage =
                    'Credential "${payload.title}" received securely in RAM!';
              });
            } on _OversizedBody {
              // Over-limit bodies never consume the single-shot slot.
              _transferAccepted = false;
              request.response
                ..statusCode = HttpStatus.requestEntityTooLarge
                ..write('payload too large')
                ..close();
            } catch (e) {
              // Failed attempt does not consume the single-shot slot.
              _transferAccepted = false;
              // V-042: never echo exception internals to the network peer.
              debugPrint('AirShare receive failed: $e');
              request.response
                ..statusCode = HttpStatus.badRequest
                ..write('bad request')
                ..close();
            }
          } else {
            request.response
              ..statusCode = HttpStatus.methodNotAllowed
              ..close();
          }
        });
      }

      final uri = _airShare.createSparkUri(
        publicKey: pk,
        nonce: nonce,
        deviceName: 'Firewood Mobile',
        host: localIps.isEmpty ? null : localIps.join(','),
        port: port,
        token: _sessionToken,
      );

      if (!mounted) return;
      setState(() {
        _sparkUri = uri;
        _isProcessing = false;
        _statusMessage = localIps.isEmpty
            ? '⚠️ No network interface found — connect to Wi-Fi so the sender can reach this device.'
            : (localIps.length > 1
                ? 'Advertising ${localIps.length} addresses (${localIps.join(', ')})'
                : '');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Failed to start receiver: $e';
      });
    }
  }

  DecryptedItem? _getActiveItem() {
    return _selectedItem ??
        widget.initialItem ??
        (_availableItems.isNotEmpty ? _availableItems.first : null);
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
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
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
                    labelStyle:
                        const TextStyle(color: Colors.white54, fontSize: 12),
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
                      setDlgState(
                          () => errorText = 'Incorrect master password');
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orangeAccent),
                onPressed: () async {
                  final pwd = passwordController.text;
                  try {
                    await VaultService().unlock(pwd);
                    if (ctx.mounted) Navigator.of(ctx).pop(true);
                  } catch (_) {
                    setDlgState(() => errorText = 'Incorrect master password');
                  }
                },
                child: const Text('Authorize',
                    style: TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );

    return authorized ?? false;
  }

  Future<void> _scanAndSend() async {
    final item = _getActiveItem();
    if (item == null) {
      setState(() =>
          _statusMessage = '⚠️ Please select a credential to share first.');
      return;
    }

    final status = await Permission.camera.request();
    if (!mounted) return;
    if (status.isDenied || status.isPermanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content:
              const Text('Camera permission is required to scan QR codes.'),
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
        builder: (_) => const CameraQrScannerScreen(title: 'Scan Receiver QR'),
      ),
    );

    if (scanned != null && scanned.isNotEmpty && mounted) {
      _sparkInputController.text = scanned;
      await _transmitWithUri(scanned);
    }
  }

  Future<void> _transmitWithUri(String rawUri) async {
    final item = _getActiveItem();
    if (item == null) {
      setState(
          () => _statusMessage = '⚠️ Please select a credential to share.');
      return;
    }

    if (rawUri.trim().isEmpty) {
      setState(() =>
          _statusMessage = '⚠️ Please scan or paste the receiver QR URI.');
      return;
    }

    // Authorize master password
    final authorized = await _promptMasterPassword();
    if (!authorized) {
      setState(() =>
          _statusMessage = 'Transfer cancelled: Master password required.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Master password verified. Parsing receiver QR…';
    });

    try {
      final parsed = _airShare.parseSparkUri(rawUri.trim());
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

      final senderPk = await senderKp.extractPublicKey();
      final senderPkBase64 = base64UrlEncode(senderPk.bytes);
      final cipherTextBase64 = base64Encode(encrypted);

      final port = parsed.port;
      var hosts = parsed.hosts;
      if (hosts.isEmpty && parsed.host != null && parsed.host!.isNotEmpty) {
        hosts = [parsed.host!];
      }

      if (hosts.isNotEmpty && port != null) {
        Object? lastError;
        var delivered = false;

        // Try every address the receiver advertised (Wi-Fi IP, hotspot IP, …)
        // until one is reachable. Walking the list is what turns a hard
        // EHOSTUNREACH (errno 113) into a successful transfer when the first
        // address sits on an interface this device cannot route to.
        for (final host in hosts) {
          try {
            setState(() => _statusMessage = 'Connecting to $host:$port…');
            final client = HttpClient()
              ..connectionTimeout = const Duration(seconds: 5);
            try {
              final request = await client
                  .post(host, port, '/airshare/transfer')
                  .timeout(const Duration(seconds: 6));
              request.headers.contentType = ContentType.json;
              // V-005: present the receiver's per-session token from the QR.
              request.headers.set('x-firewood-token', parsed.token ?? '');
              request.write(jsonEncode({
                'senderPk': senderPkBase64,
                'ciphertext': cipherTextBase64,
              }));
              final response =
                  await request.close().timeout(const Duration(seconds: 8));
              if (response.statusCode != HttpStatus.ok) {
                throw HttpException(
                    'Receiver rejected transfer: HTTP ${response.statusCode}');
              }
              delivered = true;
            } finally {
              client.close(force: true);
            }
            break;
          } catch (e) {
            lastError = e; // remember it, then fall through to the next address
          }
        }

        if (!delivered) {
          if (!mounted) return;
          setState(() {
            _isProcessing = false;
            _statusMessage =
                'Transfer failed: ${_describeTransferFailure(lastError)}';
          });
          return;
        }
      } else {
        setState(() => _statusMessage =
            'Transmitting encrypted bytes to ${parsed.deviceName}…');
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Transmitted securely to ${parsed.deviceName}!';
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
                Text('Transmitted!',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
            content: Text(
              'Credential "${item.title}" was encrypted with X25519 + ChaCha20-Poly1305 and sent directly to ${parsed.deviceName}.',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orangeAccent),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                },
                child: const Text('Done',
                    style: TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Transfer failed: ${_describeTransferFailure(e)}';
      });
    }
  }

  /// Turns raw socket errors — including the bare `errno=113` users were
  /// seeing — into guidance someone can act on.
  String _describeTransferFailure(Object? error) {
    if (error is TimeoutException) {
      return 'The receiver did not respond in time. Both devices must be on the same Wi-Fi network — generate a fresh QR and retry.';
    }

    final osError = error is SocketException ? error.osError : null;
    final code = osError?.errorCode;
    final detail = osError?.message ?? error?.toString() ?? 'unknown error';

    switch (code) {
      case 113: // EHOSTUNREACH — no route to host
      case 101: // ENETUNREACH — network unreachable
        return 'No route to the receiver ($detail). Both devices must be on the SAME Wi-Fi network: turn off mobile hotspot and VPN, and make sure the network allows device-to-device traffic (AP/client isolation off), then rescan the QR.';
      case 111: // ECONNREFUSED
        return 'The receiver refused the connection ($detail). The QR session has likely expired — generate a fresh QR on the receiver and scan it again.';
      case 110: // ETIMEDOUT
        return 'Connection to the receiver timed out. Check both devices are on the same Wi-Fi network and retry with a new QR.';
      case 104: // ECONNRESET
        return 'The connection was reset during the transfer ($detail). Please retry.';
      default:
        return 'Could not reach the receiver ($detail). Confirm both devices are on the same Wi-Fi network, then retry with a new QR.';
    }
  }

  Future<void> _saveReceivedItemToVault() async {
    final key = ref.read(authProvider);
    if (key == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vault is locked. Unlock vault to save.')),
      );
      return;
    }

    if (_receivedPayload == null) return;

    try {
      final payload = _receivedPayload!;
      final type = payload.data['type']?.toString() ?? 'login';
      final title = payload.title.trim();
      final fields = Map<String, dynamic>.from(payload.data)..remove('type');

      // Check for credential title conflict
      final allItems = await ItemService().getAllItems(key);
      DecryptedItem? conflict;
      for (final it in allItems) {
        if (it.title.trim().toLowerCase() == title.toLowerCase()) {
          conflict = it;
          break;
        }
      }

      if (conflict != null && mounted) {
        final resolution = await showDialog<String>(
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
                AppIcon(AppIcons.alertCircle,
                    color: AppColors.orangeAccent, size: 22),
                const SizedBox(width: 10),
                const Text(
                  'Credential Conflict',
                  style: TextStyle(
                    color: AppColors.offWhite,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            content: Text(
              'A credential named "$title" already exists in your vault.\n\nWould you like to overwrite it with the received data, save it as a separate copy, or cancel?',
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 13, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'cancel'),
                child: const Text('Cancel',
                    style: TextStyle(color: AppColors.textMuted)),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.borderZinc),
                  foregroundColor: AppColors.offWhite,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(ctx, 'copy'),
                child: const Text('Save as Copy'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orangeAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(ctx, 'override'),
                child: const Text('Override'),
              ),
            ],
          ),
        );

        if (resolution == null || resolution == 'cancel' || !mounted) {
          return;
        }

        if (resolution == 'override') {
          await ItemService().updateItem(
            key: key,
            itemId: conflict.itemId,
            newFields: fields,
            newTitle: title,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.mintAccent,
                content: Text('Overrode existing "$title" with received data!'),
              ),
            );
            Navigator.of(context).pop();
          }
          return;
        } else if (resolution == 'copy') {
          final copyTitle = '$title (Shared)';
          await ItemService().addItem(
            key: key,
            type: type,
            title: copyTitle,
            fields: fields,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.mintAccent,
                content: Text('Saved as "$copyTitle" to your vault!'),
              ),
            );
            Navigator.of(context).pop();
          }
          return;
        }
      }

      await ItemService().addItem(
        key: key,
        type: type,
        title: title,
        fields: fields,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.mintAccent,
            content: Text('Saved "$title" to your local vault!'),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Failed to save item: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceZinc,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 18,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
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
          const SizedBox(height: 14),

          // Header
          _buildHeader(),
          const SizedBox(height: 14),

          if (_receivedPayload != null) ...[
            Expanded(
              child: SingleChildScrollView(
                child: _buildReceivedCard(),
              ),
            ),
            const SizedBox(height: 16),
            _buildReceivedActionButtons(),
          ] else ...[
            // Single Role Switcher: Send vs Receive
            _buildRoleSelector(),
            const SizedBox(height: 16),

            Expanded(
              child: PageView(
                controller: _rolePageController,
                onPageChanged: (index) {
                  final newRole =
                      index == 0 ? AirShareRole.send : AirShareRole.receive;
                  _switchRole(newRole, animatePage: false);
                },
                children: [
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSendView(),
                        if (_statusMessage.isNotEmpty &&
                            _role == AirShareRole.send) ...[
                          const SizedBox(height: 12),
                          _buildStatusBanner(),
                        ],
                      ],
                    ),
                  ),
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildReceiveView(),
                        if (_statusMessage.isNotEmpty &&
                            _role == AirShareRole.receive) ...[
                          const SizedBox(height: 12),
                          _buildStatusBanner(),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAirShareGuide() {
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
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.orangeAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedBookOpen01,
                    size: 18,
                    color: AppColors.orangeAccent,
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'AirShare Guide',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildGuideStep('1', 'Sender',
                'Choose a credential to transfer and tap "Scan Receiver QR to Send".'),
            const SizedBox(height: 10),
            _buildGuideStep('2', 'Receiver',
                'Switch to the "Receive" tab and present your ephemeral QR code.'),
            const SizedBox(height: 10),
            _buildGuideStep('3', 'Zero-Leak Security',
                'Keys are ephemeral in volatile RAM. Transfer happens locally over Wi-Fi encrypted with ECDH + AES-256 GCM. No internet or external servers involved.'),
            const SizedBox(height: 18),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orangeAccent,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Got It',
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideStep(String step, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.cardZinc,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.borderZinc),
          ),
          alignment: Alignment.center,
          child: Text(step,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 2),
              Text(desc,
                  style: const TextStyle(
                      fontSize: 11.5, color: Colors.white60, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.orangeAccent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedQrCode,
            size: 20,
            color: AppColors.orangeAccent,
            strokeWidth: 2,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'AirShare',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        IconButton(
          tooltip: 'AirShare Guide',
          icon: const Icon(Icons.help_outline_rounded,
              color: Colors.white70, size: 20),
          onPressed: _showAirShareGuide,
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white54, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildRoleSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E23),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A32)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(9),
              onTap: () => _switchRole(AirShareRole.send),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _role == AirShareRole.send
                      ? AppColors.orangeAccent
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedUpload04,
                      size: 15,
                      color: _role == AirShareRole.send
                          ? Colors.black
                          : Colors.white70,
                      strokeWidth: 2,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Send',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: _role == AirShareRole.send
                            ? Colors.black
                            : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(9),
              onTap: () => _switchRole(AirShareRole.receive),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _role == AirShareRole.receive
                      ? AppColors.orangeAccent
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedDownload04,
                      size: 15,
                      color: _role == AirShareRole.receive
                          ? Colors.black
                          : Colors.white70,
                      strokeWidth: 2,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Receive',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: _role == AirShareRole.receive
                            ? Colors.black
                            : Colors.white70,
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

  Widget _buildSendView() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16161D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF282834)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Credential Picker
          _buildItemPicker(),
          const SizedBox(height: 16),

          // 2. Single Primary Action: Scan Receiver QR to Send
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orangeAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
            icon: const Icon(Icons.qr_code_scanner,
                color: Colors.black, size: 20),
            label: const Text(
              'Scan Receiver QR to Send',
              style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
            onPressed: _isProcessing ? null : _scanAndSend,
          ),
          const SizedBox(height: 12),

          // 3. Optional Manual URI Input Toggle
          InkWell(
            onTap: () => setState(() => _showManualInput = !_showManualInput),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _showManualInput
                        ? 'Hide manual input'
                        : 'Paste QR URI manually',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _showManualInput
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.white38,
                    size: 15,
                  ),
                ],
              ),
            ),
          ),

          if (_showManualInput) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _sparkInputController,
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'firewood://spark?...',
                      hintStyle:
                          const TextStyle(color: Colors.white24, fontSize: 11),
                      filled: true,
                      fillColor: const Color(0xFF1E1E23),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF2C2C32)),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.paste,
                            color: Colors.white54, size: 16),
                        tooltip: 'Paste from Clipboard',
                        onPressed: () async {
                          final data = await Clipboard.getData('text/plain');
                          if (data?.text != null) {
                            setState(
                                () => _sparkInputController.text = data!.text!);
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2A2A34),
                    foregroundColor: AppColors.orangeAccent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isProcessing
                      ? null
                      : () => _transmitWithUri(_sparkInputController.text),
                  child: const Text('Send',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Renders the receive QR to a PNG and opens the system save dialog
  /// (Storage Access Framework — no storage permission required, consistent
  /// with how Firewood exports everything else).
  Future<void> _saveQrImage() async {
    final uri = _sparkUri;
    if (uri == null || _isSavingQr) return;

    setState(() => _isSavingQr = true);
    try {
      final png = await buildQrPngBytes(uri);
      String? saved;
      LockService.beginForegroundFlow();
      try {
        saved = await FilePicker.platform.saveFile(
          dialogTitle: 'Save receive QR code',
          fileName: 'firewood_receive_qr.png',
          type: FileType.image,
          bytes: png,
        );
      } finally {
        LockService.endForegroundFlow();
      }

      if (!mounted || saved == null) return; // null → user cancelled
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Text('QR image saved to $saved'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save QR image: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSavingQr = false);
    }
  }

  /// Short user-facing receive state for the pill under the QR.
  /// The verbose "Advertising N addresses (…)" detail stays only in the
  /// bottom status banner, so it is deliberately never shown here.
  String _receivePillStatus() {
    final msg = _statusMessage;
    if (msg.contains('received securely')) return msg;
    if (msg.contains('Failed to start receiver')) {
      return 'Receiver error — see details below';
    }
    if (msg.contains('Starting local receiver')) {
      return 'Starting receiver…';
    }
    return 'Ready to receive';
  }

  Widget _buildReceiveView() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16161D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF282834)),
      ),
      child: Column(
        children: [
          if (_sparkUri != null)
            AnimatedQrDisplay(
              qrData: _sparkUri!,
              size: 210,
            )
          else
            SizedBox(
              height: 210,
              child: Center(
                child: CircularProgressIndicator(color: AppColors.orangeAccent),
              ),
            ),
          const SizedBox(height: 14),

          // Live connection indicator (clean receive status only —
          // the advertising/addresses detail already lives in the
          // status banner at the bottom of the sheet)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF191C23),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF2A2E3B)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _receivePillStatus(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          if (_sparkUri != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                  icon: const Icon(Icons.copy, size: 13, color: Colors.white38),
                  label: const Text(
                    'Copy QR URI',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _sparkUri!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        duration: Duration(seconds: 2),
                        content: Text('AirShare URI copied to clipboard'),
                      ),
                    );
                  },
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                  icon: _isSavingQr
                      ? const SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white38,
                          ),
                        )
                      : const Icon(Icons.save_alt,
                          size: 13, color: Colors.white38),
                  label: Text(
                    _isSavingQr ? 'Saving…' : 'Save QR',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  onPressed: _isSavingQr ? null : _saveQrImage,
                ),
              ],
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

    final current =
        _selectedItem ?? widget.initialItem ?? _availableItems.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Credential to Share',
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70),
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
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600),
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
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600),
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
                    _selectedItem =
                        _availableItems.firstWhere((it) => it.itemId == val);
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isProcessing) ...[
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                  strokeWidth: 1.8, color: AppColors.orangeAccent),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceivedCard() {
    final payload = _receivedPayload!;
    final username = payload.data['username']?.toString() ?? '';
    final password = payload.data['password']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle,
                  size: 20, color: Colors.greenAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  payload.title,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
            ],
          ),
          const Divider(color: Color(0xFF2C2C35), height: 20),
          if (username.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('Username: $username',
                  style: const TextStyle(fontSize: 12, color: Colors.white70)),
            ),
          if (password.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    _passwordRevealed ? password : '••••••••••••',
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: Colors.white),
                  ),
                ),
                IconButton(
                  icon: Icon(
                      _passwordRevealed
                          ? Icons.visibility_off
                          : Icons.visibility,
                      size: 16,
                      color: Colors.white54),
                  onPressed: () =>
                      setState(() => _passwordRevealed = !_passwordRevealed),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReceivedActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Color(0xFF2C2C35)),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Dismiss'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orangeAccent,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.download, color: Colors.black, size: 18),
            label: const Text(
              'Save to My Vault',
              style:
                  TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            onPressed: _saveReceivedItemToVault,
          ),
        ),
      ],
    );
  }
}

/// V-022: signals a request body beyond the 64 KB receiver cap.
class _OversizedBody implements Exception {
  const _OversizedBody();
}
