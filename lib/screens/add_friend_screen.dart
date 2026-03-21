import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../providers/user_provider.dart';
import '../services/friends_service.dart';

// ─── Neon-Glass palette ───────────────────────────────────────────────────────
const _cBg      = Color(0xFF0B1326);
const _cSurface = Color(0xFF131B2E);
const _cCard    = Color(0xFF171F33);
const _cCyan    = Color(0xFF00FBFB);
const _cIndigo  = Color(0xFF6366F1);

/// شاشة إضافة صديق بالإيميل
class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key});

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _service   = FriendsService();
  bool   _loading  = false;
  String? _message;
  bool   _success  = false;

  late final AnimationController _glowCtrl;
  late final Animation<double>   _glowAnim;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendRequest() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() { _message = 'add_friend.invalid_email'.tr(); _success = false; });
      return;
    }

    final token = context.read<UserProvider>().token;
    if (token == null) return;

    setState(() { _loading = true; _message = null; });

    try {
      final msg = await _service.sendRequest(email, token);
      if (mounted) {
        setState(() { _message = msg; _success = true; _loading = false; });
        _emailCtrl.clear();
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (msg.contains('404')) { msg = 'add_friend.not_found'.tr(); }
        if (msg.contains('400')) {
          if (msg.contains('أصدقاء') || msg.contains('friends')) {
            msg = 'add_friend.already'.tr();
          } else if (msg.contains('مُرسَل') || msg.contains('sent') || msg.contains('already')) {
            msg = 'add_friend.sent_before'.tr();
          } else {
            msg = 'add_friend.self_add'.tr();
          }
        }
        setState(() { _message = msg; _success = false; _loading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cBg,
      body: SafeArea(
        child: Column(
          children: [
            // ─── Header ────────────────────────────────────────────────────
            _buildHeader(context),

            // ─── Body ──────────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Column(
                  children: [
                    const SizedBox(height: 32),

                    // Glow icon
                    _buildGlowIcon(),

                    const SizedBox(height: 28),

                    // Section title + subtitle
                    Text(
                      'add_friend.section_title'.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'add_friend.subtitle'.tr(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 14,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 36),

                    // Email field
                    _buildEmailField(),

                    const SizedBox(height: 16),

                    // Result message
                    if (_message != null) _buildResultMsg(),

                    const SizedBox(height: 20),

                    // Send button
                    _buildSendButton(),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 64,
      color: _cSurface,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_forward_ios_rounded,
              color: _cCyan,
              size: 20,
            ),
          ),
          Expanded(
            child: Text(
              'add_friend.title'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
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

  // ─── Glow Icon ────────────────────────────────────────────────────────────
  Widget _buildGlowIcon() {
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (context2, child2) {
        return Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _cCard,
            border: Border.all(
              color: _cCyan.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _cCyan.withValues(alpha: _glowAnim.value * 0.25),
                blurRadius: 32,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Center(
            child: Text('👋', style: TextStyle(fontSize: 46)),
          ),
        );
      },
    );
  }

  // ─── Email Field ─────────────────────────────────────────────────────────
  Widget _buildEmailField() {
    return Container(
      decoration: BoxDecoration(
        color: _cSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: _cCyan.withValues(alpha: 0.04),
            blurRadius: 12,
          ),
        ],
      ),
      child: TextField(
        controller:   _emailCtrl,
        keyboardType: TextInputType.emailAddress,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText:   'add_friend.email_hint'.tr(),
          hintStyle:  TextStyle(color: Colors.white.withValues(alpha: 0.25)),
          prefixIcon: Icon(
            Icons.email_outlined,
            color: Colors.white.withValues(alpha: 0.4),
            size: 20,
          ),
          filled:    true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:   BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:   const BorderSide(color: _cCyan, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:   BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  // ─── Result Message ───────────────────────────────────────────────────────
  Widget _buildResultMsg() {
    final color  = _success ? const Color(0xFF00E5A0) : Colors.redAccent;
    final icon   = _success ? Icons.check_circle_outline : Icons.error_outline;

    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _message!,
              style: TextStyle(color: color, fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Send Button ─────────────────────────────────────────────────────────
  Widget _buildSendButton() {
    return SizedBox(
      width:  double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _loading ? null : _sendRequest,
        style: ElevatedButton.styleFrom(
          backgroundColor:         _cIndigo,
          disabledBackgroundColor: _cIndigo.withValues(alpha: 0.35),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: _loading
            ? const SizedBox(
                width:  22,
                height: 22,
                child:  CircularProgressIndicator(
                  color:       Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                'add_friend.send_btn'.tr(),
                style: const TextStyle(
                  fontSize:   16,
                  fontWeight: FontWeight.bold,
                  color:      Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}
