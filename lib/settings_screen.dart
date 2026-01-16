// ===== SETTINGS_SCREEN.DART - TAMAMEN BU KODLA DEĞİŞTİR =====

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kelime_turetmece/theme_provider.dart';
import 'package:kelime_turetmece/language_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // Kurallar penceresi
  void _showRulesDialog(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: Theme.of(context).brightness == Brightness.dark
                    ? [const Color(0xFF1a1a2e), const Color(0xFF16213e)]
                    : [const Color(0xFF667eea), const Color(0xFF764ba2)],
              ),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Başlık
                Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(25),
                      topRight: Radius.circular(25),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.white, size: 32),
                      const SizedBox(width: 15),
                      Text(
                        langProvider.getText('rules'),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                // İçerik
                Container(
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(25),
                    child: Text(
                      langProvider.getText('rulesContent'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.6,
                      ),
                    ),
                  ),
                ),

                // Kapat butonu
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.deepPurple,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      'Tamam / OK',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final langProvider = Provider.of<LanguageProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF2c3e50), const Color(0xFF34495e)]
                : [const Color(0xFF4facfe), const Color(0xFF00f2fe)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
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
                        const Icon(Icons.settings, color: Colors.white, size: 32),
                        const SizedBox(width: 10),
                        Text(
                          langProvider.getText('settings'),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ===== İÇERİK =====
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        // ===== DİL SEÇİMİ =====
                        _buildSectionCard(
                          title: langProvider.getText('language'),
                          icon: Icons.language,
                          children: [
                            _buildRadioTile(
                              title: 'Türkçe 🇹🇷',
                              value: 'tr',
                              groupValue: langProvider.languageCode,
                              onChanged: (value) => langProvider.setLanguage(value!),
                            ),
                            _buildRadioTile(
                              title: 'English 🇬🇧',
                              value: 'en',
                              groupValue: langProvider.languageCode,
                              onChanged: (value) => langProvider.setLanguage(value!),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // ===== OYUN SÜRESİ =====
                        _buildSectionCard(
                          title: langProvider.getText('time'),
                          icon: Icons.timer,
                          children: [
                            _buildRadioTile(
                              title: '60 ${langProvider.languageCode == 'tr' ? 'saniye' : 'seconds'}',
                              value: 60,
                              groupValue: themeProvider.gameDuration,
                              onChanged: (value) => themeProvider.setDuration(value!),
                            ),
                            _buildRadioTile(
                              title: '90 ${langProvider.languageCode == 'tr' ? 'saniye' : 'seconds'} (Default)',
                              value: 90,
                              groupValue: themeProvider.gameDuration,
                              onChanged: (value) => themeProvider.setDuration(value!),
                            ),
                            _buildRadioTile(
                              title: '120 ${langProvider.languageCode == 'tr' ? 'saniye' : 'seconds'}',
                              value: 120,
                              groupValue: themeProvider.gameDuration,
                              onChanged: (value) => themeProvider.setDuration(value!),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // ===== DİĞER AYARLAR =====
                        _buildSectionCard(
                          title: langProvider.languageCode == 'tr' ? 'Diğer' : 'Other',
                          icon: Icons.tune,
                          children: [
                            // Nasıl Oynanır
                            _buildActionTile(
                              icon: Icons.info_outline,
                              title: langProvider.getText('rules'),
                              subtitle: langProvider.languageCode == 'tr' 
                                  ? 'Oyun kurallarını öğren' 
                                  : 'Learn game rules',
                              onTap: () => _showRulesDialog(context),
                            ),

                            const Divider(color: Colors.white24, height: 1),

                            // Karanlık Mod
                            _buildSwitchTile(
                              icon: themeProvider.themeMode == ThemeMode.dark 
                                  ? Icons.dark_mode 
                                  : Icons.light_mode,
                              title: langProvider.languageCode == 'tr' 
                                  ? 'Karanlık Mod' 
                                  : 'Dark Mode',
                              value: themeProvider.themeMode == ThemeMode.dark,
                              onChanged: (value) {
                                themeProvider.setThemeMode(
                                  value ? ThemeMode.dark : ThemeMode.light,
                                );
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 30),

                        // ===== VERSİYON BİLGİSİ =====
                        Center(
                          child: Text(
                            'v1.0.0',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 14,
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
        ),
      ),
    );
  }

  // ===== BÖLÜM KARTI =====
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
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
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 15),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          // İçerik
          ...children,
        ],
      ),
    );
  }

  // ===== RADIO TILE =====
  Widget _buildRadioTile<T>({
    required String title,
    required T value,
    required T groupValue,
    required ValueChanged<T?> onChanged,
  }) {
    bool isSelected = value == groupValue;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withOpacity(0.15) : Colors.transparent,
            border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.greenAccent : Colors.white54,
                    width: 2,
                  ),
                  color: isSelected ? Colors.greenAccent : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== ACTION TILE =====
  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: Colors.white70, size: 28),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  // ===== SWITCH TILE =====
  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 28),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.greenAccent,
            activeTrackColor: Colors.green.withOpacity(0.5),
          ),
        ],
      ),
    );
  }
}