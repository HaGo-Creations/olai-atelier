// lib/widgets/app_footer.dart
import 'package:flutter/material.dart';
import '../theme.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
            top: BorderSide(
          color:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
        )),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Pastels.lavender.fgFor(b), Pastels.sky.fgFor(b)],
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child:
                const Icon(Icons.auto_awesome, size: 12, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Text(
            'Built with Gemma 4 — Google Hackathon 2026',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                  fontSize: 11,
                ),
          ),
        ],
      ),
    );
  }
}
