/// BidRadar design tokens: the "Azure Mint" direction.
///
/// Sources: the team's chosen Claude Design canvas (A · Azure Mint), built
/// from the blue-to-green gradient palette reference, plus the `material-3`
/// style guide and ui-ux-pro-max. Rules: soft gradient page grounds, frosted
/// cards, one deep azure-to-teal hero gradient per screen, 4/8 dp spacing,
/// sentence case, meaning never by colour alone, text at least 4.5:1 on every
/// gradient stop.
library;

import 'package:flutter/material.dart';

/// Seed colour for the Material 3 scheme (azure).
const Color kSeedColor = Color(0xFF0B5ED7);

/// Brand colours from the Azure Mint palette.
abstract final class Brand {
  static const Color azureDeep = Color(0xFF0A3D91);
  static const Color azure = Color(0xFF0B5ED7);
  static const Color sky = Color(0xFF2D9CF5);
  static const Color mint = Color(0xFF3DCB8A);

  /// Darkened mint, the end of the hero gradient (white text passes 4.5:1).
  static const Color teal = Color(0xFF08705F);
  static const Color ice = Color(0xFFE6F4FF);
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
  static const double gutter = 16;
}

/// Corner radii. Softer than stock Material 3 to match the frosted cards.
abstract final class Radii {
  static const double xs = 8; // verdict chips, snackbars
  static const double sm = 14; // text fields, filter chips, menus
  static const double md = 20; // cards
  static const double lg = 24; // hero cards, FAB
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
