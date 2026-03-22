import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/energy_service.dart';
import '../services/ad_service.dart';
import 'create_room_screen.dart';
import 'join_room_screen.dart';
import 'matchmaking_screen.dart';

// ─── Design Tokens (Neon-Glass Editorial) ────────────────────────────────────
const _cBg      = Color(0xFF0B1326);
const _cSurface = Color(0xFF131B2E);
const _cCard    = Color(0xFF171F33);
const _cCyan    = Color(0xFF00FBFB);
const _cIndigo  = Color(0xFF6366F1);
const _cPink    = Color(0xFFFF6B9D);

class DualMenuScreen extends StatefulWidget {
  const DualMenuScreen({super.key});

  @override
  State<DualMenuScreen> createState() => _DualMenuScreenState();
}

class _DualMenuScreenState extends State<DualMenuScreen> {
  final _energyService = EnergyService();
  bool _loading = false;

  // ─── فحص الطاقة والتنقل ──────────────────────────────────────────────────
  Future<void> _checkEnergyAndNavigate(VoidCallback navigate) async {
    if (_loading) return;
    final token = context.read<UserProvider>().token;
    if (token == null) return;

    setState(() => _loading = true);
    try {
      final result  = await _energyService.consumeEnergy(token);
      if (!mounted) return;
      final canPlay = result['can_play'] as bool? ?? false;
      if (canPlay) {
        navigate();
      } else {
        _showNoEnergyDialog(navigate);
      }
    } catch (_) {
      if (mounted) _showNoEnergyDialog(navigate);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── Dialog لا طاقة (مع زر مشاهدة إعلان) ───────────────────────────────
  void _showNoEnergyDialog(VoidCallback navigate) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _cCard,
        shape:          RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titlePadding:   const EdgeInsets.fromLTRB(20, 28, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
        title: Column(
          children: [
            // ⚡ glow circle
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.amber.withValues(alpha: 0.12),
                border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.35), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.28),
                    blurRadius: 24, spreadRadius: 2,
                  ),
                ],
              ),
              child: const Center(
                child: Text('⚡', style: TextStyle(fontSize: 34)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'dual_game.no_energy_title'.tr(),
              style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Text(
          'dual_game.no_energy'.tr(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.60),
            fontSize: 14, height: 1.65,
          ),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'common.cancel'.tr(),
              style: const TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _cIndigo,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
              elevation: 0,
            ),
            icon:  const Icon(Icons.play_circle_rounded, size: 18),
            label: Text(
              'dual_game.watch_ad_btn'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              Navigator.pop(context);
              _watchAdAndPlay(navigate);
            },
          ),
        ],
      ),
    );
  }

  // ─── مشاهدة إعلان → شحن طاقة → التنقل ──────────────────────────────────
  void _watchAdAndPlay(VoidCallback navigate) {
    final token = context.read<UserProvider>().token;
    if (token == null) return;
    AdService().showRewarded(
      onRewarded: () async {
        try {
          await _energyService.rechargeEnergy(token);
          if (!mounted) return;
          navigate();
        } catch (_) {}
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cBg,
      // ─── AppBar ──────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white54, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'dual_menu.title'.tr(),
          style: const TextStyle(
            color:      Colors.white,
            fontSize:   18,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            children: [
              const SizedBox(height: 16),

              // ─── Hero Circle ─────────────────────────────────────────────
              _buildHero(),

              const SizedBox(height: 32),

              // ─── Option Cards ─────────────────────────────────────────────
              _OptionCard(
                icon:      Icons.bolt_rounded,
                iconColor: _cCyan,
                glowColor: _cCyan,
                label:     'dual_menu.auto'.tr(),
                subtitle:  'dual_menu.auto_sub'.tr(),
                loading:   _loading,
                onTap:     () => _checkEnergyAndNavigate(
                  () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const MatchmakingScreen())),
                ),
              ),
              const SizedBox(height: 16),

              _OptionCard(
                icon:      Icons.add_home_rounded,
                iconColor: _cIndigo,
                glowColor: _cIndigo,
                label:     'dual_menu.create'.tr(),
                subtitle:  'dual_menu.create_sub'.tr(),
                loading:   _loading,
                onTap:     () => _checkEnergyAndNavigate(
                  () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const CreateRoomScreen())),
                ),
              ),
              const SizedBox(height: 16),

              _OptionCard(
                icon:      Icons.link_rounded,
                iconColor: _cPink,
                glowColor: _cPink,
                label:     'dual_menu.join'.tr(),
                subtitle:  'dual_menu.join_sub'.tr(),
                loading:   _loading,
                onTap:     () => _checkEnergyAndNavigate(
                  () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const JoinRoomScreen())),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Column(
      children: [
        // Glow ring + circle + swords icon
        Container(
          width:  140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [_cCyan, _cIndigo],
              begin:  Alignment.topLeft,
              end:    Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color:       _cCyan.withValues(alpha: 0.25),
                blurRadius:  48,
                spreadRadius: 4,
              ),
              BoxShadow(
                color:       _cIndigo.withValues(alpha: 0.20),
                blurRadius:  32,
                spreadRadius: 2,
              ),
            ],
          ),
          padding: const EdgeInsets.all(4),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: _cSurface,
            ),
            child: const Icon(
              Icons.sports_kabaddi_rounded,
              color: _cCyan,
              size:  68,
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Title
        Text(
          'dual_menu.subtitle'.tr(),
          style: const TextStyle(
            color:      Colors.white,
            fontSize:   24,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        // Description
        Text(
          'dual_menu.description'.tr(),
          style: TextStyle(
            color:    Colors.white.withValues(alpha: 0.50),
            fontSize: 14,
            height:   1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ─── Option Card ─────────────────────────────────────────────────────────────
class _OptionCard extends StatelessWidget {
  final IconData     icon;
  final Color        iconColor;
  final Color        glowColor;
  final String       label;
  final String       subtitle;
  final bool         loading;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.iconColor,
    required this.glowColor,
    required this.label,
    required this.subtitle,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity:  loading ? 0.55 : 1.0,
        child: Container(
          width:   double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          decoration: BoxDecoration(
            color:        _cCard,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color:      glowColor.withValues(alpha: 0.08),
                blurRadius: 24,
                offset:     const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon container with glow
              Container(
                width:  56,
                height: 56,
                decoration: BoxDecoration(
                  color:        glowColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color:      glowColor.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset:     const Offset(0, 4),
                    ),
                  ],
                ),
                child: loading
                    ? Center(
                        child: SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                            color:       iconColor,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    : Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 16),

              // Texts
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color:      Colors.white,
                        fontSize:   16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color:    Colors.white.withValues(alpha: 0.45),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow chevron
              Container(
                width:  36,
                height: 36,
                decoration: BoxDecoration(
                  color: glowColor.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chevron_left_rounded,
                  color: iconColor,
                  size:  22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
