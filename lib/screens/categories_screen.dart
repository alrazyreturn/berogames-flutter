import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:provider/provider.dart';
import '../models/category_model.dart';
import '../providers/user_provider.dart';
import '../services/game_service.dart';
import '../services/energy_service.dart';
import '../services/ad_service.dart';
import 'game_screen.dart';

// ─── Neon-Glass palette ───────────────────────────────────────────────────────
const _cBg      = Color(0xFF0B1326);
const _cSurface = Color(0xFF131B2E);
const _cCard    = Color(0xFF171F33);
const _cCyan    = Color(0xFF00FBFB);
const _cIndigo  = Color(0xFF6366F1);

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final _gameService   = GameService();
  final _energyService = EnergyService();
  late Future<List<CategoryModel>> _future;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _future = _gameService.getCategories(lang: context.locale.languageCode);
    }
  }

  void _reload() {
    setState(() {
      _future = _gameService.getCategories(lang: context.locale.languageCode);
    });
  }

  // ─── Navigate to game (direct) ────────────────────────────────────────────
  void _navigateToGame(CategoryModel category) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GameScreen(category: category)),
    );
  }

  // ─── Handle category tap ──────────────────────────────────────────────────
  void _onCategoryTap(CategoryModel category) {
    if (category.isPremium) {
      _showPremiumGate(category);
    } else {
      _navigateToGame(category);
    }
  }

  // ─── Premium gate bottom sheet ────────────────────────────────────────────
  void _showPremiumGate(CategoryModel category) {
    final lang = context.locale.languageCode;
    showModalBottomSheet(
      context:           context,
      backgroundColor:   Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _PremiumGateSheet(
        category:      category,
        lang:          lang,
        onWatchAd:     () => _handleWatchAd(ctx, category),
        onUseEnergy:   () => _handleUseEnergy(ctx, category),
      ),
    );
  }

  // ─── Watch rewarded ad → enter category ──────────────────────────────────
  void _handleWatchAd(BuildContext sheetCtx, CategoryModel category) {
    Navigator.pop(sheetCtx); // close sheet first
    AdService().showRewarded(
      onRewarded: () {
        if (mounted) { _navigateToGame(category); }
      },
    );
  }

  // ─── Use 1 energy → enter category ───────────────────────────────────────
  Future<void> _handleUseEnergy(BuildContext sheetCtx, CategoryModel category) async {
    final token = context.read<UserProvider>().token;
    if (token == null) return;

    Navigator.pop(sheetCtx); // close sheet

    try {
      final result = await _energyService.consumeEnergy(token);
      final canPlay = result['can_play'] as bool? ?? false;
      if (!mounted) return;
      if (canPlay) {
        _navigateToGame(category);
      } else {
        _showSnack('categories.no_energy'.tr(), isError: true);
      }
    } catch (_) {
      if (mounted) { _showSnack('categories.no_energy'.tr(), isError: true); }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError
            ? Colors.redAccent.withValues(alpha: 0.85)
            : _cCyan.withValues(alpha: 0.85),
        behavior:     SnackBarBehavior.floating,
        shape:        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content:      Text(msg, style: const TextStyle(color: Colors.white)),
        duration:     const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cBg,
      body: SafeArea(
        child: Column(
          children: [
            // ─── Header ──────────────────────────────────────────────────
            _buildHeader(),
            // ─── Grid ────────────────────────────────────────────────────
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height:  64,
      color:   _cSurface,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_forward_ios_rounded, color: _cCyan, size: 20),
          ),
          Expanded(
            child: Text(
              'categories.title'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color:      Colors.white,
                fontSize:   17,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return FutureBuilder<List<CategoryModel>>(
      future: _future,
      builder: (context, snapshot) {

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: _cCyan, strokeWidth: 2),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, color: Colors.white24, size: 56),
                const SizedBox(height: 16),
                Text(
                  'categories.load_error'.tr(),
                  style: const TextStyle(color: Colors.white54, fontSize: 15),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _reload,
                  icon:  const Icon(Icons.refresh, color: _cCyan),
                  label: Text('common.retry'.tr(),
                    style: const TextStyle(color: _cCyan)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _cCyan),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          );
        }

        final categories = snapshot.data ?? [];

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: GridView.builder(
            itemCount: categories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount:    2,
              crossAxisSpacing:  14,
              mainAxisSpacing:   14,
              childAspectRatio:  1.0,
            ),
            itemBuilder: (context, i) => _CategoryCard(
              category: categories[i],
              lang:     context.locale.languageCode,
              onTap:    () => _onCategoryTap(categories[i]),
            ),
          ),
        );
      },
    );
  }
}

// ─── Category card ────────────────────────────────────────────────────────────
class _CategoryCard extends StatelessWidget {
  final CategoryModel category;
  final String        lang;
  final VoidCallback  onTap;

  const _CategoryCard({
    required this.category,
    required this.lang,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = category.color;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color:        _cCard,
          borderRadius: BorderRadius.circular(20),
          border:       Border.all(color: color.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color:     color.withValues(alpha: 0.06),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Stack(
          children: [
            // ── Main content ──
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon circle
                Container(
                  width:  70,
                  height: 70,
                  decoration: BoxDecoration(
                    color:  color.withValues(alpha: 0.14),
                    shape:  BoxShape.circle,
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Center(
                    child: Text(
                      category.icon,
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    category.localizedName(lang),
                    textAlign: TextAlign.center,
                    maxLines:  2,
                    overflow:  TextOverflow.ellipsis,
                    style: TextStyle(
                      color:      color,
                      fontSize:   15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            // ── Premium badge (top corner) ──
            if (category.isPremium)
              Positioned(
                top:   10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF5A623), Color(0xFFFFD700)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color:     const Color(0xFFF5A623).withValues(alpha: 0.4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_rounded, size: 10, color: Colors.white),
                      SizedBox(width: 3),
                      Text('VIP',
                        style: TextStyle(
                          color:      Colors.white,
                          fontSize:   9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Premium gate bottom sheet ────────────────────────────────────────────────
class _PremiumGateSheet extends StatelessWidget {
  final CategoryModel category;
  final String        lang;
  final VoidCallback  onWatchAd;
  final VoidCallback  onUseEnergy;

  const _PremiumGateSheet({
    required this.category,
    required this.lang,
    required this.onWatchAd,
    required this.onUseEnergy,
  });

  @override
  Widget build(BuildContext context) {
    final color = category.color;

    return Container(
      decoration: const BoxDecoration(
        color:        _cSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width:  40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color:        Colors.white12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Category icon
          Container(
            width:  80,
            height: 80,
            decoration: BoxDecoration(
              color:  color.withValues(alpha: 0.14),
              shape:  BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color:     color.withValues(alpha: 0.2),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Text(category.icon, style: const TextStyle(fontSize: 36)),
            ),
          ),
          const SizedBox(height: 14),

          // Title
          Text(
            category.localizedName(lang),
            style: TextStyle(
              color:      color,
              fontSize:   19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),

          // Premium badge pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF5A623), Color(0xFFFFD700)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_rounded, size: 12, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  'categories.premium_badge'.tr(),
                  style: const TextStyle(
                    color:      Colors.white,
                    fontSize:   12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'categories.premium_desc'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color:  Colors.white.withValues(alpha: 0.55),
              fontSize: 13,
              height:   1.5,
            ),
          ),
          const SizedBox(height: 24),

          // ── Watch Ad button ──
          SizedBox(
            width:  double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: onWatchAd,
              style: ElevatedButton.styleFrom(
                backgroundColor: _cIndigo,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              icon:  const Icon(Icons.play_circle_rounded,
                  color: Colors.white, size: 20),
              label: Text(
                'categories.watch_ad_btn'.tr(),
                style: const TextStyle(
                  color:      Colors.white,
                  fontSize:   15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Use Energy button ──
          SizedBox(
            width:  double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: onUseEnergy,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: color.withValues(alpha: 0.6)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              icon:  Text('❤️', style: const TextStyle(fontSize: 16)),
              label: Text(
                'categories.use_energy_btn'.tr(),
                style: TextStyle(
                  color:      color,
                  fontSize:   15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── Cancel ──
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'common.cancel'.tr(),
              style: const TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
