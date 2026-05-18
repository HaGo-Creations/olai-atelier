// lib/screens/cabinet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../models/models.dart';
import '../services/download_helper.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/versions_panel.dart';

class CabinetScreen extends ConsumerStatefulWidget {
  const CabinetScreen({super.key});
  @override
  ConsumerState<CabinetScreen> createState() => _CabinetScreenState();
}

class _CabinetScreenState extends ConsumerState<CabinetScreen> {
  final Set<String> _activeFilters = {};
  String _groupBy = 'type';

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Cabinet',
      pastel: Pastels.cabinet,
      body: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 900;
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 7, child: _resourcesPane()),
              const VerticalDivider(width: 24),
              Expanded(flex: 3, child: _sourceLibraryPane()),
            ],
          );
        }
        return DefaultTabController(
          length: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const TabBar(tabs: [
                Tab(text: 'Generated Resources'),
                Tab(text: 'Source Library'),
              ]),
              Expanded(
                child: TabBarView(
                  children: [_resourcesPane(), _sourceLibraryPane()],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // ── Generated Resources (left) ───────────────────────────────────────────

  Widget _resourcesPane() {
    final results = ref.watch(searchResultsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text('Generated Resources',
              style: Theme.of(context).textTheme.titleMedium),
        ),
        _searchBar(),
        const SizedBox(height: AppSpacing.md),
        _filterChips(),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: results.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (items) {
              final filtered = _applyFilters(items);
              if (filtered.isEmpty) {
                return Center(
                  child: Text('No matching resources',
                      style: Theme.of(context).textTheme.bodyMedium),
                );
              }
              return _resourceList(filtered);
            },
          ),
        ),
      ],
    );
  }

  Widget _searchBar() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Find resources by topic, subject…',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: Icon(Icons.auto_awesome,
                  size: 16,
                  color: Pastels.cabinet.fgFor(Theme.of(context).brightness)),
            ),
            onChanged: (q) => ref.read(searchQueryProvider.notifier).state = q,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        IconButton.outlined(
          onPressed: _openGroupByMenu,
          icon: const Icon(Icons.tune, size: 18),
          tooltip: 'Group by',
        ),
      ],
    );
  }

  void _openGroupByMenu() async {
    final result = await showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(1000, 100, 16, 0),
      items: const [
        PopupMenuItem(value: 'type', child: Text('Group by Resource Type')),
        PopupMenuItem(value: 'subject', child: Text('Group by Subject')),
        PopupMenuItem(value: 'grade', child: Text('Group by Grade')),
        PopupMenuItem(value: 'lesson', child: Text('Group by Lesson')),
      ],
    );
    if (result != null) setState(() => _groupBy = result);
  }

  Widget _filterChips() {
    final resources = ref.watch(resourcesProvider).valueOrNull ?? const [];
    final teacherSubjects = ref.watch(teacherSubjectsProvider).toSet();
    final teacherGrades = ref.watch(teacherGradesProvider).toSet();

    final values = <String>{};
    for (final r in resources) {
      if (_groupBy == 'subject' &&
          teacherSubjects.isNotEmpty &&
          !teacherSubjects.contains(r.subject)) continue;
      if (_groupBy == 'grade' &&
          teacherGrades.isNotEmpty &&
          !teacherGrades.contains(r.grade)) continue;
      values.add(switch (_groupBy) {
        'subject' => r.subject,
        'grade' => r.grade,
        'lesson' => r.lesson,
        _ => r.type.label,
      });
    }
    if (values.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final v in values) ...[
            FilterChip(
              label: Text(v),
              selected: _activeFilters.contains(v),
              onSelected: (sel) => setState(() {
                if (sel) {
                  _activeFilters.add(v);
                } else {
                  _activeFilters.remove(v);
                }
              }),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  List<Resource> _applyFilters(List<Resource> all) {
    final teacherSubjects = ref.watch(teacherSubjectsProvider).toSet();
    final teacherGrades = ref.watch(teacherGradesProvider).toSet();
    var filtered = all.where((r) {
      if (_groupBy == 'subject' &&
          teacherSubjects.isNotEmpty &&
          !teacherSubjects.contains(r.subject)) return false;
      if (_groupBy == 'grade' &&
          teacherGrades.isNotEmpty &&
          !teacherGrades.contains(r.grade)) return false;
      return true;
    }).toList();

    if (_activeFilters.isEmpty) return filtered;
    return filtered.where((r) {
      final v = switch (_groupBy) {
        'subject' => r.subject,
        'grade' => r.grade,
        'lesson' => r.lesson,
        _ => r.type.label,
      };
      return _activeFilters.contains(v);
    }).toList();
  }

  Widget _resourceList(List<Resource> items) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 1100 ? 2 : 1;
      return GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: cols == 1 ? 2.3 : 1.5,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => _CabinetCard(resource: items[i]),
      );
    });
  }

  // ── Source Library (right) ───────────────────────────────────────────────

  Widget _sourceLibraryPane() {
    final uploads = ref.watch(uploadsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Text('Source Library',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              Text('${uploads.length}',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        Text('Every file you upload across the app',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: uploads.isEmpty
              ? Center(
                  child: Text('No uploads yet',
                      style: Theme.of(context).textTheme.bodySmall))
              : ListView.separated(
                  itemCount: uploads.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) => _UploadCard(upload: uploads[i]),
                ),
        ),
      ],
    );
  }
}

// ── Generated Resource card ────────────────────────────────────────────────

class _CabinetCard extends ConsumerWidget {
  const _CabinetCard({required this.resource});
  final Resource resource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pastel = Pastels.forResourceType(resource.type.apiKey);
    final b = Theme.of(context).brightness;
    final validFormats = resource.type.validExportFormats;

    return PastelCard(
      onTap: () => _openPreview(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: pastel.bgFor(b),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Icon(_icon(), color: pastel.fgFor(b), size: 18),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(resource.title,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
              // 3-dot actions menu
              PopupMenuButton<String>(
                tooltip: 'Actions',
                iconSize: 18,
                itemBuilder: (c) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_outlined, size: 16),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'copy',
                    child: Row(children: [
                      Icon(Icons.content_copy, size: 16),
                      SizedBox(width: 8),
                      Text('Save a copy'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'rename',
                    child: Row(children: [
                      Icon(Icons.drive_file_rename_outline, size: 16),
                      SizedBox(width: 8),
                      Text('Rename'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'versions',
                    child: Row(children: [
                      Icon(Icons.history, size: 16),
                      SizedBox(width: 8),
                      Text('Version history'),
                    ]),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ]),
                  ),
                ],
                onSelected: (action) async {
                  switch (action) {
                    case 'edit':
                      _openEditor(context, ref);
                      break;
                    case 'copy':
                      await _saveCopy(context, ref);
                      break;
                    case 'rename':
                      await _renameResource(context, ref);
                      break;
                    case 'versions':
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => VersionsPanel(resource: resource),
                      ));
                      break;
                    case 'delete':
                      final ok = await _confirmDelete(context);
                      if (ok == true) {
                        await ref
                            .read(apiServiceProvider)
                            .deleteResource(resource.id);
                        ref.invalidate(resourcesProvider);
                        ref.invalidate(searchResultsProvider);
                      }
                      break;
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('${resource.subject} • ${resource.grade}',
              style: Theme.of(context).textTheme.bodySmall),
          if (resource.lesson.isNotEmpty)
            Text(resource.lesson, style: Theme.of(context).textTheme.bodySmall),
          const Spacer(),
          Row(
            children: [
              PastelPill(label: resource.type.label, pastel: pastel),
              const Spacer(),
              Text(DateFormat('MMM d').format(resource.createdAt),
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _exportBtn(
                  context, ref, DocFormat.docx, Icons.description_outlined,
                  enabled: validFormats.contains(DocFormat.docx)),
              _exportBtn(
                  context, ref, DocFormat.pdf, Icons.picture_as_pdf_outlined,
                  enabled: validFormats.contains(DocFormat.pdf)),
              _exportBtn(context, ref, DocFormat.pptx, Icons.slideshow_outlined,
                  enabled: validFormats.contains(DocFormat.pptx)),
              IconButton(
                tooltip: 'Save to Drive',
                iconSize: 16,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.cloud_upload_outlined),
                onPressed: () => _saveToDrive(context),
              ),
              IconButton(
                tooltip: 'Share',
                iconSize: 16,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.share_outlined),
                onPressed: () => _share(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _exportBtn(
      BuildContext context, WidgetRef ref, DocFormat f, IconData icon,
      {required bool enabled}) {
    return OutlinedButton.icon(
      onPressed: enabled ? () => _export(context, ref, f) : null,
      icon: Icon(icon, size: 12),
      label: Text(f.label, style: const TextStyle(fontSize: 11)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        minimumSize: const Size(0, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  void _openPreview(BuildContext context) {
    showDialog(
      context: context,
      builder: (c) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Text(resource.title,
                            style: Theme.of(context).textTheme.titleLarge)),
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(c)),
                  ],
                ),
                const Divider(),
                Expanded(
                    child:
                        SingleChildScrollView(child: Text(resource.content))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openEditor(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController(text: resource.content);
    final titleCtrl = TextEditingController(text: resource.title);
    showDialog(
      context: context,
      builder: (c) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Editing — ${resource.title}',
                          style: Theme.of(context).textTheme.titleLarge),
                    ),
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(c)),
                  ],
                ),
                const Divider(),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    maxLines: null,
                    expands: true,
                    decoration: const InputDecoration(
                      labelText: 'Content (Markdown)',
                      hintText: 'Edit Markdown content…',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                        onPressed: () => Navigator.pop(c),
                        child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () async {
                        // Snapshot old version before saving
                        ref
                            .read(resourceVersionsProvider.notifier)
                            .recordVersion(resource, note: 'Before edit');
                        final updated = resource.copyWith(
                          title: titleCtrl.text.trim().isEmpty
                              ? resource.title
                              : titleCtrl.text.trim(),
                          content: ctrl.text,
                        );
                        try {
                          await ref
                              .read(apiServiceProvider)
                              .updateResource(updated);
                        } catch (_) {
                          // Mock service may not implement updateResource yet
                        }
                        ref.invalidate(resourcesProvider);
                        ref.invalidate(searchResultsProvider);
                        if (context.mounted) Navigator.pop(c);
                      },
                      icon: const Icon(Icons.save, size: 16),
                      label: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveCopy(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final copy = await ref.read(apiServiceProvider).duplicateResource(
            resource,
            '${resource.title} (Copy)',
          );
      ref.invalidate(resourcesProvider);
      ref.invalidate(searchResultsProvider);
      messenger.showSnackBar(
        SnackBar(content: Text('Saved as "${copy.title}"')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Copy failed: $e')));
    }
  }

  Future<void> _renameResource(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController(text: resource.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(c, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newTitle != null && newTitle.isNotEmpty && newTitle != resource.title) {
      ref
          .read(resourceVersionsProvider.notifier)
          .recordVersion(resource, note: 'Before rename');
      final updated = resource.copyWith(title: newTitle);
      try {
        await ref.read(apiServiceProvider).updateResource(updated);
      } catch (_) {}
      ref.invalidate(resourcesProvider);
      ref.invalidate(searchResultsProvider);
    }
  }

  Future<bool?> _confirmDelete(BuildContext context) => showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Delete this resource?'),
          content: Text('"${resource.title}" will be permanently removed.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel')),
            FilledButton.tonal(
              style: FilledButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

  Future<void> _export(
      BuildContext context, WidgetRef ref, DocFormat format) async {
    final branding = ref.read(brandingProvider);
    final api = ref.read(apiServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final filename = await api.exportResource(
        resource: resource,
        format: format.name,
        branding: branding.applyOnExport ? branding : null,
      );
      messenger.showSnackBar(SnackBar(
          content: Text('Downloaded $filename'),
          duration: const Duration(seconds: 3)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  void _saveToDrive(BuildContext context) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Save to Google Drive'),
        content: const Text(
            'Drive integration scaffolded. Add google_sign_in + googleapis (drive_v3) and implement upload.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Close')),
        ],
      ),
    );
  }

  void _share(BuildContext context) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Share'),
        content: const Text(
            'Share integration scaffolded. Add share_plus to enable.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Close')),
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

// ── Source Library upload card ─────────────────────────────────────────────

class _UploadCard extends ConsumerStatefulWidget {
  const _UploadCard({required this.upload});
  final UploadRecord upload;
  @override
  ConsumerState<_UploadCard> createState() => _UploadCardState();
}

class _UploadCardState extends ConsumerState<_UploadCard> {
  bool _expanded = false;

  String _formatBytes(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  IconData _icon() {
    final ext = widget.upload.extension;
    if (ext == 'pdf') return Icons.picture_as_pdf;
    if (['png', 'jpg', 'jpeg', 'gif', 'webp'].contains(ext)) return Icons.image;
    if (['doc', 'docx'].contains(ext)) return Icons.description;
    if (['ppt', 'pptx'].contains(ext)) return Icons.slideshow;
    if (ext == 'txt') return Icons.text_snippet;
    return Icons.insert_drive_file;
  }

  Pastel _sourcePastel() => switch (widget.upload.source) {
        UploadSource.studio => Pastels.studio,
        UploadSource.curriculum => Pastels.mint,
        UploadSource.drive => Pastels.sky,
      };

  String _sourceLabel() => switch (widget.upload.source) {
        UploadSource.studio => 'Studio',
        UploadSource.curriculum => 'Curriculum',
        UploadSource.drive => 'Drive',
      };

  @override
  Widget build(BuildContext context) {
    final u = widget.upload;
    final pastel = _sourcePastel();
    return PastelCard(
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
                    size: 16,
                    color: pastel.fgFor(Theme.of(context).brightness)),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u.fileName,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(
                      '${_formatBytes(u.sizeBytes)} • ${DateFormat('MMM d, HH:mm').format(u.uploadedAt)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                iconSize: 16,
                visualDensity: VisualDensity.compact,
                icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              PastelPill(label: _sourceLabel(), pastel: pastel),
              if (u.usedInResourceIds.isNotEmpty) ...[
                const SizedBox(width: 6),
                PastelPill(
                  label: 'Used in ${u.usedInResourceIds.length}',
                  pastel: Pastels.cabinet,
                ),
              ],
            ],
          ),
          if (_expanded) ...[
            const SizedBox(height: AppSpacing.sm),
            if (u.parsedTextPreview != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Text(u.parsedTextPreview!,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            Text('Tags', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            ChipListEditor(
              items: u.tags,
              hint: 'Add tag (e.g. Grade 5 Math)',
              onAdd: (t) => ref.read(uploadsProvider.notifier).addTag(u.id, t),
              onRemove: (t) =>
                  ref.read(uploadsProvider.notifier).removeTag(u.id, t),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _showRenameDialog(u),
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Rename', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: () {
                    ref.read(navIndexProvider.notifier).state = 1; // → Studio
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Open Studio and re-attach "${u.fileName}"')),
                    );
                  },
                  icon: const Icon(Icons.replay, size: 14),
                  label:
                      const Text('Use again', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const Spacer(),
                IconButton(
                  iconSize: 14,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () =>
                      ref.read(uploadsProvider.notifier).remove(u.id),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showRenameDialog(UploadRecord u) {
    final ctrl = TextEditingController(text: u.fileName);
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Rename file'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              ref.read(uploadsProvider.notifier).rename(u.id, ctrl.text.trim());
              Navigator.pop(c);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
