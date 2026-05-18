// lib/screens/settings_sections/profile_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class ProfileSection extends ConsumerWidget {
  const ProfileSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileProvider);
    final n = ref.read(profileProvider.notifier);
    final masterGrades = ref.watch(masterGradesProvider);
    final masterSubjects = ref.watch(masterSubjectsProvider);
    final locked = p.locked;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Profile'),
        actions: [
          LockToggle(
            locked: locked,
            tooltip: locked ? 'Unlock profile' : 'Lock profile',
            onChanged: (_) => n.toggleLock(),
          ),
          const Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: Center(child: ModelBadgeChip()),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if (locked) ...[
            PastelCard(
              pastel: Pastels.peach,
              child: Row(
                children: const [
                  Icon(Icons.lock, size: 18),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                      child: Text(
                          'Profile is locked. Unlock from the top bar to edit.')),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          const SectionHeader(title: 'Identity'),
          PastelCard(
            child: Column(
              children: [
                TextFormField(
                  initialValue: p.name,
                  enabled: !locked,
                  decoration: const InputDecoration(labelText: 'Name'),
                  onChanged: n.setName,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  initialValue: p.designation,
                  enabled: !locked,
                  decoration: const InputDecoration(
                    labelText: 'Designation',
                    hintText: 'e.g. Senior Teacher, Headmaster',
                  ),
                  onChanged: n.setDesignation,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  initialValue: p.school,
                  enabled: !locked,
                  decoration:
                      const InputDecoration(labelText: 'School / Organization'),
                  onChanged: n.setSchool,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Subjects you teach'),
          PastelCard(
            child: _MultiSelectChips(
              all: masterSubjects,
              selected: p.subjects,
              locked: locked,
              emptyHint: 'Add subjects in Settings → Field Editor first.',
              onChanged: n.setSubjects,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Grades you teach'),
          PastelCard(
            child: _MultiSelectChips(
              all: masterGrades,
              selected: p.grades,
              locked: locked,
              emptyHint: 'Add grades in Settings → Field Editor first.',
              onChanged: n.setGrades,
            ),
          ),
        ],
      ),
    );
  }
}

class _MultiSelectChips extends StatelessWidget {
  const _MultiSelectChips({
    required this.all,
    required this.selected,
    required this.locked,
    required this.onChanged,
    required this.emptyHint,
  });
  final List<String> all;
  final List<String> selected;
  final bool locked;
  final ValueChanged<List<String>> onChanged;
  final String emptyHint;

  @override
  Widget build(BuildContext context) {
    if (all.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(emptyHint, style: Theme.of(context).textTheme.bodySmall),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in all)
          FilterChip(
            label: Text(o),
            selected: selected.contains(o),
            onSelected: locked
                ? null
                : (s) {
                    final next = List<String>.from(selected);
                    if (s) {
                      if (!next.contains(o)) next.add(o);
                    } else {
                      next.remove(o);
                    }
                    onChanged(next);
                  },
          ),
      ],
    );
  }
}
