// Settings service for managing app preferences like dark mode and brightness

import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  static const String _brightnessKey = 'screen_brightness';

  // Theme modes: 'system', 'light', 'dark'
  String _themeMode = 'system';
  String get themeMode => _themeMode;

  // Screen brightness: 0.0 to 0.02 (0% to 2%)
  double _brightness = 0.01; // Default to 1%
  double get brightness => _brightness;

  SettingsService() {
    _loadSettings();
  }

  // Load settings from storage
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = prefs.getString(_themeKey) ?? 'system';
    _brightness = prefs.getDouble(_brightnessKey) ?? 0.01;
    notifyListeners();
  }

  // Set theme mode directly
  Future<void> setThemeMode(String mode) async {
    if (mode != 'system' && mode != 'light' && mode != 'dark') {
      mode = 'system';
    }
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, _themeMode);
    notifyListeners();
  }

  // Cycle through theme modes: system -> light -> dark -> system
  Future<void> cycleThemeMode() async {
    switch (_themeMode) {
      case 'system':
        _themeMode = 'light';
        break;
      case 'light':
        _themeMode = 'dark';
        break;
      case 'dark':
        _themeMode = 'system';
        break;
      default:
        _themeMode = 'system';
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, _themeMode);
    notifyListeners();
  }

  // Get effective brightness based on theme mode and system brightness
  Brightness getEffectiveBrightness(Brightness systemBrightness) {
    switch (_themeMode) {
      case 'light':
        return Brightness.light;
      case 'dark':
        return Brightness.dark;
      case 'system':
      default:
        return systemBrightness;
    }
  }

  // Check if currently dark based on theme mode and system brightness
  bool isDark(Brightness systemBrightness) {
    return getEffectiveBrightness(systemBrightness) == Brightness.dark;
  }

  // Set screen brightness (0.0 to 0.02 for 0% to 2%)
  Future<void> setBrightness(double value) async {
    _brightness = value.clamp(0.0, 0.02);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_brightnessKey, _brightness);
    notifyListeners();
  }
}
