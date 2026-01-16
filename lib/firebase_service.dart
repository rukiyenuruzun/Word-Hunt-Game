import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- RASTGELE ODA KODU ---
  String generateRoomId() {
    return (100000 + Random().nextInt(900000)).toString();
  }

  // --- ODA OLUŞTURMA ---
  Future<String?> createRoom(String playerName, String firstWord, int duration) async { // <-- Yeni parametre eklendi
    String roomId = generateRoomId();
    try {
      await _firestore.collection('rooms').doc(roomId).set({
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'waiting',
        'host': playerName,
        'players': [playerName],
        'scores': {playerName: 0},
        'words': {playerName: []},
        'targetWord': firstWord,
        'gameDuration': duration, // <-- Artık ayarlardan gelen süreyi kullanacak
      });
      return roomId;
    } catch (e) {
      debugPrint("Hata: $e");
      return null;
    }
  }

  // --- ODAYA KATILMA ---
  Future<bool> joinRoom(String roomId, String playerName) async {
    try {
      DocumentReference roomRef = _firestore.collection('rooms').doc(roomId);
      DocumentSnapshot snapshot = await roomRef.get();

      if (!snapshot.exists) return false;

      List players = snapshot.get('players');
      if (!players.contains(playerName)) {
        if (players.length >= 2) return false;

        await roomRef.update({
          'players': FieldValue.arrayUnion([playerName]),
          'scores.$playerName': 0,
          'words.$playerName': [], // Yeni oyuncu için boş liste
          'status': 'playing', // Oyun başlasın
        });
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- ODAYI DİNLEME ---
  Stream<DocumentSnapshot> getRoomStream(String roomId) {
    return _firestore.collection('rooms').doc(roomId).snapshots();
  }

  // --- PUAN VE KELİME GÜNCELLEME (YENİ) ---
  Future<void> updateScoreAndWords(String roomId, String playerName, double newScore, List<String> words) async {
    await _firestore.collection('rooms').doc(roomId).update({
      'scores.$playerName': newScore,
      'words.$playerName': words, // Kelime listesini veritabanına işle
    });
  }

  // --- KELİME DEĞİŞTİRME ---
  Future<void> updateTargetWord(String roomId, String newWord) async {
    await _firestore.collection('rooms').doc(roomId).update({
      'targetWord': newWord,
    });
  }
  // --- YENİ TUR BAŞLATMA (Devam Et) ---
  Future<void> restartGame(String roomId, String newWord, List<dynamic> currentPlayers) async {
    // Tüm oyuncuların puanlarını ve kelimelerini sıfırla
    Map<String, int> resetScores = {};
    Map<String, List<String>> resetWords = {};
    
    for (var player in currentPlayers) {
      resetScores[player.toString()] = 0;
      resetWords[player.toString()] = [];
    }

    await _firestore.collection('rooms').doc(roomId).update({
      'targetWord': newWord,
      'status': 'playing', // Durumu tekrar 'playing' yap
      'scores': resetScores,
      'words': resetWords,
      'startTime': FieldValue.serverTimestamp(), // Süreyi senkronize etmek için (opsiyonel)
    });
  }
}