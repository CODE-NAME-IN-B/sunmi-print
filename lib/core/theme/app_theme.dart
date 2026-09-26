import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // Brand palette (matches logo: orange #F97316 + near-black #0D0D0D)
  static const Color primary = Color(0xFFF97316);          // orange-500 (brand)
  static const Color onPrimary = Color(0xFFFFFFFF);         // white
  static const Color primaryContainer = Color(0xFFFFF3E0);  // orange-50
  static const Color onPrimaryContainer = Color(0xFF1A1A2E); // near-black

  // Secondary
  static const Color secondary = Color(0xFF1A1A2E);         // near-black (from logo bg)
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFF2D2D3F);
  static const Color onSecondaryContainer = Color(0xFFFFFFFF);

  // Tertiary (accent)
  static const Color accent = Color(0xFF1A1A2E);            // dark as accent
  static const Color onTertiary = Color(0xFFFFFFFF);

  // Background & Surface
  static const Color background = Color(0xFFFAFAFA);        // near-white
  static const Color surface = Color(0xFFFFFFFF);

  // Text
  static const Color textPrimary = Color(0xFF1A1A2E);       // near-black
  static const Color textSecondary = Color(0xFF6B7280);     // gray-500

  // Status
  static const Color success = Color(0xFF22C55E);           // green-500
  static const Color error = Color(0xFFEF4444);             // red-500
  static const Color warning = Color(0xFFF97316);           // same as brand orange

  // Dark palette
  static const Color darkPrimary = Color(0xFFF97316);       // orange
  static const Color darkSecondary = Color(0xFF9CA3AF);
  static const Color darkAccent = Color(0xFFF97316);
  static const Color darkBackground = Color(0xFF0D0D0D);    // near-black
  static const Color darkSurface = Color(0xFF1A1A2E);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);

  static ThemeData get lightTheme => _buildLight();
  static ThemeData get darkTheme => _buildDark();

  static TextTheme _buildTextTheme(TextTheme base) {
    return base.copyWith(
      headlineLarge: base.headlineLarge?.copyWith(fontFamily: 'Outfit', fontWeight: FontWeight.w700),
      headlineMedium: base.headlineMedium?.copyWith(fontFamily: 'Outfit', fontWeight: FontWeight.w700),
      headlineSmall: base.headlineSmall?.copyWith(fontFamily: 'Outfit', fontWeight: FontWeight.w600),
      titleLarge: base.titleLarge?.copyWith(fontFamily: 'Outfit', fontWeight: FontWeight.w700),
      titleMedium: base.titleMedium?.copyWith(fontFamily: 'Work Sans', fontWeight: FontWeight.w600),
      titleSmall: base.titleSmall?.copyWith(fontFamily: 'Work Sans', fontWeight: FontWeight.w600),
      bodyLarge: base.bodyLarge?.copyWith(fontFamily: 'Work Sans'),
      bodyMedium: base.bodyMedium?.copyWith(fontFamily: 'Work Sans'),
      bodySmall: base.bodySmall?.copyWith(fontFamily: 'Work Sans'),
      labelLarge: base.labelLarge?.copyWith(fontFamily: 'Work Sans', fontWeight: FontWeight.w600),
      labelMedium: base.labelMedium?.copyWith(fontFamily: 'Work Sans', fontWeight: FontWeight.w500),
      labelSmall: base.labelSmall?.copyWith(fontFamily: 'Work Sans'),
    );
  }

  static ThemeData _buildLight() {
    final colorScheme = ColorScheme.light(
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
      tertiaryContainer: const Color(0xFFFED7AA),
      onTertiaryContainer: const Color(0xFF7C2D12),
      error: error,
      onError: Colors.white,
      errorContainer: const Color(0xFFFEE2E2),
      onErrorContainer: const Color(0xFF991B1B),
      surface: surface,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      outline: const Color(0xFFCBD5E1),
      outlineVariant: const Color(0xFFE2E8F0),
      shadow: Colors.black26,
      surfaceContainerHighest: const Color(0xFFF1F5F9),
      surfaceContainerHigh: const Color(0xFFF8FAFC),
      surfaceContainer: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFFFFFFF),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: surface,
        foregroundColor: textPrimary,
        shadowColor: Colors.black26,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: const Color(0xFFE2E8F0), width: 1),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: surface,
        indicatorColor: primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((_) => GoogleFonts.workSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        )),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          textStyle: GoogleFonts.workSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: const BorderSide(color: Color(0xFFCBD5E1)),
          textStyle: GoogleFonts.workSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.workSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFF97316), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: GoogleFonts.workSans(color: textSecondary),
        hintStyle: GoogleFonts.workSans(color: const Color(0xFF94A3B8)),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE2E8F0),
        thickness: 1,
        space: 1,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return const Color(0xFFCBD5E1);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary.withValues(alpha: 0.3);
          return const Color(0xFFE2E8F0);
        }),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return textSecondary;
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: secondary,
        contentTextStyle: GoogleFonts.workSans(color: onSecondary, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: Color(0xFFE2E8F0),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        minVerticalPadding: 8,
      ),
      textTheme: _buildTextTheme(ThemeData.light().textTheme).copyWith(
        headlineLarge: GoogleFonts.outfit(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: textPrimary,
        ),
        headlineMedium: GoogleFonts.outfit(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.25,
          color: textPrimary,
        ),
        headlineSmall: GoogleFonts.outfit(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleLarge: GoogleFonts.outfit(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        titleMedium: GoogleFonts.workSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleSmall: GoogleFonts.workSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          color: textPrimary,
        ),
        bodyLarge: GoogleFonts.workSans(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        ),
        bodyMedium: GoogleFonts.workSans(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
        bodySmall: GoogleFonts.workSans(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
        labelLarge: GoogleFonts.workSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: textPrimary,
        ),
        labelMedium: GoogleFonts.workSans(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          color: textSecondary,
        ),
        labelSmall: GoogleFonts.workSans(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          color: textSecondary,
        ),
      ),
    );
  }

  static ThemeData _buildDark() {
    final colorScheme = ColorScheme.dark(
      primary: darkPrimary,
      onPrimary: const Color(0xFF1A1A2E),
      primaryContainer: const Color(0xFF7C2D12),
      onPrimaryContainer: const Color(0xFFFED7AA),
      secondary: darkSecondary,
      onSecondary: const Color(0xFF1A1A2E),
      secondaryContainer: const Color(0xFF2D2D3F),
      onSecondaryContainer: darkTextPrimary,
      tertiary: darkAccent,
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFF7C2D12),
      onTertiaryContainer: const Color(0xFFFED7AA),
      error: const Color(0xFFFCA5A5),
      onError: const Color(0xFF7F1D1D),
      errorContainer: const Color(0xFF991B1B),
      onErrorContainer: const Color(0xFFFEE2E2),
      surface: darkSurface,
      onSurface: darkTextPrimary,
      onSurfaceVariant: darkTextSecondary,
      outline: const Color(0xFF475569),
      outlineVariant: const Color(0xFF2D2D3F),
      shadow: Colors.black54,
      surfaceContainerHighest: const Color(0xFF2D2D3F),
      surfaceContainerHigh: darkSurface,
      surfaceContainer: darkSurface,
      surfaceContainerLow: darkBackground,
      surfaceContainerLowest: darkBackground,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: darkBackground,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: darkSurface,
        foregroundColor: darkTextPrimary,
        shadowColor: Colors.black26,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: darkTextPrimary,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: darkTextPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: darkSurface,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF2D2D3F), width: 1),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: darkSurface,
        indicatorColor: darkAccent.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((_) => GoogleFonts.workSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: darkTextPrimary,
        )),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: darkPrimary,
          foregroundColor: const Color(0xFF1A1A2E),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          textStyle: GoogleFonts.workSans(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: const BorderSide(color: Color(0xFF475569)),
          textStyle: GoogleFonts.workSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.workSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF475569)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF475569)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: darkAccent, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: GoogleFonts.workSans(color: darkTextSecondary),
        hintStyle: GoogleFonts.workSans(color: const Color(0xFF64748B)),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF2D2D3F),
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: darkSurface,
        contentTextStyle: GoogleFonts.workSans(color: darkTextPrimary, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: darkAccent,
        linearTrackColor: Color(0xFF2D2D3F),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return darkPrimary;
          return const Color(0xFF6B7280);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return darkPrimary.withValues(alpha: 0.3);
          return const Color(0xFF334155);
        }),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return darkPrimary;
          return darkTextSecondary;
        }),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        minVerticalPadding: 8,
      ),
      textTheme: _buildTextTheme(ThemeData.dark().textTheme).copyWith(
        headlineLarge: GoogleFonts.outfit(
          fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: darkTextPrimary,
        ),
        headlineMedium: GoogleFonts.outfit(
          fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.25, color: darkTextPrimary,
        ),
        headlineSmall: GoogleFonts.outfit(
          fontSize: 24, fontWeight: FontWeight.w600, color: darkTextPrimary,
        ),
        titleLarge: GoogleFonts.outfit(
          fontSize: 22, fontWeight: FontWeight.w700, color: darkTextPrimary,
        ),
        titleMedium: GoogleFonts.workSans(
          fontSize: 16, fontWeight: FontWeight.w600, color: darkTextPrimary,
        ),
        titleSmall: GoogleFonts.workSans(
          fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1, color: darkTextPrimary,
        ),
        bodyLarge: GoogleFonts.workSans(
          fontSize: 16, fontWeight: FontWeight.w400, color: darkTextPrimary,
        ),
        bodyMedium: GoogleFonts.workSans(
          fontSize: 14, fontWeight: FontWeight.w400, color: darkTextSecondary,
        ),
        bodySmall: GoogleFonts.workSans(
          fontSize: 12, fontWeight: FontWeight.w400, color: darkTextSecondary,
        ),
        labelLarge: GoogleFonts.workSans(
          fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: darkTextPrimary,
        ),
        labelMedium: GoogleFonts.workSans(
          fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5, color: darkTextSecondary,
        ),
        labelSmall: GoogleFonts.workSans(
          fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5, color: darkTextSecondary,
        ),
      ),
    );
  }

  // Semantic color helpers
  static Color statusColor(String status) => switch (status) {
    'connected' => success,
    'disconnected' => error,
    'pending' => warning,
    'printing' => const Color(0xFF3B82F6),
    'completed' => success,
    'failed' => error,
    'cancelled' => secondary,
    _ => secondary,
  };
}
