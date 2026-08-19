import 'package:flutter/material.dart';

/// VerbTask 视觉 token —— 暖纸底 + 深青主色 + 卡片化层次（含深色模式）。
class AppColors {
  AppColors._();
  static const paper = Color(0xFFF6F4EF);
  static const surface = Color(0xFFFFFFFF);
  static const primary = Color(0xFF0D6E6E);
  static const primarySoft = Color(0xFFCDE9E4);
  static const accent = Color(0xFFE2743B);
  static const text = Color(0xFF1F2937);
  static const muted = Color(0xFF6B7280);
  static const done = Color(0xFF3B7F5E);
  static const line = Color(0xFFE7E2D8);

  // 深色
  static const darkPaper = Color(0xFF16140F);
  static const darkSurface = Color(0xFF211E18);
  static const darkPrimary = Color(0xFF6FD0C6);
  static const darkPrimarySoft = Color(0xFF1F3B37);
  static const darkAccent = Color(0xFFF09A6C);
  static const darkText = Color(0xFFF1EFE9);
  static const darkMuted = Color(0xFFA9A295);
  static const darkDone = Color(0xFF7FC49B);
  static const darkLine = Color(0xFF3A362E);
}

ThemeData buildAppTheme() => _theme(Brightness.light, AppColors.paper, AppColors.surface, AppColors.primary, AppColors.primarySoft, AppColors.text, AppColors.muted, AppColors.line, AppColors.done);

ThemeData buildDarkTheme() => _theme(Brightness.dark, AppColors.darkPaper, AppColors.darkSurface, AppColors.darkPrimary, AppColors.darkPrimarySoft, AppColors.darkText, AppColors.darkMuted, AppColors.darkLine, AppColors.darkDone);

ThemeData _theme(Brightness brightness, Color paper, Color surface, Color primary, Color primarySoft, Color text, Color muted, Color line, Color done) {
  final scheme = ColorScheme.fromSeed(seedColor: primary, brightness: brightness).copyWith(
    primary: primary,
    onPrimary: brightness == Brightness.dark ? const Color(0xFF101312) : Colors.white,
    surface: surface,
    onSurface: text,
    outline: line,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness);
  return base.copyWith(
    scaffoldBackgroundColor: paper,
    canvasColor: paper,
    appBarTheme: AppBarTheme(
      backgroundColor: paper,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(color: text, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3),
      iconTheme: IconThemeData(color: text, size: 22),
      actionsIconTheme: IconThemeData(color: text, size: 22),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(color: muted),
      prefixIconColor: muted,
      suffixIconColor: muted,
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: primary, width: 1.5)),
    ),
    dividerColor: line,
    listTileTheme: ListTileThemeData(iconColor: muted),
    snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: text, contentTextStyle: const TextStyle(color: Colors.white)),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: brightness == Brightness.dark ? const Color(0xFF101312) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(foregroundColor: primary, side: BorderSide(color: line), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surface,
      textStyle: TextStyle(color: text),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
