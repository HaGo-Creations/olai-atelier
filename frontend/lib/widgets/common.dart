// lib/widgets/common.dart
//
// Shared UI building blocks used across all four screens.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../state/connection_status.dart';
import '../state/providers.dart';
import '../theme.dart';

// ────────────────────────────────────────────────────────────────────────────
// Pastel card — the visual primitive used everywhere
// ────────────────────────────────────────────────────────────────────────────

class PastelCard extends StatelessWidget {
  const PastelCard({
    super.key,
    required this.child,
    this.pastel,
    this.padding,
    this.onTap,
    this.selected = false,
    this.borderRadius,
    this.height,
  });

  final Widget child;
  final Pastel? pastel;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final bool selected;
  final double? borderRadius;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final isLight = brightness == Brightness.light;

    final bg = pastel != null
        ? pastel!.bgFor(brightness)
        : (isLight ? Colors.white : const Color(0xFF2C2C2E));

    final radius = borderRadius ?? AppRadii.lg;

    final container = Container(
      height: height,
      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          ...AppShadows.card(brightness),
          if (!isLight && (pastel != null || selected))
            ...AppShadows.glow(
              pastel?.bgFor(Brightness.dark) ?? theme.colorScheme.primary,
              radius: 32,
              opacity: selected ? 0.55 : 0.25,
            ),
        ],
        border: selected
            ? Border.all(
                color: pastel?.fgFor(brightness) ?? theme.colorScheme.primary,
                width: 1.5,
              )
            : null,
      ),
      child: DefaultTextStyle(
        style: TextStyle(
            color: pastel?.fgFor(brightness) ?? theme.colorScheme.onSurface),
        child: child,
      ),
    );

    if (onTap == null) return container;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: container,
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Frosted surface — used by the bottom nav and top app bar
// ────────────────────────────────────────────────────────────────────────────

class FrostedSurface extends StatelessWidget {
  const FrostedSurface({super.key, required this.child, this.sigma = 24});
  final Widget child;
  final double sigma;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: child,
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Model badge — top-right corner everywhere.
// Reads live backend status from connectionStatusProvider so it switches
// between Mock / Local / Online automatically.
// ────────────────────────────────────────────────────────────────────────────

class ModelBadgeChip extends ConsumerWidget {
  const ModelBadgeChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectionStatusProvider);
    final brightness = Theme.of(context).brightness;

    // Pick a pastel + icon based on what's actually connected.
    final Pastel pastel;
    final IconData icon;
    if (!status.backendReachable) {
      pastel = Pastels.rose;
      icon = Icons.wifi_off_outlined;
    } else if (status.cloudAvailable) {
      pastel = Pastels.sky;
      icon = Icons.cloud_outlined;
    } else if (status.localAvailable) {
      pastel = Pastels.mint;
      icon = Icons.computer_outlined;
    } else {
      pastel = Pastels.rose;
      icon = Icons.cloud_off_outlined;
    }

    final bg = pastel.bgFor(brightness);
    final fg = pastel.fgFor(brightness);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        boxShadow: brightness == Brightness.dark
            ? AppShadows.glow(pastel.bgFor(Brightness.dark),
                radius: 18, opacity: 0.4)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            status.badge,
            style:
                TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Lock button with confirm-to-unlock dialog
// ────────────────────────────────────────────────────────────────────────────

class LockToggle extends StatelessWidget {
  const LockToggle({
    super.key,
    required this.locked,
    required this.onChanged,
    this.tooltip,
    this.size = 18,
  });

  final bool locked;
  final ValueChanged<bool> onChanged;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip ?? (locked ? 'Unlock' : 'Lock'),
      iconSize: size,
      visualDensity: VisualDensity.compact,
      icon: Icon(locked ? Icons.lock_outline : Icons.lock_open_outlined),
      color: locked
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
      onPressed: () async {
        if (locked) {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('Unlock this?'),
              content: const Text(
                'Unlocking will let you edit content that affects AI context. Continue?',
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Unlock')),
              ],
            ),
          );
          if (confirm == true) onChanged(false);
        } else {
          onChanged(true);
        }
      },
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Section header
// ────────────────────────────────────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Addable/removable chip row (used in Profile, Field options, etc.)
// ────────────────────────────────────────────────────────────────────────────

class ChipListEditor extends StatefulWidget {
  const ChipListEditor({
    super.key,
    required this.items,
    required this.onAdd,
    required this.onRemove,
    this.hint = 'Add new…',
    this.locked = false,
  });

  final List<String> items;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;
  final String hint;
  final bool locked;

  @override
  State<ChipListEditor> createState() => _ChipListEditorState();
}

class _ChipListEditorState extends State<ChipListEditor> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in widget.items)
              Chip(
                label: Text(item),
                onDeleted: widget.locked ? null : () => widget.onRemove(item),
                deleteIcon: const Icon(Icons.close, size: 16),
              ),
          ],
        ),
        if (!widget.locked) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(hintText: widget.hint),
                  onSubmitted: _submit,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton.tonalIcon(
                onPressed: () => _submit(_controller.text),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  void _submit(String v) {
    final trimmed = v.trim();
    if (trimmed.isEmpty) return;
    widget.onAdd(trimmed);
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Pastel pill (e.g. resource type tag)
// ────────────────────────────────────────────────────────────────────────────

class PastelPill extends StatelessWidget {
  const PastelPill(
      {super.key, required this.label, required this.pastel, this.icon});

  final String label;
  final Pastel pastel;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: pastel.bgFor(b),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: pastel.fgFor(b)),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
                color: pastel.fgFor(b),
                fontWeight: FontWeight.w600,
                fontSize: 11),
          ),
        ],
      ),
    );
  }
}
