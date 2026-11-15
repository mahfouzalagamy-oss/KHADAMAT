import 'package:flutter/material.dart';

class AppColors {
  static const Color customerPrimary = Color(0xFF07162C);
  static const Color primaryNavy = Color(0xFF0D2342);
  static const Color syaanhOrange = Color(0xFFFF6B00);
  static const Color goldAccent = Color(0xFFEAB308);

  static const Color technicianPrimary = Color(0xFF0F3D68);
  static const Color companyPrimary = Color(0xFF0D5C63);
  static const Color adminPrimary = Color(0xFF6B1D1D);

  static const Color background = Color(0xFFF3F6FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF07162C);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
  static const Color success = Color(0xFF10B981);
  static const Color danger = Color(0xFFEF4444);

  static Color byRole(int roleIndex) {
    if (roleIndex == 1) return technicianPrimary;
    if (roleIndex == 2) return companyPrimary;
    if (roleIndex == 3) return adminPrimary;
    return customerPrimary;
  }
}

class AppTheme {
  static ThemeData build(int roleIndex) {
    final Color primary = AppColors.byRole(roleIndex);
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Cairo',
      fontFamilyFallback: const ['Segoe UI', 'Tahoma', 'Arial', 'sans-serif'],
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: AppColors.syaanhOrange,
        surface: AppColors.surface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.customerPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.syaanhOrange,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w900),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary.withAlpha(70), width: 1.4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.syaanhOrange, width: 2)),
      ),
    );
  }
}