import 'package:flutter/material.dart';
import 'tokens.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light() => _buildTheme(AppTokens.light, Brightness.light);
  static ThemeData dark() => _buildTheme(AppTokens.dark, Brightness.dark);

  static ThemeData _buildTheme(AppTokens tokens, Brightness brightness) {
    final textTheme = TextTheme(
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: tokens.textSecondary,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: tokens.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: tokens.textPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: tokens.textPrimary,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: tokens.background,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: tokens.actionFill,
        onPrimary: tokens.actionOnFill,
        secondary: tokens.textSecondary,
        onSecondary: tokens.actionOnFill,
        error: tokens.danger,
        onError: tokens.actionOnFill,
        surface: tokens.surface,
        onSurface: tokens.textPrimary,
      ),
      textTheme: textTheme,
      dividerTheme: DividerThemeData(
        color: tokens.border,
        thickness: tokens.borderWidth,
        space: tokens.borderWidth,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tokens.actionFill,
          foregroundColor: tokens.actionOnFill,
          elevation: 0,
          minimumSize: Size(tokens.minTouchTarget, tokens.minTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radiusSm),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.textPrimary,
          elevation: 0,
          side: BorderSide(color: tokens.border, width: tokens.borderWidth),
          minimumSize: Size(tokens.minTouchTarget, tokens.minTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radiusSm),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tokens.textPrimary,
          elevation: 0,
          minimumSize: Size(tokens.minTouchTarget, tokens.minTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radiusSm),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surface,
        contentPadding: EdgeInsets.symmetric(
          horizontal: tokens.space12,
          vertical: tokens.space12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          borderSide: BorderSide(
            color: tokens.border,
            width: tokens.borderWidth,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          borderSide: BorderSide(
            color: tokens.border,
            width: tokens.borderWidth,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          borderSide: BorderSide(
            color: tokens.textPrimary,
            width: tokens.borderWidth,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          borderSide: BorderSide(
            color: tokens.danger,
            width: tokens.borderWidth,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          borderSide: BorderSide(
            color: tokens.danger,
            width: tokens.borderWidth,
          ),
        ),
        hintStyle: TextStyle(
          color: tokens.textDisabled,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(tokens.radiusLg),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: tokens.actionFill,
        contentTextStyle: TextStyle(
          color: tokens.actionOnFill,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusSm),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
      ),
      extensions: <ThemeExtension<dynamic>>[tokens],
    );
  }
}
