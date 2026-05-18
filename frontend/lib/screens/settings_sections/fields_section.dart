// lib/screens/settings_sections/fields_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'question_schemas_section.dart';

class FieldsSection extends ConsumerWidget {
  const FieldsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fields = ref.watch(fieldsProvider);
    final notifier = ref.read(fieldsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Field Editor'), actions: const [
        Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: Center(child: ModelBadgeChip())),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddFieldDialog(context, notifier),
        icon: const Icon(Icons.add),
        label: const Text('Add Field'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Question Schemas link card (NEW)
          PastelCard(
            pastel: Pastels.sky,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const QuestionSchemasSection()),
            ),
            child: Row(
              children: [
                const Icon(Icons.quiz_outlined, size: 22),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Question Schemas',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        'Define data shapes for MCQ, Short Answer, etc. Used by builder + AI.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Info banner
          PastelCard(
            pastel: Pastels.lavender,
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Fields defined here drive dropdowns and chips in Studio, Curriculum, and Profile in real time.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Field cards
          for (final f in fields) ...[
            _FieldCard(field: f),
            const SizedBox(height: AppSpacing.md),
          ],
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  void _showAddFieldDialog(BuildContext context, FieldsNotifier notifier) {
    final nameCtrl = TextEditingController();
    FieldType type = FieldType.dropdown;
    final optsCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('New Field'),
        content: StatefulBuilder(builder: (c, set) {
          return SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Field name')),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<FieldType>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(
                        value: FieldType.text, child: Text('Text')),
                    DropdownMenuItem(
                        value: FieldType.dropdown, child: Text('Dropdown')),
                    DropdownMenuItem(
                        value: FieldType.number, child: Text('Number')),
                    DropdownMenuItem(
                        value: FieldType.date, child: Text('Date')),
                    DropdownMenuItem(
                        value: FieldType.multiSelect,
                        child: Text('Multi-select')),
                  ],
                  onChanged: (v) => set(() => type = v ?? type),
                ),
                if (type == FieldType.dropdown ||
                    type == FieldType.multiSelect) ...[
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: optsCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Options (comma-separated)'),
                    maxLines: 3,
                  ),
                ],
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
              final opts = optsCtrl.text
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList();
              notifier.addField(nameCtrl.text.trim(), type, opts);
              Navigator.pop(c);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _FieldCard extends ConsumerStatefulWidget {
  const _FieldCard({required this.field});
  final CustomField field;
  @override
  ConsumerState<_FieldCard> createState() => _FieldCardState();
}

class _FieldCardState extends ConsumerState<_FieldCard> {
  final _newOpt = TextEditingController();

  @override
  void dispose() {
    _newOpt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.field;
    final notifier = ref.read(fieldsProvider.notifier);
    final isSubject = f.name == 'Subject';

    return PastelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PastelPill(label: f.type.name, pastel: Pastels.lavender),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                  child: Text(f.name,
                      style: Theme.of(context).textTheme.titleSmall)),
              LockToggle(
                  locked: f.locked,
                  onChanged: (_) => notifier.toggleLock(f.id)),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: f.locked ? null : () => notifier.removeField(f.id),
              ),
            ],
          ),
          if (f.type == FieldType.dropdown ||
              f.type == FieldType.multiSelect) ...[
            const Divider(),
            if (isSubject) ...[
              Text(
                'Each subject has a short code used in curriculum codes (e.g. MATH → G5-MATH-CG-01).',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final opt in f.options)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: Text(opt)),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          initialValue: f.optionCodes[opt] ?? '',
                          enabled: !f.locked,
                          decoration: const InputDecoration(
                            hintText: 'CODE',
                            isDense: true,
                          ),
                          textCapitalization: TextCapitalization.characters,
                          onChanged: (v) =>
                              notifier.setOptionCode(f.id, opt, v),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        iconSize: 16,
                        icon: const Icon(Icons.close),
                        onPressed: f.locked
                            ? null
                            : () => notifier.removeOption(f.id, opt),
                      ),
                    ],
                  ),
                ),
              if (!f.locked) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newOpt,
                        decoration: const InputDecoration(
                            hintText: 'Add subject', isDense: true),
                        onSubmitted: (v) => _addOpt(v),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    FilledButton.tonalIcon(
                      onPressed: () => _addOpt(_newOpt.text),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add'),
                    ),
                  ],
                ),
              ],
            ] else
              ChipListEditor(
                items: f.options,
                hint: 'Add option',
                locked: f.locked,
                onAdd: (s) => notifier.addOption(f.id, s),
                onRemove: (s) => notifier.removeOption(f.id, s),
              ),
          ],
        ],
      ),
    );
  }

  void _addOpt(String v) {
    final t = v.trim();
    if (t.isEmpty) return;
    ref.read(fieldsProvider.notifier).addOption(widget.field.id, t);
    _newOpt.clear();
  }
}
