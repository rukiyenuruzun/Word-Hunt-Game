import 'package:shared_preferences/shared_preferences.dart';

class UserDataService {
  static const String _totalCoinsKey = 'total_coins';
  // _ownedPowerUpsKey silindi ✅

  // --- TOPLAM COIN OKUMA ---
  static Future<int> getTotalCoins() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_totalCoinsKey) ?? 0;
  }

  // --- COIN EKLEME ---
  static Future<void> addCoins(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    int current = prefs.getInt(_totalCoinsKey) ?? 0;
    await prefs.setInt(_totalCoinsKey, current + amount);
  }

  // --- COIN HARCAMA ---
  static Future<bool> spendCoins(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    int current = prefs.getInt(_totalCoinsKey) ?? 0;
    
    if (current >= amount) {
      await prefs.setInt(_totalCoinsKey, current - amount);
      return true;
    }
    return false;
  }

  // --- SAHİP OLUNAN GÜÇLER (Karıştırma sayısı) ---
  static Future<int> getShuffleCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('shuffle_count') ?? 0;
  }

  static Future<void> addShuffle(int count) async {
    final prefs = await SharedPreferences.getInstance();
    int current = prefs.getInt('shuffle_count') ?? 0;
    await prefs.setInt('shuffle_count', current + count);
  }

  static Future<bool> useShuffle() async {
    final prefs = await SharedPreferences.getInstance();
    int current = prefs.getInt('shuffle_count') ?? 0;
    
    if (current > 0) {
      await prefs.setInt('shuffle_count', current - 1);
      return true;
    }
    return false;
  }

  // --- SIFIRLAMA (Test için) ---
  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}