// lib/screens/settings_sections/question_schemas_section.dart
//
// Manages structured question schemas. Each schema (MCQ, Short Answer, etc.)
// has a list of fields (stem, options, answer…) that define its data shape.
// Users can edit built-ins or create new ones from scratch.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/question_schema.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class QuestionSchemasSection extends ConsumerWidget {
  const QuestionSchemasSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schemas = ref.watch(questionSchemasProvider);
    final notifier = ref.read(questionSchemasProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Question Schemas'), actions: const [
        Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: Center(child: ModelBadgeChip())),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addSchema(context, notifier),
        icon: const Icon(Icons.add),
        label: const Text('New Schema'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          PastelCard(
            pastel: Pastels.lavender,
            child: Row(
              children: [
                const Icon(Icons.code, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Schemas define the data shape of each question type. Gemma uses these to generate structured JSON that the builder and exporters render consistently.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final s in schemas) ...[
            _SchemaCard(schema: s),
            const SizedBox(height: AppSpacing.md),
          ],
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  void _addSchema(BuildContext context, QuestionSchemasNotifier n) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('New Question Schema'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Schema name',
            hintText: 'e.g. Case Study, Reasoning, Reflection',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              n.createNew(ctrl.text.trim());
              Navigator.pop(c);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _SchemaCard extends ConsumerStatefulWidget {
  const _SchemaCard({required this.schema});
  final QuestionSchema schema;
  @override
  ConsumerState<_SchemaCard> createState() => _SchemaCardState();
}

class _SchemaCardState extends ConsumerState<_SchemaCard> {
  bool _expanded = false;
  final _uuid = const Uuid();

  @override
  Widget build(BuildContext context) {
    final s = widget.schema;
    final n = ref.read(questionSchemasProvider.notifier);

    return PastelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PastelPill(
                label: s.builtIn ? 'Built-in' : 'Custom',
                pastel: s.builtIn ? Pastels.sky : Pastels.peach,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child:
                    Text(s.name, style: Theme.of(context).textTheme.titleSmall),
              ),
              Text('${s.fields.length} fields',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: AppSpacing.sm),
              LockToggle(
                  locked: s.locked, onChanged: (_) => n.toggleLock(s.id)),
              IconButton(
                icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
              if (!s.builtIn)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: s.locked ? null : () => n.remove(s.id),
                ),
            ],
          ),
          if (_expanded) ...[
            const Divider(),
            for (final f in s.fields) ...[
              _FieldRow(schema: s, field: f),
              const SizedBox(height: 6),
            ],
            const SizedBox(height: 6),
            FilledButton.tonalIcon(
              onPressed: s.locked
                  ? null
                  : () => n.addField(
                      s.id,
                      QSchemaField(
                        id: _uuid.v4(),
                        label: 'New field',
                        kind: QFieldKind.custom,
                      )),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add field'),
            ),
          ],
        ],
      ),
    );
  }
}

class _FieldRow extends ConsumerWidget {
  const _FieldRow({required this.schema, required this.field});
  final QuestionSchema schema;
  final QSchemaField field;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.read(questionSchemasProvider.notifier);
    final locked = schema.locked;
    final hasCount = field.kind == QFieldKind.options ||
        field.kind == QFieldKind.blanks ||
        field.kind == QFieldKind.matchPairs;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  key: ValueKey('lbl-${field.id}'),
                  initialValue: field.label,
                  enabled: !locked,
                  decoration: const InputDecoration(
                      labelText: 'Field label', isDense: true),
                  onChanged: (v) =>
                      n.updateField(schema.id, field.copyWith(label: v)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<QFieldKind>(
                  value: field.kind,
                  decoration:
                      const InputDecoration(labelText: 'Type', isDense: true),
                  onChanged: locked
                      ? null
                      : (v) => v == null
                          ? null
                          : n.updateField(schema.id, field.copyWith(kind: v)),
                  items: [
                    for (final k in QFieldKind.values)
                      DropdownMenuItem(
                          value: k,
                          child: Text(_kindLabel(k),
                              style: const TextStyle(fontSize: 12))),
                  ],
                ),
              ),
              IconButton(
                iconSize: 16,
                icon: const Icon(Icons.close),
                onPressed:
                    locked ? null : () => n.removeField(schema.id, field.id),
              ),
            ],
          ),
          Row(
            children: [
              if (hasCount) ...[
                SizedBox(
                  width: 110,
                  child: TextFormField(
                    key: ValueKey('cnt-${field.id}'),
                    initialValue: field.optionCount.toString(),
                    enabled: !locked,
                    decoration: const InputDecoration(
                        labelText: 'Count', isDense: true),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final n2 = int.tryParse(v);
                      if (n2 != null)
                        n.updateField(
                            schema.id, field.copyWith(optionCount: n2));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                if (field.kind != QFieldKind.blanks)
                  Expanded(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Allow more',
                          style: TextStyle(fontSize: 12)),
                      value: field.allowMoreOptions,
                      onChanged: locked
                          ? null
                          : (v) => n.updateField(
                              schema.id, field.copyWith(allowMoreOptions: v)),
                    ),
                  ),
              ] else
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title:
                        const Text('Required', style: TextStyle(fontSize: 12)),
                    value: field.required,
                    onChanged: locked
                        ? null
                        : (v) => n.updateField(
                            schema.id, field.copyWith(required: v)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _kindLabel(QFieldKind k) => switch (k) {
        QFieldKind.stem => 'Stem',
        QFieldKind.options => 'Options',
        QFieldKind.answer => 'Answer',
        QFieldKind.binary => 'Binary',
        QFieldKind.blanks => 'Blanks',
        QFieldKind.matchPairs => 'Match pairs',
        QFieldKind.numeric => 'Numeric',
        QFieldKind.diagram => 'Diagram',
        QFieldKind.custom => 'Custom',
      };
}
