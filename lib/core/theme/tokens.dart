/// BidRadar design tokens.
///
/// Sources: the `material-3` and `quiet-product` style guides from the team
/// design library, plus ui-ux-pro-max (calm navy/blue trust palette).
/// Rules: one accent colour per screen, borders instead of shadows,
/// 4/8 dp spacing rhythm, sentence case, meaning never by colour alone.
library;

import 'package:flutter/material.dart';

/// Seed colour for the Material 3 scheme (cobalt, from quiet-product).
const Color kSeedColor = Color(0xFF2F4BD8);

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
  static const double gutter = 16;
}

/// Corner radii, matching Material 3 shape tokens.
abstract final class Radii {
  static const double xs = 4; // chips, snackbars
  static const double sm = 8; // text fields, menus
  static const double md = 12; // cards
  static const double lg = 16; // FAB
  static const double xl = 28; // dialogs, bottom sheets
}

/// Icon sizes.
abstract final class IconSizes {
  static const double sm = 18;
  static const double md = 24;
  static const double lg = 32;
}

/// Minimum touch target on Android (Material).
const double kMinTouchTarget = 48;
