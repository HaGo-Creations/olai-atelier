// lib/state/connection_status.dart
//
// Polls the backend /health endpoint to know which Gemma 4 modes are available.
// The Local/Cloud/Online badge in the app bar reads from this.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

@immutable
class ConnectionStatus {
  const ConnectionStatus({
    this.backendReachable = false,
    this.localAvailable = false,
    this.cloudAvailable = false,
    this.localModel = '',
    this.cloudModel = '',
  });

  final bool backendReachable;
  final bool localAvailable;
  final bool cloudAvailable;
  final String localModel;
  final String cloudModel;

  /// Returns the badge label that should appear in the app bar.
  String get badge {
    if (!backendReachable) return 'Mock';
    if (cloudAvailable && localAvailable) return 'Online + Local';
    if (cloudAvailable) return 'Online';
    if (localAvailable) return 'Local';
    return 'Offline';
  }
}

class ConnectionStatusNotifier extends StateNotifier<ConnectionStatus> {
  ConnectionStatusNotifier() : super(const ConnectionStatus()) {
    _check();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _check());
  }

  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    final baseUrl = dotenv.maybeGet('API_BASE_URL')?.trim() ?? '';
    if (baseUrl.isEmpty) {
      if (mounted) state = const ConnectionStatus();
      return;
    }
    try {
      final r = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        if (mounted) {
          state = ConnectionStatus(
            backendReachable: true,
            localAvailable: data['local_available'] ?? false,
            cloudAvailable: data['cloud_available'] ?? false,
            localModel: data['local_model'] ?? '',
            cloudModel: data['cloud_model'] ?? '',
          );
        }
      } else {
        if (mounted) state = const ConnectionStatus();
      }
    } catch (_) {
      if (mounted) state = const ConnectionStatus();
    }
  }

  Future<void> refresh() => _check();
}

final connectionStatusProvider =
    StateNotifierProvider<ConnectionStatusNotifier, ConnectionStatus>(
        (_) => ConnectionStatusNotifier());

// ── Model mode ──────────────────────────────────────────────────────────────

enum ModelMode { auto, cloud, local }

final modelModeProvider = StateProvider<ModelMode>((ref) => ModelMode.auto);
