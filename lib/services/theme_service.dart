import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Service for managing theme preferences
class ThemeService extends ChangeNotifier {
  static const String _themeBoxName = 'theme_preferences';
  static const String _themeModeKey = 'theme_mode';
  
  late Box _themeBox;
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  /// Initialize theme service
  Future<void> init() async {
    _themeBox = await Hive.openBox(_themeBoxName);
    _loadThemeMode();
  }

  /// Load saved theme mode
  void _loadThemeMode() {
    final savedMode = _themeBox.get(_themeModeKey, defaultValue: 'light');
    switch (savedMode) {
      case 'light':
        _themeMode = ThemeMode.light;
        break;
      case 'dark':
        _themeMode = ThemeMode.dark;
        break;
      default:
        _themeMode = ThemeMode.light; // Default to light instead of system
    }
    notifyListeners();
  }

  /// Set theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    String modeString;
    switch (mode) {
      case ThemeMode.light:
        modeString = 'light';
        break;
      case ThemeMode.dark:
        modeString = 'dark';
        break;
      case ThemeMode.system:
        modeString = 'system';
        break;
    }
    await _themeBox.put(_themeModeKey, modeString);
    notifyListeners();
  }

  /// Toggle between light and dark mode
  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.light) {
      await setThemeMode(ThemeMode.dark);
    } else {
      await setThemeMode(ThemeMode.light);
    }
  }
}
