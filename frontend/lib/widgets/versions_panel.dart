// lib/widgets/versions_panel.dart
//
// Displays version history for a resource. Each version is a snapshot taken
// before an edit or rename. User can view, restore, or diff.

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../state/providers.dart';
import '../theme.dart';
import 'common.dart';

class VersionsPanel extends ConsumerStatefulWidget {
  const VersionsPanel({super.key, required this.resource});
  final Resource resource;
  @override
  ConsumerState<VersionsPanel> createState() => _VersionsPanelState();
}

class _VersionsPanelState extends ConsumerState<VersionsPanel> {
  ResourceVersion? _selected;

  @override
  Widget build(BuildContext context) {
    final versions =
        ref.watch(resourceVersionsProvider)[widget.resource.id] ?? const [];
    final sorted = [...versions]
      ..sort((a, b) => b.versionNumber.compareTo(a.versionNumber));

    return Scaffold(
      appBar: AppBar(title: Text('Version History — ${widget.resource.title}')),
      body: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 800;
        if (versions.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history,
                      size: 48,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4)),
                  const SizedBox(height: AppSpacing.md),
                  Text('No previous versions',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'A snapshot is taken every time you edit or rename this resource.',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final list = ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: sorted.length + 1,
          itemBuilder: (_, i) {
            if (i == 0) return _currentTile();
            final v = sorted[i - 1];
            return _versionTile(v);
          },
        );

        if (wide) {
          return Row(
            children: [
              SizedBox(width: 320, child: list),
              const VerticalDivider(width: 1),
              Expanded(child: _preview()),
            ],
          );
        }
        return _selected == null ? list : _preview();
      }),
    );
  }

  Widget _currentTile() {
    return PastelCard(
      pastel: Pastels.studio,
      child: Row(
        children: [
          PastelPill(label: 'CURRENT', pastel: Pastels.studio),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.resource.title,
                    style: Theme.of(context).textTheme.bodyMedium),
                Text('Active version',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _versionTile(ResourceVersion v) {
    final selected = _selected?.id == v.id;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: PastelCard(
        selected: selected,
        onTap: () => setState(() => _selected = v),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              alignment: Alignment.center,
              child: Text('v${v.versionNumber}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 12)),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(v.title ?? widget.resource.title,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(
                    DateFormat('MMM d, HH:mm').format(v.savedAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (v.note.isNotEmpty)
                    Text(v.note,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontStyle: FontStyle.italic),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _preview() {
    final v = _selected;
    if (v == null) {
      return Center(
        child: Text('Pick a version to preview',
            style: Theme.of(context).textTheme.bodySmall),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Version ${v.versionNumber}',
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(DateFormat('MMM d, yyyy • HH:mm').format(v.savedAt),
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _restore(v),
                icon: const Icon(Icons.restore, size: 16),
                label: const Text('Restore this version'),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: PastelCard(
              child: SingleChildScrollView(
                child: MarkdownBody(data: v.content),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _restore(ResourceVersion v) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Restore version ${v.versionNumber}?'),
        content: const Text(
            'The current content will be replaced. A snapshot of the current version will be saved first.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Restore')),
        ],
      ),
    );
    if (confirm != true) return;

    // Snapshot current before replacing
    ref.read(resourceVersionsProvider.notifier).recordVersion(
          widget.resource,
          note: 'Auto-saved before restoring v${v.versionNumber}',
        );
    final restored =
        widget.resource.copyWith(content: v.content, title: v.title);
    await ref.read(apiServiceProvider).updateResource(restored);
    ref.invalidate(resourcesProvider);
    ref.invalidate(searchResultsProvider);
    if (mounted) Navigator.pop(context);
  }
}
