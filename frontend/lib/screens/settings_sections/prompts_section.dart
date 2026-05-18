// lib/screens/settings_sections/prompts_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class PromptsSection extends ConsumerWidget {
  const PromptsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prompts = ref.watch(promptsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Prompt Editor'), actions: const [
        Padding(padding: EdgeInsets.only(right: AppSpacing.md), child: Center(child: ModelBadgeChip())),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addPrompt(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Prompt'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          PastelCard(
            pastel: Pastels.rose,
            child: Row(
              children: [
                const Icon(Icons.psychology_alt_outlined, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'These prompts shape how Gemma generates resources. Locked by default — unlock with care.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final p in prompts) ...[
            _PromptCard(prompt: p),
            const SizedBox(height: AppSpacing.md),
          ],
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  void _addPrompt(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('New Prompt'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Prompt name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              ref.read(promptsProvider.notifier).create(
                    name: nameCtrl.text.trim(),
                    role: 'You are a school teacher.',
                    instructions: '',
                    constraints: '',
                    style: '',
                  );
              Navigator.pop(c);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _PromptCard extends ConsumerStatefulWidget {
  const _PromptCard({required this.prompt});
  final PromptTemplate prompt;
  @override
  ConsumerState<_PromptCard> createState() => _PromptCardState();
}

class _PromptCardState extends ConsumerState<_PromptCard> {
  late TextEditingController _name;
  late TextEditingController _role;
  late TextEditingController _instructions;
  late TextEditingController _constraints;
  late TextEditingController _style;

  @override
  void initState() {
    super.initState();
    final p = widget.prompt;
    _name = TextEditingController(text: p.name);
    _role = TextEditingController(text: p.role);
    _instructions = TextEditingController(text: p.instructions);
    _constraints = TextEditingController(text: p.constraints);
    _style = TextEditingController(text: p.style);
  }

  @override
  void didUpdateWidget(covariant _PromptCard old) {
    super.didUpdateWidget(old);
    if (old.prompt.id != widget.prompt.id) {
      _name.text = widget.prompt.name;
      _role.text = widget.prompt.role;
      _instructions.text = widget.prompt.instructions;
      _constraints.text = widget.prompt.constraints;
      _style.text = widget.prompt.style;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _role.dispose();
    _instructions.dispose();
    _constraints.dispose();
    _style.dispose();
    super.dispose();
  }

  void _save() {
    ref.read(promptsProvider.notifier).update(
          widget.prompt.copyWith(
            name: _name.text,
            role: _role.text,
            instructions: _instructions.text,
            constraints: _constraints.text,
            style: _style.text,
          ),
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Prompt saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.prompt;
    final notifier = ref.read(promptsProvider.notifier);
    final locked = p.locked;

    return PastelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with proper alignment
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: _name,
                  enabled: !locked,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                  ),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              LockToggle(locked: locked, onChanged: (_) => notifier.toggleLock(p.id)),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: locked ? null : () => notifier.remove(p.id),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md), // <-- gap between Name and Role
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.md),
          _field(label: 'Role', controller: _role, locked: locked, hint: 'Who is the AI playing?'),
          const SizedBox(height: AppSpacing.md),
          _field(label: 'Instructions', controller: _instructions, locked: locked, maxLines: 4,
              hint: 'What should it do?'),
          const SizedBox(height: AppSpacing.md),
          _field(label: 'Constraints', controller: _constraints, locked: locked, maxLines: 3,
              hint: 'What must it avoid?'),
          const SizedBox(height: AppSpacing.md),
          _field(label: 'Style', controller: _style, locked: locked, maxLines: 2,
              hint: 'How should the output read?'),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              onPressed: locked ? null : _save,
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required bool locked,
    String? hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      enabled: !locked,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }
}
