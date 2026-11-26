import 'package:flutter/material.dart';

import 'brand_colors.dart';
import 'status_colors.dart';
import 'tokens.dart';

export 'brand_colors.dart';

/// Builds the light and dark Material 3 themes for the Ember Slate direction.
///
/// Scaffolds are transparent: every page sits on a [GradientBackground]
/// (now a flat grey-blue ground), so cards float on it with soft shadows.
///
/// Orange is split in two roles: [BrandColors.action] (#FF5C00) is a FILL with
/// dark text on it (filled buttons, nav pill), while [ColorScheme.primary] is
/// the darker #B33F00 so every place Material draws "primary" as text, icon or
/// border still passes 4.5:1.
abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  /// Hero card background. Kept as a gradient for older call sites; Ember
  /// Slate heroes are a flat colour.
  static LinearGradient heroGradient(Brightness b) {
    final c = b == Brightness.light ? BrandColors.light : BrandColors.dark;
    return LinearGradient(colors: [c.hero, c.hero]);
  }

  /// Secondary text on the hero card (light mode).
  static const Color heroMuted = Color(0xFFB9C2C5);

  static ColorScheme _scheme(Brightness brightness) {
    final base = ColorScheme.fromSeed(
      seedColor: kSeedColor,
      brightness: brightness,
    );
    if (brightness == Brightness.light) {
      return base.copyWith(
        primary: Brand.emberInk,
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFFFFE2D1),
        onPrimaryContainer: const Color(0xFF6B2600),
        secondary: const Color(0xFF6E5410),
        onSecondary: Colors.white,
        secondaryContainer: const Color(0xFFF6E7BC),
        onSecondaryContainer: const Color(0xFF4A3800),
        tertiary: const Color(0xFF0B5A3A),
        onTertiary: Colors.white,
        tertiaryContainer: const Color(0xFFDCF2E8),
        onTertiaryContainer: const Color(0xFF0B5A3A),
        surface: Colors.white,
        onSurface: Brand.ink,
        onSurfaceVariant: const Color(0xFF4A5458),
        outline: const Color(0xFF6F7B80),
        outlineVariant: const Color(0xFFC9D3D6),
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: const Color(0xFFF5F8F9),
        surfaceContainer: const Color(0xFFEEF2F3),
        surfaceContainerHigh: const Color(0xFFE6ECEE),
        surfaceContainerHighest: const Color(0xFFDEE6E8),
        inverseSurface: Brand.ink,
        onInverseSurface: Colors.white,
        inversePrimary: const Color(0xFFFF8A4C),
      );
    }
    return base.copyWith(
      primary: const Color(0xFFFF8A4C),
      onPrimary: Brand.ink,
      primaryContainer: const Color(0xFF4A2410),
      onPrimaryContainer: const Color(0xFFFFD3BC),
      secondary: const Color(0xFFDBB144),
      onSecondary: Brand.ink,
      secondaryContainer: const Color(0xFF3D3214),
      onSecondaryContainer: const Color(0xFFF6E7BC),
      tertiary: const Color(0xFF7FD3B1),
      onTertiary: const Color(0xFF00311F),
      tertiaryContainer: const Color(0xFF163D2E),
      onTertiaryContainer: const Color(0xFFA6E3C8),
      surface: const Color(0xFF181D20),
      onSurface: const Color(0xFFEEF2F3),
      onSurfaceVariant: const Color(0xFFA7B2B6),
      outline: const Color(0xFF7C888D),
      outlineVariant: const Color(0xFF2E383D),
      surfaceContainerLowest: const Color(0xFF0E1113),
      surfaceContainerLow: const Color(0xFF14191B),
      surfaceContainer: const Color(0xFF1C2225),
      surfaceContainerHigh: const Color(0xFF222A2E),
      surfaceContainerHighest: const Color(0xFF2A3337),
      inverseSurface: const Color(0xFFEEF2F3),
      onInverseSurface: Brand.ink,
      inversePrimary: Brand.emberInk,
    );
  }

  static ThemeData _build(Brightness brightness) {
    final scheme = _scheme(brightness);
    final isLight = brightness == Brightness.light;
    final brand = isLight ? BrandColors.light : BrandColors.dark;
    const pill = StadiumBorder();
    const buttonText = TextStyle(
      fontFamily: kFontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w700,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: kFontFamily,
    );
    final text = base.textTheme;

    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: scheme.surface,
      extensions: [isLight ? StatusColors.light : StatusColors.dark, brand],
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      textTheme: text.copyWith(
        displaySmall: text.displaySmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -1.2,
        ),
        headlineLarge: text.headlineLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
        ),
        headlineMedium: text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
        ),
        headlineSmall: text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        titleLarge: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.scrolledUnder)
              ? brand.ground.withValues(alpha: .96)
              : Colors.transparent,
        ),
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          fontFamily: kFontFamily,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: isLight ? 2 : 0,
        shadowColor: brand.shadow,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        color: brand.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          side: isLight ? BorderSide.none : BorderSide(color: brand.line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brand.action,
          foregroundColor: brand.onAction,
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: .12),
          disabledForegroundColor: scheme.onSurface.withValues(alpha: .38),
          minimumSize: const Size(64, 56),
          shape: pill,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: const Size(64, 56),
          shape: pill,
          textStyle: buttonText,
          side: BorderSide(color: scheme.outline, width: 1.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: pill,
          textStyle: buttonText.copyWith(fontSize: 15),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: brand.accent,
        foregroundColor: brand.onAccent,
        elevation: 4,
        extendedTextStyle: buttonText,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md - 4),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        showCheckmark: false,
        side: WidgetStateBorderSide.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.selected)
                ? brand.ink
                : scheme.outlineVariant,
            width: 1.5,
          ),
        ),
        color: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? brand.ink : brand.surface,
        ),
        labelStyle: TextStyle(
          fontFamily: kFontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? brand.surface
                : brand.ink,
          ),
        ),
        iconTheme: IconThemeData(color: brand.ink2, size: 18),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 52)),
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          textStyle: const WidgetStatePropertyAll(buttonText),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? brand.ink : null,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? brand.surface : brand.ink,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? brand.onAction : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? brand.action : null,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? Colors.white : brand.surface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
          borderSide: BorderSide(color: scheme.outlineVariant, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        // Helper and error text wrap instead of being cut off on small
        // phones (seen on a 720 px wide screen).
        helperMaxLines: 3,
        errorMaxLines: 3,
      ),
      navigationBarTheme: NavigationBarThemeData(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        backgroundColor: brand.nav,
        surfaceTintColor: Colors.transparent,
        indicatorColor: brand.navActive,
        elevation: 0,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.onSurface,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: brand.action,
        labelStyle: buttonText.copyWith(fontSize: 15),
        unselectedLabelStyle: buttonText.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        dividerColor: Colors.transparent,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: brand.surface2,
        circularTrackColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.xl),
        ),
      ),
      dividerTheme: DividerThemeData(color: brand.line, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        contentTextStyle: TextStyle(
          fontFamily: kFontFamily,
          fontWeight: FontWeight.w600,
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
      ),
    );
  }
}

/// The page ground. Wrap each page's [Scaffold] in it (scaffolds are
/// transparent in [AppTheme]). Ember Slate uses a flat grey-blue ground; the
/// name is kept from the earlier gradient design so pages need no edits.
class GradientBackground extends StatelessWidget {
  const GradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      color: context.brand.ground,
      child: child,
    );
  }
}
