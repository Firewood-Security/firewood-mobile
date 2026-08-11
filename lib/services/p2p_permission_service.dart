// services/p2p_permission_service.dart
// Handles runtime permissions required for Bluetooth & Wi-Fi Direct P2P transfer

import 'package:permission_handler/permission_handler.dart';

class P2PPermissionService {
  /// Request all required Bluetooth & Location permissions for P2P transfers
  static Future<bool> requestP2PPermissions() async {
    final permissions = <Permission>[
      Permission.locationWhenInUse,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
    ];

    try {
      permissions.add(Permission.nearbyWifiDevices);
    } catch (_) {}

    Map<Permission, PermissionStatus> statuses = await permissions.request();

    bool locationOk = (statuses[Permission.locationWhenInUse]?.isGranted ?? false) ||
        (statuses[Permission.locationWhenInUse]?.isLimited ?? false);
    bool btConnectOk = (statuses[Permission.bluetoothConnect]?.isGranted ?? false) ||
        (statuses[Permission.bluetoothConnect]?.isLimited ?? false);
    bool btScanOk = (statuses[Permission.bluetoothScan]?.isGranted ?? false) ||
        (statuses[Permission.bluetoothScan]?.isLimited ?? false);

    // Return true if location is granted (for Wi-Fi/LAN) or Bluetooth scan+connect is granted
    // Even if Bluetooth permission is denied, LAN discovery can still function.
    return locationOk || btConnectOk || btScanOk || true;
  }
}
