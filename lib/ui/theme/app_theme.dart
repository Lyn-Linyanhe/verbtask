import 'package:flutter/material.dart';

/// VerbTask visual tokens: cool neutral canvas, indigo actions, and semantic status colors.
class AppColors {
  AppColors._();
  static const paper = Color(0xFFF6F7FB);
  static const surface = Color(0xFFFFFFFF);
  static const primary = Color(0xFF5367E8);
  static const primarySoft = Color(0xFFE9ECFF);
  static const accent = Color(0xFFC94A4A);
  static const text = Color(0xFF18202A);
  static const muted = Color(0xFF667085);
  static const done = Color(0xFF2E946B);
  static const line = Color(0xFFE3E7EF);

  static const darkPaper = Color(0xFF10131A);
  static const darkSurface = Color(0xFF191E28);
  static const darkPrimary = Color(0xFF8A96FF);
  static const darkPrimarySoft = Color(0xFF293052);
  static const darkAccent = Color(0xFFFF7E7E);
  static const darkText = Color(0xFFF1F3F7);
  static const darkMuted = Color(0xFFA2ABBB);
  static const darkDone = Color(0xFF68C69B);
  static const darkLine = Color(0xFF303846);
}

ThemeData buildAppTheme() => _theme(
    Brightness.light,
    AppColors.paper,
    AppColors.surface,
    AppColors.primary,
    AppColors.primarySoft,
    AppColors.text,
    AppColors.muted,
    AppColors.line,
    AppColors.done);

ThemeData buildDarkTheme() => _theme(
    Brightness.dark,
    AppColors.darkPaper,
    AppColors.darkSurface,
    AppColors.darkPrimary,
    AppColors.darkPrimarySoft,
    AppColors.darkText,
    AppColors.darkMuted,
    AppColors.darkLine,
    AppColors.darkDone);

ThemeData _theme(
    Brightness brightness,
    Color paper,
    Color surface,
    Color primary,
    Color primarySoft,
    Color text,
    Color muted,
    Color line,
    Color done) {
  final scheme =
      ColorScheme.fromSeed(seedColor: primary, brightness: brightness).copyWith(
    primary: primary,
    onPrimary:
        brightness == Brightness.dark ? const Color(0xFF101312) : Colors.white,
    surface: surface,
    onSurface: text,
    tertiary: done,
    onTertiary: Colors.white,
    error:
        brightness == Brightness.dark ? AppColors.darkAccent : AppColors.accent,
    surfaceContainerLowest: paper,
    surfaceContainerLow: paper,
    outline: line,
  );
  final base = ThemeData(
      useMaterial3: true, colorScheme: scheme, brightness: brightness);
  return base.copyWith(
    scaffoldBackgroundColor: paper,
    canvasColor: paper,
    appBarTheme: AppBarTheme(
      backgroundColor: paper,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
          color: text,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3),
      iconTheme: IconThemeData(color: text, size: 22),
      actionsIconTheme: IconThemeData(color: text, size: 22),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          side: BorderSide(color: line)),
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      hintStyle: TextStyle(color: muted),
      prefixIconColor: muted,
      suffixIconColor: muted,
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: line)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primary, width: 1.5)),
    ),
    dividerColor: line,
    dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
    listTileTheme:
        ListTileThemeData(iconColor: muted, contentPadding: EdgeInsets.zero),
    snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: text,
        contentTextStyle: const TextStyle(color: Colors.white)),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: brightness == Brightness.dark
            ? const Color(0xFF101312)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: line),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surface,
      textStyle: TextStyle(color: text),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}
