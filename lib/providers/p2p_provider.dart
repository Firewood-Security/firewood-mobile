// providers/p2p_provider.dart
// Riverpod providers for Firewood P2P transfer system

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../p2p/p2p_service.dart';
import '../p2p/session_manager.dart';
import '../p2p/transfer_models.dart';

/// SessionManager provider
final sessionProvider = Provider<SessionManager>((ref) {
  final session = SessionManager();
  ref.onDispose(() => session.dispose());
  return session;
});

/// P2PService provider
final p2pServiceProvider = Provider<P2PService>((ref) {
  final session = ref.watch(sessionProvider);
  final service = P2PService(sessionManager: session);
  ref.onDispose(() => service.dispose());
  return service;
});

/// Transfer State provider stream
final connectionStateProvider = StreamProvider<TransferState>((ref) {
  final session = ref.watch(sessionProvider);
  return session.stateStream;
});

/// Transfer Progress provider stream
final transferProgressProvider = StreamProvider<double>((ref) {
  final session = ref.watch(sessionProvider);
  return session.progressStream;
});
