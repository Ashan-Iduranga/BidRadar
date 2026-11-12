/// BidRadar design tokens: the "Ember Slate" direction (A).
///
/// Sources: the team's Claude Design canvas "BidRadar redesign" (direction A),
/// built from the user's colour-palette pins (grey-blue #DEE6E8, orange
/// #FF5C00, mustard #DBB144, black), the `material-3` style guide and
/// ui-ux-pro-max. Rules: flat grey-blue ground, white cards with soft shadows,
/// one black hero card per screen, orange for actions with dark text on it,
/// darker orange (#B33F00) whenever orange is text, 4/8 dp spacing, sentence
/// case, meaning never by colour alone, text at least 4.5:1.
library;

import 'package:flutter/material.dart';

/// Seed colour for the Material 3 scheme (ember orange).
const Color kSeedColor = Color(0xFFFF5C00);

/// The font bundled in assets/fonts (OFL).
const String kFontFamily = 'PlusJakartaSans';

/// Raw brand colours of the Ember Slate palette.
abstract final class Brand {
  static const Color ember = Color(0xFFFF5C00);

  /// Orange that passes 4.5:1 as text on white and on the grey-blue ground.
  static const Color emberInk = Color(0xFFB33F00);
  static const Color mustard = Color(0xFFDBB144);
  static const Color slateGround = Color(0xFFDEE6E8);
  static const Color ink = Color(0xFF0E1011);
}

/// Spacing scale on a 4 dp base.
abstract final class Space {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Horizontal page gutter on phones.
  static const double gutter = 20;
}

/// Corner radii: big and soft, like the reference cards.
abstract final class Radii {
  static const double xs = 10; // small chips, snackbars
  static const double sm = 16; // text fields, menus, icon tiles
  static const double md = 24; // cards
  static const double lg = 28; // hero cards
  static const double xl = 32; // dialogs, bottom sheets
  static const double pill = 999;
}

/// Icon sizes.
abstract final class IconSizes {
  static const double sm = 18;
  static const double md = 24;
  static const double lg = 32;
}

/// Minimum touch target on Android (Material).
const double kMinTouchTarget = 48;
