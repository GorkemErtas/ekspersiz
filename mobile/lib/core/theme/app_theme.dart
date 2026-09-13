import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // =========================================================
  // BRAND COLORS
  // =========================================================

  static const Color primaryColor = Color(0xFF2563EB);

  static const Color primaryDark = Color(0xFF1D4ED8);

  static const Color secondaryColor = Color(0xFF0EA5E9);

  static const Color accentColor = Color(0xFF38BDF8);

  // =========================================================
  // LIGHT COLORS
  // =========================================================

  static const Color backgroundColor = Color(0xFFF8F9FA);

  static const Color surfaceColor = Color(0xFFFFFFFF);

  static const Color surfaceSoft = Color(0xFFF1F5F9);

  static const Color surfaceMuted = Color(0xFFEFF6FF);

  static const Color textPrimary = Color(0xFF0F172A);

  static const Color textSecondary = Color(0xFF64748B);

  static const Color textMuted = Color(0xFF94A3B8);

  static const Color borderColor = Color(0xFFE2E8F0);

  static const Color borderStrong = Color(0xFFCBD5E1);

  // =========================================================
  // SEMANTIC COLORS
  // =========================================================

  static const Color successColor = Color(0xFF16A34A);

  static const Color successSoft = Color(0xFFDCFCE7);

  static const Color warningColor = Color(0xFFF59E0B);

  static const Color warningSoft = Color(0xFFFEF3C7);

  static const Color dangerColor = Color(0xFFDC2626);

  static const Color dangerSoft = Color(0xFFFEE2E2);

  static const Color infoColor = Color(0xFF0284C7);

  static const Color infoSoft = Color(0xFFE0F2FE);

  // =========================================================
  // DAMAGE SEVERITY COLORS
  // =========================================================

  static const Color severityNone = Color(0xFF16A34A);

  static const Color severityMinor = Color(0xFFF59E0B);

  static const Color severityModerate = Color(0xFFEA580C);

  static const Color severitySevere = Color(0xFFDC2626);

  static const Color severityUnknown = Color(0xFF64748B);

  // =========================================================
  // SPACING
  // =========================================================

  static const double spacingXS = 4;
  static const double spacingS = 8;
  static const double spacingM = 16;
  static const double spacingL = 24;
  static const double spacingXL = 32;
  static const double spacingXXL = 40;

  // =========================================================
  // RADIUS
  // =========================================================

  static const double radiusSmall = 12;
  static const double radiusMedium = 16;
  static const double radiusLarge = 24;
  static const double radiusXLarge = 28;
  static const double radiusPill = 999;

  // =========================================================
  // PAGE CONSTANTS
  // =========================================================

  static const double maxContentWidth = 1100;

  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(20, 16, 20, 110);

  static const EdgeInsets compactPagePadding = EdgeInsets.fromLTRB(
    16,
    12,
    16,
    24,
  );

  // =========================================================
  // SHADOWS
  // =========================================================

  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 30,
      offset: const Offset(0, 12),
    ),
  ];

  static List<BoxShadow> get primaryShadow => [
    BoxShadow(
      color: primaryColor.withValues(alpha: 0.18),
      blurRadius: 28,
      offset: const Offset(0, 12),
    ),
  ];

  // =========================================================
  // LIGHT THEME
  // =========================================================

  static ThemeData get lightTheme {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.light,
        ).copyWith(
          primary: primaryColor,
          onPrimary: Colors.white,

          secondary: secondaryColor,
          onSecondary: Colors.white,

          surface: surfaceColor,
          onSurface: textPrimary,

          surfaceContainerLowest: surfaceColor,

          surfaceContainerLow: Color(0xFFFBFCFE),

          surfaceContainer: surfaceSoft,

          surfaceContainerHigh: Color(0xFFEFF3F8),

          surfaceContainerHighest: Color(0xFFE8EEF5),

          error: dangerColor,
          onError: Colors.white,

          outline: borderStrong,
          outlineVariant: borderColor,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      colorScheme: colorScheme,

      scaffoldBackgroundColor: backgroundColor,

      canvasColor: backgroundColor,

      textTheme: GoogleFonts.interTextTheme(
        const TextTheme(
          displayLarge: TextStyle(
            color: textPrimary,
            fontSize: 48,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.6,
            height: 1.05,
          ),

          displayMedium: TextStyle(
            color: textPrimary,
            fontSize: 40,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.3,
            height: 1.08,
          ),

          headlineLarge: TextStyle(
            color: textPrimary,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
            height: 1.1,
          ),

          headlineMedium: TextStyle(
            color: textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            height: 1.15,
          ),

          headlineSmall: TextStyle(
            color: textPrimary,
            fontSize: 23,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            height: 1.2,
          ),

          titleLarge: TextStyle(
            color: textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),

          titleMedium: TextStyle(
            color: textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),

          titleSmall: TextStyle(
            color: textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),

          bodyLarge: TextStyle(color: textPrimary, fontSize: 16, height: 1.5),

          bodyMedium: TextStyle(
            color: textSecondary,
            fontSize: 14,
            height: 1.5,
          ),

          bodySmall: TextStyle(
            color: textSecondary,
            fontSize: 12,
            height: 1.45,
          ),

          labelLarge: TextStyle(
            color: textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),

          labelMedium: TextStyle(
            color: textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      visualDensity: VisualDensity.standard,

      splashFactory: InkSparkle.splashFactory,

      // =====================================================
      // APP BAR
      // =====================================================
      appBarTheme: const AppBarTheme(
        centerTitle: false,

        elevation: 0,
        scrolledUnderElevation: 0,

        backgroundColor: Colors.transparent,

        foregroundColor: textPrimary,

        surfaceTintColor: Colors.transparent,

        titleSpacing: 20,

        toolbarHeight: 64,

        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),

        iconTheme: IconThemeData(color: textPrimary, size: 24),

        actionsIconTheme: IconThemeData(color: textPrimary, size: 24),
      ),

      // =====================================================
      // INPUT
      // =====================================================
      inputDecorationTheme: InputDecorationTheme(
        filled: true,

        fillColor: surfaceColor,

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),

        hintStyle: const TextStyle(color: textMuted, fontSize: 15),

        labelStyle: const TextStyle(
          color: textSecondary,
          fontWeight: FontWeight.w600,
        ),

        prefixIconColor: textSecondary,

        suffixIconColor: textSecondary,

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: borderColor),
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: borderColor),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: primaryColor, width: 1.7),
        ),

        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: dangerColor),
        ),

        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: dangerColor, width: 1.7),
        ),
      ),

      // =====================================================
      // FILLED BUTTON
      // =====================================================
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,

          foregroundColor: Colors.white,

          disabledBackgroundColor: borderColor,

          disabledForegroundColor: textSecondary,

          minimumSize: const Size.fromHeight(54),

          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),

          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.1,
          ),

          elevation: 0,
        ),
      ),

      // =====================================================
      // OUTLINED BUTTON
      // =====================================================
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,

          minimumSize: const Size.fromHeight(52),

          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),

          side: const BorderSide(color: borderColor),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),

          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),

      // =====================================================
      // TEXT BUTTON
      // =====================================================
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,

          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),

          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),

      // =====================================================
      // ICON BUTTON
      // =====================================================
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: textPrimary,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
        ),
      ),

      // =====================================================
      // CARD
      // =====================================================
      cardTheme: CardThemeData(
        elevation: 0,

        color: surfaceColor,

        surfaceTintColor: Colors.transparent,

        margin: EdgeInsets.zero,

        clipBehavior: Clip.antiAlias,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),

          side: const BorderSide(color: borderColor),
        ),
      ),

      // =====================================================
      // NAVIGATION BAR
      // =====================================================
      navigationBarTheme: NavigationBarThemeData(
        height: 76,

        elevation: 0,

        backgroundColor: surfaceColor,

        surfaceTintColor: Colors.transparent,

        indicatorColor: surfaceMuted,

        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),

        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryColor, size: 24);
          }

          return const IconThemeData(color: textSecondary, size: 23);
        }),

        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);

          return TextStyle(
            fontSize: 11,
            color: selected ? primaryColor : textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
      ),

      // =====================================================
      // NAVIGATION RAIL
      // =====================================================
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surfaceColor,

        indicatorColor: surfaceMuted,

        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),

        selectedIconTheme: const IconThemeData(color: primaryColor, size: 25),

        unselectedIconTheme: const IconThemeData(
          color: textSecondary,
          size: 24,
        ),

        selectedLabelTextStyle: const TextStyle(
          color: primaryColor,
          fontWeight: FontWeight.w700,
        ),

        unselectedLabelTextStyle: const TextStyle(
          color: textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),

      // =====================================================
      // FAB
      // =====================================================
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,

        foregroundColor: Colors.white,

        elevation: 2,

        focusElevation: 3,

        hoverElevation: 4,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusMedium)),
        ),
      ),

      // =====================================================
      // CHIP
      // =====================================================
      chipTheme: ChipThemeData(
        backgroundColor: surfaceSoft,

        selectedColor: surfaceMuted,

        side: BorderSide.none,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),

        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          color: textPrimary,
          fontSize: 13,
        ),

        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      ),

      // =====================================================
      // SNACKBAR
      // =====================================================
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,

        backgroundColor: const Color(0xFF0F172A),

        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),

        insetPadding: const EdgeInsets.all(16),
      ),

      // =====================================================
      // DIVIDER
      // =====================================================
      dividerTheme: const DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 1,
      ),

      // =====================================================
      // DIALOG
      // =====================================================
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,

        surfaceTintColor: Colors.transparent,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXLarge),
        ),

        titleTextStyle: const TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),

        contentTextStyle: const TextStyle(
          color: textSecondary,
          fontSize: 15,
          height: 1.5,
        ),
      ),

      // =====================================================
      // BOTTOM SHEET
      // =====================================================
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceColor,

        surfaceTintColor: Colors.transparent,

        showDragHandle: true,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusXLarge),
          ),
        ),
      ),

      // =====================================================
      // PROGRESS
      // =====================================================
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryColor,

        linearTrackColor: borderColor,

        circularTrackColor: borderColor,
      ),

      // =====================================================
      // RADIO
      // =====================================================
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }

          return textSecondary;
        }),
      ),
    );
  }

  // =========================================================
  // DARK THEME
  // =========================================================

  static ThemeData get darkTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,

        brightness: Brightness.dark,
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme),

      scaffoldBackgroundColor: const Color(0xFF0B1120),

      colorScheme: base.colorScheme.copyWith(
        primary: const Color(0xFF60A5FA),

        secondary: const Color(0xFF38BDF8),

        surface: const Color(0xFF111827),

        onSurface: const Color(0xFFF8FAFC),

        outline: const Color(0xFF475569),

        outlineVariant: const Color(0xFF1E293B),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,

        foregroundColor: Color(0xFFF8FAFC),

        surfaceTintColor: Colors.transparent,

        elevation: 0,

        scrolledUnderElevation: 0,
      ),

      cardTheme: CardThemeData(
        elevation: 0,

        color: const Color(0xFF111827),

        surfaceTintColor: Colors.transparent,

        margin: EdgeInsets.zero,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),

          side: const BorderSide(color: Color(0xFF1E293B)),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 76,

        elevation: 0,

        backgroundColor: const Color(0xFF111827),

        indicatorColor: const Color(0xFF1E3A5F),
      ),
    );
  }
}
