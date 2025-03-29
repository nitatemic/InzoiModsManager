import 'package:flutter/material.dart';

class AppTheme {
  // Primary colors
  static const Color primaryLight = Color(0xFF2196F3); // Light blue
  static const Color primaryDark = Color(0xFF1976D2); // Dark blue
  
  // Background colors
  static const Color backgroundLight = Color(0xFFF5F9FC);
  static const Color backgroundDark = Color(0xFF121212);
  
  // Card colors
  static const Color cardLight = Colors.white;
  static const Color cardDark = Color(0xFF1E1E1E);
  
  // Text colors
  static const Color textLight = Color(0xFF424242);
  static const Color textDark = Color(0xFFE0E0E0);
  
  // Settings constants
  static const double borderRadius = 8.0;
  static const double cardElevation = 2.0;
  static const double cardBorderRadius = 12.0;
  static const double itemSpacing = 16.0;

  // Light theme
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: primaryLight,
      secondary: primaryLight.withOpacity(0.7),
      surface: cardLight,
      background: backgroundLight,
    ),
    scaffoldBackgroundColor: backgroundLight,
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryLight,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardTheme: CardTheme(
      color: cardLight,
      elevation: cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardBorderRadius),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryLight,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryLight,
        side: const BorderSide(color: primaryLight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(
        color: textLight,
        fontWeight: FontWeight.bold,
      ),
      titleMedium: TextStyle(
        color: textLight,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: TextStyle(
        color: textLight,
      ),
      bodyMedium: TextStyle(
        color: textLight,
      ),
    ),
  );

  // Dark theme
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: primaryDark,
      secondary: primaryDark.withOpacity(0.7),
      surface: cardDark,
      background: backgroundDark,
    ),
    scaffoldBackgroundColor: backgroundDark,
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryDark,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardTheme: CardTheme(
      color: cardDark,
      elevation: cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardBorderRadius),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryDark,
        side: const BorderSide(color: primaryDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(
        color: textDark,
        fontWeight: FontWeight.bold,
      ),
      titleMedium: TextStyle(
        color: textDark,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: TextStyle(
        color: textDark,
      ),
      bodyMedium: TextStyle(
        color: textDark,
      ),
    ),
  );
} 