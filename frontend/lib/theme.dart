// lib/theme.dart
//
// Visual identity for Gemma Educator.
// - Apple-inspired Material 3 (off-white / charcoal backgrounds)
// - Notion-like semantic pastels (per tab + per resource type)
// - Multi-layer soft shadows in light mode, soft glow in dark mode
// - Noto Sans for UI, Noto Serif for educational output preview
// - Medium radii (14–20px), comfortable spacing

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ────────────────────────────────────────────────────────────────────────────
// Design tokens
// ────────────────────────────────────────────────────────────────────────────

class AppRadii {
  AppRadii._();
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
}

class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

// ────────────────────────────────────────────────────────────────────────────
// Pastel palette — semantic and consistent
// ────────────────────────────────────────────────────────────────────────────
//
// Each pastel has a [light] and [dark] variant. The dark variant is deeper,
// muted, and designed to support a glow halo on top in dark mode.

class Pastel {
  const Pastel({
    required this.name,
    required this.light,
    required this.dark,
    required this.onLight,
    required this.onDark,
  });

  final String name;
  final Color light;
  final Color dark;
  final Color onLight;
  final Color onDark;

  Color bgFor(Brightness b) => b == Brightness.light ? light : dark;
  Color fgFor(Brightness b) => b == Brightness.light ? onLight : onDark;
}

class Pastels {
  Pastels._();

  // Per-tab signature colors
  static const Pastel peach = Pastel(
    name: 'peach',
    light: Color(0xFFFDE2D3),       // soft peach
    dark: Color(0xFF7A3D2A),        // deep burnt amber
    onLight: Color(0xFF7A3D2A),
    onDark: Color(0xFFFDE2D3),
  );

  static const Pastel lavender = Pastel(
    name: 'lavender',
    light: Color(0xFFE8DAF5),       // soft lavender
    dark: Color(0xFF4E3470),        // deep plum
    onLight: Color(0xFF4E3470),
    onDark: Color(0xFFE8DAF5),
  );

  static const Pastel mint = Pastel(
    name: 'mint',
    light: Color(0xFFD2ECDC),       // soft mint
    dark: Color(0xFF1F5236),        // deep forest
    onLight: Color(0xFF1F5236),
    onDark: Color(0xFFD2ECDC),
  );

  static const Pastel sky = Pastel(
    name: 'sky',
    light: Color(0xFFD3E4F5),       // soft sky
    dark: Color(0xFF1F3F66),        // deep navy
    onLight: Color(0xFF1F3F66),
    onDark: Color(0xFFD3E4F5),
  );

  // Extras for resource types beyond the 4 tabs
  static const Pastel butter = Pastel(
    name: 'butter',
    light: Color(0xFFFDEFC2),
    dark: Color(0xFF6B5418),
    onLight: Color(0xFF6B5418),
    onDark: Color(0xFFFDEFC2),
  );

  static const Pastel rose = Pastel(
    name: 'rose',
    light: Color(0xFFF7D5DE),
    dark: Color(0xFF7A2F45),
    onLight: Color(0xFF7A2F45),
    onDark: Color(0xFFF7D5DE),
  );

  // Tab → pastel map (semantic)
  static const Pastel desk = peach;
  static const Pastel studio = lavender;
  static const Pastel cabinet = mint;
  static const Pastel settings = sky;

  // Resource type → pastel map (semantic, consistent across the app)
  static const Map<String, Pastel> byResourceType = {
    'worksheet': peach,
    'lesson_plan': mint,
    'question_paper': sky,
    'presentation': lavender,
    'activity': butter,
    'notes': rose,
  };

  static Pastel forResourceType(String type) =>
      byResourceType[type] ?? sky;
}

// ────────────────────────────────────────────────────────────────────────────
// Shadows — multi-layer soft in light, soft glow in dark
// ────────────────────────────────────────────────────────────────────────────

class AppShadows {
  AppShadows._();

  static List<BoxShadow> card(Brightness b) {
    if (b == Brightness.light) {
      // Multi-layer macOS-style soft shadow
      return const [
        BoxShadow(color: Color(0x0A000000), blurRadius: 1, offset: Offset(0, 1)),
        BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 4)),
        BoxShadow(color: Color(0x08000000), blurRadius: 24, offset: Offset(0, 12)),
      ];
    }
    // Dark mode: very subtle dark drop, no glow on plain cards
    return const [
      BoxShadow(color: Color(0x40000000), blurRadius: 12, offset: Offset(0, 6)),
    ];
  }

  /// Soft pastel glow halo — for active nav items, focused cards, etc.
  static List<BoxShadow> glow(Color color, {double radius = 24, double opacity = 0.45}) {
    return [
      BoxShadow(
        color: color.withValues(alpha: opacity),
        blurRadius: radius,
        spreadRadius: -4,
      ),
    ];
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Theme builders
// ────────────────────────────────────────────────────────────────────────────

class AppTheme {
  AppTheme._();

  // Background tones (off-white / charcoal — softer than pure)
  static const _bgLight = Color(0xFFFAFAFA);
  static const _surfaceLight = Color(0xFFFFFFFF);
  static const _surfaceVariantLight = Color(0xFFF1F1F3);

  static const _bgDark = Color(0xFF1C1C1E);
  static const _surfaceDark = Color(0xFF2C2C2E);
  static const _surfaceVariantDark = Color(0xFF3A3A3C);

  static const _seed = Color(0xFF6B5BD2); // soft indigo as fallback accent

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final isLight = b == Brightness.light;
    final bg = isLight ? _bgLight : _bgDark;
    final surface = isLight ? _surfaceLight : _surfaceDark;
    final surfaceVariant = isLight ? _surfaceVariantLight : _surfaceVariantDark;
    final onSurface = isLight ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
    final onSurfaceMuted = isLight ? const Color(0xFF6B6B70) : const Color(0xFFA0A0A5);

    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: b,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: surfaceVariant,
    );

    final textTheme = GoogleFonts.notoSansTextTheme(
      isLight
          ? Typography.material2021().black
          : Typography.material2021().white,
    ).apply(
      bodyColor: onSurface,
      displayColor: onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,

      textTheme: textTheme.copyWith(
        displayLarge: textTheme.displayLarge?.copyWith(
          fontWeight: FontWeight.w700, letterSpacing: -0.5,
        ),
        displayMedium: textTheme.displayMedium?.copyWith(
          fontWeight: FontWeight.w700, letterSpacing: -0.4,
        ),
        headlineLarge: textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700, letterSpacing: -0.3,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600, letterSpacing: -0.2,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        titleMedium: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        labelLarge: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        bodyMedium: textTheme.bodyMedium?.copyWith(color: onSurface),
        bodySmall: textTheme.bodySmall?.copyWith(color: onSurfaceMuted),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl, vertical: AppSpacing.md),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          side: BorderSide(color: isLight ? const Color(0xFFE5E5EA) : const Color(0xFF48484A)),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl, vertical: AppSpacing.md),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        hintStyle: TextStyle(color: onSurfaceMuted),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: surfaceVariant,
        selectedColor: scheme.primary.withValues(alpha: 0.15),
        labelStyle: TextStyle(color: onSurface, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),

      dividerTheme: DividerThemeData(
        color: isLight ? const Color(0xFFE5E5EA) : const Color(0xFF38383A),
        thickness: 0.5,
        space: 1,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return isLight ? Colors.white : const Color(0xFFE5E5EA);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return isLight ? const Color(0xFFE5E5EA) : const Color(0xFF48484A);
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface.withValues(alpha: 0.7),
        elevation: 0,
        height: 68,
        indicatorColor: scheme.primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.all(
          textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.12),
        selectedIconTheme: IconThemeData(color: scheme.primary),
        unselectedIconTheme: IconThemeData(color: onSurfaceMuted),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: scheme.primary, fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: onSurfaceMuted,
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
        ),
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Notable text styles for output preview (serif)
// ────────────────────────────────────────────────────────────────────────────

class AppFonts {
  AppFonts._();
  static TextStyle serifBody(BuildContext context) =>
      GoogleFonts.notoSerif(textStyle: Theme.of(context).textTheme.bodyLarge);
  static TextStyle serifHeading(BuildContext context) =>
      GoogleFonts.notoSerif(
        textStyle: Theme.of(context).textTheme.headlineMedium,
        fontWeight: FontWeight.w700,
      );
}
