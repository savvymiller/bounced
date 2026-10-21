import 'package:flutter/material.dart';

/// Light/dark Material 3 themes for the app shell. No door-specific styling
/// yet (the one-big-button door screen is PR-09) — this exists so every
/// screen pulls from one definition instead of `MaterialApp` defaults.
abstract final class AppTheme {
  static final ThemeData light = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.indigo,
      brightness: Brightness.light,
    ),
  );

  static final ThemeData dark = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.indigo,
      brightness: Brightness.dark,
    ),
  );
}
