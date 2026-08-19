import 'package:flutter/material.dart';

/// VerbTask 视觉 token —— 暖纸底 + 深青主色 + 卡片化层次。
/// 签名元素：任务行左侧的状态色条 + 紧凑的截止时间 pill。
class AppColors {
  AppColors._();
  static const paper = Color(0xFFF6F4EF); // 暖纸背景
  static const surface = Color(0xFFFFFFFF); // 卡片/输入
  static const primary = Color(0xFF0D6E6E); // 深青
  static const primarySoft = Color(0xFFCDE9E4); // 青色调浅
  static const accent = Color(0xFFE2743B); // 强调（紧急/截止近）
  static const text = Color(0xFF1F2937);
  static const muted = Color(0xFF6B7280);
  static const done = Color(0xFF3B7F5E);
  static const line = Color(0xFFE7E2D8); // 描边
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    outline: AppColors.line,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme);

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.paper,
    canvasColor: AppColors.paper,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.paper,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: const TextStyle(
        color: AppColors.text,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      iconTheme: const IconThemeData(color: AppColors.text, size: 22),
      actionsIconTheme: const IconThemeData(color: AppColors.text, size: 22),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: AppColors.muted),
      prefixIconColor: AppColors.muted,
      suffixIconColor: AppColors.muted,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    ),
    dividerColor: AppColors.line,
    listTileTheme: const ListTileThemeData(iconColor: AppColors.muted),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.text,
      contentTextStyle: const TextStyle(color: Colors.white),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}
