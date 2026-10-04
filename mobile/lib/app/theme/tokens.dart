import 'package:flutter/material.dart';

@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.actionFill,
    required this.actionOnFill,
    required this.danger,
    required this.markerShopeeFood,
    required this.markerSpx,
    required this.markerIcon,
    this.radiusSm = 8.0,
    this.radiusLg = 16.0,
    this.space4 = 4.0,
    this.space8 = 8.0,
    this.space12 = 12.0,
    this.space16 = 16.0,
    this.space24 = 24.0,
    this.minTouchTarget = 48.0,
    this.borderWidth = 1.0,
  });

  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color actionFill;
  final Color actionOnFill;
  final Color danger;
  final Color markerShopeeFood;
  final Color markerSpx;
  final Color markerIcon;

  final double radiusSm;
  final double radiusLg;
  final double space4;
  final double space8;
  final double space12;
  final double space16;
  final double space24;
  final double minTouchTarget;
  final double borderWidth;

  static const AppTokens light = AppTokens(
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF5F5F5),
    border: Color(0xFFE5E5E5),
    textPrimary: Color(0xFF111111),
    textSecondary: Color(0xFF737373),
    textDisabled: Color(0xFFA3A3A3),
    actionFill: Color(0xFF111111),
    actionOnFill: Color(0xFFFFFFFF),
    danger: Color(0xFFB42318),
    markerShopeeFood: Color(0xFF1E9E57),
    markerSpx: Color(0xFF1F6FEB),
    markerIcon: Color(0xFFFFFFFF),
  );

  static const AppTokens dark = AppTokens(
    background: Color(0xFF0B0B0B),
    surface: Color(0xFF161616),
    surfaceMuted: Color(0xFF1F1F1F),
    border: Color(0xFF2A2A2A),
    textPrimary: Color(0xFFF5F5F5),
    textSecondary: Color(0xFFA3A3A3),
    textDisabled: Color(0xFF5C5C5C),
    actionFill: Color(0xFFF5F5F5),
    actionOnFill: Color(0xFF111111),
    danger: Color(0xFFF97066),
    markerShopeeFood: Color(0xFF3DBE79),
    markerSpx: Color(0xFF5B9BFF),
    markerIcon: Color(0xFF0B0B0B),
  );

  @override
  AppTokens copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textDisabled,
    Color? actionFill,
    Color? actionOnFill,
    Color? danger,
    Color? markerShopeeFood,
    Color? markerSpx,
    Color? markerIcon,
    double? radiusSm,
    double? radiusLg,
    double? space4,
    double? space8,
    double? space12,
    double? space16,
    double? space24,
    double? minTouchTarget,
    double? borderWidth,
  }) {
    return AppTokens(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textDisabled: textDisabled ?? this.textDisabled,
      actionFill: actionFill ?? this.actionFill,
      actionOnFill: actionOnFill ?? this.actionOnFill,
      danger: danger ?? this.danger,
      markerShopeeFood: markerShopeeFood ?? this.markerShopeeFood,
      markerSpx: markerSpx ?? this.markerSpx,
      markerIcon: markerIcon ?? this.markerIcon,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusLg: radiusLg ?? this.radiusLg,
      space4: space4 ?? this.space4,
      space8: space8 ?? this.space8,
      space12: space12 ?? this.space12,
      space16: space16 ?? this.space16,
      space24: space24 ?? this.space24,
      minTouchTarget: minTouchTarget ?? this.minTouchTarget,
      borderWidth: borderWidth ?? this.borderWidth,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) {
      return this;
    }
    return AppTokens(
      background: Color.lerp(background, other.background, t) ?? background,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      surfaceMuted:
          Color.lerp(surfaceMuted, other.surfaceMuted, t) ?? surfaceMuted,
      border: Color.lerp(border, other.border, t) ?? border,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary:
          Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      textDisabled:
          Color.lerp(textDisabled, other.textDisabled, t) ?? textDisabled,
      actionFill: Color.lerp(actionFill, other.actionFill, t) ?? actionFill,
      actionOnFill:
          Color.lerp(actionOnFill, other.actionOnFill, t) ?? actionOnFill,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      markerShopeeFood:
          Color.lerp(markerShopeeFood, other.markerShopeeFood, t) ??
          markerShopeeFood,
      markerSpx: Color.lerp(markerSpx, other.markerSpx, t) ?? markerSpx,
      markerIcon: Color.lerp(markerIcon, other.markerIcon, t) ?? markerIcon,
      radiusSm: radiusSm,
      radiusLg: radiusLg,
      space4: space4,
      space8: space8,
      space12: space12,
      space16: space16,
      space24: space24,
      minTouchTarget: minTouchTarget,
      borderWidth: borderWidth,
    );
  }
}

extension AppTokensX on BuildContext {
  AppTokens get tokens =>
      Theme.of(this).extension<AppTokens>() ?? AppTokens.light;
}
