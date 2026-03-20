import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
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

class DualMenuScreen extends StatelessWidget {
  const DualMenuScreen({super.key});

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

              // ─── Hero Circle ───────────────────────────────────────────────
              _buildHero(),

              const SizedBox(height: 32),

              // ─── Option Cards ─────────────────────────────────────────────
              _OptionCard(
                icon:      Icons.bolt_rounded,
                iconColor: _cCyan,
                glowColor: _cCyan,
                label:     'dual_menu.auto'.tr(),
                subtitle:  'dual_menu.auto_sub'.tr(),
                onTap:     () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MatchmakingScreen()),
                ),
              ),
              const SizedBox(height: 16),

              _OptionCard(
                icon:      Icons.add_home_rounded,
                iconColor: _cIndigo,
                glowColor: _cIndigo,
                label:     'dual_menu.create'.tr(),
                subtitle:  'dual_menu.create_sub'.tr(),
                onTap:     () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateRoomScreen()),
                ),
              ),
              const SizedBox(height: 16),

              _OptionCard(
                icon:      Icons.link_rounded,
                iconColor: _cPink,
                glowColor: _cPink,
                label:     'dual_menu.join'.tr(),
                subtitle:  'dual_menu.join_sub'.tr(),
                onTap:     () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const JoinRoomScreen()),
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
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.iconColor,
    required this.glowColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
              child: Icon(icon, color: iconColor, size: 28),
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
                color:        glowColor.withValues(alpha: 0.10),
                shape:        BoxShape.circle,
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
    );
  }
}
