import 'package:flutter/material.dart';

/// Motion tokens.
///
/// One duration scale and one easing curve for the whole app. Transitions
/// outside 150-300ms either feel abrupt or feel sluggish on a device that is
/// used dozens of times a day behind a counter, and mixing curves across
/// screens reads as two apps stitched together.
class AppMotion {
  AppMotion._();

  /// Hover and colour transitions. Instant enough to feel direct.
  static const Duration fast = Duration(milliseconds: 150);

  /// Default for screen transitions and card presses.
  static const Duration base = Duration(milliseconds: 220);

  /// Reserved for large surfaces such as a paper preview fading in.
  static const Duration slow = Duration(milliseconds: 300);

  /// The single easing curve used app wide. `easeOut` decelerates into the
  /// destination, which is what makes a press feel like it lands rather than
  /// stops.
  static const Curve curve = Curves.easeOutCubic;

  /// How much a pressable shrinks. 4% is the most that still reads as
  /// "pressed" rather than "bounced".
  static const double pressScale = 0.96;

  /// Overshoot used when a value settles, such as a count incrementing.
  static const Curve emphasize = Curves.easeOutBack;
}

/// Corner radii, kept concentric.
///
/// A 16px card holds 12px buttons, which hold 8px chips. Using an unrelated
/// radius on a nested element is the fastest way to make a layout look
/// assembled rather than designed.
class AppRadii {
  AppRadii._();

  static const double card = 16;
  static const double control = 12;
  static const double chip = 8;
  static const double sheet = 20;
}

/// Layout constants.
class AppSizes {
  AppSizes._();

  /// Minimum interactive size. The accessibility floor is 44dp; 48dp leaves
  /// room for a shaky thumb without pushing layout around.
  static const double touchTarget = 48;

  static const double gutter = 16;
  static const double sectionGap = 24;
  static const double itemGap = 8;
  static const double cardPadding = 16;
}
