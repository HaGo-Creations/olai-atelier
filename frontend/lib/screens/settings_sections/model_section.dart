// lib/screens/settings_sections/model_section.dart
//
// Defensive version: no dependency on Pastels.* constants or SectionHeader.
// Uses raw colors so it can't silently fail if theme names are missing.

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/connection_status.dart';

class ModelSection extends ConsumerWidget {
  const ModelSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectionStatusProvider);
    final mode = ref.watch(modelModeProvider);
    final baseUrl =
        dotenv.maybeGet('API_BASE_URL')?.trim() ?? '(not configured)';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Model & Connection'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh status',
            onPressed: () =>
                ref.read(connectionStatusProvider.notifier).refresh(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _statusCard(context, status, baseUrl),
          const SizedBox(height: 16),
          _sectionTitle(context, 'Mode'),
          _modeCard(context, ref, status, mode),
          const SizedBox(height: 16),
          _sectionTitle(context, 'Available models'),
          _availableModelsCard(context, status),
          const SizedBox(height: 16),
          _capabilitiesCard(context),
        ],
      ),
    );
  }

  Widget _statusCard(
      BuildContext context, ConnectionStatus status, String baseUrl) {
    final Color bg;
    final IconData icon;
    if (!status.backendReachable) {
      bg = const Color(0xFFF5E0DC);
      icon = Icons.cloud_off;
    } else if (status.cloudAvailable) {
      bg = const Color(0xFFC6F0D2);
      icon = Icons.cloud_done;
    } else {
      bg = const Color(0xFFC9DDF5);
      icon = Icons.computer;
    }

    return Card(
      color: bg,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 22, color: Colors.black87),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    status.backendReachable
                        ? 'Backend connected'
                        : 'Backend unreachable (using mock data)',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    status.badge,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Endpoint: $baseUrl',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeCard(BuildContext context, WidgetRef ref, ConnectionStatus status,
      ModelMode mode) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            RadioListTile<ModelMode>(
              title: const Text('Auto'),
              subtitle:
                  const Text('Use cloud if available, fall back to local'),
              value: ModelMode.auto,
              groupValue: mode,
              onChanged: (v) {
                if (v != null) {
                  ref.read(modelModeProvider.notifier).state = v;
                }
              },
            ),
            const Divider(height: 1),
            RadioListTile<ModelMode>(
              title: const Text('Cloud only'),
              subtitle: Text(
                status.cloudAvailable
                    ? 'Gemma 4 26B A4B IT — fastest, frontier quality'
                    : 'Not available (no Google API key on backend)',
              ),
              value: ModelMode.cloud,
              groupValue: mode,
              onChanged: status.cloudAvailable
                  ? (v) {
                      if (v != null) {
                        ref.read(modelModeProvider.notifier).state = v;
                      }
                    }
                  : null,
            ),
            const Divider(height: 1),
            RadioListTile<ModelMode>(
              title: const Text('Local only'),
              subtitle: Text(
                status.localAvailable
                    ? 'Gemma 4 ${status.localModel} via Ollama — offline'
                    : 'Not available (Ollama not running on backend)',
              ),
              value: ModelMode.local,
              groupValue: mode,
              onChanged: status.localAvailable
                  ? (v) {
                      if (v != null) {
                        ref.read(modelModeProvider.notifier).state = v;
                      }
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _availableModelsCard(BuildContext context, ConnectionStatus status) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _modelRow('Local (offline)', status.localModel,
                status.localAvailable, 'Runs on user device via Ollama'),
            const Divider(),
            _modelRow('Cloud (online)', status.cloudModel,
                status.cloudAvailable, 'Google AI Studio API'),
          ],
        ),
      ),
    );
  }

  Widget _modelRow(String label, String model, bool available, String detail) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            available ? Icons.check_circle : Icons.cancel_outlined,
            size: 18,
            color: available ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text(
                  model.isEmpty ? detail : '$model · $detail',
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _capabilitiesCard(BuildContext context) {
    return Card(
      color: const Color(0xFFE7DFF7), // lavender
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gemma 4 capabilities used',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87),
            ),
            const SizedBox(height: 8),
            _cap('Native system prompt'),
            _cap('Image understanding (PDF/photo OCR, multilingual)'),
            _cap('Audio (ASR + translate) — local E2B only'),
            _cap('Function calling (structured JSON output)'),
            _cap('Thinking mode (reasoning toggle)'),
            _cap('128K–256K context window'),
            _cap('35+ languages out of the box'),
          ],
        ),
      ),
    );
  }

  Widget _cap(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, size: 12, color: Colors.black54),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 12, color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}
