import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kelime_turetmece/firebase_service.dart';
import 'package:kelime_turetmece/score_calculator.dart'; // ScoreCalculator'ın olduğu dosya
import 'package:provider/provider.dart';
import 'package:kelime_turetmece/language_provider.dart';

class OnlineGameScreen extends StatefulWidget {
  final String roomId;
  final String playerName;
  final bool isHost;

  const OnlineGameScreen({
    super.key, 
    required this.roomId, 
    required this.playerName, 
    required this.isHost
  });

  @override
  State<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends State<OnlineGameScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<String> allWords = [];
  List<String> enteredWords = []; 
  
  // Bu değişkenler anlık hesaplama için değil, oyun sonu gösterimi için tutulabilir
  // Ancak Multiplayer'da Firebase'e sadece "girilenleri" ve "anlık puanı" atıyoruz.
  // Doğru/Yanlış ayrımını oyun sonunda yapacağız.
  
  String currentTargetWord = "";
  double myScore = 0;
  
  Timer? _timer;
  int _remainingTime = 90;
  bool _isTimerStarted = false;
  bool _isGameFinished = false;

  @override
  void initState() {
    super.initState();
    loadDictionary();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // --- DİL DUYARLI KÜÇÜLTME (GameScreen'den Alındı) ---
  String convertToLowerCase(String input, String langCode) {
    if (langCode == 'tr') {
      return input.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
    } else {
      return input.toLowerCase();
    }
  }

  // --- SÖZLÜK YÜKLEME (GameScreen Mantığıyla Güncellendi) ---
  Future<void> loadDictionary() async {
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    String fileName = (langProvider.languageCode == 'tr') ? 'assets/words.json' : 'assets/words_en.json';
    
    try {
      final String response = await rootBundle.loadString(fileName);
      final dynamic decodedData = json.decode(response);
      List<String> rawList = [];

      // Senin JSON yapına uygun kontrol
      if (decodedData is Map) {
        rawList = decodedData.keys.map((k) => k.toString()).toList();
      } else if (decodedData is List) {
        rawList = decodedData.map((e) {
           if (e is Map && e.containsKey('word')) return e['word'].toString();
           return e.toString();
        }).toList();
      }

      if(mounted) {
        setState(() {
          allWords = rawList.map((e) => convertToLowerCase(e.trim(), langProvider.languageCode))
                            .where((w) => !w.contains(' ')) // Deyimleri ele
                            .toList();
        });
      }
    } catch (e) {
      debugPrint("Sözlük hatası: $e");
    }
  }

  // --- SAYAÇ VE OYUN BİTİŞİ ---
  void startLocalTimer() {
    if (_isTimerStarted) return;
    
    setState(() {
      _isTimerStarted = true;
      _isGameFinished = false;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime > 0) {
        setState(() {
          _remainingTime--;
        });
      } else {
        timer.cancel();
        finishGameLocally();
      }
    });
  }

  void finishGameLocally() {
    setState(() {
      _isGameFinished = true;
      _isTimerStarted = false;
    });
    // Son puanı tekrar garanti olarak gönder
    _firebaseService.updateScoreAndWords(widget.roomId, widget.playerName, myScore, enteredWords);
  }

  // --- YENİ TUR (HOST) ---
  void startNewRound(List<dynamic> players) {
    if (!widget.isHost) return;

    // Yeni kelimeyi mevcut sözlükten seç
    List<String> longWords = allWords.where((w) => w.length >= 7).toList();
    String newWord = "bilgisayar"; 
    if (longWords.isNotEmpty) {
      newWord = longWords[Random().nextInt(longWords.length)];
    }

    _firebaseService.restartGame(widget.roomId, newWord, players);
  }

  // --- KELİME GİRİŞİ VE ANLIK PUANLAMA ---
  void onWordSubmitted(String rawValue) {
    if (_isGameFinished || allWords.isEmpty) return;

    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    String langCode = langProvider.languageCode;
    String word = convertToLowerCase(rawValue.trim(), langCode);

    if (word.isEmpty) return;
    
    if (enteredWords.contains(word)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(langProvider.getText('duplicate')), duration: const Duration(milliseconds: 500)));
      _textController.clear();
      return;
    }

    // --- PUANLAMA ---
    // GameScreen'deki mantığı buraya anlık uyguluyoruz ki rakip puanı görsün
    bool isDictionaryWord = allWords.contains(word);
    bool isDerived = _isDerived(currentTargetWord, word, langCode);
    bool isLengthValid = word.length >= 3;

    setState(() {
      enteredWords.add(word);
      
      if (isDictionaryWord && isDerived && isLengthValid) {
        myScore += ScoreCalculator.calculateWordScore(word.length);
      } else {
        // Yanlış kelime sayısı hesaplamak için geçici liste
        int wrongCount = enteredWords.where((w) {
           bool d = allWords.contains(w);
           bool r = _isDerived(currentTargetWord, w, langCode);
           return !(d && r && w.length >= 3);
        }).length;
        
        myScore -= ScoreCalculator.calculatePenalty(wrongCount);
      }
    });

    _firebaseService.updateScoreAndWords(widget.roomId, widget.playerName, myScore, enteredWords);
    _textController.clear();
    _focusNode.requestFocus();
  }

  // --- HARF TÜRETME KONTROLÜ ---
  bool _isDerived(String main, String derived, String langCode) {
    var mainChars = convertToLowerCase(main, langCode).split('');
    var derivedChars = convertToLowerCase(derived, langCode).split('');
    
    for (var char in derivedChars) {
      if (mainChars.contains(char)) {
        mainChars.remove(char); 
      } else {
        return false;
      }
    }
    return true;
  }

  // --- SONUÇ EKRANI (GameScreen İLE AYNI GÖRSEL) ---
  void showGameOverDialog(Map<String, dynamic> data) {
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    String langCode = langProvider.languageCode;

    Map<String, dynamic> scores = data['scores'] ?? {};
    Map<String, dynamic> wordsMap = data['words'] ?? {};
    List players = data['players'] ?? [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(langProvider.getText('gameOver'), textAlign: TextAlign.center),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: players.map<Widget>((pName) {
              double pScore = (scores[pName] ?? 0).toDouble();
              List<dynamic> rawPWords = wordsMap[pName] ?? [];
              List<String> pWords = rawPWords.map((e) => e.toString()).toList();
              
              bool isMe = pName == widget.playerName;

              // Doğru/Yanlış ayrımını burada görselleştiriyoruz
              List<String> correct = [];
              List<String> wrong = [];

              for (String w in pWords) {
                 // allWords boşsa (sözlük yüklenmemişse) hata vermesin
                 if (allWords.isNotEmpty) {
                    bool d = allWords.contains(w);
                    bool r = _isDerived(currentTargetWord, w, langCode);
                    if (d && r && w.length >= 3) {
                      correct.add(w);
                    } else {
                      wrong.add(w);
                    }
                 } else {
                   // Sözlük yoksa hepsi gri kalsın (fallback)
                   wrong.add(w); 
                 }
              }

              return Card(
                color: isMe ? Colors.green.shade50 : Colors.grey.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    children: [
                      Text(
                        isMe ? "${langProvider.getText('yourName')} (Ben)" : pName, 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)
                      ),
                      Text(
                        "${pScore.toStringAsFixed(1)} Puan", 
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple, fontSize: 20)
                      ),
                      const Divider(),
                      
                      // DOĞRULAR
                      if (correct.isNotEmpty)
                      Wrap(
                        spacing: 4,
                        children: correct.map((w) => Chip(
                          label: Text(w, style: const TextStyle(fontSize: 10, color: Colors.black)),
                          backgroundColor: Colors.green.shade100,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        )).toList(),
                      ),

                      // YANLIŞLAR
                      if (wrong.isNotEmpty)
                      Wrap(
                        spacing: 4,
                        children: wrong.map((w) => Chip(
                          label: Text(w, style: const TextStyle(fontSize: 10, color: Colors.black, decoration: TextDecoration.lineThrough)),
                          backgroundColor: Colors.red.shade100,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        )).toList(),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); 
              Navigator.pop(context); // Lobiye dön
            },
            child: Text(langProvider.getText('menu'), style: const TextStyle(color: Colors.red)),
          ),
          if (widget.isHost)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                startNewRound(players);
              },
              child: Text(langProvider.getText('continue')),
            ),
          if (!widget.isHost)
             const Padding(
               padding: EdgeInsets.all(8.0),
               child: Text("Host bekleniyor...", style: TextStyle(fontSize: 12, color: Colors.grey)),
             )
        ],
      ),
    );
  }

  // ===== ONLINE_GAME_SCREEN.DART İÇİNDEKİ build() METODUNU BU KODLA DEĞİŞTİR =====
// (Dosyanın başındaki import'lar ve diğer metodlar AYNEN KALACAK)

@override
Widget build(BuildContext context) {
  final langProvider = Provider.of<LanguageProvider>(context);
  bool showTurkishChars = (langProvider.languageCode == 'tr');
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return Scaffold(
    body: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF141E30), const Color(0xFF243B55)]
              : [const Color(0xFF00d2ff), const Color(0xFF928DAB)],
        ),
      ),
      child: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: _firebaseService.getRoomStream(widget.roomId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 20),
                    Text(
                      langProvider.languageCode == 'tr' ? 'Yükleniyor...' : 'Loading...',
                      style: const TextStyle(color: Colors.white70, fontSize: 18),
                    ),
                  ],
                ),
              );
            }
            
            var data = snapshot.data!.data() as Map<String, dynamic>;
            String status = data['status'];
            String targetWordFromDB = data['targetWord'] ?? "";

            // ===== 1. BEKLEME EKRANI =====
            if (status == 'waiting') {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animasyonlu ikon
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.8, end: 1.2),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeInOut,
                      builder: (context, scale, child) {
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            padding: const EdgeInsets.all(40),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.2),
                                  Colors.white.withOpacity(0.1),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.hourglass_empty, size: 80, color: Colors.white),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 40),
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 25),
                    Text(
                      langProvider.languageCode == 'tr' ? 'Rakip Bekleniyor...' : 'Waiting for opponent...',
                      style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 40),
                    
                    // Oda kodu kartı
                    Container(
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.25),
                            Colors.white.withOpacity(0.15),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                      ),
                      child: Column(
                        children: [
                          Text(
                            langProvider.getText('roomCode'),
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SelectableText(
                            widget.roomId,
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            // KELİME DEĞİŞTİ Mİ?
            if (targetWordFromDB.isNotEmpty && currentTargetWord != targetWordFromDB) {
              currentTargetWord = targetWordFromDB;
              enteredWords.clear();
              myScore = 0;
              _textController.clear();
              _isGameFinished = false;
              _isTimerStarted = false;
            }

            // ===== 2. OYUN BAŞLADI =====
            if (status == 'playing' && !_isGameFinished) {
              if (!_isTimerStarted) {
                int dbDuration = data['gameDuration'] ?? 90;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  setState(() {
                    _remainingTime = dbDuration;
                  });
                  startLocalTimer();
                });
              }
            }

            // ===== 3. OYUN BİTTİ =====
            if (_isGameFinished) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDark
                        ? [const Color(0xFF000000), const Color(0xFF434343)]
                        : [const Color(0xFFee0979), const Color(0xFFff6a00)],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.emoji_events, size: 100, color: Colors.amber),
                      const SizedBox(height: 30),
                      Text(
                        langProvider.getText('gameOver'),
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 40),
                      ElevatedButton(
                        onPressed: () => showGameOverDialog(data),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 10,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.leaderboard, size: 28),
                            const SizedBox(width: 12),
                            Text(
                              langProvider.languageCode == 'tr' ? 'SONUÇLARI GÖR' : 'VIEW RESULTS',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // ===== 4. OYUN ARAYÜZÜ =====
            Map<String, dynamic> scores = data['scores'] ?? {};
            List players = data['players'] ?? [];

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // ===== ÜST BAR =====
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Geri butonu
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),

                      // Zaman
                      _buildOnlineInfoCard(
                        icon: Icons.timer_outlined,
                        label: langProvider.getText('time'),
                        value: '$_remainingTime',
                        color: Colors.red,
                      ),

                      // Girilen
                      _buildOnlineInfoCard(
                        icon: Icons.edit_note,
                        label: langProvider.getText('entered'),
                        value: '${enteredWords.length}',
                        color: Colors.blue,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ===== SKORBOARD (OYUNCULAR) =====
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.2),
                          Colors.white.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: players.map<Widget>((pName) {
                        double pScore = (scores[pName] ?? 0).toDouble();
                        bool isMe = pName == widget.playerName;
                        
                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isMe
                                    ? [const Color(0xFF11998e), const Color(0xFF38ef7d)]
                                    : [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.1)],
                              ),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: isMe ? Colors.greenAccent : Colors.white.withOpacity(0.2),
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  isMe ? Icons.person : Icons.person_outline,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  isMe ? '${langProvider.getText('yourName')} (Sen)' : pName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '${pScore.toStringAsFixed(1)} 🏆',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ===== HEDEF KELİME =====
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.25),
                          Colors.white.withOpacity(0.15),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        currentTargetWord.split('').join('  '),
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 6,
                          shadows: [
                            Shadow(
                              color: Colors.black38,
                              offset: Offset(0, 3),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ===== GİRİŞ ALANI =====
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: langProvider.getText('hint'),
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        suffixIcon: Container(
                          margin: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFf093fb), Color(0xFFf5576c)],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                      onChanged: (text) {
                        if (text.endsWith(' ')) onWordSubmitted(text);
                      },
                      onSubmitted: onWordSubmitted,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ===== TÜRKÇE HARFLER =====
                  if (showTurkishChars)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: ['Ç', 'Ğ', 'I', 'İ', 'Ö', 'Ş', 'Ü'].map((harf) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: _buildOnlineLetterButton(harf, langProvider.languageCode),
                          );
                        }).toList(),
                      ),
                    ),

                  const SizedBox(height: 15),
                  
                  Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.0),
                          Colors.white.withOpacity(0.3),
                          Colors.white.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),
                  
                  Text(
                    langProvider.getText('added'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),

                  // ===== KELİME LİSTESİ =====
                  Expanded(
                    child: enteredWords.isEmpty
                        ? Center(
                            child: Text(
                              langProvider.languageCode == 'tr'
                                  ? '🚀 Hadi başla!'
                                  : '🚀 Let\'s start!',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 18,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: enteredWords.length,
                            itemBuilder: (context, index) {
                              final reversedIndex = enteredWords.length - 1 - index;
                              return TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.0, end: 1.0),
                                duration: Duration(milliseconds: 300 + (index * 40)),
                                curve: Curves.easeOut,
                                builder: (context, value, child) {
                                  return Transform.translate(
                                    offset: Offset(0, 20 * (1 - value)),
                                    child: Opacity(opacity: value, child: child),
                                  );
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withOpacity(0.2),
                                        Colors.white.withOpacity(0.1),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                                          ),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${reversedIndex + 1}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          enteredWords[reversedIndex],
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 17,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 22),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}

// ===== YARDIMCI WIDGET'LAR (class içine en sona ekle) =====

Widget _buildOnlineInfoCard({
  required IconData icon,
  required String label,
  required String value,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.white.withOpacity(0.2),
          Colors.white.withOpacity(0.1),
        ],
      ),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: Colors.white.withOpacity(0.3)),
    ),
    child: Column(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7)),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    ),
  );
}

Widget _buildOnlineLetterButton(String harf, String langCode) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () {
        String currentText = _textController.text;
        TextSelection selection = _textController.selection;
        String harfEkle = convertToLowerCase(harf, langCode);

        String newText;
        int newCursorPos;

        if (selection.start >= 0) {
          newText = currentText.replaceRange(selection.start, selection.end, harfEkle);
          newCursorPos = selection.start + harfEkle.length;
        } else {
          newText = currentText + harfEkle;
          newCursorPos = newText.length;
        }

        _textController.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newCursorPos),
        );
        _focusNode.requestFocus();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.25),
              Colors.white.withOpacity(0.15),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.4)),
        ),
        child: Center(
          child: Text(
            harf,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 19,
              color: Colors.white,
            ),
          ),
        ),
      ),
    ),
  );
}
}