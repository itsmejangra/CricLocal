import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// CricHeros-inspired theme: Blue primary, Teal accents, Light Gray background.
class AppTheme {
  AppTheme._();

  // ── Brand Colors ──────────────────────────────────────────────────────────
  static const Color primaryBlue = Color(0xFF1565C0);
  static const Color primaryBlueDark = Color(0xFF0D47A1);

  // Aliases to change all Red themed elements (AppBar, Headers, main buttons) to Blue
  static const Color primaryRed = primaryBlue;
  static const Color primaryRedDark = primaryBlueDark;
  static const Color accentTeal = Color(0xFF00897B);
  static const Color accentTealLight = Color(0xFFE0F2F1);

  // ── Neutrals ──────────────────────────────────────────────────────────────
  static const Color backgroundGray = Color(0xFFF5F5F5);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFE0E0E0);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFF9E9E9E);
  static const Color dividerColor = Color(0xFFEEEEEE);

  // ── Semantic Colors ───────────────────────────────────────────────────────
  static const Color liveBadge = Color(0xFFEF5350);
  static const Color winGreen = Color(0xFF4CAF50);
  static const Color wicketRed = Color(0xFFD32F2F);
  static const Color fourColor = Color(0xFF1565C0);
  static const Color sixColor = Color(0xFF6A1B9A);
  static const Color dotBallColor = Color(0xFF9E9E9E);

  // ── Scoring Button Colors ─────────────────────────────────────────────────
  static const Color runButtonBg = Color(0xFFF5F5F5);
  static const Color wideColor = Color(0xFFFFF3E0);
  static const Color noBallColor = Color(0xFFFCE4EC);
  static const Color byeColor = Color(0xFFE8F5E9);
  static const Color legByeColor = Color(0xFFE3F2FD);

  // ── Dimensions ────────────────────────────────────────────────────────────
  static const double cardRadius = 12.0;
  static const double buttonRadius = 8.0;
  static const double chipRadius = 16.0;
  static const double bottomNavHeight = 64.0;

  // ── Text Styles ───────────────────────────────────────────────────────────
  static TextStyle get headlineLarge => GoogleFonts.roboto(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      );

  static TextStyle get headlineMedium => GoogleFonts.roboto(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      );

  static TextStyle get titleLarge => GoogleFonts.roboto(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      );

  static TextStyle get titleMedium => GoogleFonts.roboto(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: textPrimary,
      );

  static TextStyle get bodyLarge => GoogleFonts.roboto(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textPrimary,
      );

  static TextStyle get bodyMedium => GoogleFonts.roboto(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textPrimary,
      );

  static TextStyle get bodySmall => GoogleFonts.roboto(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: textSecondary,
      );

  static TextStyle get labelLarge => GoogleFonts.roboto(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: accentTeal,
      );

  static TextStyle get scoreDisplay => GoogleFonts.roboto(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      );

  static TextStyle get scoreOvers => GoogleFonts.roboto(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textSecondary,
      );

  static TextStyle get playerName => GoogleFonts.roboto(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: accentTeal,
      );

  static TextStyle get statValue => GoogleFonts.roboto(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textPrimary,
      );

  static TextStyle get dismissalText => GoogleFonts.roboto(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: textSecondary,
      );

  // ── ThemeData ─────────────────────────────────────────────────────────────
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryRed,
          primary: primaryRed,
          secondary: accentTeal,
          surface: surfaceWhite,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: backgroundGray,
        appBarTheme: AppBarTheme(
          backgroundColor: primaryRed,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: GoogleFonts.roboto(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        cardTheme: CardThemeData(
          color: surfaceWhite,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cardRadius),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: surfaceWhite,
          selectedItemColor: primaryRed,
          unselectedItemColor: textSecondary,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        tabBarTheme: TabBarThemeData(
          labelColor: primaryRed,
          unselectedLabelColor: textSecondary,
          indicatorColor: primaryRed,
          labelStyle: GoogleFonts.roboto(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.roboto(
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: dividerColor,
          thickness: 1,
          space: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentTeal,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(buttonRadius),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: accentTeal,
          ),
        ),
      );

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryRed,
          primary: primaryRed,
          secondary: accentTeal,
          surface: const Color(0xFF1E1E1E),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF1E1E1E),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: GoogleFonts.roboto(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E1E),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cardRadius),
            side: const BorderSide(color: Color(0xFF333333)),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1E1E1E),
          selectedItemColor: primaryRed,
          unselectedItemColor: Colors.white60,
          type: BottomNavigationBarType.fixed,
        ),
        tabBarTheme: TabBarThemeData(
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: primaryRed,
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFF333333),
          thickness: 1,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentTeal,
            foregroundColor: Colors.white,
          ),
        ),
      );
}
