// lib/screens/settings_sections/appearance_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class AppearanceSection extends ConsumerWidget {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final access = ref.watch(accessibilityProvider);
    final n = ref.read(accessibilityProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Appearance'), actions: const [
        Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: Center(child: ModelBadgeChip())),
      ]),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const SectionHeader(title: 'Theme'),
          PastelCard(
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Light'),
                  value: ThemeMode.light,
                  groupValue: themeMode,
                  onChanged: (v) => ref.read(themeModeProvider.notifier).state =
                      v ?? themeMode,
                ),
                const Divider(),
                RadioListTile<ThemeMode>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Dark'),
                  value: ThemeMode.dark,
                  groupValue: themeMode,
                  onChanged: (v) => ref.read(themeModeProvider.notifier).state =
                      v ?? themeMode,
                ),
                const Divider(),
                RadioListTile<ThemeMode>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('System'),
                  value: ThemeMode.system,
                  groupValue: themeMode,
                  onChanged: (v) => ref.read(themeModeProvider.notifier).state =
                      v ?? themeMode,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Accessibility'),
          PastelCard(
            child: Column(
              children: [
                // Font scale
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: Text('Font size',
                                  style:
                                      Theme.of(context).textTheme.bodyMedium)),
                          Text(
                              '${(access.fontScale * 100).toStringAsFixed(0)}%',
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Slider(
                        min: 0.85,
                        max: 1.5,
                        divisions: 13,
                        label:
                            '${(access.fontScale * 100).toStringAsFixed(0)}%',
                        value: access.fontScale,
                        onChanged: n.setFontScale,
                      ),
                    ],
                  ),
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('High contrast'),
                  subtitle: const Text('Stronger borders and text contrast'),
                  value: access.highContrast,
                  onChanged: n.setHighContrast,
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Reduce motion'),
                  subtitle: const Text('Disable animations and transitions'),
                  value: access.reduceMotion,
                  onChanged: n.setReduceMotion,
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Dyslexia-friendly font'),
                  subtitle:
                      const Text('Use OpenDyslexic-style font when available'),
                  value: access.dyslexiaFont,
                  onChanged: n.setDyslexiaFont,
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Larger touch targets'),
                  subtitle: const Text('Bigger buttons and tap areas'),
                  value: access.largerTouchTargets,
                  onChanged: n.setLargerTouchTargets,
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Screen reader hints'),
                  subtitle: const Text(
                      'Add semantic labels for VoiceOver / TalkBack'),
                  value: access.screenReaderHints,
                  onChanged: n.setScreenReaderHints,
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Colorblind-safe palette'),
                  subtitle: const Text('Use deuteranopia-friendly chip colors'),
                  value: access.colorblindSafePalette,
                  onChanged: n.setColorblindSafe,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PastelCard(
            pastel: Pastels.sky,
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Wire these settings into your MaterialApp builder using MediaQuery '
                    'textScaler and a custom ThemeData (high contrast / colorblind palette).',
                    style: Theme.of(context).textTheme.bodySmall,
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
