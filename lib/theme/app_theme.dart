import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Core Colors (Deep Night Theme)
  static const Color backgroundColor = Color(
    0xFF0F1115,
  ); // Deep dark blue-black
  static const Color surfaceColor = Color(
    0xFF181B21,
  ); // Slightly lifted card color
  static const Color primaryColor = Color(0xFFEAEAF0); // Main text
  static const Color secondaryColor = Color(0xFF9A9AA5); // Secondary text

  // Accents (Soft & Calm)
  static const Color accentColor = Color(0xFF818CF8); // Soft Indigo/Violet
  static const Color goldColor = Color(
    0xFFFFD700,
  ); // Kept for highlights/premium
  static const Color errorColor = Color(0xFFEF4444); // Soft Red

  // Category Colors (Muted/Pastel)
  static const Color loveColor = Color(0xFFF472B6); // Soft Pink
  static const Color regretColor = Color(0xFF9CA3AF); // Muted Gray
  static const Color secretColor = Color(0xFF818CF8); // Soft Indigo
  static const Color fearColor = Color(0xFFF87171); // Soft Red

  // Gradients (Subtle)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF181B21), Color(0xFF1F2937)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundColor,
      primaryColor: accentColor,

      // Typography
      textTheme: TextTheme(
        // Body: Serif for reading comfort (Confessions)
        bodyLarge: GoogleFonts.merriweather(
          fontSize: 17,
          height: 1.6,
          color: primaryColor,
          fontWeight: FontWeight.w400,
        ),
        // UI: Clean Sans for buttons/labels
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          color: secondaryColor,
          fontWeight: FontWeight.w500,
        ),
        // Headers: Clean Sans
        titleLarge: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: primaryColor,
          letterSpacing: -0.5,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: secondaryColor,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
        margin: EdgeInsets.zero,
      ),

      // AppBar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: primaryColor,
        ),
        iconTheme: const IconThemeData(color: primaryColor),
      ),

      // Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
