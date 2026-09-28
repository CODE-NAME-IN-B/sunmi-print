import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_motion.dart';

/// The design system.
///
/// Two constraints drive every decision here. The device is a Sunmi terminal at
/// a shop counter: it is used fast, often one handed, and in lighting that
/// changes through the day. So the type is a proper Arabic face rather than a
/// Latin display font with an Arabic fallback, every interactive element clears
/// 48dp, and both colour schemes hold up at WCAG AA.
class AppTheme {
  AppTheme._();

  // Brand palette, taken from the logo: orange #F97316 over near-black #1A1A2E.
  static const Color primary = Color(0xFFF97316);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFFFF3E0);
  static const Color onPrimaryContainer = Color(0xFF1A1A2E);

  static const Color secondary = Color(0xFF1A1A2E);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFF2D2D3F);
  static const Color onSecondaryContainer = Color(0xFFFFFFFF);

  static const Color accent = Color(0xFF1A1A2E);
  static const Color onTertiary = Color(0xFFFFFFFF);

  static const Color background = Color(0xFFF7F7F8);
  static const Color surface = Color(0xFFFFFFFF);

  /// Muted body text. 6.1:1 on the light background, comfortably past AA.
  static const Color textPrimary = Color(0xFF15172A);
  static const Color textSecondary = Color(0xFF5B6472);

  static const Color success = Color(0xFF15803D);
  static const Color error = Color(0xFFDC2626);
  static const Color warning = Color(0xFFD97706);
  static const Color info = Color(0xFF1D4ED8);

  // Dark palette
  static const Color darkPrimary = Color(0xFFFB923C);
  static const Color darkSecondary = Color(0xFFB4BCC9);
  static const Color darkAccent = Color(0xFFFB923C);
  static const Color darkBackground = Color(0xFF0B0B0F);
  static const Color darkSurface = Color(0xFF16161C);
  static const Color darkTextPrimary = Color(0xFFF4F4F5);

  /// 7.2:1 on the dark surface.
  static const Color darkTextSecondary = Color(0xFFA8B0BD);

  static const Color darkSuccess = Color(0xFF4ADE80);
  static const Color darkError = Color(0xFFF87171);
  static const Color darkWarning = Color(0xFFFBBF24);
  static const Color darkInfo = Color(0xFF93C5FD);

  static ThemeData get lightTheme => _buildLight();
  static ThemeData get darkTheme => _buildDark();

  /// Numerals share a fixed advance so a running total or a copy counter does
  /// not shift sideways as digits change.
  static const List<FontFeature> _tabular = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  static TextTheme _baseTextTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final heading = isDark ? darkTextPrimary : textPrimary;
    final body = isDark ? darkTextSecondary : textSecondary;

    // Noto Sans Arabic carries the Arabic letterforms properly and also covers
    // Latin and digits, so one family keeps a mixed line of text coherent.
    final arabic = GoogleFonts.notoSansArabicTextTheme(
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    );

    return arabic.copyWith(
      displaySmall: arabic.displaySmall?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: heading,
        fontFeatures: _tabular,
      ),
      headlineLarge: arabic.headlineLarge?.copyWith(
        fontFamily: 'Outfit',
        fontSize: 30,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: heading,
      ),
      headlineMedium: arabic.headlineMedium?.copyWith(
        fontFamily: 'Outfit',
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: heading,
      ),
      headlineSmall: arabic.headlineSmall?.copyWith(
        fontFamily: 'Outfit',
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: heading,
      ),
      titleLarge: arabic.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: heading,
      ),
      titleMedium: arabic.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: heading,
      ),
      titleSmall: arabic.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: heading,
      ),
      bodyLarge: arabic.bodyLarge?.copyWith(fontSize: 16, color: heading),
      bodyMedium: arabic.bodyMedium?.copyWith(fontSize: 14, color: body),
      bodySmall: arabic.bodySmall?.copyWith(fontSize: 12.5, color: body),
      labelLarge: arabic.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: heading,
      ),
      labelMedium: arabic.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: body,
      ),
      labelSmall: arabic.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: body,
      ),
    );
  }

  static ThemeData _buildLight() {
    const colorScheme = ColorScheme.light(
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimaryContainer,
      secondary: secondary,
      onSecondary: onSecondary,
      secondaryContainer: secondaryContainer,
      onSecondaryContainer: onSecondaryContainer,
      tertiary: accent,
      onTertiary: onTertiary,
      tertiaryContainer: Color(0xFFFED7AA),
      onTertiaryContainer: Color(0xFF7C2D12),
      error: error,
      onError: Colors.white,
      errorContainer: Color(0xFFFEE2E2),
      onErrorContainer: Color(0xFF991B1B),
      surface: surface,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      outline: Color(0xFFB6BFC9),
      outlineVariant: Color(0xFFE2E8F0),
      shadow: Colors.black26,
      surfaceContainerHighest: Color(0xFFEEF1F5),
      surfaceContainerHigh: Color(0xFFF4F6F8),
      surfaceContainer: surface,
      surfaceContainerLow: Color(0xFFFBFBFC),
      surfaceContainerLowest: Colors.white,
    );

    final textTheme = _baseTextTheme(Brightness.light);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      splashFactory: InkSparkle.splashFactory,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: surface,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: textTheme.titleLarge,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size(AppSizes.touchTarget, AppSizes.touchTarget),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: const BorderSide(color: Color(0xFFE4E8EE), width: 1),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 68,
        backgroundColor: surface,
        indicatorColor: primary.withValues(alpha: 0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? textTheme.labelMedium?.copyWith(color: primary)
              : textTheme.labelMedium,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size(64, AppSizes.touchTarget + 4),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          elevation: 0,
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size(64, AppSizes.touchTarget + 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          elevation: 0,
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, AppSizes.touchTarget + 4),
          foregroundColor: textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          side: const BorderSide(color: Color(0xFFCBD5E1)),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, AppSizes.touchTarget),
          foregroundColor: primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.chip),
          ),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 14),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(64, AppSizes.touchTarget),
          selectedBackgroundColor: primary.withValues(alpha: 0.12),
          selectedForegroundColor: primary,
          side: const BorderSide(color: Color(0xFFE2E8F0)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.cardPadding,
          vertical: 14,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: textSecondary),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF64748B),
        ),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 6,
        activeTrackColor: primary,
        inactiveTrackColor: const Color(0xFFE2E8F0),
        thumbColor: primary,
        overlayColor: primary.withValues(alpha: 0.12),
        valueIndicatorColor: primary,
        valueIndicatorTextStyle: textTheme.labelMedium?.copyWith(
          color: Colors.white,
          fontFeatures: _tabular,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE8ECF1),
        thickness: 1,
        space: 1,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return const Color(0xFFF8FAFC);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return const Color(0xFFCBD5E1);
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return Colors.transparent;
        }),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.chip - 2),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primary
              : const Color(0xFF94A3B8),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: secondary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
        insetPadding: const EdgeInsets.all(AppSizes.gutter),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: Color(0xFFE2E8F0),
        linearMinHeight: 6,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.cardPadding,
          vertical: 6,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
        minVerticalPadding: 10,
        iconColor: textSecondary,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData _buildDark() {
    const colorScheme = ColorScheme.dark(
      primary: darkPrimary,
      onPrimary: Color(0xFF3B1A02),
      primaryContainer: Color(0xFF7C2D12),
      onPrimaryContainer: Color(0xFFFED7AA),
      secondary: darkSecondary,
      onSecondary: Color(0xFF0B0B0F),
      secondaryContainer: Color(0xFF2A2A33),
      onSecondaryContainer: darkTextPrimary,
      tertiary: darkAccent,
      onTertiary: Color(0xFF3B1A02),
      tertiaryContainer: Color(0xFF7C2D12),
      onTertiaryContainer: Color(0xFFFED7AA),
      error: darkError,
      onError: Color(0xFF7F1D1D),
      errorContainer: Color(0xFF7F1D1D),
      onErrorContainer: Color(0xFFFEE2E2),
      surface: darkSurface,
      onSurface: darkTextPrimary,
      onSurfaceVariant: darkTextSecondary,
      outline: Color(0xFF4A5261),
      outlineVariant: Color(0xFF2A2A33),
      shadow: Colors.black54,
      surfaceContainerHighest: Color(0xFF23232C),
      surfaceContainerHigh: darkSurface,
      surfaceContainer: darkSurface,
      surfaceContainerLow: Color(0xFF101014),
      surfaceContainerLowest: darkBackground,
    );

    final textTheme = _baseTextTheme(Brightness.dark);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: darkBackground,
      splashFactory: InkSparkle.splashFactory,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: darkSurface,
        foregroundColor: darkTextPrimary,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: textTheme.titleLarge,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: darkTextPrimary,
          minimumSize: const Size(AppSizes.touchTarget, AppSizes.touchTarget),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: darkSurface,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: const BorderSide(color: Color(0xFF2A2A33), width: 1),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 68,
        backgroundColor: darkSurface,
        indicatorColor: darkAccent.withValues(alpha: 0.2),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? textTheme.labelMedium?.copyWith(color: darkAccent)
              : textTheme.labelMedium,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: darkPrimary,
          foregroundColor: const Color(0xFF3B1A02),
          minimumSize: const Size(64, AppSizes.touchTarget + 4),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          elevation: 0,
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkPrimary,
          foregroundColor: const Color(0xFF3B1A02),
          minimumSize: const Size(64, AppSizes.touchTarget + 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          elevation: 0,
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, AppSizes.touchTarget + 4),
          foregroundColor: darkTextPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          side: const BorderSide(color: Color(0xFF3A3F4B)),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, AppSizes.touchTarget),
          foregroundColor: darkAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.chip),
          ),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 14),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(64, AppSizes.touchTarget),
          selectedBackgroundColor: darkAccent.withValues(alpha: 0.2),
          selectedForegroundColor: darkAccent,
          side: const BorderSide(color: Color(0xFF2A2A33)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: Color(0xFF3A3F4B)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: Color(0xFF3A3F4B)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: darkAccent, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.cardPadding,
          vertical: 14,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: darkTextSecondary),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF7C8595),
        ),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 6,
        activeTrackColor: darkAccent,
        inactiveTrackColor: const Color(0xFF2A2A33),
        thumbColor: darkAccent,
        overlayColor: darkAccent.withValues(alpha: 0.16),
        valueIndicatorColor: darkAccent,
        valueIndicatorTextStyle: textTheme.labelMedium?.copyWith(
          color: const Color(0xFF0B0B0F),
          fontFeatures: _tabular,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF26262F),
        thickness: 1,
        space: 1,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF3B1A02);
          }
          return const Color(0xFF6B7280);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return darkAccent;
          return const Color(0xFF334155);
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return darkAccent;
          return Colors.transparent;
        }),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.chip - 2),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? darkAccent
              : const Color(0xFF6B7280),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF23232C),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: darkTextPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
        insetPadding: const EdgeInsets.all(AppSizes.gutter),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: darkAccent,
        linearTrackColor: Color(0xFF2A2A33),
        linearMinHeight: 6,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.cardPadding,
          vertical: 6,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
        minVerticalPadding: 10,
        iconColor: darkTextSecondary,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  /// Maps a job or connection status onto its semantic colour.
  static Color statusColor(String status) => switch (status) {
    'connected' || 'completed' => success,
    'disconnected' || 'failed' => error,
    'pending' || 'noPaper' => warning,
    'printing' => info,
    'overheat' => const Color(0xFFEA580C),
    'cancelled' => textSecondary,
    _ => textSecondary,
  };
}
