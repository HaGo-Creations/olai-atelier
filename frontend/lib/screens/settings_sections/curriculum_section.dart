// lib/screens/settings_sections/curriculum_section.dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class CurriculumSectionScreen extends ConsumerStatefulWidget {
  const CurriculumSectionScreen({super.key});
  @override
  ConsumerState<CurriculumSectionScreen> createState() =>
      _CurriculumSectionScreenState();
}

class _CurriculumSectionScreenState
    extends ConsumerState<CurriculumSectionScreen> {
  String? _g;
  String? _s;

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(curriculumProvider);
    final grades = ref.watch(teacherGradesProvider);
    final subjects = ref.watch(teacherSubjectsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Curriculum Library'), actions: const [
        Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: Center(child: ModelBadgeChip())),
      ]),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          PastelCard(
            pastel: Pastels.mint,
            child: Row(
              children: [
                const Icon(Icons.psychology_outlined, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Entries here are passed as context whenever Gemma generates a resource. Subjects and grades come from your Profile.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'New Curriculum Entry'),
          PastelCard(
            child: (grades.isEmpty || subjects.isEmpty)
                ? Text(
                    'Add subjects and grades in Profile (and Field Editor) first.',
                    style: Theme.of(context).textTheme.bodySmall)
                : Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _g,
                          decoration: const InputDecoration(labelText: 'Grade'),
                          items: [
                            for (final g in grades)
                              DropdownMenuItem(value: g, child: Text(g))
                          ],
                          onChanged: (v) => setState(() => _g = v),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _s,
                          decoration:
                              const InputDecoration(labelText: 'Subject'),
                          items: [
                            for (final s in subjects)
                              DropdownMenuItem(value: s, child: Text(s))
                          ],
                          onChanged: (v) => setState(() => _s = v),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      FilledButton.icon(
                        onPressed: (_g != null && _s != null)
                            ? () {
                                ref
                                    .read(curriculumProvider.notifier)
                                    .addEntry(grade: _g!, subject: _s!);
                                setState(() {
                                  _g = null;
                                  _s = null;
                                });
                              }
                            : null,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Create'),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Library'),
          if (entries.isEmpty)
            PastelCard(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text('No entries yet — create your first one above.',
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
            )
          else
            for (final e in entries) ...[
              _EntryCard(entry: e),
              const SizedBox(height: AppSpacing.md),
            ],
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────

class _EntryCard extends ConsumerStatefulWidget {
  const _EntryCard({required this.entry});
  final CurriculumEntry entry;
  @override
  ConsumerState<_EntryCard> createState() => _EntryCardState();
}

class _EntryCardState extends ConsumerState<_EntryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final n = ref.read(curriculumProvider.notifier);

    final filled = CurriculumSectionKey.values.where((k) {
      return k.isListBased
          ? e.listSection(k).hasContent
          : e.freeTextSection(k).hasContent;
    }).length;

    return PastelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${e.grade} • ${e.subject}',
                        style: Theme.of(context).textTheme.titleSmall),
                    Text(
                        '$filled of ${CurriculumSectionKey.values.length} sections filled',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              if (e.policyScope != null)
                PastelPill(
                  label: e.policyScope == PolicyScope.national
                      ? 'National'
                      : 'State',
                  pastel: Pastels.sky,
                ),
              const SizedBox(width: AppSpacing.sm),
              LockToggle(
                  locked: e.locked, onChanged: (_) => n.toggleEntryLock(e.id)),
              IconButton(
                icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: e.locked ? null : () => n.remove(e.id),
              ),
            ],
          ),
          if (_expanded) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Text('Policy scope',
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(width: AppSpacing.md),
                  SegmentedButton<PolicyScope?>(
                    style:
                        const ButtonStyle(visualDensity: VisualDensity.compact),
                    segments: const [
                      ButtonSegment(
                          value: PolicyScope.national, label: Text('National')),
                      ButtonSegment(
                          value: PolicyScope.state, label: Text('State')),
                    ],
                    selected: {e.policyScope},
                    emptySelectionAllowed: true,
                    onSelectionChanged: e.locked
                        ? null
                        : (s) => n.replace(e.copyWith(
                            policyScope: s.isEmpty ? null : s.first)),
                  ),
                ],
              ),
            ),
            const Divider(),
            for (final key in CurriculumSectionKey.values) ...[
              if (key.isListBased)
                _ListSectionEditor(entry: e, sectionKey: key)
              else
                _FreeTextSectionEditor(entry: e, sectionKey: key),
              if (key != CurriculumSectionKey.values.last) const Divider(),
            ],
          ],
        ],
      ),
    );
  }
}

// ── List section (Goals / Competencies / Outcomes / Lessons) ───────────────

class _ListSectionEditor extends ConsumerWidget {
  const _ListSectionEditor({required this.entry, required this.sectionKey});
  final CurriculumEntry entry;
  final CurriculumSectionKey sectionKey;

  Future<void> _uploadDoc(WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'docx'],
    );
    if (result == null) return;
    final file = result.files.first;
    final mockParsed =
        'Auto-extracted from ${file.name} — Gemma will refine items from here. Click items below to edit.';
    ref.read(curriculumProvider.notifier).setListDocument(
          entry.id,
          sectionKey,
          name: file.name,
          parsedText: mockParsed,
        );
    // Mock: append 3 proposed items
    for (var i = 1; i <= 3; i++) {
      ref.read(curriculumProvider.notifier).addListItem(entry.id, sectionKey,
          text: 'Proposed item ${i} from ${file.name}');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.read(curriculumProvider.notifier);
    final section = entry.listSection(sectionKey);
    final locked = entry.locked || section.locked;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  sectionKey.label,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (section.hasContent) ...[
                Icon(Icons.check_circle,
                    size: 16,
                    color: Pastels.mint.fgFor(Theme.of(context).brightness)),
                const SizedBox(width: 4),
              ],
              LockToggle(
                locked: locked,
                size: 16,
                onChanged: entry.locked
                    ? (_) {}
                    : (_) => n.toggleListSectionLock(entry.id, sectionKey),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          // Items
          if (section.items.isEmpty)
            Text('No items yet — tap + to add.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontStyle: FontStyle.italic))
          else
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorder: locked
                  ? (a, b) {}
                  : (oldIdx, newIdx) =>
                      n.reorderListItems(entry.id, sectionKey, oldIdx, newIdx),
              children: [
                for (var idx = 0; idx < section.items.length; idx++)
                  _ItemRow(
                    key: ValueKey(section.items[idx].id),
                    item: section.items[idx],
                    index: idx,
                    locked: locked,
                    onTextChanged: (v) => n.updateListItemText(
                        entry.id, sectionKey, section.items[idx].id, v),
                    onDelete: () => n.removeListItem(
                        entry.id, sectionKey, section.items[idx].id),
                  ),
              ],
            ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              TextButton.icon(
                onPressed:
                    locked ? null : () => n.addListItem(entry.id, sectionKey),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add item'),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const Spacer(),
              if (section.documentName != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(section.documentName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              TextButton.icon(
                onPressed: locked ? null : () => _uploadDoc(ref),
                icon: const Icon(Icons.upload_file, size: 14),
                label: Text(
                    section.documentName == null ? 'Auto-extract' : 'Replace',
                    style: const TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              if (section.documentName != null)
                IconButton(
                  iconSize: 14,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close),
                  onPressed: locked
                      ? null
                      : () => n.setListDocument(entry.id, sectionKey,
                          name: null, parsedText: null),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    super.key,
    required this.item,
    required this.index,
    required this.locked,
    required this.onTextChanged,
    required this.onDelete,
  });
  final CurriculumItem item;
  final int index;
  final bool locked;
  final ValueChanged<String> onTextChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (!locked)
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.drag_indicator, size: 16, color: Colors.grey),
              ),
            ),
          SizedBox(
            width: 144,
            child: Text(
              item.code,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: TextFormField(
              key: ValueKey('text-${item.id}'),
              initialValue: item.text,
              enabled: !locked,
              decoration: const InputDecoration(
                hintText: 'Type the item…',
                isDense: true,
                border: InputBorder.none,
              ),
              maxLines: null,
              onChanged: onTextChanged,
            ),
          ),
          IconButton(
            iconSize: 14,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close),
            onPressed: locked ? null : onDelete,
          ),
        ],
      ),
    );
  }
}

// ── Free-text section (Policy / Domain / Additional Context) ───────────────

class _FreeTextSectionEditor extends ConsumerStatefulWidget {
  const _FreeTextSectionEditor({required this.entry, required this.sectionKey});
  final CurriculumEntry entry;
  final CurriculumSectionKey sectionKey;
  @override
  ConsumerState<_FreeTextSectionEditor> createState() =>
      _FreeTextSectionEditorState();
}

class _FreeTextSectionEditorState
    extends ConsumerState<_FreeTextSectionEditor> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.entry.freeTextSection(widget.sectionKey).text,
    );
  }

  @override
  void didUpdateWidget(covariant _FreeTextSectionEditor old) {
    super.didUpdateWidget(old);
    final newText = widget.entry.freeTextSection(widget.sectionKey).text;
    if (_ctrl.text != newText) _ctrl.text = newText;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _uploadDoc() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'docx'],
    );
    if (result == null) return;
    final file = result.files.first;
    final section = widget.entry.freeTextSection(widget.sectionKey);
    ref.read(curriculumProvider.notifier).updateFreeText(
          widget.entry.id,
          widget.sectionKey,
          section.copyWith(
            documentName: file.name,
            documentParsedText:
                'Extracted from ${file.name}. Gemma will use this text as context.',
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.entry.freeTextSection(widget.sectionKey);
    final locked = widget.entry.locked || s.locked;
    final n = ref.read(curriculumProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(widget.sectionKey.label,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              if (s.hasContent) ...[
                Icon(Icons.check_circle,
                    size: 16,
                    color: Pastels.mint.fgFor(Theme.of(context).brightness)),
                const SizedBox(width: 4),
              ],
              LockToggle(
                locked: locked,
                size: 16,
                onChanged: widget.entry.locked
                    ? (_) {}
                    : (_) => n.toggleFreeTextLock(
                        widget.entry.id, widget.sectionKey),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: _ctrl,
            enabled: !locked,
            decoration: const InputDecoration(
              hintText: 'Paste text here…',
              isDense: true,
            ),
            maxLines: 3,
            onChanged: (v) => n.updateFreeText(
                widget.entry.id, widget.sectionKey, s.copyWith(text: v)),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              if (s.documentName != null) ...[
                Icon(Icons.description_outlined,
                    size: 14,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(s.documentName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
                ),
                IconButton(
                  iconSize: 14,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close),
                  onPressed: locked
                      ? null
                      : () => n.updateFreeText(widget.entry.id,
                          widget.sectionKey, s.copyWith(clearDocument: true)),
                ),
              ] else
                Expanded(
                  child: Text('No document uploaded',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontStyle: FontStyle.italic)),
                ),
              TextButton.icon(
                onPressed: locked ? null : _uploadDoc,
                icon: const Icon(Icons.upload_file, size: 14),
                label: Text(s.documentName == null ? 'Upload' : 'Replace',
                    style: const TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
