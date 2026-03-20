import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;

import '../config/api_config.dart';
import '../providers/user_provider.dart';
import 'login_screen.dart';
import 'leaderboard_screen.dart';
import 'stats_screen.dart';

// ─── ألوان متسقة مع الـ home screen ────────────────────────────────────────
const _cBg        = Color(0xFF0D1117);
const _cCard      = Color(0xFF161B2E);
const _cTeal      = Color(0xFF00BCD4);
const _cPink      = Color(0xFFFF79F5);
const _cNavActive = Color(0xFFE040FB);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _picker   = ImagePicker();
  final _dio      = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));

  File?   _pickedImage;
  bool    _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = context.read<UserProvider>().user;
    _nameCtrl.text = user?.name ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  // ─── اختيار صورة ─────────────────────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context);
    final xfile = await _picker.pickImage(
      source:       source,
      maxWidth:     800,
      maxHeight:    800,
      imageQuality: 85,
    );
    if (xfile != null) setState(() => _pickedImage = File(xfile.path));
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'profile.choose_source'.tr(),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _SourceButton(
                    icon:  Icons.photo_library_rounded,
                    label: 'profile.gallery'.tr(),
                    onTap: () => _pickImage(ImageSource.gallery),
                  ),
                  _SourceButton(
                    icon:  Icons.camera_alt_rounded,
                    label: 'profile.camera'.tr(),
                    onTap: () => _pickImage(ImageSource.camera),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  // ─── حفظ التغييرات ────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final token   = context.read<UserProvider>().token;
    final newName = _nameCtrl.text.trim();
    setState(() { _loading = true; _error = null; });

    try {
      final formData   = FormData();
      final currentName = context.read<UserProvider>().user?.name ?? '';

      if (newName != currentName) {
        formData.fields.add(MapEntry('name', newName));
      }

      if (_pickedImage != null) {
        formData.files.add(MapEntry(
          'avatar',
          await MultipartFile.fromFile(
            _pickedImage!.path,
            filename: 'avatar${_pickedImage!.path.contains('.') ? '.${_pickedImage!.path.split('.').last}' : '.jpg'}',
          ),
        ));
      }

      if (formData.fields.isEmpty && formData.files.isEmpty) {
        setState(() => _loading = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('profile.no_change'.tr()),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final res = await _dio.put(
        ApiConfig.profile,
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final updatedUser = res.data['user'] as Map<String, dynamic>;
      if (!mounted) return;
      final userProvider = context.read<UserProvider>();
      await userProvider.updateProfile(
        name:   updatedUser['name'],
        avatar: updatedUser['avatar'],
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('profile.updated'.tr()),
          backgroundColor: _cTeal,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (mounted) Navigator.pop(context);

    } on DioException catch (e) {
      setState(() {
        _error   = e.response?.data?['message'] ?? 'profile.error'.tr();
        _loading = false;
      });
    } catch (_) {
      setState(() { _error = 'common.error_generic'.tr(); _loading = false; });
    }
  }

  // ─── تسجيل الخروج ────────────────────────────────────────────────────────
  Future<void> _logout() async {
    await context.read<UserProvider>().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  // ─── Language Sheet ───────────────────────────────────────────────────────
  static const _langs = [
    {'code': 'ar', 'flag': '🇸🇦', 'label': 'العربية'},
    {'code': 'en', 'flag': '🇬🇧', 'label': 'English'},
    {'code': 'tr', 'flag': '🇹🇷', 'label': 'Türkçe'},
  ];

  void _showLangSheet() {
    final current = context.locale.languageCode;
    showModalBottomSheet(
      context: context,
      backgroundColor: _cCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Text(
              'language.choose'.tr(),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ..._langs.map((lang) {
              final isSelected = lang['code'] == current;
              return GestureDetector(
                onTap: () {
                  context.setLocale(Locale(lang['code']!));
                  Navigator.pop(ctx);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _cNavActive.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? _cNavActive : Colors.white12,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(lang['flag']!,
                          style: const TextStyle(fontSize: 26)),
                      const SizedBox(width: 16),
                      Text(
                        lang['label']!,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 16,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      const Spacer(),
                      if (isSelected)
                        const Icon(Icons.check_circle,
                            color: _cNavActive, size: 20),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //                              BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    context.locale;
    final user = context.watch<UserProvider>().user;
    final isGoogle = user?.avatar?.startsWith('https://lh3') == true;

    return Scaffold(
      backgroundColor: _cBg,
      // ─── AppBar ────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: _cBg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _cTeal),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'profile.title'.tr(),
          style: const TextStyle(
            color: _cPink,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      // ─── Body ──────────────────────────────────────────────────────────
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 12),

              // ─── Avatar ──────────────────────────────────────────────
              GestureDetector(
                onTap: _showImageSourceSheet,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    // Gradient border ring
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF00BCD4),
                            Color(0xFF8B35D6),
                            Color(0xFFFF79F5),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: const Color(0xFF1E2140),
                        backgroundImage: _pickedImage != null
                            ? FileImage(_pickedImage!) as ImageProvider
                            : (user?.avatar != null
                                ? NetworkImage(user!.avatar!)
                                : null),
                        child: (_pickedImage == null && user?.avatar == null)
                            ? Text(
                                user?.name.isNotEmpty == true
                                    ? user!.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: _cTeal,
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                    ),
                    // Camera badge
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: _cPink,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Display name
              Text(
                user?.name ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'profile.change_photo'.tr(),
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),

              const SizedBox(height: 28),

              // ─── Email Card ─────────────────────────────────────────
              _FieldCard(
                label: 'profile.email_label'.tr(),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        user?.email ?? '',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14),
                        textDirection: TextDirection.ltr,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.mail_outline_rounded,
                        color: _cTeal, size: 20),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ─── Name Card ──────────────────────────────────────────
              _FieldCard(
                label: 'profile.name_label'.tr(),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nameCtrl,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'profile.name_required'.tr();
                          }
                          if (v.trim().length < 2) {
                            return 'profile.name_short'.tr();
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.person_outline_rounded,
                        color: _cTeal, size: 20),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ─── Provider + Points Card ─────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _cCard,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    // Provider
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isGoogle ? 'GOOGLE' : 'EMAIL',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isGoogle ? 'Google' : 'profile.email_provider'.tr(),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'profile.provider'.tr(),
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    // Divider
                    Container(
                      width: 1,
                      height: 56,
                      color: Colors.white10,
                      margin:
                          const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    // Points
                    Column(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: Color(0xFFFFD700), size: 28),
                        const SizedBox(height: 4),
                        Text(
                          '${user?.totalScore ?? 0}',
                          style: const TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'profile.points'.tr(),
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ─── Error message ──────────────────────────────────────
              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.redAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                              color: Colors.redAccent, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // ─── Language Row ───────────────────────────────────────
              GestureDetector(
                onTap: _showLangSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: _cCard,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.language_rounded,
                          color: _cTeal, size: 24),
                      const SizedBox(width: 14),
                      Text(
                        'profile.language'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _currentLangName(context),
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 13),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_left_rounded,
                          color: Colors.white38, size: 22),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ─── Save Button ────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _loading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _cPink,
                    disabledBackgroundColor:
                        _cPink.withValues(alpha: 0.4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          'profile.save'.tr(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 14),

              // ─── Logout Button ──────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: _logout,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                        color: Colors.redAccent, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                    foregroundColor: Colors.redAccent,
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  label: Text(
                    'profile.logout'.tr(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),

      // ─── Bottom Navigation ──────────────────────────────────────────────
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  // ─── اسم اللغة الحالية ────────────────────────────────────────────────────
  String _currentLangName(BuildContext context) {
    switch (context.locale.languageCode) {
      case 'en': return 'English';
      case 'tr': return 'Türkçe';
      default:   return 'العربية';
    }
  }

  // ─── Bottom Nav ───────────────────────────────────────────────────────────
  Widget _buildBottomNav(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cCard,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'home.nav_home'.tr(),
                isActive: false,
                onTap: () => Navigator.of(context)
                    .popUntil((r) => r.isFirst),
              ),
              _NavItem(
                icon: Icons.leaderboard_rounded,
                label: 'home.nav_ranking'.tr(),
                isActive: false,
                onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const LeaderboardScreen())),
              ),
              _NavItem(
                icon: Icons.bar_chart_rounded,
                label: 'home.nav_stats'.tr(),
                isActive: false,
                onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const StatsScreen())),
              ),
              _NavItem(
                icon: Icons.person_rounded,
                label: 'home.nav_profile'.tr(),
                isActive: true,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Field Card (label + content) ────────────────────────────────────────────
class _FieldCard extends StatelessWidget {
  final String label;
  final Widget child;

  const _FieldCard({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: _cCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(14),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ─── زر مصدر الصورة ──────────────────────────────────────────────────────────
class _SourceButton extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final VoidCallback onTap;

  const _SourceButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _cTeal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _cTeal.withValues(alpha: 0.4)),
              ),
              child: Icon(icon, color: _cTeal, size: 32),
            ),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
      );
}

// ─── Bottom Nav Item ──────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final bool         isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isActive
                    ? _cNavActive.withValues(alpha: 0.2)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isActive ? _cNavActive : Colors.white38,
                size: 24,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isActive ? _cNavActive : Colors.white38,
                fontSize: 10,
                fontWeight:
                    isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      );
}
