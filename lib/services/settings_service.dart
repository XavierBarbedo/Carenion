import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  late SharedPreferences _prefs;

  // Defaults
  ThemeMode _themeMode = ThemeMode.system;
  int _eventNotificationTime = 60; // Minutes before event
  int _lowStockThreshold = 5; // Stock limit below which it turns red
  String _calendarLanguage = 'pt';

  // Keys
  static const String _themeModeKey = 'theme_mode';
  static const String _eventNotificationTimeKey = 'event_notification_time';
  static const String _lowStockThresholdKey = 'low_stock_threshold';
  static const String _calendarLanguageKey = 'calendar_language';

  ThemeMode get themeMode => _themeMode;
  int get eventNotificationTime => _eventNotificationTime;
  int get lowStockThreshold => _lowStockThreshold;
  String get calendarLanguage => _calendarLanguage;

  SettingsService(SharedPreferences prefs) {
    _prefs = prefs;
    _loadSettings();
  }

  void _loadSettings() {
    final themeIndex = _prefs.getInt(_themeModeKey) ?? ThemeMode.system.index;
    _themeMode = ThemeMode.values[themeIndex];
    
    _eventNotificationTime = _prefs.getInt(_eventNotificationTimeKey) ?? 60;
    _lowStockThreshold = _prefs.getInt(_lowStockThresholdKey) ?? 5;
    _calendarLanguage = _prefs.getString(_calendarLanguageKey) ?? 'pt';
    
    notifyListeners();
  }

  Future<void> updateThemeMode(ThemeMode newThemeMode) async {
    if (newThemeMode == _themeMode) return;
    _themeMode = newThemeMode;
    await _prefs.setInt(_themeModeKey, newThemeMode.index);
    notifyListeners();
  }

  Future<void> updateEventNotificationTime(int minutes) async {
    if (minutes == _eventNotificationTime) return;
    _eventNotificationTime = minutes;
    await _prefs.setInt(_eventNotificationTimeKey, minutes);
    notifyListeners();
  }

  Future<void> updateLowStockThreshold(int threshold) async {
    if (threshold == _lowStockThreshold) return;
    _lowStockThreshold = threshold;
    await _prefs.setInt(_lowStockThresholdKey, threshold);
    notifyListeners();
  }

  Future<void> updateCalendarLanguage(String language) async {
    if (language == _calendarLanguage) return;
    _calendarLanguage = language;
    await _prefs.setString(_calendarLanguageKey, language);
    notifyListeners();
  }
}
