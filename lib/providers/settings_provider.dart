import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  Locale _currentLocale = const Locale('en', '');

  bool get isDarkMode => _isDarkMode;
  Locale get currentLocale => _currentLocale;

  SettingsProvider() {
    _loadSettings();
  }

  // Загрузить настройки
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      
      final String? langCode = prefs.getString('languageCode');
      if (langCode != null) {
        _currentLocale = Locale(langCode, '');
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Ошибка при загрузке настроек: $e');
    }
  }

  // Изменить тему
  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', _isDarkMode);
    } catch (e) {
      debugPrint('Ошибка при сохранении темы: $e');
    }
    
    notifyListeners();
  }

  // Изменить язык
  Future<void> setLocale(Locale locale) async {
    if (_currentLocale.languageCode == locale.languageCode) return;
    
    _currentLocale = locale;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('languageCode', locale.languageCode);
    } catch (e) {
      debugPrint('Ошибка при сохранении языка: $e');
    }
    
    notifyListeners();
  }
} 