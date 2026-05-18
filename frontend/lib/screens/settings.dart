// lib/screens/settings.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main.dart';
import '../theme.dart';
import '../widgets/common.dart';

import 'settings_sections/profile_section.dart';
import 'settings_sections/curriculum_section.dart';
import 'settings_sections/fields_section.dart';
import 'settings_sections/templates_section.dart';
import 'settings_sections/prompts_section.dart';
import 'settings_sections/branding_section.dart';
import 'settings_sections/appearance_section.dart';
import 'settings_sections/model_section.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = <_SettingsCard>[
      _SettingsCard(
        title: 'Teacher Profile',
        subtitle: 'Name, designation, school, subjects, grades',
        icon: Icons.person_outline,
        pastel: Pastels.peach,
        builder: (_) => const ProfileSection(),
      ),
      _SettingsCard(
        title: 'Curriculum Library',
        subtitle:
            'NEP-aligned context — goals, competencies, outcomes, lessons',
        icon: Icons.menu_book_outlined,
        pastel: Pastels.mint,
        builder: (_) => const CurriculumSectionScreen(),
      ),
      _SettingsCard(
        title: 'Field Editor',
        subtitle:
            'Master lists for subjects (with codes), grades, languages, question types',
        icon: Icons.dashboard_customize_outlined,
        pastel: Pastels.lavender,
        builder: (_) => const FieldsSection(),
      ),
      _SettingsCard(
        title: 'Resource Templates',
        subtitle: 'Presets and worksheet visual builder',
        icon: Icons.view_quilt_outlined,
        pastel: Pastels.sky,
        builder: (_) => const TemplatesSection(),
      ),
      _SettingsCard(
        title: 'Prompt Editor',
        subtitle: 'AI prompts — locked by default',
        icon: Icons.psychology_outlined,
        pastel: Pastels.rose,
        builder: (_) => const PromptsSection(),
      ),
      _SettingsCard(
        title: 'Brand & Layout',
        subtitle: 'Letterhead, page setup, typography per format',
        icon: Icons.school_outlined,
        pastel: Pastels.butter,
        builder: (_) => const BrandingSection(),
      ),
      _SettingsCard(
        title: 'Appearance',
        subtitle: 'Theme and interface language',
        icon: Icons.palette_outlined,
        pastel: Pastels.peach,
        builder: (_) => const AppearanceSection(),
      ),
      _SettingsCard(
        title: 'Model & Connection',
        subtitle: 'Local / Cloud / Auto, Gemma version, model path',
        icon: Icons.cloud_outlined,
        pastel: Pastels.sky,
        builder: (_) => const ModelSection(),
      ),
    ];

    return ScreenScaffold(
      title: 'Settings',
      pastel: Pastels.settings,
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, i) {
          final card = cards[i];
          return PastelCard(
            pastel: card.pastel,
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: card.builder)),
            child: Row(
              children: [
                Icon(card.icon, size: 24),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(card.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(card.subtitle, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SettingsCard {
  final String title, subtitle;
  final IconData icon;
  final Pastel pastel;
  final WidgetBuilder builder;
  _SettingsCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.pastel,
    required this.builder,
  });
}
