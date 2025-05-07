import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;
  static const String _themeKey = 'dark_mode';

  ThemeProvider() {
    _loadThemeFromPrefs();
  }

  bool get isDarkMode => _isDarkMode;

  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  Future<void> _loadThemeFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool(_themeKey) ?? false;
      notifyListeners();
    } catch (e) {
      print('Error loading theme: $e');
    }
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themeKey, _isDarkMode);
    } catch (e) {
      print('Error saving theme: $e');
    }
  }

  // Theme data for light mode
  ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: const Color.fromARGB(255, 0, 58, 92),
      scaffoldBackgroundColor: Colors.grey[100],
      cardColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color.fromARGB(255, 0, 58, 92),
        foregroundColor: Colors.white,
      ),
      colorScheme: ColorScheme.light(
        primary: const Color.fromARGB(255, 0, 58, 92),
        secondary: Colors.blue[700]!,
      ),
      textTheme: TextTheme(
        bodyMedium: TextStyle(color: Colors.grey[800]),
      ),
      iconTheme: IconThemeData(
        color: Colors.grey[800],
      ),
    );
  }

  // Theme data for dark mode
  ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: const Color.fromARGB(255, 0, 58, 92),
      scaffoldBackgroundColor: const Color(0xFF121212),
      cardColor: const Color(0xFF1E1E1E),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color.fromARGB(255, 0, 58, 92),
        foregroundColor: Colors.white,
      ),
      colorScheme: ColorScheme.dark(
        primary: const Color.fromARGB(255, 0, 58, 92),
        secondary: Colors.blue[300]!,
        background: const Color(0xFF121212),
        surface: const Color(0xFF1E1E1E),
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Colors.white70),
      ),
      iconTheme: const IconThemeData(
        color: Colors.white70,
      ),
    );
  }
}
