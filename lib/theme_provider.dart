import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  // --- TEMA AYARLARI ---
  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  // --- YENİ: SÜRE AYARLARI ---
  // Varsayılan süre 90 saniye olsun
  int _gameDuration = 90; 

  // Diğer dosyaların süreyi okuması için
  int get gameDuration => _gameDuration;

  // Ayarlar ekranından süreyi değiştirmek için
  void setDuration(int seconds) {
    _gameDuration = seconds;
    notifyListeners(); // Herkese haber ver: Süre değişti!
  }
}