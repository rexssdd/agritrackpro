import 'package:flutter/material.dart';

class AgriTheme {
  static const green = Color(0xFF00672E);
  static const darkGreen = Color(0xFF064524);
  static const paleGreen = Color(0xFFEAF7EA);
  static const ink = Color(0xFF17251C);
  static ThemeData get light => ThemeData(
      useMaterial3: true,
      colorScheme:
          ColorScheme.fromSeed(seedColor: green, surface: Colors.white),
      scaffoldBackgroundColor: const Color(0xFFF5F8F5),
      appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F8F5),
          foregroundColor: ink,
          elevation: 0,
          centerTitle: false),
      cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 5),
          shape: RoundedRectangleBorder(
              side: const BorderSide(color: Color(0xFFE3ECE4)),
              borderRadius: BorderRadius.circular(20))),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              minimumSize: const Size(0, 50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)))),
      navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          elevation: 4,
          indicatorColor: paleGreen,
          labelTextStyle: WidgetStateProperty.all(
              const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
      textTheme: const TextTheme(
          headlineSmall: TextStyle(fontWeight: FontWeight.w800, color: ink),
          titleLarge: TextStyle(fontWeight: FontWeight.w800, color: ink),
          titleMedium: TextStyle(fontWeight: FontWeight.w700, color: ink)),
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Color(0xFFBDD2C3))),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 15)));
}
