import 'package:flutter/material.dart';

/// Lapis-and-brass palette: oud inlay, Iznik tile blue, polished brass.
class Palette {
  static const bg = Color(0xFF0E1B2E);
  static const panel = Color(0xFF16294A);
  static const line = Color(0xFF2C4468);
  static const ivory = Color(0xFFF1E9D8);
  static const muted = Color(0xFF9FB0C8);
  static const brass = Color(0xFFD9A441);
  static const ok = Color(0xFF6FD3A3);
}

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    primary: Palette.brass,
    onPrimary: Palette.bg,
    secondary: Palette.ok,
    surface: Palette.panel,
    onSurface: Palette.ivory,
    outline: Palette.line,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.bg,
      foregroundColor: Palette.ivory,
      elevation: 0,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Palette.panel,
      indicatorColor: Palette.brass.withAlpha(50),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, color: Palette.ivory),
      ),
    ),
    textTheme: const TextTheme().apply(
      bodyColor: Palette.ivory,
      displayColor: Palette.ivory,
    ),
    dividerColor: Palette.line,
    sliderTheme: const SliderThemeData(
      activeTrackColor: Palette.brass,
      thumbColor: Palette.brass,
      inactiveTrackColor: Palette.line,
    ),
  );
}
