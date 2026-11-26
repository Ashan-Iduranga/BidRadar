import 'package:flutter/material.dart';

/// Ember Slate surface and accent roles that Material's [ColorScheme] has no
/// slot for: the page ground, the black hero card, the floating nav bar and
/// the intro radar. Read with `context.brand`.
///
/// Pairs (`hero`/`onHero`, `nav`/`navInk`, ...) are checked at 4.5:1 or more
/// for text.
@immutable
class BrandColors extends ThemeExtension<BrandColors> {
  const BrandColors({
    required this.ground,
    required this.surface,
    required this.surface2,
    required this.line,
    required this.ink,
    required this.ink2,
    required this.action,
    required this.onAction,
    required this.actionInk,
    required this.accent,
    required this.onAccent,
    required this.hero,
    required this.onHero,
    required this.heroMuted,
    required this.heroAccent,
    required this.heroTrack,
    required this.nav,
    required this.navInk,
    required this.navActive,
    required this.onNavActive,
    required this.tint,
    required this.ringLine,
    required this.shadow,
  });

  /// Page ground behind every screen.
  final Color ground;

  /// Cards and sheets.
  final Color surface;

  /// Icon tiles, tracks, quote boxes inside cards.
  final Color surface2;

  /// Hairlines between rows.
  final Color line;

  /// Primary and secondary text.
  final Color ink;
  final Color ink2;

  /// Ember orange fill for primary actions, with dark text on it.
  final Color action;
  final Color onAction;

  /// Orange that is safe as text and icon colour on [surface] and [ground].
  final Color actionInk;

  /// Mustard accent (scan button, highlights) with dark text on it.
  final Color accent;
  final Color onAccent;

  /// The one bold card per screen (black in light mode, grey-blue in dark).
  final Color hero;
  final Color onHero;
  final Color heroMuted;
  final Color heroAccent;

  /// Ring track drawn on [hero].
  final Color heroTrack;

  /// Floating bottom navigation bar.
  final Color nav;
  final Color navInk;
  final Color navActive;
  final Color onNavActive;

  /// Intro radar: warm disc and ring colours.
  final Color tint;
  final Color ringLine;

  /// Soft card shadow colour.
  final Color shadow;

  static const light = BrandColors(
    ground: Color(0xFFDEE6E8),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFEEF2F3),
    line: Color(0xFFE3E9EB),
    ink: Color(0xFF0E1011),
    ink2: Color(0xFF4A5458),
    action: Color(0xFFFF5C00),
    onAction: Color(0xFF0E1011),
    actionInk: Color(0xFFB33F00),
    accent: Color(0xFFDBB144),
    onAccent: Color(0xFF0E1011),
    hero: Color(0xFF0E1011),
    onHero: Color(0xFFFFFFFF),
    heroMuted: Color(0xFFB9C2C5),
    heroAccent: Color(0xFFFF5C00),
    heroTrack: Color(0xFF2A3033),
    nav: Color(0xFF0E1011),
    navInk: Color(0xFFB9C2C5),
    navActive: Color(0xFFFF5C00),
    onNavActive: Color(0xFF0E1011),
    tint: Color(0xFFFFE9DC),
    ringLine: Color(0xFFFFC9A8),
    shadow: Color(0x140E1011),
  );

  static const dark = BrandColors(
    ground: Color(0xFF0E1113),
    surface: Color(0xFF181D20),
    surface2: Color(0xFF222A2E),
    line: Color(0xFF2A3337),
    ink: Color(0xFFEEF2F3),
    ink2: Color(0xFFA7B2B6),
    action: Color(0xFFFF6A1A),
    onAction: Color(0xFF0E1011),
    actionInk: Color(0xFFFF8A4C),
    accent: Color(0xFFDBB144),
    onAccent: Color(0xFF0E1011),
    hero: Color(0xFFDEE6E8),
    onHero: Color(0xFF0E1011),
    heroMuted: Color(0xFF4A5458),
    heroAccent: Color(0xFFB33F00),
    heroTrack: Color(0xFFC9D3D6),
    nav: Color(0xFF222A2E),
    navInk: Color(0xFFA7B2B6),
    navActive: Color(0xFFFF6A1A),
    onNavActive: Color(0xFF0E1011),
    tint: Color(0xFF2A1A10),
    ringLine: Color(0xFF5A3420),
    shadow: Color(0x4D000000),
  );

  /// Standard soft card shadow.
  List<BoxShadow> get cardShadow => [
    BoxShadow(color: shadow, blurRadius: 24, offset: const Offset(0, 8)),
  ];

  @override
  BrandColors copyWith({Color? ground, Color? surface, Color? hero}) {
    return BrandColors(
      ground: ground ?? this.ground,
      surface: surface ?? this.surface,
      surface2: surface2,
      line: line,
      ink: ink,
      ink2: ink2,
      action: action,
      onAction: onAction,
      actionInk: actionInk,
      accent: accent,
      onAccent: onAccent,
      hero: hero ?? this.hero,
      onHero: onHero,
      heroMuted: heroMuted,
      heroAccent: heroAccent,
      heroTrack: heroTrack,
      nav: nav,
      navInk: navInk,
      navActive: navActive,
      onNavActive: onNavActive,
      tint: tint,
      ringLine: ringLine,
      shadow: shadow,
    );
  }

  @override
  BrandColors lerp(BrandColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return BrandColors(
      ground: l(ground, other.ground),
      surface: l(surface, other.surface),
      surface2: l(surface2, other.surface2),
      line: l(line, other.line),
      ink: l(ink, other.ink),
      ink2: l(ink2, other.ink2),
      action: l(action, other.action),
      onAction: l(onAction, other.onAction),
      actionInk: l(actionInk, other.actionInk),
      accent: l(accent, other.accent),
      onAccent: l(onAccent, other.onAccent),
      hero: l(hero, other.hero),
      onHero: l(onHero, other.onHero),
      heroMuted: l(heroMuted, other.heroMuted),
      heroAccent: l(heroAccent, other.heroAccent),
      heroTrack: l(heroTrack, other.heroTrack),
      nav: l(nav, other.nav),
      navInk: l(navInk, other.navInk),
      navActive: l(navActive, other.navActive),
      onNavActive: l(onNavActive, other.onNavActive),
      tint: l(tint, other.tint),
      ringLine: l(ringLine, other.ringLine),
      shadow: l(shadow, other.shadow),
    );
  }
}

extension BrandColorsX on BuildContext {
  BrandColors get brand =>
      Theme.of(this).extension<BrandColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? BrandColors.dark
          : BrandColors.light);
}
