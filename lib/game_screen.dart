import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:kelime_turetmece/theme_provider.dart';
import 'package:kelime_turetmece/score_calculator.dart';
import 'package:kelime_turetmece/language_provider.dart';
import 'package:kelime_turetmece/user_data_service.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  String targetWord = ""; 
  List<String> allWords = [];
  List<String> enteredWords = []; 
  
  List<String> correctWords = []; 
  List<String> wrongWords = [];   

  int shuffleCount = 0;
  bool hasUsedShuffle = false;
  
  double totalScore = 0;
  int remainingTime = 0;
  Timer? timer;
  
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode(); 
  bool isLoading = true;

 @override
void initState() {
  super.initState();
  final provider = Provider.of<ThemeProvider>(context, listen: false);
  remainingTime = provider.gameDuration;
  
  loadWordsAndStartGame();
  _loadShuffleCount(); // ✅ ZATEN VAR
}

  Future<void> _loadShuffleCount() async {
    int count = await UserDataService.getShuffleCount();
    setState(() {
      shuffleCount = count;
    });
  }

  @override
  void dispose() {
    timer?.cancel(); 
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String convertToLowerCase(String input, String langCode) {
    if (langCode == 'tr') {
      return input.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
    } else {
      return input.toLowerCase();
    }
  }

  Future<void> loadWordsAndStartGame() async {
  try {
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    String langCode = langProvider.languageCode;
    
    String fileName = (langCode == 'tr') ? 'assets/words.json' : 'assets/words_en.json';

    debugPrint("📂 Dosya yükleniyor: $fileName"); // LOG EKLE

    final String response = await rootBundle.loadString(fileName);
    
    debugPrint("✅ Dosya yüklendi, boyut: ${response.length}"); // LOG EKLE
    
    final dynamic decodedData = json.decode(response);
    
    List<String> rawWordList = [];

    if (decodedData is Map) {
      rawWordList = decodedData.keys.map((k) => k.toString()).toList();
      debugPrint("📦 Map formatı, ${rawWordList.length} kelime"); // LOG EKLE
    } else if (decodedData is List) {
      rawWordList = decodedData.map((e) {
         if (e is Map && e.containsKey('word')) {
           return e['word'].toString();
         }
         return e.toString();
      }).toList();
      debugPrint("📦 List formatı, ${rawWordList.length} kelime"); // LOG EKLE
    }

    if (!mounted) return;

    setState(() {
      allWords = rawWordList.map((kelime) {
        return convertToLowerCase(kelime.trim(), langCode);
      })
      .where((kelime) => !kelime.contains(' '))
      .toList();
      
      debugPrint("🎯 ${allWords.length} kelime işlendi"); // LOG EKLE
      
      selectNewTargetWord();
      
      debugPrint("🎲 Seçilen kelime: $targetWord"); // LOG EKLE
      
      isLoading = false;
    });
    
    startTimer();
    
  } catch (e, stackTrace) {
    debugPrint("❌ HATA: $e");
    debugPrint("📍 StackTrace: $stackTrace");
    
    if (mounted) {
      setState(() {
        targetWord = "teknoloji"; // Yedek kelime
        isLoading = false;
      });
      
      // KULLANICIYA GÖSTER
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Sözlük yüklenemedi! Hata: $e"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}

  void selectNewTargetWord() {
    List<String> longWords = allWords.where((word) => word.length >= 7).toList();
    if (longWords.isNotEmpty) {
      targetWord = longWords[Random().nextInt(longWords.length)];
    } else {
      targetWord = "programlama";
    }
  }

  void startTimer() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingTime > 0) {
        setState(() {
          remainingTime--;
        });
      } else {
        timer.cancel();
        finishGame();
      }
    });
  }

  void startNewRound() {
  setState(() {
    enteredWords.clear();
    correctWords.clear();
    wrongWords.clear();
    totalScore = 0;
    _textController.clear();
    hasUsedShuffle = false;
    
    final provider = Provider.of<ThemeProvider>(context, listen: false);
    remainingTime = provider.gameDuration;

    selectNewTargetWord();
  });

  _loadShuffleCount(); // ✅ YENİ TURDA GÜNCELLE
  startTimer();
  
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _focusNode.requestFocus();
  });
}

  void onWordSubmitted(String rawInput) {
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    String langCode = langProvider.languageCode;

    List<String> candidates = rawInput.split(' ');

    for (String word in candidates) {
      String lowerWord = convertToLowerCase(word.trim(), langCode);

      if (lowerWord.isEmpty) continue;

      if (enteredWords.contains(lowerWord)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(langProvider.getText('duplicate')),
            duration: const Duration(milliseconds: 500),
          ),
        );
        continue; 
      }

      setState(() {
        enteredWords.add(lowerWord); 
      });
    }
    
    _textController.clear();
    _focusNode.requestFocus();
  }

  void finishGame() async {
    double tempScore = 0;
    int wrongCount = 0;
    
    correctWords.clear();
    wrongWords.clear();

    for (String word in enteredWords) {
      bool isDictionaryWord = allWords.contains(word);
      bool isDerived = isValidDerivation(targetWord, word);
      bool isLengthValid = word.length >= 3;

      if (isDictionaryWord && isDerived && isLengthValid) {
        correctWords.add(word);
        tempScore += ScoreCalculator.calculateWordScore(word.length);
      } else {
        wrongWords.add(word);
        wrongCount++;
        tempScore -= ScoreCalculator.calculatePenalty(wrongCount);
      }
    }

    setState(() {
      totalScore = tempScore;
    });

    int earnedCoins = 0;
    if (totalScore > 0) {
      earnedCoins = totalScore.round();
      await UserDataService.addCoins(earnedCoins);
    }

    showResultsDialog(earnedCoins);
  }

  bool isValidDerivation(String mainWord, String derivedWord) {
    List<String> mainChars = mainWord.split('');
    List<String> derivedChars = derivedWord.split('');

    for (var char in derivedChars) {
      if (mainChars.contains(char)) {
        mainChars.remove(char);
      } else {
        return false;
      }
    }
    return true;
  }
  void showResultsDialog(int earnedCoins) {
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: Theme.of(context).brightness == Brightness.dark
                  ? [const Color(0xFF1a1a2e), const Color(0xFF16213e), const Color(0xFF0f3460)]
                  : [const Color(0xFF667eea), const Color(0xFF764ba2), const Color(0xFFf093fb)],
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Colors.amber.shade300, Colors.orange.shade400],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withOpacity(0.5),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.emoji_events, size: 40, color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      langProvider.getText('gameOver'),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 22),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '${langProvider.getText('totalScore')} ${totalScore.toStringAsFixed(1)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (earnedCoins > 0) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFffd700), Color(0xFFffed4e)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.monetization_on, color: Colors.orange, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              '+$earnedCoins Coin!',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (correctWords.isNotEmpty) ...[
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                langProvider.getText('correct'),
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${correctWords.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6.0,
                          runSpacing: 6.0,
                          children: correctWords.map((w) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.green.shade400, Colors.green.shade600],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                w,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                      ],
                      if (wrongWords.isNotEmpty) ...[
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.cancel, color: Colors.red, size: 20),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                langProvider.getText('wrong'),
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${wrongWords.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6.0,
                          runSpacing: 6.0,
                          children: wrongWords.map((w) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.red.shade400, Colors.red.shade600],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                w,
                                style: const TextStyle(
                                  color: Colors.white,
                                  decoration: TextDecoration.lineThrough,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      if (correctWords.isEmpty && wrongWords.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(30),
                            child: Text(
                              langProvider.languageCode == 'tr'
                                  ? '😔 Hiç kelime girmedin!'
                                  : '😔 No words entered!',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).pop();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Colors.white.withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                            side: BorderSide(color: Colors.white.withOpacity(0.3)),
                          ),
                        ),
                        child: Text(
                          langProvider.getText('menu'),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          startNewRound();
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.deepPurple,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: Text(
                          langProvider.getText('continue'),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

 @override
Widget build(BuildContext context) {
  final langProvider = Provider.of<LanguageProvider>(context);
  bool showTurkishChars = (langProvider.languageCode == 'tr');
  final isDark = Theme.of(context).brightness == Brightness.dark;

  if (isLoading) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF1a1a2e), const Color(0xFF16213e)]
                : [const Color(0xFF667eea), const Color(0xFF764ba2)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 20),
              Text(
                'Kelimeler yükleniyor...',
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== HATA KONTROLÜ EKLE =====
  if (targetWord.isEmpty) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1a1a2e), const Color(0xFF16213e)]
                : [const Color(0xFF667eea), const Color(0xFF764ba2)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: 20),
              const Text(
                'Kelime yüklenemedi!',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    isLoading = true;
                  });
                  loadWordsAndStartGame();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Yeniden Dene'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Ana Menü'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  return Scaffold(
    body: Container(
      width: double.infinity, // ← BU EKLENMELİ
      height: double.infinity, // ← BU EKLENMELİ
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF0f2027), const Color(0xFF203a43), const Color(0xFF2c5364)]
              : [const Color(0xFF00d2ff), const Color(0xFF3a7bd5)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // ÜST BAR
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
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
                  _buildInfoCard(
                    icon: Icons.timer_outlined,
                    label: langProvider.getText('time'),
                    value: '$remainingTime',
                    color: Colors.red,
                  ),
                  _buildInfoCard(
                    icon: Icons.edit_note,
                    label: langProvider.getText('entered'),
                    value: '${enteredWords.length}',
                    color: Colors.blue,
                  ),
                ],
              ),

              const SizedBox(height: 30),

Container(
  width: double.infinity,
  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [
        Colors.white.withOpacity(0.2),
        Colors.white.withOpacity(0.1),
      ],
    ),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: Colors.white.withOpacity(0.3)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 20,
        spreadRadius: 5,
      ),
    ],
  ),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        targetWord.split('').join('  '),
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 4,
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      const SizedBox(height: 15),
      
      // ===== BUTONLAR (DÜZELTME) =====
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ===== SHUFFLE BUTONU (DÜZELTME) =====
          if (shuffleCount > 0 && !hasUsedShuffle) ...[
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFffd700), Color(0xFFffed4e)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.5),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.shuffle, color: Colors.black87, size: 28),
                onPressed: () async {
                  bool used = await UserDataService.useShuffle();
                  if (used) {
                    setState(() {
                      List<String> chars = targetWord.split('');
                      chars.shuffle();
                      targetWord = chars.join('');
                      hasUsedShuffle = true;
                      shuffleCount--; // ✅ YENİ: Görsel olarak azalt
                    });
                    
                    // İsteğe bağlı: Feedback göster
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          Provider.of<LanguageProvider>(context, listen: false).languageCode == 'tr'
                              ? '✨ Harfler karıştırıldı!'
                              : '✨ Letters shuffled!',
                        ),
                        duration: const Duration(milliseconds: 800),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.amber,
                      ),
                    );
                  }
                },
                tooltip: 'Karıştır (x$shuffleCount)', // ✅ YENİ: Tooltip
              ),
            ),
            const SizedBox(width: 10),
          ],
          
          // ===== YENİLEME BUTONU =====
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFf093fb), Color(0xFFf5576c)],
              ),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 28),
              onPressed: startNewRound,
              tooltip: 'Yeni Tur',
            ),
          ),
        ],
      ),
    ],
  ),
),

              const SizedBox(height: 30),

              // GİRİŞ ALANI
              Container(
                width: double.infinity, // ← EKLENMELİ
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
                          colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: onWordSubmitted,
                  onChanged: (text) {
                    if (text.endsWith(' ')) {
                      onWordSubmitted(text);
                    }
                  },
                ),
              ),

              const SizedBox(height: 15),

              if (showTurkishChars)
                SizedBox(
                  width: double.infinity, // ← EKLENMELİ
                  height: 50, // ← EKLENMELİ
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: ['Ç', 'Ğ', 'I', 'İ', 'Ö', 'Ş', 'Ü'].map((harf) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: _buildLetterButton(harf, langProvider.languageCode),
                      );
                    }).toList(),
                  ),
                ),

              const SizedBox(height: 20),

              Container(
                width: double.infinity, // ← EKLENMELİ
                height: 2,
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

              const SizedBox(height: 10),

              Expanded(
                child: enteredWords.isEmpty
                    ? Center(
                        child: Text(
                          langProvider.languageCode == 'tr'
                              ? '🎯 Kelime yazmaya başla!'
                              : '🎯 Start typing words!',
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
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(16),
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
                                  width: 40,
                                  height: 40,
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
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Text(
                                    enteredWords[reversedIndex],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.pending_outlined, color: Colors.white70, size: 20),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
              shadows: const [
                Shadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLetterButton(String harf, String langCode) {
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
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.25),
                Colors.white.withOpacity(0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              harf,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}