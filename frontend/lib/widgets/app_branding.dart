// lib/widgets/app_branding.dart
//
// Single source of truth for the app's logo + name + tagline.
// To swap later, edit ONLY the constants and `_logoWidget` below.
//
// To replace the placeholder icon with a real PNG:
//   1. Drop the file at  frontend/assets/images/logo.png
//   2. Add to pubspec.yaml under flutter -> assets:
//        - assets/images/logo.png
//   3. Replace the body of `_logoWidget` with:
//        Image.asset('assets/images/logo.png', width: size, height: size)

import 'package:flutter/material.dart';
import '../theme.dart';

class AppBrandingConfig {
  // Edit these placeholders to set your final app name & tagline
  static const String appName = 'OLAI';
  static const String tagline = 'Agentic Workflow for Educators';
}

/// Square logo (default 32px). Swap the contents of this method to use a PNG.
Widget _logoWidget(BuildContext context, double size) {
  // Placeholder: pastel purple↔sky gradient with a sparkle.
  final b = Theme.of(context).brightness;
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Pastels.lavender.fgFor(b),
          Pastels.sky.fgFor(b),
        ],
      ),
      borderRadius: BorderRadius.circular(size * 0.22),
    ),
    child: Icon(
      Icons.auto_awesome,
      size: size * 0.6,
      color: Colors.white,
    ),
  );
}

// ── Sized variants used across the app ────────────────────────────────────

/// Just the square logo (no text). Use in compact bars.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 28});
  final double size;
  @override
  Widget build(BuildContext context) => _logoWidget(context, size);
}

/// Logo + name, single row. Use in app bars and side rails.
class AppLogoWithName extends StatelessWidget {
  const AppLogoWithName({
    super.key,
    this.logoSize = 26,
    this.compact = false,
  });

  final double logoSize;

  /// In `compact` mode (mobile app bar), shrinks the typography.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _logoWidget(context, logoSize),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            AppBrandingConfig.appName,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: compact ? 15 : 16,
              letterSpacing: 0.2,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

/// Big stacked logo + name + tagline. Used at the top of Desk.
class AppHero extends StatelessWidget {
  const AppHero({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          _logoWidget(context, 48),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppBrandingConfig.appName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppBrandingConfig.tagline,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.65),
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
