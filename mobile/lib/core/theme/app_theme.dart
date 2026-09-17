import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // Brand: near-black + electric violet.
  static const Color primaryColor = Color(0xFF8B5CF6);
  static const Color primaryDark = Color(0xFF6D28D9);
  static const Color secondaryColor = Color(0xFFC084FC);
  static const Color accentColor = Color(0xFFA78BFA);

  // Kept for compatibility with existing screens. The app is dark-first.
  static const Color backgroundColor = Color(0xFF08070B);
  static const Color surfaceColor = Color(0xFF111014);
  static const Color surfaceSoft = Color(0xFF18161D);
  static const Color surfaceMuted = Color(0xFF211B2B);
  static const Color textPrimary = Color(0xFFF7F4FB);
  static const Color textSecondary = Color(0xFFB9B1C5);
  static const Color textMuted = Color(0xFF81798D);
  static const Color borderColor = Color(0xFF2A2631);
  static const Color borderStrong = Color(0xFF3B3447);

  static const Color successColor = Color(0xFF34D399);
  static const Color successSoft = Color(0xFF102A22);
  static const Color warningColor = Color(0xFFFBBF24);
  static const Color warningSoft = Color(0xFF30240B);
  static const Color dangerColor = Color(0xFFFB7185);
  static const Color dangerSoft = Color(0xFF35151B);
  static const Color infoColor = Color(0xFFA78BFA);
  static const Color infoSoft = Color(0xFF241B36);

  static const Color severityNone = Color(0xFF34D399);
  static const Color severityMinor = Color(0xFFFBBF24);
  static const Color severityModerate = Color(0xFFFB923C);
  static const Color severitySevere = Color(0xFFFB7185);
  static const Color severityUnknown = Color(0xFF9CA3AF);

  static const double spacingXS = 4;
  static const double spacingS = 8;
  static const double spacingM = 16;
  static const double spacingL = 24;
  static const double spacingXL = 32;
  static const double spacingXXL = 40;

  static const double radiusSmall = 12;
  static const double radiusMedium = 16;
  static const double radiusLarge = 24;
  static const double radiusXLarge = 28;
  static const double radiusPill = 999;

  static const double maxContentWidth = 1100;
  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(20, 16, 20, 110);
  static const EdgeInsets compactPagePadding = EdgeInsets.fromLTRB(
    16,
    12,
    16,
    24,
  );

  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6), Color(0xFFC084FC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient deepBrandGradient = LinearGradient(
    colors: [Color(0xFF171021), Color(0xFF291448), Color(0xFF6D28D9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.34),
      blurRadius: 28,
      offset: const Offset(0, 12),
    ),
    BoxShadow(
      color: primaryColor.withValues(alpha: 0.045),
      blurRadius: 24,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.48),
      blurRadius: 42,
      offset: const Offset(0, 18),
    ),
    BoxShadow(
      color: primaryColor.withValues(alpha: 0.08),
      blurRadius: 34,
      offset: const Offset(0, 12),
    ),
  ];

  static List<BoxShadow> get primaryShadow => [
    BoxShadow(
      color: primaryColor.withValues(alpha: 0.28),
      blurRadius: 34,
      offset: const Offset(0, 14),
    ),
  ];

  static Color successSoftFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? successSoft
      : const Color(0xFFDDF8EC);

  static Color successColorFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? successColor
      : const Color(0xFF087A55);

  static Color warningSoftFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? warningSoft
      : const Color(0xFFFFF1C7);

  static Color warningColorFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? warningColor
      : const Color(0xFF8A5A00);

  static Color dangerSoftFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? dangerSoft
      : const Color(0xFFFFE1E6);

  static Color dangerColorFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? dangerColor
      : const Color(0xFFBE123C);

  static Color infoSoftFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? infoSoft
      : const Color(0xFFF0E7FF);

  static Color infoColorFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? infoColor : primaryDark;

  static Color moderateSoftFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF33200F)
      : const Color(0xFFFFE8D2);

  static Color moderateColorFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? severityModerate
      : const Color(0xFFB54708);

  static Color neutralSoftFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF24202B)
      : Theme.of(context).colorScheme.surfaceContainerHighest;

  static Color neutralColorFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? severityUnknown
      : const Color(0xFF59616D);

  static List<BoxShadow> softShadowFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? softShadow
      : [
          BoxShadow(
            color: const Color(0xFF3D284D).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ];

  static List<BoxShadow> elevatedShadowFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? elevatedShadow
      : [
          BoxShadow(
            color: const Color(0xFF3D284D).withValues(alpha: 0.13),
            blurRadius: 34,
            offset: const Offset(0, 15),
          ),
        ];

  static List<BoxShadow> primaryShadowFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? primaryShadow
      : [
          BoxShadow(
            color: primaryDark.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ];

  static ThemeData get lightTheme => _buildLightTheme();
  static ThemeData get darkTheme => _buildDarkTheme();

  static const PageTransitionsTheme _pageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: _SmoothPageTransitionsBuilder(),
      TargetPlatform.iOS: _SmoothPageTransitionsBuilder(),
      TargetPlatform.windows: _SmoothPageTransitionsBuilder(),
      TargetPlatform.macOS: _SmoothPageTransitionsBuilder(),
      TargetPlatform.linux: _SmoothPageTransitionsBuilder(),
    },
  );

  static TextTheme _customizeTextTheme(
    TextTheme base,
    Color primaryText,
    Color secondaryText,
  ) => base.copyWith(
    displayLarge: base.displayLarge?.copyWith(
      fontWeight: FontWeight.w900,
      letterSpacing: -1.6,
      height: 1.04,
    ),
    displayMedium: base.displayMedium?.copyWith(
      fontWeight: FontWeight.w900,
      letterSpacing: -1.2,
      height: 1.06,
    ),
    headlineLarge: base.headlineLarge?.copyWith(
      fontWeight: FontWeight.w900,
      letterSpacing: -0.9,
    ),
    headlineMedium: base.headlineMedium?.copyWith(
      fontWeight: FontWeight.w900,
      letterSpacing: -0.7,
    ),
    headlineSmall: base.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.45,
    ),
    titleLarge: base.titleLarge?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
    ),
    titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    bodyLarge: base.bodyLarge?.copyWith(color: primaryText, height: 1.5),
    bodyMedium: base.bodyMedium?.copyWith(color: secondaryText, height: 1.5),
    bodySmall: base.bodySmall?.copyWith(color: secondaryText, height: 1.45),
    labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w800),
    labelMedium: base.labelMedium?.copyWith(
      color: secondaryText,
      fontWeight: FontWeight.w700,
    ),
  );

  static ThemeData _buildLightTheme() {
    const background = Color(0xFFF8F6FB);
    const surface = Color(0xFFFFFFFF);
    const surfaceLow = Color(0xFFF4F0F8);
    const surfaceContainer = Color(0xFFF0EBF5);
    const surfaceHigh = Color(0xFFEAE3F0);
    const surfaceHighest = Color(0xFFE2D9E9);
    const foreground = Color(0xFF211A29);
    const foregroundMuted = Color(0xFF655C6F);
    const outline = Color(0xFF7B7185);
    const outlineVariant = Color(0xFFD9D0E1);

    final scheme = const ColorScheme.light().copyWith(
      primary: primaryDark,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFEBDDFF),
      onPrimaryContainer: const Color(0xFF32105A),
      secondary: const Color(0xFF7C3AED),
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFF0E4FF),
      onSecondaryContainer: const Color(0xFF32104F),
      tertiary: const Color(0xFF7253B7),
      onTertiary: Colors.white,
      surface: surface,
      onSurface: foreground,
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: surfaceLow,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceHigh,
      surfaceContainerHighest: surfaceHighest,
      onSurfaceVariant: foregroundMuted,
      error: const Color(0xFFBA1A1A),
      onError: Colors.white,
      errorContainer: const Color(0xFFFFDAD6),
      onErrorContainer: const Color(0xFF410002),
      outline: outline,
      outlineVariant: outlineVariant,
      shadow: const Color(0xFF211A29),
      scrim: Colors.black,
    );

    final baseTextTheme = GoogleFonts.interTextTheme(
      ThemeData.light(useMaterial3: true).textTheme,
    ).apply(bodyColor: foreground, displayColor: foreground);
    final textTheme = _customizeTextTheme(
      baseTextTheme,
      foreground,
      foregroundMuted,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      textTheme: textTheme,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: _pageTransitions,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: foreground,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        toolbarHeight: 64,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: foreground,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
        iconTheme: const IconThemeData(color: foreground, size: 24),
        actionsIconTheme: const IconThemeData(color: foreground, size: 24),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFCFAFD),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        hintStyle: const TextStyle(color: Color(0xFF81778B), fontSize: 15),
        labelStyle: const TextStyle(
          color: foregroundMuted,
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: const Color(0xFF766685),
        suffixIconColor: const Color(0xFF766685),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: primaryDark, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryDark,
          foregroundColor: Colors.white,
          disabledBackgroundColor: surfaceHighest,
          disabledForegroundColor: foregroundMuted,
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
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: foreground,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          side: const BorderSide(color: outlineVariant),
          backgroundColor: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryDark,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: foreground,
          highlightColor: primaryColor.withValues(alpha: 0.10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: const BorderSide(color: outlineVariant),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: outlineVariant,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        elevation: 0,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0xFFEBDDFF),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? primaryDark
                : foregroundMuted,
            size: states.contains(WidgetState.selected) ? 25 : 23,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            color: states.contains(WidgetState.selected)
                ? primaryDark
                : foregroundMuted,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: const Color(0xFFEBDDFF),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        selectedIconTheme: const IconThemeData(color: primaryDark, size: 25),
        unselectedIconTheme: const IconThemeData(
          color: foregroundMuted,
          size: 24,
        ),
        selectedLabelTextStyle: const TextStyle(
          color: primaryDark,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: foregroundMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        elevation: 4,
        focusElevation: 5,
        hoverElevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusMedium)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceLow,
        selectedColor: const Color(0xFFEBDDFF),
        side: const BorderSide(color: outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          color: foreground,
          fontSize: 13,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2B2432),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        elevation: 8,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 14,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: const BorderSide(color: outlineVariant),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: outline,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusXLarge),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: const BorderSide(color: outlineVariant),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryDark,
        linearTrackColor: outlineVariant,
        circularTrackColor: outlineVariant,
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primaryDark
              : foregroundMuted,
        ),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primaryColor
              : surfaceHighest,
        ),
      ),
    );
  }

  static ThemeData _buildDarkTheme() {
    final scheme = const ColorScheme.dark().copyWith(
      primary: primaryColor,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFF2B1A46),
      onPrimaryContainer: const Color(0xFFE9D5FF),
      secondary: secondaryColor,
      onSecondary: const Color(0xFF180B22),
      secondaryContainer: const Color(0xFF291A35),
      onSecondaryContainer: const Color(0xFFF3E8FF),
      tertiary: accentColor,
      onTertiary: const Color(0xFF150A20),
      surface: surfaceColor,
      onSurface: textPrimary,
      surfaceContainerLowest: const Color(0xFF08070B),
      surfaceContainerLow: const Color(0xFF0E0D11),
      surfaceContainer: const Color(0xFF151319),
      surfaceContainerHigh: const Color(0xFF1B1820),
      surfaceContainerHighest: const Color(0xFF24202B),
      onSurfaceVariant: textSecondary,
      error: dangerColor,
      onError: const Color(0xFF260A10),
      errorContainer: dangerSoft,
      onErrorContainer: const Color(0xFFFFD9DF),
      outline: borderStrong,
      outlineVariant: borderColor,
      shadow: Colors.black,
      scrim: Colors.black,
    );

    final baseTextTheme = GoogleFonts.interTextTheme(
      ThemeData.dark(useMaterial3: true).textTheme,
    ).apply(bodyColor: textPrimary, displayColor: textPrimary);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: backgroundColor,
      canvasColor: backgroundColor,
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: -1.6,
          height: 1.04,
        ),
        displayMedium: baseTextTheme.displayMedium?.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: -1.2,
          height: 1.06,
        ),
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: -0.9,
        ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: -0.7,
        ),
        headlineSmall: baseTextTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.45,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        titleSmall: baseTextTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          color: textPrimary,
          height: 1.5,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          color: textSecondary,
          height: 1.5,
        ),
        bodySmall: baseTextTheme.bodySmall?.copyWith(
          color: textSecondary,
          height: 1.45,
        ),
        labelLarge: baseTextTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        labelMedium: baseTextTheme.labelMedium?.copyWith(
          color: textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _SmoothPageTransitionsBuilder(),
          TargetPlatform.iOS: _SmoothPageTransitionsBuilder(),
          TargetPlatform.windows: _SmoothPageTransitionsBuilder(),
          TargetPlatform.macOS: _SmoothPageTransitionsBuilder(),
          TargetPlatform.linux: _SmoothPageTransitionsBuilder(),
        },
      ),
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
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0E0D11),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        hintStyle: const TextStyle(color: textMuted, fontSize: 15),
        labelStyle: const TextStyle(
          color: textSecondary,
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: const Color(0xFF9F8FB2),
        suffixIconColor: const Color(0xFF9F8FB2),
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
          borderSide: const BorderSide(color: primaryColor, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: dangerColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: dangerColor, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF27232D),
          disabledForegroundColor: textMuted,
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
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          side: const BorderSide(color: borderStrong),
          backgroundColor: const Color(0xFF100E13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: secondaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: textPrimary,
          highlightColor: primaryColor.withValues(alpha: 0.12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
        ),
      ),
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
      dividerTheme: const DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        elevation: 0,
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0xFF2C1B46),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? secondaryColor
                : textSecondary,
            size: states.contains(WidgetState.selected) ? 25 : 23,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            color: states.contains(WidgetState.selected)
                ? secondaryColor
                : textSecondary,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surfaceColor,
        indicatorColor: const Color(0xFF2C1B46),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        selectedIconTheme: const IconThemeData(color: secondaryColor, size: 25),
        unselectedIconTheme: const IconThemeData(
          color: textSecondary,
          size: 24,
        ),
        selectedLabelTextStyle: const TextStyle(
          color: secondaryColor,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        focusElevation: 5,
        hoverElevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusMedium)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceSoft,
        selectedColor: const Color(0xFF2C1B46),
        side: const BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          color: textPrimary,
          fontSize: 13,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1B1720),
        contentTextStyle: const TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        elevation: 10,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF151319),
        surfaceTintColor: Colors.transparent,
        elevation: 18,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: const BorderSide(color: borderColor),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF151319),
        modalBackgroundColor: Color(0xFF151319),
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: Color(0xFF665B72),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusXLarge),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: const Color(0xFF17141B),
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: const BorderSide(color: borderColor),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: secondaryColor,
        linearTrackColor: borderColor,
        circularTrackColor: borderColor,
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? secondaryColor
              : textSecondary,
        ),
      ),
    );
  }
}

class _SmoothPageTransitionsBuilder extends PageTransitionsBuilder {
  const _SmoothPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.025, 0.018),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
