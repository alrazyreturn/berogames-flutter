import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'create_room_screen.dart';
import 'join_room_screen.dart';
import 'matchmaking_screen.dart';

/// شاشة اختيار: إنشاء غرفة أو الانضمام لغرفة
class DualMenuScreen extends StatelessWidget {
  const DualMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'dual_menu.title'.tr(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ─── صورة توضيحية ───────────────────────────────────────────────
            const Text('⚔️', style: TextStyle(fontSize: 80)),
            const SizedBox(height: 16),
            Text(
              'dual_menu.subtitle'.tr(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'dual_menu.description'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 15),
            ),

            const SizedBox(height: 48),

            // ─── بحث تلقائي ─────────────────────────────────────────────────
            _BigButton(
              icon: '⚡',
              label: 'dual_menu.auto'.tr(),
              subtitle: 'dual_menu.auto_sub'.tr(),
              color: const Color(0xFFFFD700),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MatchmakingScreen()),
              ),
            ),

            const SizedBox(height: 16),

            // ─── إنشاء غرفة ────────────────────────────────────────────────
            _BigButton(
              icon: '🏠',
              label: 'dual_menu.create'.tr(),
              subtitle: 'dual_menu.create_sub'.tr(),
              color: const Color(0xFF6C63FF),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateRoomScreen()),
              ),
            ),

            const SizedBox(height: 16),

            // ─── الانضمام لغرفة ─────────────────────────────────────────────
            _BigButton(
              icon: '🔗',
              label: 'dual_menu.join'.tr(),
              subtitle: 'dual_menu.join_sub'.tr(),
              color: const Color(0xFFFF6584),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const JoinRoomScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── زر كبير ─────────────────────────────────────────────────────────────────
class _BigButton extends StatelessWidget {
  final String       icon;
  final String       label;
  final String       subtitle;
  final Color        color;
  final VoidCallback onTap;

  const _BigButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:   double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 24),
        decoration: BoxDecoration(
          color:        color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(20),
          border:       Border.all(color: color.withValues(alpha: 0.45), width: 1.5),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 40)),
            const SizedBox(width: 18),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color, fontSize: 18, fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, color: color, size: 18),
          ],
        ),
      ),
    );
  }
}
