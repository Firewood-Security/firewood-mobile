// services/p2p_size_limit_service.dart
// Service to configure and enforce P2P transfer size limits (Sending & Receiving)

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class P2PSizeLimitOption {
  final String label;
  final int sizeMb; // 0 = No Limit

  const P2PSizeLimitOption({required this.label, required this.sizeMb});
}

class P2PSizeLimitService {
  static const String _prefKey = 'firewood_p2p_max_share_size_mb';

  static const List<P2PSizeLimitOption> options = [
    P2PSizeLimitOption(label: 'No Limit (Unlimited)', sizeMb: 0),
    P2PSizeLimitOption(label: '10 MB', sizeMb: 10),
    P2PSizeLimitOption(label: '50 MB', sizeMb: 50),
    P2PSizeLimitOption(label: '100 MB', sizeMb: 100),
    P2PSizeLimitOption(label: '500 MB', sizeMb: 500),
  ];

  static final ValueNotifier<int> currentSizeLimitMb = ValueNotifier<int>(0);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    currentSizeLimitMb.value = prefs.getInt(_prefKey) ?? 0;
  }

  static Future<void> setSizeLimitMb(int sizeMb) async {
    currentSizeLimitMb.value = sizeMb;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKey, sizeMb);
  }

  /// Returns null if allowed, or error message if payload exceeds limit
  static String? validatePayloadSize(int bytes) {
    final maxMb = currentSizeLimitMb.value;
    if (maxMb <= 0) return null; // 0 = No Limit

    final payloadMb = bytes / (1024 * 1024);
    if (payloadMb > maxMb) {
      return 'Payload size (${payloadMb.toStringAsFixed(1)} MB) exceeds configured limit of ${maxMb} MB.';
    }
    return null;
  }
}
