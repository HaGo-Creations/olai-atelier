// lib/main.dart
//
// App entry. Loads i18n strings, sets up Riverpod, applies theme,
// and builds the adaptive shell (bottom nav on phone, side rail elsewhere).

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'l10n/strings.dart';
import 'screens/desk.dart';
import 'screens/studio.dart';
import 'screens/cabinet.dart';
import 'screens/settings.dart';
import 'state/providers.dart';
import 'state/persistence.dart';
import 'theme.dart';
import 'widgets/app_branding.dart';
import 'widgets/app_footer.dart';
import 'widgets/common.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: "assets/env.txt");
  } catch (_) {
    // .env missing or unreadable — fall back to mock mode
  }
  runApp(const ProviderScope(child: _Bootstrap()));
}

class _Bootstrap extends ConsumerStatefulWidget {
  const _Bootstrap();
  @override
  ConsumerState<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends ConsumerState<_Bootstrap> {
  late final Future<Strings> _stringsF;

  @override
  void initState() {
    super.initState();
    _stringsF = Strings.load(const Locale('en'));
    // Load saved settings (curriculum, fields, prompts, profile, branding…)
    // from SharedPreferences and start auto-saving on every change.
    // It's a fire-and-forget read; the FutureProvider keeps it idempotent.
    ref.read(persistenceBootstrapProvider);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Strings>(
      future: _stringsF,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const MaterialApp(
              home: Scaffold(body: Center(child: CircularProgressIndicator())));
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(stringsProvider.notifier).state = snap.data;
        });
        return _GemmaEducatorApp(strings: snap.data!);
      },
    );
  }
}

class _GemmaEducatorApp extends ConsumerWidget {
  const _GemmaEducatorApp({required this.strings});
  final Strings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final access = ref.watch(accessibilityProvider);

    return MaterialApp(
      title: AppBrandingConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      locale: strings.locale,
      supportedLocales: Strings.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        final mq = MediaQuery.of(context);
        Widget wrapped = MediaQuery(
          data: mq.copyWith(
            textScaler: TextScaler.linear(access.fontScale),
            disableAnimations: access.reduceMotion,
          ),
          child: child,
        );
        if (access.highContrast) {
          wrapped = Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                    outline: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
            child: wrapped,
          );
        }
        return wrapped;
      },
      home: const AppShell(),
    );
  }
}

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(navIndexProvider);

    final destinations = [
      _Dest('Desk', Icons.dashboard_outlined, Icons.dashboard, Pastels.desk,
          const DeskScreen()),
      _Dest('Studio', Icons.auto_awesome_outlined, Icons.auto_awesome,
          Pastels.studio, const StudioScreen()),
      _Dest('Cabinet', Icons.folder_outlined, Icons.folder, Pastels.cabinet,
          const CabinetScreen()),
      _Dest('Settings', Icons.settings_outlined, Icons.settings,
          Pastels.settings, const SettingsScreen()),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        if (wide) {
          return _DesktopShell(destinations: destinations, index: index);
        }
        return _PhoneShell(destinations: destinations, index: index);
      },
    );
  }
}

class _Dest {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Pastel pastel;
  final Widget screen;
  _Dest(this.label, this.icon, this.selectedIcon, this.pastel, this.screen);
}

class _DesktopShell extends ConsumerWidget {
  const _DesktopShell({required this.destinations, required this.index});
  final List<_Dest> destinations;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final railExtended = MediaQuery.of(context).size.width >= 1100;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: railExtended,
            selectedIndex: index,
            onDestinationSelected: (i) =>
                ref.read(navIndexProvider.notifier).state = i,
            // Replaced the graduation cap with logo (+ name when extended)
            leading: Padding(
              padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.md, horizontal: AppSpacing.sm),
              child: railExtended
                  ? const AppLogoWithName(logoSize: 28)
                  : const AppLogo(size: 32),
            ),
            destinations: [
              for (final d in destinations)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon,
                      color: d.pastel.fgFor(Theme.of(context).brightness)),
                  label: Text(d.label),
                ),
            ],
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: const ModelBadgeChip(),
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                Expanded(child: destinations[index].screen),
                const AppFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneShell extends ConsumerWidget {
  const _PhoneShell({required this.destinations, required this.index});
  final List<_Dest> destinations;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(child: destinations[index].screen),
          const AppFooter(),
        ],
      ),
      bottomNavigationBar: FrostedSurface(
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) =>
              ref.read(navIndexProvider.notifier).state = i,
          destinations: [
            for (final d in destinations)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon,
                    color: d.pastel.fgFor(Theme.of(context).brightness)),
                label: d.label,
              ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Standard screen scaffold used by all four tab screens
// On mobile, the app bar now shows the logo + name instead of the page title.
// The page title is shown smaller below the app bar (still useful for context).
// ────────────────────────────────────────────────────────────────────────────

class ScreenScaffold extends StatelessWidget {
  const ScreenScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.pastel,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Pastel? pastel;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 720;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        // Desktop: keep the page title (logo lives in side rail)
        // Mobile: replace title with logo + app name
        title: wide
            ? Text(title)
            : const AppLogoWithName(logoSize: 24, compact: true),
        centerTitle: false,
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: Center(child: ModelBadgeChip()),
          ),
          ...?actions,
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: !wide
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tiny page title on mobile so user knows which tab they're on
                    Padding(
                      padding:
                          const EdgeInsets.only(bottom: AppSpacing.sm, top: 2),
                      child: Text(
                        title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              color:
                                  pastel?.fgFor(Theme.of(context).brightness),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    Expanded(child: body),
                  ],
                )
              : body,
        ),
      ),
    );
  }
}
