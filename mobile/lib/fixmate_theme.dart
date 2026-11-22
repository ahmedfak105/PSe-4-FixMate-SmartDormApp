import 'package:flutter/material.dart';

/// FixMate visual system shared by the mobile and operations web clients.
/// Presentation only: authentication, RLS and RPC permissions are unchanged.
class FixMateTheme {
  static const ink = Color(0xFF18323F);
  static const teal = Color(0xFF127F76);
  static const mint = Color(0xFFDFF5ED);
  static const canvas = Color(0xFFEEF4F5);
  static const outline = Color(0xFFDBE8E8);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: teal,
      brightness: Brightness.light,
      surface: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ink, fontSize: 18, fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: teal,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Colors.white,
        indicatorColor: mint,
        selectedIconTheme: IconThemeData(color: teal),
        selectedLabelTextStyle: TextStyle(color: teal, fontWeight: FontWeight.w700),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(fontSize: 26, color: ink,
          fontWeight: FontWeight.w800, letterSpacing: -0.6),
        titleLarge: TextStyle(fontSize: 20, color: ink, fontWeight: FontWeight.w800),
        titleMedium: TextStyle(fontSize: 16, color: ink, fontWeight: FontWeight.w700),
        bodyMedium: TextStyle(fontSize: 14, color: ink),
      ),
    );
  }
}
