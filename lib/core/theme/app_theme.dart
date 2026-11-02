import 'package:flutter/material.dart';

import 'status_colors.dart';
import 'tokens.dart';

/// Builds the light and dark Material 3 themes for the Azure Mint direction.
///
/// Scaffolds are transparent: every page sits on a [GradientBackground], so
/// the soft azure-to-mint wash shows behind app bars, lists and cards.
abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  /// Deep azure-to-teal gradient for hero cards and headers. White text and
  /// [heroMuted] text pass 4.5:1 at every stop.
  static LinearGradient heroGradient(Brightness b) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: b == Brightness.light
        ? const [Brand.azureDeep, Brand.azure, Brand.teal]
        : const [Brand.azureDeep, Color(0xFF0B4FB8), Color(0xFF0A6B5D)],
    stops: const [0, .52, 1],
  );

  /// Secondary text on the hero gradient.
  static const Color heroMuted = Color(0xFFDCEBFF);

  static ColorScheme _scheme(Brightness brightness) {
    final base = ColorScheme.fromSeed(
      seedColor: kSeedColor,
      brightness: brightness,
    );
    if (brightness == Brightness.light) {
      return base.copyWith(
        primary: Brand.azure,
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFFDCEAFF),
        onPrimaryContainer: Brand.azureDeep,
        tertiary: Brand.teal,
        onTertiary: Colors.white,
        tertiaryContainer: const Color(0xFFDDF6EA),
        onTertiaryContainer: const Color(0xFF0B5A3A),
        surface: const Color(0xFFF7FAFF),
        onSurface: const Color(0xFF0B1F3A),
        onSurfaceVariant: const Color(0xFF45566E),
        outline: const Color(0xFF71839C),
        outlineVariant: const Color(0xFFD3E1F2),
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: const Color(0xFFF2F7FF),
        surfaceContainer: const Color(0xFFEAF2FD),
        surfaceContainerHigh: const Color(0xFFE3EDFB),
        surfaceContainerHighest: const Color(0xFFDCE7F7),
      );
    }
    return base.copyWith(
      primary: const Color(0xFF6BB8FF),
      onPrimary: const Color(0xFF04172F),
      primaryContainer: const Color(0xFF163A66),
      onPrimaryContainer: const Color(0xFFCFE5FF),
      tertiary: const Color(0xFF5FDDA6),
      onTertiary: const Color(0xFF00311F),
      tertiaryContainer: const Color(0xFF15402F),
      onTertiaryContainer: const Color(0xFFA6E3C8),
      surface: const Color(0xFF0B1A30),
      onSurface: const Color(0xFFEAF3FF),
      onSurfaceVariant: const Color(0xFFA3B6D0),
      outline: const Color(0xFF6F84A3),
      outlineVariant: const Color(0xFF22385C),
      surfaceContainerLowest: const Color(0xFF06122A),
      surfaceContainerLow: const Color(0xFF0F2140),
      surfaceContainer: const Color(0xFF13274A),
      surfaceContainerHigh: const Color(0xFF183055),
      surfaceContainerHighest: const Color(0xFF1E3860),
    );
  }

  static ThemeData _build(Brightness brightness) {
    final scheme = _scheme(brightness);
    final isLight = brightness == Brightness.light;
    final ground = isLight ? _Ground.light : _Ground.dark;
    // Frosted cards: mostly opaque so text contrast holds on any gradient stop.
    final cardColor = isLight
        ? Colors.white.withValues(alpha: .86)
        : const Color(0xFF112442).withValues(alpha: .86);
    final cardEdge = isLight
        ? Colors.white.withValues(alpha: .9)
        : const Color(0xFF78AAE6).withValues(alpha: .16);
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.sm + 2),
    );
    const buttonText = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final text = base.textTheme;

    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: scheme.surface,
      extensions: [isLight ? StatusColors.light : StatusColors.dark],
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      textTheme: text.copyWith(
        headlineMedium: text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
        ),
        headlineSmall: text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        titleLarge: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        // Clear over the gradient; frosted once content scrolls under it.
        backgroundColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.scrolledUnder)
              ? ground.top.withValues(alpha: .94)
              : Colors.transparent,
        ),
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 3,
        shadowColor: const Color(0xFF103050).withValues(alpha: .22),
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          side: BorderSide(color: cardEdge),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: buttonShape,
          textStyle: buttonText,
          side: BorderSide(color: scheme.outline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: buttonShape,
          textStyle: buttonText.copyWith(fontSize: 15),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg - 4),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.sm - 2),
        ),
        side: BorderSide(color: scheme.outlineVariant),
        color: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primaryContainer
              : cardColor,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? Colors.white : scheme.surfaceContainerLow,
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
        backgroundColor: isLight
            ? Colors.white.withValues(alpha: .92)
            : const Color(0xFF0A182E).withValues(alpha: .94),
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
      ),
    );
  }
}

/// Page-ground colours: a diagonal wash plus two soft colour glows.
class _Ground {
  const _Ground(this.top, this.middle, this.bottom, this.glowA, this.glowB);
  final Color top;
  final Color middle;
  final Color bottom;
  final Color glowA; // sky, top right
  final Color glowB; // mint, bottom left

  static const light = _Ground(
    Color(0xFFE2EEFF),
    Color(0xFFEEF6FF),
    Color(0xFFE4F8EF),
    Color(0x4D2D9CF5),
    Color(0x423DCB8A),
  );
  static const dark = _Ground(
    Color(0xFF061328),
    Color(0xFF08182E),
    Color(0xFF06221F),
    Color(0x332D9CF5),
    Color(0x293DCB8A),
  );
}

/// The soft azure-to-mint page ground. Wrap each page's [Scaffold] in it
/// (scaffolds are transparent in [AppTheme]).
class GradientBackground extends StatelessWidget {
  const GradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).brightness == Brightness.light
        ? _Ground.light
        : _Ground.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: const Alignment(-0.6, -1),
          end: const Alignment(0.6, 1),
          colors: [g.top, g.middle, g.bottom],
          stops: const [0, .48, 1],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.85, -0.9),
            radius: 0.9,
            colors: [g.glowA, g.glowA.withValues(alpha: 0)],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.9, 0.95),
              radius: 1.0,
              colors: [g.glowB, g.glowB.withValues(alpha: 0)],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
