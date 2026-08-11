// main.dart
// App entry point - initializes services and runs FirewoodApp

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'services/accent_color_service.dart';
import 'services/update_service.dart';
import 'services/p2p_size_limit_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Custom error handler to log Flutter framework errors and prevent silent white screens in Release mode
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError caught: ${details.exception}');
  };

  // Custom error widget builder to display diagnostic information instead of a blank screen in Release mode
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFF121212),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              const Text(
                'An unexpected error occurred.',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                details.exceptionAsString(),
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  };

  try {
    await AccentColorService.init();
  } catch (e) {
    debugPrint('Failed to initialize AccentColorService: $e');
  }

  try {
    await P2PSizeLimitService.init();
  } catch (e) {
    debugPrint('Failed to initialize P2PSizeLimitService: $e');
  }

  try {
    UpdateService.initUpdateChecker();
  } catch (e) {
    debugPrint('Failed to initialize UpdateChecker: $e');
  }

  runApp(const ProviderScope(child: FirewoodApp()));
}