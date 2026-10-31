import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

ThemeProvider? appThemeProvider;

// ─── AppThemeConfig ───────────────────────────────────────────────────────────

class AppThemeConfig {
  final String name;
  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color quaternary;
  final Color bg;
  final Color surface;
  final Color card;
  final Color text;
  final Color textDim;
  final Brightness brightness;

  const AppThemeConfig({
    required this.name,
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.quaternary,
    required this.bg,
    required this.surface,
    required this.card,
    required this.text,
    required this.textDim,
    required this.brightness,
  });
}

final kThemes = <String, AppThemeConfig>{
  'dark_violet': AppThemeConfig(
    name: 'Violet Nuit',
    primary: const Color(0xFF7C3AED),
    secondary: const Color(0xFF06B6D4),
    tertiary: const Color(0xFFFF2D78),
    quaternary: const Color(0xFFFFD700),
    bg: const Color(0xFF0A0A0F),
    surface: const Color(0xFF12121A),
    card: const Color(0xFF1A1A25),
    text: Colors.white,
    textDim: const Color(0xFF6B7280),
    brightness: Brightness.dark,
  ),
  'dark_cyan': AppThemeConfig(
    name: 'Cyan Nuit',
    primary: const Color(0xFF06B6D4),
    secondary: const Color(0xFF7C3AED),
    tertiary: const Color(0xFFFF2D78),
    quaternary: const Color(0xFFFFD700),
    bg: const Color(0xFF030F12),
    surface: const Color(0xFF071820),
    card: const Color(0xFF0C2028),
    text: Colors.white,
    textDim: const Color(0xFF4B8A95),
    brightness: Brightness.dark,
  ),
  'dark_green': AppThemeConfig(
    name: 'Vert Matrix',
    primary: const Color(0xFF10B981),
    secondary: const Color(0xFF06B6D4),
    tertiary: const Color(0xFFEC4899),
    quaternary: const Color(0xFFF59E0B),
    bg: const Color(0xFF020F08),
    surface: const Color(0xFF071A0F),
    card: const Color(0xFF0A2318),
    text: Colors.white,
    textDim: const Color(0xFF3D7A5A),
    brightness: Brightness.dark,
  ),
  'dark_blue': AppThemeConfig(
    name: 'Bleu Océan',
    primary: const Color(0xFF3B82F6),
    secondary: const Color(0xFF06B6D4),
    tertiary: const Color(0xFFEC4899),
    quaternary: const Color(0xFFFFD700),
    bg: const Color(0xFF03060F),
    surface: const Color(0xFF080C1E),
    card: const Color(0xFF0D1228),
    text: Colors.white,
    textDim: const Color(0xFF3A5080),
    brightness: Brightness.dark,
  ),
  'dark_pink': AppThemeConfig(
    name: 'Rose Neon',
    primary: const Color(0xFFEC4899),
    secondary: const Color(0xFF7C3AED),
    tertiary: const Color(0xFF06B6D4),
    quaternary: const Color(0xFFFFD700),
    bg: const Color(0xFF0F030A),
    surface: const Color(0xFF1E0814),
    card: const Color(0xFF280D1C),
    text: Colors.white,
    textDim: const Color(0xFF7A3055),
    brightness: Brightness.dark,
  ),
  'dark_orange': AppThemeConfig(
    name: 'Orange Feu',
    primary: const Color(0xFFF97316),
    secondary: const Color(0xFFEC4899),
    tertiary: const Color(0xFF06B6D4),
    quaternary: const Color(0xFFFFD700),
    bg: const Color(0xFF0F0703),
    surface: const Color(0xFF1E1008),
    card: const Color(0xFF28160C),
    text: Colors.white,
    textDim: const Color(0xFF7A4820),
    brightness: Brightness.dark,
  ),
  'light_white': AppThemeConfig(
    name: 'Blanc Pur',
    primary: const Color(0xFF7C3AED),
    secondary: const Color(0xFF06B6D4),
    tertiary: const Color(0xFFEC4899),
    quaternary: const Color(0xFFF59E0B),
    bg: const Color(0xFFF8F9FA),
    surface: Colors.white,
    card: const Color(0xFFF1F3F5),
    text: const Color(0xFF0A0A0F),
    textDim: const Color(0xFF6B7280),
    brightness: Brightness.light,
  ),
  'light_soft': AppThemeConfig(
    name: 'Beige Doux',
    primary: const Color(0xFF8B5CF6),
    secondary: const Color(0xFFEC4899),
    tertiary: const Color(0xFF06B6D4),
    quaternary: const Color(0xFFF59E0B),
    bg: const Color(0xFFFAF5FF),
    surface: const Color(0xFFF3E8FF),
    card: const Color(0xFFEDE9FE),
    text: const Color(0xFF1E1B4B),
    textDim: const Color(0xFF7C3AED),
    brightness: Brightness.light,
  ),
  'midnight': AppThemeConfig(
    name: 'Minuit',
    primary: const Color(0xFFFFD700),
    secondary: const Color(0xFFFF6B35),
    tertiary: const Color(0xFF06B6D4),
    quaternary: const Color(0xFFEC4899),
    bg: Colors.black,
    surface: const Color(0xFF0D0D0D),
    card: const Color(0xFF141414),
    text: Colors.white,
    textDim: const Color(0xFF555555),
    brightness: Brightness.dark,
  ),
  'neon': AppThemeConfig(
    name: 'Neon',
    primary: const Color(0xFF39FF14),
    secondary: const Color(0xFFFF073A),
    tertiary: const Color(0xFF00F5FF),
    quaternary: const Color(0xFFFFD700),
    bg: const Color(0xFF050505),
    surface: const Color(0xFF0A0A0A),
    card: const Color(0xFF111111),
    text: Colors.white,
    textDim: const Color(0xFF444444),
    brightness: Brightness.dark,
  ),
};

// ─── ThemeProvider ────────────────────────────────────────────────────────────

class ThemeProvider extends ChangeNotifier {
  AppThemeConfig get _defaultTheme =>
      kThemes['dark_violet'] ?? kThemes.values.first;
  AppThemeConfig _current = kThemes['dark_violet'] ?? kThemes.values.first;
  AppThemeConfig get current => _current;

  ThemeProvider() {
    appThemeProvider = this;
    load();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString('app_theme') ?? 'dark_violet';
    _current = kThemes[key] ?? _defaultTheme;
    notifyListeners();
  }

  Future<void> setTheme(String key) async {
    if (!kThemes.containsKey(key)) return;
    _current = kThemes[key] ?? _defaultTheme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_theme', key);
    notifyListeners();
  }
}
