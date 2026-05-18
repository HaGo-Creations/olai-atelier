// lib/screens/desk.dart
//
// The Desk: dashboard with App Hero (logo+name+tagline), Welcome card,
// Quick Launch, Recent Resources.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../models/models.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../widgets/app_branding.dart';
import '../widgets/common.dart';

class DeskScreen extends ConsumerWidget {
  const DeskScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ScreenScaffold(
      title: 'Desk',
      pastel: Pastels.desk,
      body: ListView(
        children: [
          const AppHero(),
          const SizedBox(height: AppSpacing.md),
          const _WelcomeCard(),
          const SizedBox(height: AppSpacing.lg),
          const _QuickLaunch(),
          const SizedBox(height: AppSpacing.lg),
          const _RecentResources(),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Welcome card
// ────────────────────────────────────────────────────────────────────────────

class _WelcomeCard extends ConsumerWidget {
  const _WelcomeCard();

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final resources = ref.watch(resourcesProvider).valueOrNull ?? const [];
    final thisWeek = resources
        .where(
          (r) => r.createdAt
              .isAfter(DateTime.now().subtract(const Duration(days: 7))),
        )
        .length;
    final today = DateFormat('EEEE, MMMM d').format(DateTime.now());

    return PastelCard(
      pastel: Pastels.desk,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            today,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Pastels.desk
                  .fgFor(Theme.of(context).brightness)
                  .withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${_greeting()}, ${profile.name.split(' ').first}.',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Pastels.desk.fgFor(Theme.of(context).brightness),
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$thisWeek resources created this week.',
            style: TextStyle(
              fontSize: 14,
              color: Pastels.desk
                  .fgFor(Theme.of(context).brightness)
                  .withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: () => ref.read(navIndexProvider.notifier).state = 1,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Continue last session'),
            style: FilledButton.styleFrom(
              backgroundColor: Pastels.desk.fgFor(Theme.of(context).brightness),
              foregroundColor: Pastels.desk.bgFor(Theme.of(context).brightness),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Quick Launch — single Create New button that opens a picker
// ────────────────────────────────────────────────────────────────────────────

class _QuickLaunch extends ConsumerWidget {
  const _QuickLaunch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Quick Launch'),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: PastelCard(
            onTap: () => _openPicker(context, ref),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.xl,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Icon(Icons.add,
                      color: Theme.of(context).colorScheme.primary, size: 24),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Create New',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        'Worksheets, lesson plans, question papers, and more',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openPicker(BuildContext context, WidgetRef ref) async {
    final type = await showModalBottomSheet<ResourceType>(
      context: context,
      isScrollControlled: true,
      builder: (c) => _CreateNewPicker(),
    );
    if (type != null) {
      ref.read(studioPresetProvider.notifier).state = type;
      ref.read(navIndexProvider.notifier).state = 1;
    }
  }
}

class _CreateNewPicker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final types = ResourceType.values;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 4,
              width: 40,
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text('What would you like to create?',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 1.6,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final t in types)
                  PastelCard(
                    pastel: Pastels.byResourceType[t.apiKey],
                    onTap: () => Navigator.pop(context, t),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(_iconFor(t), size: 26),
                        const SizedBox(height: AppSpacing.sm),
                        Text(t.label,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(ResourceType t) => switch (t) {
        ResourceType.worksheet => Icons.assignment_outlined,
        ResourceType.lessonPlan => Icons.menu_book_outlined,
        ResourceType.questionPaper => Icons.quiz_outlined,
        ResourceType.presentation => Icons.slideshow_outlined,
        ResourceType.activity => Icons.extension_outlined,
        ResourceType.notes => Icons.sticky_note_2_outlined,
      };
}

// ────────────────────────────────────────────────────────────────────────────
// Recent Resources with grid/list toggle
// ────────────────────────────────────────────────────────────────────────────

class _RecentResources extends ConsumerStatefulWidget {
  const _RecentResources();
  @override
  ConsumerState<_RecentResources> createState() => _RecentResourcesState();
}

class _RecentResourcesState extends ConsumerState<_RecentResources> {
  bool _gridView = true;

  @override
  Widget build(BuildContext context) {
    final res = ref.watch(resourcesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Recent Resources',
          trailing: SegmentedButton<bool>(
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            segments: const [
              ButtonSegment(
                  value: true,
                  icon: Icon(Icons.grid_view, size: 16),
                  label: Text('Grid')),
              ButtonSegment(
                  value: false,
                  icon: Icon(Icons.view_list, size: 16),
                  label: Text('List')),
            ],
            selected: {_gridView},
            onSelectionChanged: (s) => setState(() => _gridView = s.first),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        res.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Error: $e'),
          data: (items) {
            if (items.isEmpty) {
              return PastelCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Center(
                    child: Text(
                      'No resources yet. Create your first one.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
              );
            }
            return _gridView ? _grid(items) : _list(items);
          },
        ),
      ],
    );
  }

  Widget _grid(List<Resource> items) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 900 ? 3 : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 1.25,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) =>
            _ResourceTile(resource: items[i], compact: false),
      );
    });
  }

  Widget _list(List<Resource> items) {
    return Column(
      children: [
        for (final r in items) ...[
          _ResourceTile(resource: r, compact: true),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _ResourceTile extends StatelessWidget {
  const _ResourceTile({required this.resource, required this.compact});
  final Resource resource;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final pastel = Pastels.forResourceType(resource.type.apiKey);
    final dateStr = DateFormat('MMM d').format(resource.createdAt);

    if (compact) {
      return PastelCard(
        onTap: () {},
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: pastel.bgFor(Theme.of(context).brightness),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Icon(_icon(),
                  color: pastel.fgFor(Theme.of(context).brightness), size: 18),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(resource.title,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('${resource.subject} • ${resource.grade} • $dateStr',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            PastelPill(label: resource.type.label, pastel: pastel),
          ],
        ),
      );
    }

    return PastelCard(
      onTap: () {},
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: pastel.bgFor(Theme.of(context).brightness),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Icon(_icon(),
                    color: pastel.fgFor(Theme.of(context).brightness),
                    size: 16),
              ),
              const Spacer(),
              Icon(
                resource.modelUsed == 'cloud'
                    ? Icons.cloud_outlined
                    : Icons.computer_outlined,
                size: 14,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4),
              ),
            ],
          ),
          const Spacer(),
          Text(resource.title,
              style: Theme.of(context).textTheme.titleSmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text('${resource.subject} • ${resource.grade}',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          PastelPill(label: resource.type.label, pastel: pastel),
        ],
      ),
    );
  }

  IconData _icon() => switch (resource.type) {
        ResourceType.worksheet => Icons.assignment_outlined,
        ResourceType.lessonPlan => Icons.menu_book_outlined,
        ResourceType.questionPaper => Icons.quiz_outlined,
        ResourceType.presentation => Icons.slideshow_outlined,
        ResourceType.activity => Icons.extension_outlined,
        ResourceType.notes => Icons.sticky_note_2_outlined,
      };
}
