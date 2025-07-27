import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// Application theme configuration
class AppTheme {
  static const _primaryColor = Color(0xFF0099FF);
  static const _secondaryColor = Color(0xFFFF6B6B);
  static const _tertiaryColor = Color(0xFF00D4AA);
  static const _errorColor = Color(0xFFFF5555);
  static const _backgroundColor = Color(0xFF0F0F23);
  static const _surfaceColor = Color(0xFF1A1A2E);
  static const _surfaceVariantColor = Color(0xFF16213E);
  static const _onSurfaceColor = Color(0xFFEEEEFF);
  static const _outlineColor = Color(0xFF4A4A6A);
  static const _outlineVariantColor = Color(0xFF2A2A4A);

  static ThemeData get darkTheme {
    return ThemeData(
      colorScheme: const ColorScheme.dark(
        primary: _primaryColor,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFF0066CC),
        onPrimaryContainer: Color(0xFFCCE7FF),

        secondary: _secondaryColor,
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFFCC4444),
        onSecondaryContainer: Color(0xFFFFE6E6),

        surface: _surfaceColor,
        onSurface: _onSurfaceColor,
        surfaceContainerHighest: _surfaceVariantColor,
        onSurfaceVariant: Color(0xFFD4D4FF),

        tertiary: _tertiaryColor,
        onTertiary: Colors.white,

        error: _errorColor,
        onError: Colors.white,

        outline: _outlineColor,
        outlineVariant: _outlineVariantColor,
      ),
      useMaterial3: true,
      elevatedButtonTheme: _elevatedButtonTheme,
      filledButtonTheme: _filledButtonTheme,
      outlinedButtonTheme: _outlinedButtonTheme,
      cardTheme: _cardTheme,
      progressIndicatorTheme: _progressIndicatorTheme,
      appBarTheme: _appBarTheme,
    );
  }

  static ElevatedButtonThemeData get _elevatedButtonTheme {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: AppConstants.buttonElevation,
        shadowColor: _primaryColor.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }

  static FilledButtonThemeData get _filledButtonTheme {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _secondaryColor,
        foregroundColor: Colors.white,
        elevation: AppConstants.buttonElevation,
        shadowColor: _secondaryColor.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }

  static OutlinedButtonThemeData get _outlinedButtonTheme {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _primaryColor,
        side: const BorderSide(color: _primaryColor, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }

  static CardThemeData get _cardTheme {
    return CardThemeData(
      color: _surfaceVariantColor,
      elevation: AppConstants.cardElevation,
      shadowColor: const Color(0xFF000033),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
      ),
      margin: const EdgeInsets.all(8),
    );
  }

  static ProgressIndicatorThemeData get _progressIndicatorTheme {
    return const ProgressIndicatorThemeData(
      color: _primaryColor,
      linearTrackColor: _outlineVariantColor,
      circularTrackColor: _outlineVariantColor,
    );
  }

  static AppBarTheme get _appBarTheme {
    return const AppBarTheme(
      backgroundColor: _backgroundColor,
      foregroundColor: _onSurfaceColor,
      elevation: 0,
      centerTitle: true,
    );
  }
}
