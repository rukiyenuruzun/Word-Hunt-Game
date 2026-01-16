class ScoreCalculator {
  
  // --- KELİME PUANI HESAPLAMA ---
  // Formül: uzunluk + (uzunluk - 3) * 0.5
  static double calculateWordScore(int length) {
    if (length < 3) return 0; // 3 harften kısaysa puan yok
    return length + (length - 3) * 0.5;
  }

  // --- CEZA PUANI HESAPLAMA ---
  // 4. yanlıştan itibaren başlar.
  // 4. yanlış -> 0.5, sonra her seferinde 0.1 artar.
  static double calculatePenalty(int wrongCount) {
    if (wrongCount < 4) return 0; // İlk 3 hata cezasız
    
    // (wrongCount - 4) kısmı: 4. hata için 0, 5. hata için 1 olur.
    return 0.5 + (wrongCount - 4) * 0.1;
  }
}