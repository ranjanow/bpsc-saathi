import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BPSC Saathi — 3-Theme Design System
//
// Three distinct visual identities:
//   1. Vibrant  — Warm saffron/orange, cream backgrounds, rounded, friendly
//   2. Professional — Navy/blue, clean whites, Material-crisp, authoritative
//   3. Dark Tech — Purple/teal neon, dark surfaces, monospace display, bold
//
// Ported from the HTML/CSS prototype: frontend/design/bpsc_saathi_dashboard.html
// ─────────────────────────────────────────────────────────────────────────────

/// Enum for the three supported themes.
enum AppThemeMode { vibrant, professional, darkTech }

/// Centralised colour palette for each theme.
///
/// Access via [BpscThemeData] or directly for non-themed constants.
abstract final class AppColors {
  // ── Vibrant Theme ──────────────────────────────────────────────────────────
  static const Color vibrantPrimary = Color(0xFFFF7A45);
  static const Color vibrantPrimarySoft = Color(0xFFFFE2D2);
  static const Color vibrantSecondary = Color(0xFF00A896);
  static const Color vibrantSecondarySoft = Color(0xFFD7F5F0);
  static const Color vibrantAccent = Color(0xFFFFC107);
  static const Color vibrantBg = Color(0xFFFFFBF4);
  static const Color vibrantSurface = Color(0xFFFFFFFF);
  static const Color vibrantSurfaceAlt = Color(0xFFFFF1E2);
  static const Color vibrantSidebar = Color(0xFFFFFFFF);
  static const Color vibrantText = Color(0xFF2B2118);
  static const Color vibrantTextMuted = Color(0xFFA6927E);
  static const Color vibrantBorder = Color(0xFFF1E4D4);

  // ── Professional Theme ─────────────────────────────────────────────────────
  static const Color proPrimary = Color(0xFF2F4FCF);
  static const Color proPrimarySoft = Color(0xFFE3E9FC);
  static const Color proSecondary = Color(0xFF1AA1E0);
  static const Color proSecondarySoft = Color(0xFFDFF3FC);
  static const Color proAccent = Color(0xFF2F4FCF);
  static const Color proBg = Color(0xFFF3F6FB);
  static const Color proSurface = Color(0xFFFFFFFF);
  static const Color proSurfaceAlt = Color(0xFFEAF0FC);
  static const Color proSidebar = Color(0xFF16203A);
  static const Color proText = Color(0xFF16203A);
  static const Color proTextMuted = Color(0xFF7C88A3);
  static const Color proBorder = Color(0xFFE2E8F4);

  // ── Dark Tech Theme ────────────────────────────────────────────────────────
  static const Color darkPrimary = Color(0xFFBB86FC);
  static const Color darkPrimarySoft = Color(0xFF271E3D);
  static const Color darkSecondary = Color(0xFF03DAC6);
  static const Color darkSecondarySoft = Color(0xFF16302D);
  static const Color darkAccent = Color(0xFFFF4D9D);
  static const Color darkBg = Color(0xFF0D0D12);
  static const Color darkSurface = Color(0xFF17171F);
  static const Color darkSurfaceAlt = Color(0xFF1E1E2A);
  static const Color darkSidebar = Color(0xFF0A0A0E);
  static const Color darkText = Color(0xFFF1EFFB);
  static const Color darkTextMuted = Color(0xFF8E89A8);
  static const Color darkBorder = Color(0xFF2A2A38);

  // ── Shared Semantic Colours ────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // ── Legacy aliases (used by existing widgets) ──────────────────────────────
  static const Color primary = vibrantPrimary;
  static const Color primaryLight = vibrantPrimarySoft;
  static const Color primaryDark = Color(0xFFC2410C);
  static const Color secondary = vibrantSecondary;
  static const Color secondaryLight = vibrantSecondarySoft;
  static const Color darkAccentLegacy = Color(0xFFFBBF24);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF334155);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textDisabled = Color(0xFF94A3B8);
  static const Color surface = Colors.white;
  static const Color surfaceVariant = Color(0xFFF8FAFC);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);
  static const Color streak = vibrantPrimary;
  static const Color streakGlow = Color(0xFFFED7AA);
}

/// Consistent spacing scale based on 4px grid.
abstract final class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;
}

/// Runtime theme data — resolved from [AppThemeMode].
///
/// Holds all colours, radii, and fonts for a specific theme variant.
/// Use via `BpscThemeData.of(context)` or from the [ThemeProvider].
class BpscThemeData {
  final Color primary;
  final Color primarySoft;
  final Color secondary;
  final Color secondarySoft;
  final Color accent;
  final Color bg;
  final Color cardSurface;
  final Color surfaceAlt;
  final Color sidebar;
  final Color text;
  final Color textMuted;
  final Color borderColor;
  final double radius;
  final String displayFontFamily;
  final String bodyFontFamily;
  final Brightness brightness;

  const BpscThemeData({
    required this.primary,
    required this.primarySoft,
    required this.secondary,
    required this.secondarySoft,
    required this.accent,
    required this.bg,
    required this.cardSurface,
    required this.surfaceAlt,
    required this.sidebar,
    required this.text,
    required this.textMuted,
    required this.borderColor,
    required this.radius,
    required this.displayFontFamily,
    required this.bodyFontFamily,
    required this.brightness,
  });

  /// Vibrant Modern theme — warm orange on cream.
  factory BpscThemeData.vibrant() => const BpscThemeData(
        primary: AppColors.vibrantPrimary,
        primarySoft: AppColors.vibrantPrimarySoft,
        secondary: AppColors.vibrantSecondary,
        secondarySoft: AppColors.vibrantSecondarySoft,
        accent: AppColors.vibrantAccent,
        bg: AppColors.vibrantBg,
        cardSurface: AppColors.vibrantSurface,
        surfaceAlt: AppColors.vibrantSurfaceAlt,
        sidebar: AppColors.vibrantSidebar,
        text: AppColors.vibrantText,
        textMuted: AppColors.vibrantTextMuted,
        borderColor: AppColors.vibrantBorder,
        radius: 18.0,
        displayFontFamily: 'Baloo 2',
        bodyFontFamily: 'Inter',
        brightness: Brightness.light,
      );

  /// Clean Professional theme — navy and white.
  factory BpscThemeData.professional() => const BpscThemeData(
        primary: AppColors.proPrimary,
        primarySoft: AppColors.proPrimarySoft,
        secondary: AppColors.proSecondary,
        secondarySoft: AppColors.proSecondarySoft,
        accent: AppColors.proAccent,
        bg: AppColors.proBg,
        cardSurface: AppColors.proSurface,
        surfaceAlt: AppColors.proSurfaceAlt,
        sidebar: AppColors.proSidebar,
        text: AppColors.proText,
        textMuted: AppColors.proTextMuted,
        borderColor: AppColors.proBorder,
        radius: 10.0,
        displayFontFamily: 'Roboto',
        bodyFontFamily: 'Open Sans',
        brightness: Brightness.light,
      );

  /// Dark Tech theme — purple neon on charcoal.
  factory BpscThemeData.darkTech() => const BpscThemeData(
        primary: AppColors.darkPrimary,
        primarySoft: AppColors.darkPrimarySoft,
        secondary: AppColors.darkSecondary,
        secondarySoft: AppColors.darkSecondarySoft,
        accent: AppColors.darkAccent,
        bg: AppColors.darkBg,
        cardSurface: AppColors.darkSurface,
        surfaceAlt: AppColors.darkSurfaceAlt,
        sidebar: AppColors.darkSidebar,
        text: AppColors.darkText,
        textMuted: AppColors.darkTextMuted,
        borderColor: AppColors.darkBorder,
        radius: 14.0,
        displayFontFamily: 'JetBrains Mono',
        bodyFontFamily: 'Inter',
        brightness: Brightness.dark,
      );

  /// Get the [BpscThemeData] for a specific [AppThemeMode].
  factory BpscThemeData.fromMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.vibrant:
        return BpscThemeData.vibrant();
      case AppThemeMode.professional:
        return BpscThemeData.professional();
      case AppThemeMode.darkTech:
        return BpscThemeData.darkTech();
    }
  }

  /// Look up [BpscThemeData] from an ancestor [BpscThemeInherited].
  static BpscThemeData of(BuildContext context) {
    final inherited =
        context.dependOnInheritedWidgetOfExactType<BpscThemeInherited>();
    return inherited?.themeData ?? BpscThemeData.vibrant();
  }
}

/// InheritedWidget to propagate [BpscThemeData] down the tree.
class BpscThemeInherited extends InheritedWidget {
  final BpscThemeData themeData;

  const BpscThemeInherited({
    super.key,
    required this.themeData,
    required super.child,
  });

  @override
  bool updateShouldNotify(BpscThemeInherited oldWidget) =>
      themeData != oldWidget.themeData;
}

/// Centralised Material [ThemeData] builder.
///
/// Generates Material 3 themes that align with the BPSC Saathi design tokens.
abstract final class AppTheme {
  /// Build a Material [ThemeData] from a [BpscThemeData].
  static ThemeData fromBpsc(BpscThemeData t) {
    final isLight = t.brightness == Brightness.light;
    final textTheme = _buildTextTheme(t);

    return ThemeData(
      colorSchemeSeed: t.primary,
      useMaterial3: true,
      brightness: t.brightness,
      scaffoldBackgroundColor: t.bg,
      textTheme: textTheme,

      // ── App Bar ─────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: t.bg,
        foregroundColor: t.text,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: t.text,
        ),
      ),

      // ── Cards ───────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        color: t.cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radius),
          side: BorderSide(color: t.borderColor),
        ),
      ),

      // ── Buttons ─────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: t.primary,
          foregroundColor: isLight ? Colors.white : t.bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.radius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.getFont(
            t.bodyFontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.primary,
          side: BorderSide(color: t.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.radius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.primary,
          foregroundColor: isLight ? Colors.white : t.bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.radius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),

      // ── Inputs ──────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(t.radius * 0.65),
          borderSide: BorderSide(color: t.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(t.radius * 0.65),
          borderSide: BorderSide(color: t.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(t.radius * 0.65),
          borderSide: BorderSide(color: t.primary, width: 2),
        ),
      ),

      // ── Navigation Bar ──────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: t.primarySoft,
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.getFont(
            t.bodyFontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Navigation Rail ─────────────────────────────────────
      navigationRailTheme: NavigationRailThemeData(
        indicatorColor: t.primarySoft,
      ),

      // ── Chips ───────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: t.surfaceAlt,
        selectedColor: t.primarySoft,
        shape: const StadiumBorder(),
        side: BorderSide(color: t.borderColor),
        labelStyle: GoogleFonts.getFont(t.bodyFontFamily, fontSize: 13),
      ),

      // ── Divider ─────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: t.borderColor,
        thickness: 1,
      ),
    );
  }

  /// Legacy helpers — map to Vibrant light / Dark Tech dark.
  static ThemeData light() => fromBpsc(BpscThemeData.vibrant());
  static ThemeData dark() => fromBpsc(BpscThemeData.darkTech());

  // ── Text Theme Builder ─────────────────────────────────────────────────────
  static TextTheme _buildTextTheme(BpscThemeData t) {
    final display = GoogleFonts.getFont(t.displayFontFamily);
    final body = GoogleFonts.getFont(t.bodyFontFamily);

    return TextTheme(
      headlineLarge: display.copyWith(
        fontWeight: FontWeight.w800,
        color: t.text,
      ),
      headlineMedium: display.copyWith(
        fontWeight: FontWeight.w800,
        color: t.text,
      ),
      headlineSmall: display.copyWith(
        fontWeight: FontWeight.w700,
        color: t.text,
      ),
      titleLarge: display.copyWith(
        fontWeight: FontWeight.w700,
        color: t.text,
      ),
      titleMedium: display.copyWith(
        fontWeight: FontWeight.w600,
        color: t.text,
      ),
      titleSmall: body.copyWith(
        fontWeight: FontWeight.w600,
        color: t.text,
      ),
      bodyLarge: body.copyWith(color: t.text),
      bodyMedium: body.copyWith(color: t.textMuted),
      bodySmall: body.copyWith(
        color: t.textMuted,
        fontSize: 12,
      ),
      labelLarge: body.copyWith(
        fontWeight: FontWeight.w600,
        color: t.text,
      ),
      labelMedium: body.copyWith(
        fontWeight: FontWeight.w500,
        color: t.textMuted,
        fontSize: 11,
      ),
      labelSmall: body.copyWith(
        fontWeight: FontWeight.w600,
        color: t.textMuted,
        fontSize: 10,
        letterSpacing: 0.5,
      ),
    );
  }
}
