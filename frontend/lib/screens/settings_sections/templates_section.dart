// lib/screens/settings_sections/templates_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/models.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class TemplatesSection extends ConsumerWidget {
  const TemplatesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = ref.watch(presetsProvider);

    final byType = <ResourceType, List<ResourcePreset>>{};
    for (final t in ResourceType.values) {
      byType[t] = presets.where((p) => p.resourceType == t).toList();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Resource Templates'), actions: const [
        Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: Center(child: ModelBadgeChip())),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addPreset(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Preset'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          PastelCard(
            pastel: Pastels.sky,
            child: Row(
              children: [
                const Icon(Icons.tune, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Each resource type has its own template. Only Worksheet has a visual builder right now. Cards below summarize the fields currently selected in each template — open the builder to add, remove, or reorder them.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final t in ResourceType.values) ...[
            _typeSection(context, t, byType[t]!, ref),
            const SizedBox(height: AppSpacing.lg),
          ],
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _typeSection(BuildContext context, ResourceType type,
      List<ResourcePreset> presets, WidgetRef ref) {
    final pastel = Pastels.forResourceType(type.apiKey);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: pastel.fgFor(Theme.of(context).brightness),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(type.label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(width: 8),
            Text('${presets.length} preset${presets.length == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (presets.isEmpty)
          PastelCard(
            pastel: pastel,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.add_circle_outline,
                      size: 18,
                      color: pastel.fgFor(Theme.of(context).brightness)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        'No presets yet — tap "+ New Preset" to add one.',
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                ],
              ),
            ),
          )
        else
          for (final p in presets) ...[
            _PresetCard(preset: p),
            const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }

  void _addPreset(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    ResourceType type = ResourceType.worksheet;
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('New Preset'),
        content: StatefulBuilder(builder: (c, set) {
          return SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Preset name'),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<ResourceType>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Resource Type'),
                  items: [
                    for (final t in ResourceType.values)
                      DropdownMenuItem(value: t, child: Text(t.label)),
                  ],
                  onChanged: (v) => set(() => type = v ?? type),
                ),
              ],
            ),
          );
        }),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              ref
                  .read(presetsProvider.notifier)
                  .add(nameCtrl.text.trim(), type);
              Navigator.pop(c);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Preset card — shows ordered block list, not toggles
// ════════════════════════════════════════════════════════════════════════════

class _PresetCard extends ConsumerWidget {
  const _PresetCard({required this.preset});
  final ResourcePreset preset;

  bool get _isUnderConstruction =>
      preset.resourceType != ResourceType.worksheet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(presetsProvider.notifier);
    final pastel = Pastels.forResourceType(preset.resourceType.apiKey);

    return PastelCard(
      onTap: _isUnderConstruction || preset.locked
          ? null
          : () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => _WorksheetBuilder(presetId: preset.id))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              PastelPill(label: preset.resourceType.label, pastel: pastel),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(preset.name,
                    style: Theme.of(context).textTheme.titleSmall),
              ),
              if (_isUnderConstruction)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.construction,
                          size: 12,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Text('Builder coming soon',
                          style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ),
                )
              else
                TextButton.icon(
                  onPressed: preset.locked
                      ? null
                      : () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) =>
                              _WorksheetBuilder(presetId: preset.id))),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Open builder'),
                ),
              LockToggle(
                  locked: preset.locked,
                  onChanged: (_) => notifier.toggleLock(preset.id)),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed:
                    preset.locked ? null : () => notifier.remove(preset.id),
              ),
            ],
          ),
          const Divider(),
          // Ordered block list (replaces the toggles)
          if (preset.blocks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                _isUnderConstruction
                    ? 'Builder coming soon — fields will appear here.'
                    : 'No blocks yet. Tap "Open builder" to design this template.',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${preset.blocks.length} field${preset.blocks.length == 1 ? '' : 's'} configured',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Numbered ordered list
                  for (var i = 0; i < preset.blocks.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 22,
                            child: Text(
                              '${i + 1}.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color:
                                    pastel.fgFor(Theme.of(context).brightness),
                              ),
                            ),
                          ),
                          Icon(_iconFor(preset.blocks[i].type),
                              size: 14,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              preset.blocks[i].label,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (preset.blocks[i].type ==
                                  WorksheetBlockType.questions &&
                              preset.blocks[i].columns > 1)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color:
                                    pastel.bgFor(Theme.of(context).brightness),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                '${preset.blocks[i].columns} cols',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: pastel
                                      .fgFor(Theme.of(context).brightness),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  IconData _iconFor(WorksheetBlockType t) => switch (t) {
        WorksheetBlockType.title => Icons.title,
        WorksheetBlockType.lesson => Icons.menu_book_outlined,
        WorksheetBlockType.objectives => Icons.flag_outlined,
        WorksheetBlockType.instructions => Icons.info_outline,
        WorksheetBlockType.questions => Icons.help_outline,
        WorksheetBlockType.image => Icons.image_outlined,
        WorksheetBlockType.table => Icons.table_chart_outlined,
        WorksheetBlockType.answerKey => Icons.check_circle_outline,
        WorksheetBlockType.notes => Icons.sticky_note_2_outlined,
        WorksheetBlockType.custom => Icons.widgets_outlined,
      };
}

// ════════════════════════════════════════════════════════════════════════════
// Worksheet Builder (unchanged from your version)
// ════════════════════════════════════════════════════════════════════════════

class _WorksheetBuilder extends ConsumerStatefulWidget {
  const _WorksheetBuilder({required this.presetId});
  final String presetId;
  @override
  ConsumerState<_WorksheetBuilder> createState() => _WorksheetBuilderState();
}

class _WorksheetBuilderState extends ConsumerState<_WorksheetBuilder> {
  String? _selectedBlockId;
  final _uuid = const Uuid();

  ResourcePreset get _preset =>
      ref.read(presetsProvider).firstWhere((p) => p.id == widget.presetId);

  void _saveBlocks(List<WorksheetBlock> blocks) {
    ref.read(presetsProvider.notifier).replaceBlocks(widget.presetId, blocks);
  }

  void _addBlock(WorksheetBlockType type) {
    final blocks = List<WorksheetBlock>.from(_preset.blocks);
    blocks.add(WorksheetBlock(id: _uuid.v4(), type: type, label: type.label));
    _saveBlocks(blocks);
    setState(() => _selectedBlockId = blocks.last.id);
  }

  void _removeBlock(String id) {
    _saveBlocks(_preset.blocks.where((b) => b.id != id).toList());
    setState(() => _selectedBlockId = null);
  }

  void _moveBlock(String id, int delta) {
    final blocks = List<WorksheetBlock>.from(_preset.blocks);
    final idx = blocks.indexWhere((b) => b.id == id);
    if (idx < 0) return;
    final newIdx = (idx + delta).clamp(0, blocks.length - 1);
    if (newIdx == idx) return;
    final item = blocks.removeAt(idx);
    blocks.insert(newIdx, item);
    _saveBlocks(blocks);
  }

  void _updateBlock(WorksheetBlock updated) {
    final blocks = [
      for (final b in _preset.blocks)
        if (b.id == updated.id) updated else b,
    ];
    _saveBlocks(blocks);
  }

  @override
  Widget build(BuildContext context) {
    final preset =
        ref.watch(presetsProvider).firstWhere((p) => p.id == widget.presetId);
    final selected = _selectedBlockId == null
        ? null
        : preset.blocks.cast<WorksheetBlock?>().firstWhere(
              (b) => b!.id == _selectedBlockId,
              orElse: () => null,
            );
    final branding = ref.watch(brandingProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Builder — ${preset.name}'),
      ),
      body: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 720;
        if (wide) {
          return Row(
            children: [
              Expanded(flex: 3, child: _paperPanel(preset, branding)),
              const VerticalDivider(width: 1),
              SizedBox(width: 320, child: _sidePanel(preset, selected)),
            ],
          );
        }
        return Column(
          children: [
            Expanded(child: _paperPanel(preset, branding)),
            const Divider(height: 1),
            SizedBox(height: 360, child: _sidePanel(preset, selected)),
          ],
        );
      }),
    );
  }

  Widget _paperPanel(ResourcePreset preset, Branding branding) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: AspectRatio(
              aspectRatio: 210 / 297,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: AppShadows.card(Brightness.light),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _LetterheadHeader(branding: branding),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        children: [
                          for (final block in preset.blocks) ...[
                            _PaperBlock(
                              block: block,
                              selected: block.id == _selectedBlockId,
                              onTap: () =>
                                  setState(() => _selectedBlockId = block.id),
                            ),
                            const SizedBox(height: 8),
                          ],
                          InkWell(
                            onTap: _showAddBlockSheet,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Pastels.peach
                                    .bgFor(Brightness.light)
                                    .withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Pastels.peach
                                      .fgFor(Brightness.light)
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add,
                                      size: 14,
                                      color: Pastels.peach
                                          .fgFor(Brightness.light)),
                                  const SizedBox(width: 6),
                                  Text('Add block',
                                      style: TextStyle(
                                          color: Pastels.peach
                                              .fgFor(Brightness.light),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _LetterheadFooter(branding: branding),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sidePanel(ResourcePreset preset, WorksheetBlock? selected) {
    if (selected == null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Blocks', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            Text('Click a block on the page to edit it, or add new blocks.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.tonalIcon(
              onPressed: _showAddBlockSheet,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add new block'),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Order', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Expanded(
              child: ListView(
                children: [
                  for (final b in preset.blocks)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(_iconFor(b.type), size: 16),
                      title: Text(b.label,
                          style: Theme.of(context).textTheme.bodyMedium),
                      onTap: () => setState(() => _selectedBlockId = b.id),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final qTypes = ref.watch(questionTypesProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_iconFor(selected.type), size: 18),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(selected.type.label,
                        style: Theme.of(context).textTheme.titleMedium)),
                IconButton(
                    icon: const Icon(Icons.arrow_upward, size: 18),
                    onPressed: () => _moveBlock(selected.id, -1)),
                IconButton(
                    icon: const Icon(Icons.arrow_downward, size: 18),
                    onPressed: () => _moveBlock(selected.id, 1)),
                IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () => _removeBlock(selected.id)),
              ],
            ),
            const Divider(),
            TextFormField(
              key: ValueKey('label-${selected.id}'),
              initialValue: selected.label,
              decoration: const InputDecoration(labelText: 'Label'),
              onChanged: (v) => _updateBlock(selected.copyWith(label: v)),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: ValueKey('ph-${selected.id}'),
              initialValue: selected.placeholder,
              decoration: InputDecoration(
                labelText: selected.type == WorksheetBlockType.custom
                    ? 'Content / placeholder'
                    : 'Placeholder / hint',
                hintText: selected.type == WorksheetBlockType.custom
                    ? 'Write the custom block content or hint'
                    : 'Shown in the preview',
              ),
              maxLines: 3,
              onChanged: (v) => _updateBlock(selected.copyWith(placeholder: v)),
            ),
            if (selected.type == WorksheetBlockType.questions) ...[
              const SizedBox(height: AppSpacing.lg),
              Text('Columns', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('1')),
                  ButtonSegment(value: 2, label: Text('2')),
                  ButtonSegment(value: 3, label: Text('3')),
                ],
                selected: {selected.columns.clamp(1, 3)},
                onSelectionChanged: (s) =>
                    _updateBlock(selected.copyWith(columns: s.first)),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Question types',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(
                'Defined in Field Editor → Question Schemas',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              if (qTypes.isEmpty)
                Text('No question types defined yet.',
                    style: Theme.of(context).textTheme.bodySmall)
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final t in qTypes)
                      FilterChip(
                        label: Text(t),
                        selected: selected.questionTypes.contains(t),
                        onSelected: (sel) {
                          final list =
                              List<String>.from(selected.questionTypes);
                          if (sel) {
                            if (!list.contains(t)) list.add(t);
                          } else {
                            list.remove(t);
                          }
                          _updateBlock(selected.copyWith(questionTypes: list));
                        },
                      ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAddBlockSheet() {
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add block', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in WorksheetBlockType.values)
                    ActionChip(
                      avatar: Icon(_iconFor(t), size: 16),
                      label: Text(t.label),
                      onPressed: () {
                        _addBlock(t);
                        Navigator.pop(c);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(WorksheetBlockType t) => switch (t) {
        WorksheetBlockType.title => Icons.title,
        WorksheetBlockType.lesson => Icons.menu_book_outlined,
        WorksheetBlockType.objectives => Icons.flag_outlined,
        WorksheetBlockType.instructions => Icons.info_outline,
        WorksheetBlockType.questions => Icons.help_outline,
        WorksheetBlockType.image => Icons.image_outlined,
        WorksheetBlockType.table => Icons.table_chart_outlined,
        WorksheetBlockType.answerKey => Icons.check_circle_outline,
        WorksheetBlockType.notes => Icons.sticky_note_2_outlined,
        WorksheetBlockType.custom => Icons.widgets_outlined,
      };
}

// ── Letterhead rendering for builder canvas ────────────────────────────────

class _LetterheadHeader extends StatelessWidget {
  const _LetterheadHeader({required this.branding});
  final Branding branding;
  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.55,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(color: Colors.grey.shade400, width: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: const Color(0xFF4E3470),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Icon(Icons.school, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    branding.schoolName.isEmpty
                        ? 'School Name'
                        : branding.schoolName,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87),
                  ),
                  if (branding.address.isNotEmpty)
                    Text(branding.address,
                        style:
                            const TextStyle(fontSize: 8, color: Colors.black54),
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
}

class _LetterheadFooter extends StatelessWidget {
  const _LetterheadFooter({required this.branding});
  final Branding branding;
  @override
  Widget build(BuildContext context) {
    final txt = branding.footerText.isNotEmpty
        ? branding.footerText
        : '${branding.phone} ${branding.email}'.trim();
    return Opacity(
      opacity: 0.55,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 3),
        decoration: BoxDecoration(
          border:
              Border(top: BorderSide(color: Colors.grey.shade400, width: 0.5)),
        ),
        child: Text(
          txt.isEmpty ? 'Footer' : txt,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 8, color: Colors.black54),
        ),
      ),
    );
  }
}

class _PaperBlock extends StatelessWidget {
  const _PaperBlock(
      {required this.block, required this.selected, required this.onTap});
  final WorksheetBlock block;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isHeader = block.type == WorksheetBlockType.title;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding:
            EdgeInsets.symmetric(horizontal: 10, vertical: isHeader ? 10 : 6),
        decoration: BoxDecoration(
          color: selected
              ? Pastels.studio.bgFor(Brightness.light).withValues(alpha: 0.6)
              : block.type == WorksheetBlockType.custom
                  ? Pastels.peach
                      .bgFor(Brightness.light)
                      .withValues(alpha: 0.25)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? Pastels.studio.fgFor(Brightness.light)
                : block.type == WorksheetBlockType.custom
                    ? Pastels.peach
                        .fgFor(Brightness.light)
                        .withValues(alpha: 0.6)
                    : Colors.grey.shade300,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (block.type == WorksheetBlockType.custom) ...[
                  Icon(Icons.widgets,
                      size: 12, color: Pastels.peach.fgFor(Brightness.light)),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    block.label,
                    style: TextStyle(
                      fontSize: isHeader ? 14 : 11,
                      fontWeight: isHeader ? FontWeight.w800 : FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            if (block.placeholder.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(block.placeholder,
                  style: const TextStyle(
                      fontSize: 10,
                      color: Colors.black54,
                      fontStyle: FontStyle.italic)),
            ],
            if (block.type == WorksheetBlockType.questions) ...[
              const SizedBox(height: 4),
              if (block.questionTypes.isNotEmpty) ...[
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: [
                    for (final t in block.questionTypes)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Pastels.studio.bgFor(Brightness.light),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(t,
                            style: TextStyle(
                              fontSize: 8,
                              color: Pastels.studio.fgFor(Brightness.light),
                              fontWeight: FontWeight.w600,
                            )),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
            ],
            if (block.type == WorksheetBlockType.image)
              Container(
                margin: const EdgeInsets.only(top: 4),
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.image, size: 20, color: Colors.grey),
              ),
            if (block.type == WorksheetBlockType.lesson)
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Text('Lesson: {{lesson_name}}',
                    style: TextStyle(
                        fontSize: 9,
                        color: Colors.black54,
                        fontStyle: FontStyle.italic)),
              ),
          ],
        ),
      ),
    );
  }
}
