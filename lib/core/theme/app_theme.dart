import 'package:material_ui/material_ui.dart';

abstract final class OneColors {
  static const navy = Color(0xFF09285B);
  static const blue = Color(0xFF1557A0);
  static const gold = Color(0xFFF5BF30);
  static const background = Color(0xFFF5F7FC);
  static const muted = Color(0xFF526079);
}

abstract final class OneSpace {
  static const small = 8.0;
  static const medium = 16.0;
  static const large = 24.0;
  static const section = 32.0;
  static const radius = 20.0;
  static const maxWidth = 960.0;
}

abstract final class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: OneColors.navy,
      primary: OneColors.navy,
      secondary: OneColors.blue,
      tertiary: OneColors.gold,
      surface: Colors.white,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor: OneColors.background,
      textTheme: base.textTheme
          .copyWith(
            headlineMedium: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.2,
              letterSpacing: -.7,
            ),
            headlineSmall: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
            titleLarge: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
            titleMedium: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
            bodyMedium: const TextStyle(fontSize: 14, height: 1.45),
          )
          .apply(bodyColor: OneColors.navy, displayColor: OneColors.navy),
      dividerTheme: const DividerThemeData(color: Color(0xFFE2E7F0), space: 24),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: OneColors.background,
        selectedColor: const Color(0xFFE6EDF8),
        side: const BorderSide(color: Color(0xFFE2E7F0)),
        labelStyle: const TextStyle(color: OneColors.navy, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: OneColors.navy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: OneColors.background,
        foregroundColor: OneColors.navy,
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OneSpace.radius),
          side: const BorderSide(color: Color(0xFFE2E7F0)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD5DDEB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: OneColors.blue, width: 2),
        ),
        helperMaxLines: 4,
        errorMaxLines: 5,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: OneColors.gold.withValues(alpha: .24),
      ),
    );
  }
}
