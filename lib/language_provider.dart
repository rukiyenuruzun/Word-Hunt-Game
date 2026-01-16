import 'package:flutter/material.dart';

class LanguageProvider extends ChangeNotifier {
  // Varsayılan dil Türkçe ('tr')
  String _languageCode = 'tr';

  String get languageCode => _languageCode;

  // Dili değiştiren fonksiyon
  void setLanguage(String code) {
    _languageCode = code;
    notifyListeners();
  }

  // --- ÇEVİRİ SÖZLÜĞÜ ---
  final Map<String, Map<String, String>> _localizedStrings = {
    'tr': {
      'gameTitle': 'Oyun Ekranı',
      'score': 'Puan',
      'time': 'Süre',
      'entered': 'Girilen',
      'target': 'Hedef Kelime',
      'hint': 'Kelimeleri boşlukla ayırarak yazın...',
      'added': 'Eklenen Kelimeler (Kontrol Bekleniyor):',
      'gameOver': 'Oyun Bitti!',
      'totalScore': 'Toplam Puan:',
      'correct': 'Doğru Kelimeler:',
      'wrong': 'Hatalı Kelimeler:',
      'menu': 'Ana Menüye Dön',
      'continue': 'Devam Et / Yeni Kelime',
      'change': 'Kelimeyi Değiştir',
      'duplicate': 'Bu kelimeyi zaten ekledin!',
      'settings': 'Ayarlar',
      'language': 'Dil / Language',
      'rules': 'Nasıl Oynanır?', 
      'appTitle': 'KELİME TÜRETMECE', // Ana Başlık
      'singlePlayer': 'Tek Oyunculu',
      'multiPlayer': 'Çok Oyunculu',// Başlık
      'startGame': 'Oyuna Başla',
      'lobbyTitle': 'Lobi',
      'yourName': 'Adın',
      'roomCode': 'Oda Kodu',
      'createRoomBtn': 'Oda Oluştur',
      'joinRoomBtn': 'Odaya Katıl',
      'enterNameErr': 'Lütfen adınızı girin!',
      'enterAllErr': 'Adını ve Oda Kodunu gir!',
      'error': 'Bir hata oluştu!',
      'roomNotFound': 'Oda bulunamadı veya hata oluştu.',
      
      // --- İŞTE EKSİK OLAN KISIM (TÜRKÇE) ---
      'rulesContent': 
          '🎯 Amaç:\n'
          'Size verilen uzun kelimenin harflerini kullanarak, süre bitmeden türetebildiğiniz kadar çok kelime türetmektir.\n\n'
          '📜 Kurallar:\n'
          '• Kelimeler en az 3 harfli olmalıdır.\n'
          '• Sadece verilen harfleri kullanabilirsiniz.\n'
          '• Anlamsız (sözlükte olmayan) kelimeler kabul edilmez.\n\n'
          '🏆 Puanlama:\n'
          'Kelime ne kadar uzunsa o kadar çok puan kazanırsınız.\n'
          '• 3 Harf: 3.0 Puan\n'
          '• 4 Harf: 4.5 Puan\n'
          '• 5 Harf: 6.0 Puan\n'
          '• ...ve artarak devam eder.\n\n'
          '⚠️ Ceza Sistemi:\n'
          'Rastgele kelime denemekten kaçının!\n'
          '• İlk 3 hata için ceza yoktur.\n'
          '• 4. hatadan itibaren her yanlış kelime puanınızdan düşmeye başlar.',
    },
    'en': {
      'gameTitle': 'Game Screen',
      'score': 'Score',
      'time': 'Time',
      'entered': 'Entered',
      'target': 'Target Word',
      'hint': 'Type words separated by space...',
      'added': 'Added Words (Pending Check):',
      'gameOver': 'Game Over!',
      'totalScore': 'Total Score:',
      'correct': 'Correct Words:',
      'wrong': 'Wrong Words:',
      'menu': 'Back to Menu',
      'continue': 'Continue / New Word',
      'change': 'Change Word',
      'duplicate': 'Word already added!',
      'settings': 'Settings',
      'language': 'Language / Dil',
      'rules': 'How to Play?', 
      'appTitle': 'WORD HUNT', // İngilizcesi havalı olsun :)
      'singlePlayer': 'Single Player',
      'multiPlayer': 'Multiplayer',// Başlık
      'startGame': 'Start Game',
      'lobbyTitle': 'Lobby',
      'yourName': 'Your Name',
      'roomCode': 'Room Code',
      'createRoomBtn': 'Create Room',
      'joinRoomBtn': 'Join Room',
      'enterNameErr': 'Please enter your name!',
      'enterAllErr': 'Enter your name and Room Code!',
      'error': 'An error occurred!',
      'roomNotFound': 'Room not found or error occurred.',

      // --- İŞTE EKSİK OLAN KISIM (İNGİLİZCE) ---
      'rulesContent': 
          '🎯 Objective:\n'
          'Create as many words as possible from the given long word before time runs out.\n\n'
          '📜 Rules:\n'
          '• Words must be at least 3 letters long.\n'
          '• You can only use the provided letters.\n'
          '• Meaningless words (not in dictionary) are rejected.\n\n'
          '🏆 Scoring:\n'
          'The longer the word, the higher the score.\n'
          '• 3 Letters: 3.0 Points\n'
          '• 4 Letters: 4.5 Points\n'
          '• 5 Letters: 6.0 Points\n'
          '• ...and increases with length.\n\n'
          '⚠️ Penalty System:\n'
          'Avoid guessing randomly!\n'
          '• No penalty for the first 3 mistakes.\n'
          '• Starting from the 4th mistake, points will be deducted.',
    }
  };

  String getText(String key) {
    return _localizedStrings[_languageCode]?[key] ?? key;
  }
}