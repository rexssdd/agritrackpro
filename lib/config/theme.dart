import 'package:flutter/material.dart';

class AgriTheme {
  static const green = Color(0xFF166534);
  static ThemeData get light => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: green),
      scaffoldBackgroundColor: const Color(0xFFF6F8F5),
      appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF6F8F5), centerTitle: false),
      cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12)));
}
