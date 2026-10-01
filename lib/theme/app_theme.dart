// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

/// ثيم احترافي مبني على Material 3
/// - وضع داكن أنيق مع لمسة برتقالية/بنفسجية للهوية.
/// - وضع فاتح نظيف بخلفية بيضاء حقيقية وتباين مرتفع.
///
/// ملاحظة: تم الحفاظ على جميع الأسماء العامة والخاصة كما هي:
/// [primaryColor], [_primary], [_bgDark], [_surface], [_surfaceHigh],
/// [_bgLight], [_lightSurface], [dark], [light].
class AppTheme {
  // ===== الألوان الأساسية (الأسماء محفوظة كما هي) =====
  static const primaryColor = Color(0xFFFF9D2E);
  static const _primary = Color(0xFFFF9D2E);
  static const _bgDark = Color(0xFF000000);
  static const _surface = Color(0xFF1A1530);
  static const _surfaceHigh = Color(0xFF231C3F);
  static const _bgLight = Color(0xFFFFFFFF); // خلفية بيضاء حقيقية
  static const _lightSurface = Color(0xFFFFFFFF);

  // ===== ألوان مساعدة داخلية (للتنسيق فقط) =====
  static const _secondary = Color(0xFFEBAA07);
  static const _darkOutline = Color(0xFF2E2748);
  static const _darkOutlineVariant = Color(0xFF3A3255);
  static const _darkOnSurfaceVariant = Color(0xFFCFCADC);

  static const _lightOnSurface = Color(0xFF111111);
  static const _lightOnSurfaceVariant = Color(0xFF4A4A4A);
  static const _lightOutline = Color(0xFFE2E2E7);
  static const _lightOutlineVariant = Color(0xFFEDEDEF);
  static const _lightSurfaceVariant = Color(0xFFF5F5F7);
  static const _lightHint = Color(0xFF9AA0A6);
  static const _lightDisabled = Color(0xFFBDBDBD);

  static const _errorDark = Color(0xFFFF6B6B);
  static const _errorLight = Color(0xFFD32F2F);

  // ============================================================
  //                        DARK THEME
  // ============================================================
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);

    const colorScheme = ColorScheme.dark(
      brightness: Brightness.dark,
      primary: _primary,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFF3A2410),
      onPrimaryContainer: Color(0xFFFFD9BE),
      secondary: _secondary,
      onSecondary: Colors.black,
      secondaryContainer: Color(0xFF3A2C05),
      onSecondaryContainer: Color(0xFFFFE7A8),
      tertiary: Color(0xFFB39DDB),
      onTertiary: Colors.black,
      error: _errorDark,
      onError: Colors.white,
      surface: _surface,
      onSurface: Colors.white,
      onSurfaceVariant: _darkOnSurfaceVariant,
      surfaceContainerLowest: _bgDark,
      surfaceContainerLow: Color(0xFF15112A),
      surfaceContainer: _surface,
      surfaceContainerHigh: _surfaceHigh,
      surfaceContainerHighest: Color(0xFF2A2249),
      outline: _darkOutline,
      outlineVariant: _darkOutlineVariant,
      inverseSurface: Colors.white,
      onInverseSurface: _bgDark,
      inversePrimary: Color(0xFFFFB98A),
      scrim: Colors.black54,
      shadow: Colors.black,
    );

    final textTheme = _buildTextTheme(base.textTheme, Colors.white);

    return base.copyWith(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: _primary,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _bgDark,
      canvasColor: _bgDark,
      dividerColor: _darkOutlineVariant,
      splashFactory: InkRipple.splashFactory,
      highlightColor: Colors.white10,
      hoverColor: Colors.white10,
      focusColor: Colors.white12,

      // ---------------- Text ----------------
      textTheme: textTheme,
      primaryTextTheme: textTheme,

      // ---------------- AppBar ----------------
      appBarTheme: const AppBarTheme(
        backgroundColor: _bgDark,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
        actionsIconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),

      // ---------------- Card ----------------
      cardTheme: const CardThemeData(
        color: _surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black45,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          side: BorderSide(color: _darkOutline, width: 0.6),
        ),
      ),

      // ---------------- TabBar ----------------
      tabBarTheme: const TabBarThemeData(
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle:
            TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        indicatorColor: _primary,
        dividerColor: Colors.transparent,
        overlayColor: WidgetStatePropertyAll(Colors.white10),
      ),

      // ---------------- Bottom Navigation ----------------
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _surface,
        selectedItemColor: _primary,
        unselectedItemColor: Colors.white54,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle:
            TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle:
            TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
      ),

      // ---------------- Navigation Bar (M3) ----------------
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: _primary.withValues(alpha: 0.18),
        height: 68,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: _primary, size: 26);
          }
          return const IconThemeData(color: Colors.white54, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: _primary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            );
          }
          return const TextStyle(
            color: Colors.white54,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          );
        }),
      ),

      // ---------------- Dialog ----------------
      dialogTheme: const DialogThemeData(
        backgroundColor: _surfaceHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(
          color: Colors.white70,
          fontSize: 14,
          height: 1.5,
        ),
      ),

      // ---------------- BottomSheet ----------------
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: _surface,
        modalBarrierColor: Colors.black54,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: Colors.white24,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),

      // ---------------- PopupMenu ----------------
      popupMenuTheme: const PopupMenuThemeData(
        color: _surfaceHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        textStyle: TextStyle(color: Colors.white, fontSize: 14),
      ),

      // ---------------- Menu ----------------
      menuTheme: const MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(_surfaceHigh),
          surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
          elevation: WidgetStatePropertyAll(4),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
      ),

      // ---------------- Divider ----------------
      dividerTheme: const DividerThemeData(
        color: _darkOutlineVariant,
        thickness: 0.6,
        space: 1,
      ),

      // ---------------- ListTile ----------------
      listTileTheme: const ListTileThemeData(
        iconColor: Colors.white70,
        textColor: Colors.white,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: TextStyle(
          color: Colors.white70,
          fontSize: 13,
        ),
        selectedColor: _primary,
        selectedTileColor: Color(0x22EB7303),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),

      // ---------------- InputDecoration ----------------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surface,
        hintStyle: const TextStyle(color: Colors.white54),
        labelStyle: const TextStyle(color: Colors.white70),
        floatingLabelStyle: const TextStyle(color: _primary),
        prefixIconColor: Colors.white70,
        suffixIconColor: Colors.white70,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _darkOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _darkOutline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _errorDark),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _errorDark, width: 1.4),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _darkOutlineVariant),
        ),
      ),

      // ---------------- FloatingActionButton ----------------
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 4,
        focusElevation: 6,
        hoverElevation: 6,
        highlightElevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),

      // ---------------- SnackBar ----------------
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _surfaceHigh,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        actionTextColor: _primary,
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // ---------------- ProgressIndicator ----------------
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: _primary,
        linearTrackColor: Colors.white12,
        circularTrackColor: Colors.white12,
      ),

      // ---------------- Slider ----------------
      sliderTheme: const SliderThemeData(
        activeTrackColor: _primary,
        inactiveTrackColor: Colors.white24,
        thumbColor: _primary,
        overlayColor: Color(0x33EB7303),
        valueIndicatorColor: _primary,
        valueIndicatorTextStyle:
            TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        trackHeight: 3,
      ),

      // ---------------- Switch ----------------
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _primary;
          return Colors.white70;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _primary.withValues(alpha: 0.4);
          }
          return Colors.white24;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),

      // ---------------- Checkbox ----------------
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _primary;
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: const BorderSide(color: Colors.white54, width: 1.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),

      // ---------------- Radio ----------------
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _primary;
          return Colors.white54;
        }),
      ),

      // ---------------- Chip ----------------
      chipTheme: ChipThemeData(
        backgroundColor: _surface,
        selectedColor: _primary,
        secondarySelectedColor: _primary,
        disabledColor: Colors.white12,
        labelStyle: const TextStyle(color: Colors.white, fontSize: 13),
        secondaryLabelStyle: const TextStyle(color: Colors.white, fontSize: 13),
        side: const BorderSide(color: _darkOutline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        iconTheme: const IconThemeData(color: Colors.white70, size: 18),
        checkmarkColor: Colors.white,
        showCheckmark: true,
        brightness: Brightness.dark,
      ),

      // ---------------- Scrollbar ----------------
      scrollbarTheme: const ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(Color(0x66FFFFFF)),
        trackColor: WidgetStatePropertyAll(Colors.transparent),
        radius: Radius.circular(8),
        thickness: WidgetStatePropertyAll(4),
        thumbVisibility: WidgetStatePropertyAll(false),
      ),

      // ---------------- Tooltip ----------------
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: _surfaceHigh,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _darkOutline),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),

      // ---------------- Icon ----------------
      iconTheme: const IconThemeData(color: Colors.white),
      primaryIconTheme: const IconThemeData(color: Colors.white),
    );
  }

  // ============================================================
  //                        LIGHT THEME
  // ============================================================
  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);

    const colorScheme = ColorScheme.light(
      brightness: Brightness.light,
      primary: _primary,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFFFE1CC),
      onPrimaryContainer: Color(0xFF3A1A00),
      secondary: _secondary,
      onSecondary: Colors.black,
      secondaryContainer: Color(0xFFFFF3CC),
      onSecondaryContainer: Color(0xFF3A2C00),
      tertiary: Color(0xFF6750A4),
      onTertiary: Colors.white,
      error: _errorLight,
      onError: Colors.white,
      surface: _lightSurface,
      onSurface: _lightOnSurface,
      onSurfaceVariant: _lightOnSurfaceVariant,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Color(0xFFFAFAFB),
      surfaceContainer: Color(0xFFF7F7F9),
      surfaceContainerHigh: _lightSurfaceVariant,
      surfaceContainerHighest: Color(0xFFEFEFF2),
      outline: _lightOutline,
      outlineVariant: _lightOutlineVariant,
      inverseSurface: Color(0xFF1B1B1F),
      onInverseSurface: Colors.white,
      inversePrimary: Color(0xFFFFB98A),
      scrim: Colors.black54,
      shadow: Colors.black26,
    );

    final textTheme = _buildTextTheme(base.textTheme, _lightOnSurface);

    return base.copyWith(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: _primary,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _bgLight, // أبيض حقيقي
      canvasColor: _bgLight,
      dividerColor: _lightOutlineVariant,
      splashFactory: InkRipple.splashFactory,
      highlightColor: Colors.black.withValues(alpha: 0.04),
      hoverColor: Colors.black.withValues(alpha: 0.04),
      focusColor: Colors.black.withValues(alpha: 0.06),

      // ---------------- Text ----------------
      textTheme: textTheme,
      primaryTextTheme: textTheme,

      // ---------------- AppBar ----------------
      appBarTheme: const AppBarTheme(
        backgroundColor: _bgLight,
        foregroundColor: _lightOnSurface,
        surfaceTintColor: Colors.transparent, // إزالة Surface Tint
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: _lightOnSurface),
        actionsIconTheme: IconThemeData(color: _lightOnSurface),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: _lightOnSurface,
        ),
      ),

      // ---------------- Card ----------------
      cardTheme: CardThemeData(
        color: _lightSurface,
        surfaceTintColor: Colors.transparent, // إزالة Surface Tint
        shadowColor: Colors.black.withValues(alpha: 0.06),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _lightOutline, width: 0.8),
        ),
      ),

      // ---------------- TabBar ----------------
      tabBarTheme: const TabBarThemeData(
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle:
            TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        labelColor: _primary,
        unselectedLabelColor: Color(0xFFA5A4A4),
        indicatorColor: _primary,
        dividerColor: Colors.transparent,
        overlayColor: WidgetStatePropertyAll(Color(0x11EB7303)),
      ),

      // ---------------- Bottom Navigation ----------------
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _lightSurface,
        selectedItemColor: _primary,
        unselectedItemColor: Color(0xFF777777),
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle:
            TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle:
            TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
      ),

      // ---------------- Navigation Bar (M3) ----------------
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _lightSurface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: _primary.withValues(alpha: 0.14),
        height: 68,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: _primary, size: 26);
          }
          return const IconThemeData(color: Color(0xFF777777), size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: _primary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            );
          }
          return const TextStyle(
            color: Color(0xFF777777),
            fontWeight: FontWeight.w500,
            fontSize: 12,
          );
        }),
      ),

      // ---------------- Dialog ----------------
      dialogTheme: const DialogThemeData(
        backgroundColor: _lightSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        titleTextStyle: TextStyle(
          color: _lightOnSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(
          color: _lightOnSurfaceVariant,
          fontSize: 14,
          height: 1.5,
        ),
      ),

      // ---------------- BottomSheet ----------------
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _lightSurface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: _lightSurface,
        modalBarrierColor: Colors.black45,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: Color(0xFFDDDDDD),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),

      // ---------------- PopupMenu ----------------
      popupMenuTheme: const PopupMenuThemeData(
        color: _lightSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        textStyle: TextStyle(color: _lightOnSurface, fontSize: 14),
      ),

      // ---------------- Menu ----------------
      menuTheme: const MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(_lightSurface),
          surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
          elevation: WidgetStatePropertyAll(4),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
      ),

      // ---------------- Divider ----------------
      dividerTheme: const DividerThemeData(
        color: _lightOutlineVariant,
        thickness: 0.8,
        space: 1,
      ),

      // ---------------- ListTile ----------------
      listTileTheme: const ListTileThemeData(
        iconColor: _lightOnSurfaceVariant,
        textColor: _lightOnSurface,
        titleTextStyle: TextStyle(
          color: _lightOnSurface,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: TextStyle(
          color: _lightOnSurfaceVariant,
          fontSize: 13,
        ),
        selectedColor: _primary,
        selectedTileColor: Color(0x14EB7303),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),

      // ---------------- InputDecoration ----------------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightSurfaceVariant,
        hintStyle: const TextStyle(color: _lightHint),
        labelStyle: const TextStyle(color: _lightOnSurfaceVariant),
        floatingLabelStyle: const TextStyle(color: _primary),
        prefixIconColor: _lightOnSurfaceVariant,
        suffixIconColor: _lightOnSurfaceVariant,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _lightOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _lightOutline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _errorLight),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _errorLight, width: 1.4),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _lightOutlineVariant),
        ),
      ),

      // ---------------- FloatingActionButton ----------------
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 3,
        focusElevation: 5,
        hoverElevation: 5,
        highlightElevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // ---------------- SnackBar ----------------
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1B1B1F),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        actionTextColor: _secondary,
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // ---------------- ProgressIndicator ----------------
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: _primary,
        linearTrackColor: Color(0xFFEDEDEF),
        circularTrackColor: Color(0xFFEDEDEF),
      ),

      // ---------------- Slider ----------------
      sliderTheme: const SliderThemeData(
        activeTrackColor: _primary,
        inactiveTrackColor: Color(0xFFDDDDDD),
        thumbColor: _primary,
        overlayColor: Color(0x22EB7303),
        valueIndicatorColor: _primary,
        valueIndicatorTextStyle:
            TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        trackHeight: 3,
      ),

      // ---------------- Switch ----------------
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _primary;
          if (states.contains(WidgetState.disabled)) return _lightDisabled;
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _primary.withValues(alpha: 0.4);
          }
          return const Color(0xFFDDDDDD);
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),

      // ---------------- Checkbox ----------------
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _primary;
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: const BorderSide(color: Color(0xFFBDBDBD), width: 1.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),

      // ---------------- Radio ----------------
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _primary;
          return const Color(0xFFBDBDBD);
        }),
      ),

      // ---------------- Chip ----------------
      chipTheme: ChipThemeData(
        backgroundColor: _lightSurfaceVariant,
        selectedColor: _primary,
        secondarySelectedColor: _primary,
        disabledColor: const Color(0xFFEDEDEF),
        labelStyle: const TextStyle(color: _lightOnSurface, fontSize: 13),
        secondaryLabelStyle: const TextStyle(color: Colors.white, fontSize: 13),
        side: const BorderSide(color: _lightOutline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        iconTheme: const IconThemeData(color: _lightOnSurfaceVariant, size: 18),
        checkmarkColor: Colors.white,
        showCheckmark: true,
        brightness: Brightness.light,
      ),

      // ---------------- Scrollbar ----------------
      scrollbarTheme: const ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(Color(0x55000000)),
        trackColor: WidgetStatePropertyAll(Colors.transparent),
        radius: Radius.circular(8),
        thickness: WidgetStatePropertyAll(4),
        thumbVisibility: WidgetStatePropertyAll(false),
      ),

      // ---------------- Tooltip ----------------
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B1F),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),

      // ---------------- Icon ----------------
      iconTheme: const IconThemeData(color: _lightOnSurface),
      primaryIconTheme: const IconThemeData(color: _lightOnSurface),
    );
  }

  // ============================================================
  //                     TEXT THEME BUILDER
  // ============================================================
  static TextTheme _buildTextTheme(TextTheme base, Color color) {
    return base
        .copyWith(
          displayLarge: base.displayLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
          displayMedium: base.displayMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
          displaySmall: base.displaySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
          headlineLarge: base.headlineLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
          headlineMedium: base.headlineMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
          headlineSmall: base.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
          titleLarge: base.titleLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
          titleMedium: base.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          titleSmall: base.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          bodyLarge: base.bodyLarge?.copyWith(
            color: color,
            fontSize: 15,
            height: 1.45,
          ),
          bodyMedium: base.bodyMedium?.copyWith(
            color: color,
            fontSize: 14,
            height: 1.45,
          ),
          bodySmall: base.bodySmall?.copyWith(
            color: color.withValues(alpha: 0.75),
            fontSize: 12,
            height: 1.4,
          ),
          labelLarge: base.labelLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          labelMedium: base.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          labelSmall: base.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
        )
        .apply(
          bodyColor: color,
          displayColor: color,
        );
  }
}
