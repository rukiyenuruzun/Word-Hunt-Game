// market_screen.dart - YENİ DOSYA OLUŞTUR

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kelime_turetmece/user_data_service.dart';
import 'package:kelime_turetmece/language_provider.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> with SingleTickerProviderStateMixin {
  int totalCoins = 0;
  int shuffleCount = 0;
  bool isLoading = true;

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
    _loadData();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    int coins = await UserDataService.getTotalCoins();
    int shuffles = await UserDataService.getShuffleCount();
    
    setState(() {
      totalCoins = coins;
      shuffleCount = shuffles;
      isLoading = false;
    });
  }

  Future<void> _buyShuffle() async {
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    
    bool success = await UserDataService.spendCoins(30);
    
    if (success) {
      await UserDataService.addShuffle(1);
      await _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              langProvider.languageCode == 'tr' 
                  ? '✅ Karıştırma satın alındı!' 
                  : '✅ Shuffle purchased!',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              langProvider.languageCode == 'tr' 
                  ? '❌ Yetersiz coin!' 
                  : '❌ Not enough coins!',
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
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
                ? [const Color(0xFF1a1a2e), const Color(0xFF16213e), const Color(0xFF0f3460)]
                : [const Color(0xFFf093fb), const Color(0xFFf5576c), const Color(0xFFffd700)],
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
                      const Icon(Icons.store, color: Colors.white, size: 32),
                      const SizedBox(width: 10),
                      Text(
                        langProvider.languageCode == 'tr' ? 'Market' : 'Store',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      // COIN BAKİYESİ
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFffd700), Color(0xFFffed4e)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.monetization_on, color: Colors.orange, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              '$totalCoins',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ===== İÇERİK =====
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator(color: Colors.white))
                      : ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            // SAHIP OLUNAN GÜÇLER
                            _buildInventoryCard(langProvider),

                            const SizedBox(height: 30),

                            // SATIN ALINABİLİR ÜRÜNLER BAŞLIĞI
                            Text(
                              langProvider.languageCode == 'tr' 
                                  ? '🛒 Satın Alınabilir Güçler' 
                                  : '🛒 Available Power-Ups',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),

                            const SizedBox(height: 15),

                            // KARIŞTIRMA ÜRÜNLERİ
                            _buildProductCard(
                              icon: Icons.shuffle,
                              title: langProvider.languageCode == 'tr' 
                                  ? 'Karıştırma' 
                                  : 'Shuffle',
                              description: langProvider.languageCode == 'tr'
                                  ? 'Hedef kelimenin harflerini karıştırır'
                                  : 'Shuffles the letters of target word',
                              price: 30,
                              onBuy: _buyShuffle,
                              langProvider: langProvider,
                            ),

                            // İLERİDE DİĞER GÜÇLER BURAYA EKLENEBİLİR
                            // Örnek:
                            // _buildProductCard(
                            //   icon: Icons.lightbulb,
                            //   title: 'İpucu',
                            //   description: 'Rastgele bir kelime önerir',
                            //   price: 200,
                            //   onBuy: _buyHint,
                            // ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===== ENVANTER KARTI =====
  Widget _buildInventoryCard(LanguageProvider lang) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Text(
                lang.languageCode == 'tr' ? 'Envanterim' : 'My Inventory',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          _buildInventoryItem(
            icon: Icons.shuffle,
            name: lang.languageCode == 'tr' ? 'Karıştırma' : 'Shuffle',
            count: shuffleCount,
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryItem({
    required IconData icon,
    required String name,
    required int count,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.yellowAccent, size: 24),
          const SizedBox(width: 12),
          Text(
            name,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.greenAccent),
            ),
            child: Text(
              'x$count',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== ÜRÜN KARTI =====
  Widget _buildProductCard({
    required IconData icon,
    required String title,
    required String description,
    required int price,
    required VoidCallback onBuy,
    required LanguageProvider langProvider,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
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
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // IKON
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),

            const SizedBox(width: 15),

            // AÇIKLAMA
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // SATIN AL BUTONU
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onBuy,
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFffd700), Color(0xFFffed4e)],
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.monetization_on, color: Colors.orange, size: 20),
                      const SizedBox(height: 2),
                      Text(
                        '$price',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}