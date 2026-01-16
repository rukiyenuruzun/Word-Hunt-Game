// ===== LOBBY_SCREEN.DART - TAMAMEN BU KODLA DEĞİŞTİR =====

import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:kelime_turetmece/firebase_service.dart';
import 'package:kelime_turetmece/online_game_screen.dart';
import 'package:kelime_turetmece/language_provider.dart';
import 'package:kelime_turetmece/theme_provider.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _roomCodeController = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();
  bool isLoading = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _roomCodeController.dispose();
    super.dispose();
  }

  // ODA OLUŞTURMA
  void _createRoom(LanguageProvider lang) async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang.getText('enterNameErr')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      int selectedDuration = themeProvider.gameDuration;

      String fileName = (lang.languageCode == 'tr') ? 'assets/words.json' : 'assets/words_en.json';
      final String response = await rootBundle.loadString(fileName);
      final dynamic decodedData = json.decode(response);
      
      List<String> allWords = [];

      if (decodedData is Map) {
        allWords = decodedData.keys.map((k) => k.toString()).toList();
      } else if (decodedData is List) {
        allWords = decodedData.map((e) {
             if (e is Map && e.containsKey('word')) return e['word'].toString();
             return e.toString();
        }).toList();
      }

      List<String> longWords = allWords
          .map((e) => e.trim())
          .where((w) => w.length >= 7 && !w.contains(' '))
          .toList();

      String targetWord = "teknoloji";
      if (longWords.isNotEmpty) {
        targetWord = longWords[Random().nextInt(longWords.length)];
      }

      String? roomId = await _firebaseService.createRoom(
        _nameController.text.trim(), 
        targetWord,
        selectedDuration 
      );

      if (!mounted) return;
      setState(() => isLoading = false);

      if (roomId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => OnlineGameScreen(
            roomId: roomId, 
            playerName: _nameController.text.trim(),
            isHost: true, 
          )),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.getText('error')),
            backgroundColor: Colors.red,
          ),
        );
      }

    } catch (e) {
      debugPrint("Oda kurma hatası: $e");
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sözlük yüklenemedi!")),
      );
    }
  }

  // ODAYA KATILMA
  void _joinRoom(LanguageProvider lang) async {
    if (_nameController.text.isEmpty || _roomCodeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang.getText('enterAllErr')),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    bool success = await _firebaseService.joinRoom(
      _roomCodeController.text.trim(),
      _nameController.text.trim(),
    );

    if (!mounted) return;
    setState(() => isLoading = false);

    if (success) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => OnlineGameScreen(
          roomId: _roomCodeController.text.trim(), 
          playerName: _nameController.text.trim(),
          isHost: false, 
        )),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang.getText('roomNotFound')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF1e3c72), const Color(0xFF2a5298)]
                : [const Color(0xFF4facfe), const Color(0xFF00f2fe)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                // ===== HEADER =====
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
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
                      const SizedBox(width: 15),
                      Text(
                        langProvider.getText('lobbyTitle'),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),

                        // ===== İKON =====
                        Container(
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.groups_rounded,
                            size: 80,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // ===== AD GİRİŞİ =====
                        _buildModernTextField(
                          controller: _nameController,
                          label: langProvider.getText('yourName'),
                          icon: Icons.person,
                          hint: langProvider.languageCode == 'tr' ? 'Adınızı girin' : 'Enter your name',
                        ),

                        const SizedBox(height: 40),

                        // ===== ODA OLUŞTUR BUTONU =====
                        if (isLoading)
                          const CircularProgressIndicator(color: Colors.white)
                        else
                          _buildActionButton(
                            label: langProvider.getText('createRoomBtn'),
                            icon: Icons.add_circle_outline,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                            ),
                            onPressed: () => _createRoom(langProvider),
                          ),

                        const SizedBox(height: 30),

                        // ===== AYRAÇ =====
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 1,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.white.withOpacity(0.5),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 15),
                              child: Text(
                                langProvider.languageCode == 'tr' ? 'VEYA' : 'OR',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 1,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withOpacity(0.5),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 30),

                        // ===== ODA KODU GİRİŞİ =====
                        _buildModernTextField(
                          controller: _roomCodeController,
                          label: langProvider.getText('roomCode'),
                          icon: Icons.vpn_key,
                          hint: langProvider.languageCode == 'tr' ? '6 haneli kod' : '6-digit code',
                          keyboardType: TextInputType.number,
                        ),

                        const SizedBox(height: 20),

                        // ===== ODAYA KATIL BUTONU =====
                        if (!isLoading)
                          _buildActionButton(
                            label: langProvider.getText('joinRoomBtn'),
                            icon: Icons.login,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
                            ),
                            onPressed: () => _joinRoom(langProvider),
                          ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===== MODERN TEXT FIELD =====
  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    TextInputType? keyboardType,
  }) {
    return Container(
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
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontWeight: FontWeight.w500,
          ),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
          prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.8)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(20),
        ),
      ),
    );
  }

  // ===== MODERN BUTON =====
  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(25),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}