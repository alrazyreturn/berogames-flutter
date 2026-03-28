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
import 'friends_screen.dart';

// ─── Design tokens (Galactic Play) ───────────────────────────────────────────
const _cBg      = Color(0xFF0B0B23);
const _cSurface = Color(0xFF10102B);
const _cCard    = Color(0xFF1C1C3C);
const _cCyan    = Color(0xFF00E3FD);
const _cPurple  = Color(0xFFA4A5FF);
const _cPink    = Color(0xFFFF59E3);

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
  bool    _loading        = false;
  bool    _uploadingAvatar = false; // حالة رفع الصورة التلقائي
  String? _error;

  int?    _rank;
  int?    _totalPlayers;
  bool    _rankLoading = true;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = context.read<UserProvider>().user?.name ?? '';
    _loadRank();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  // ─── جلب الترتيب العالمي ─────────────────────────────────────────────────
  Future<void> _loadRank() async {
    final token = context.read<UserProvider>().token;
    try {
      final rankRes = await _dio.get(
        ApiConfig.myRank,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final rank = (rankRes.data['rank'] as num?)?.toInt();

      final lbRes = await _dio.get(ApiConfig.leaderboard);
      final total = (lbRes.data as List).length;

      if (mounted) {
        setState(() {
          _rank         = rank;
          _totalPlayers = total;
          _rankLoading  = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _rankLoading = false);
    }
  }

  // ─── اختيار صورة ثم رفعها فوراً ──────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context);
    final xfile = await _picker.pickImage(
      source:       source,
      maxWidth:     800,
      maxHeight:    800,
      imageQuality: 85,
    );
    if (xfile == null) return;
    final file = File(xfile.path);
    setState(() => _pickedImage = file);
    // حفظ الصورة فوراً بدون انتظار الضغط على "حفظ التعديلات"
    await _saveAvatarOnly(file);
  }

  // ─── رفع الصورة تلقائياً ──────────────────────────────────────────────────
  Future<void> _saveAvatarOnly(File imageFile) async {
    final token = context.read<UserProvider>().token;
    if (token == null) return;

    setState(() { _uploadingAvatar = true; _error = null; });

    try {
      final ext      = imageFile.path.contains('.')
          ? '.${imageFile.path.split('.').last}' : '.jpg';
      final formData = FormData();
      formData.files.add(MapEntry(
        'avatar',
        await MultipartFile.fromFile(imageFile.path, filename: 'avatar$ext'),
      ));

      final res = await _dio.put(
        ApiConfig.profile,
        data:    formData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final updatedUser = res.data['user'] as Map<String, dynamic>;
      if (!mounted) return;
      await context.read<UserProvider>().updateProfile(
        name:   updatedUser['name'],
        avatar: updatedUser['avatar'],
      );

      if (!mounted) return;
      setState(() {
        _uploadingAvatar = false;
        _pickedImage     = null; // تم الحفظ → امسح المؤقت حتى لا تُرفع مرة ثانية
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:         Text('profile.updated'.tr()),
        backgroundColor: _cCyan.withValues(alpha: 0.9),
        behavior:        SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ));

    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error           = e.response?.data?['message'] ?? 'profile.error'.tr();
        _uploadingAvatar = false;
        _pickedImage     = null; // أعد الصورة القديمة عند الخطأ
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error           = 'common.error_generic'.tr();
        _uploadingAvatar = false;
        _pickedImage     = null;
      });
    }
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
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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

    final token    = context.read<UserProvider>().token;
    final newName  = _nameCtrl.text.trim();
    setState(() { _loading = true; _error = null; });

    try {
      final formData    = FormData();
      final currentName = context.read<UserProvider>().user?.name ?? '';

      if (newName != currentName) formData.fields.add(MapEntry('name', newName));

      if (_pickedImage != null) {
        formData.files.add(MapEntry(
          'avatar',
          await MultipartFile.fromFile(
            _pickedImage!.path,
            filename: 'avatar${_pickedImage!.path.contains('.')
                ? '.${_pickedImage!.path.split('.').last}' : '.jpg'}',
          ),
        ));
      }

      if (formData.fields.isEmpty && formData.files.isEmpty) {
        setState(() => _loading = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('profile.no_change'.tr()),
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }

      final res = await _dio.put(
        ApiConfig.profile,
        data:    formData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final updatedUser = res.data['user'] as Map<String, dynamic>;
      if (!mounted) return;
      await context.read<UserProvider>().updateProfile(
        name:   updatedUser['name'],
        avatar: updatedUser['avatar'],
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:         Text('profile.updated'.tr()),
        backgroundColor: _cCyan,
        behavior:        SnackBarBehavior.floating,
      ));
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
                  color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            Text(
              'language.choose'.tr(),
              style: const TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _cCyan.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? _cCyan : Colors.white12,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(lang['flag']!, style: const TextStyle(fontSize: 26)),
                      const SizedBox(width: 16),
                      Text(
                        lang['label']!,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 16,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      const Spacer(),
                      if (isSelected)
                        const Icon(Icons.check_circle, color: _cCyan, size: 20),
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

    return Scaffold(
      backgroundColor: _cBg,

      // ─── AppBar ──────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: _cBg,
        elevation: 0,
        automaticallyImplyLeading: false,
        // In RTL: actions appear on the LEFT side → gear on the left ✓
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: Colors.white54),
            onPressed: _showLangSheet,
          ),
        ],
        // In RTL: title aligns to the right (start = right in RTL) ✓
        title: const Text(
          'Mind Crush 🚀',
          style: TextStyle(
            color:      _cCyan,
            fontSize:   20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: false,
      ),

      // ─── Body ────────────────────────────────────────────────────────────
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),

              // ─── Avatar with glow ring ─────────────────────────────────
              GestureDetector(
                onTap: _uploadingAvatar ? null : _showImageSourceSheet,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    // Gradient glow ring
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: _uploadingAvatar
                              ? [_cPurple, _cCyan]
                              : [_cCyan, _cPurple],
                          begin: Alignment.topLeft,
                          end:   Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:       (_uploadingAvatar ? _cPurple : _cCyan)
                                .withValues(alpha: 0.45),
                            blurRadius:  32,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircleAvatar(
                            radius: 56,
                            backgroundColor: _cCard,
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
                                      color:      _cCyan,
                                      fontSize:   44,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          // ── Overlay spinner أثناء الرفع ──────────────
                          if (_uploadingAvatar)
                            Container(
                              width:  112,
                              height: 112,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withValues(alpha: 0.55),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color:       _cCyan,
                                  strokeWidth: 2.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Edit badge (يختفي أثناء الرفع)
                    if (!_uploadingAvatar)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:  _cCyan,
                          shape:  BoxShape.circle,
                          border: Border.all(color: _cBg, width: 2),
                        ),
                        child: const Icon(
                            Icons.edit_rounded, color: Colors.black, size: 16),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Name
              Text(
                user?.name ?? '',
                style: const TextStyle(
                  color:      Colors.white,
                  fontSize:   22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              // ─── Stats Row (Level | XP) ───────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon:      Icons.flash_on_rounded,
                      iconColor: _cPink,
                      label:     'profile.level'.tr(),
                      value:     '${user?.currentLevel ?? 1}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon:      Icons.military_tech_rounded,
                      iconColor: _cCyan,
                      label:     'profile.xp_points'.tr(),
                      value:     _fmt(user?.totalScore ?? 0),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ─── World Rank Card ───────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 18),
                decoration: BoxDecoration(
                  color:         _cCard,
                  borderRadius:  BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color:      _cCyan.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset:     const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Rank number
                    _rankLoading
                        ? const SizedBox(
                            width: 32, height: 32,
                            child: CircularProgressIndicator(
                                color: _cCyan, strokeWidth: 2),
                          )
                        : Text(
                            _rank != null ? '#${_fmt(_rank!)}' : '---',
                            style: const TextStyle(
                              color:       _cCyan,
                              fontSize:    30,
                              fontWeight:  FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                    const Spacer(),
                    // Title + subtitle
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Text(
                              'profile.world_rank'.tr(),
                              style: const TextStyle(
                                color:      Colors.white,
                                fontSize:   15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.bar_chart_rounded,
                                color: _cCyan, size: 20),
                          ],
                        ),
                        if (!_rankLoading &&
                            _rank != null &&
                            _totalPlayers != null &&
                            _totalPlayers! > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            'profile.top_percent'.tr(namedArgs: {
                              'percent':
                                  ((_rank! / _totalPlayers!) * 100)
                                      .toStringAsFixed(0),
                            }),
                            style: TextStyle(
                              color:    Colors.white.withValues(alpha: 0.55),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ─── Account Info title ────────────────────────────────────
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  'profile.account_info'.tr(),
                  style: const TextStyle(
                    color:      Colors.white,
                    fontSize:   16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // ─── Username field ────────────────────────────────────────
              _FieldCard(
                label: 'profile.username'.tr(),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nameCtrl,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14),
                        decoration: const InputDecoration(
                          isDense:        true,
                          contentPadding: EdgeInsets.zero,
                          border:         InputBorder.none,
                          enabledBorder:  InputBorder.none,
                          focusedBorder:  InputBorder.none,
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
                        color: _cCyan, size: 20),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ─── Email field ───────────────────────────────────────────
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
                        overflow:      TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.mail_outline_rounded,
                        color: _cCyan, size: 20),
                  ],
                ),
              ),

              // ─── Error message ─────────────────────────────────────────
              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:        Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border:       Border.all(
                        color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.redAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                color: Colors.redAccent, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),

              // ─── Save Button (gradient pill) ───────────────────────────
              SizedBox(
                width:  double.infinity,
                height: 54,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: (_loading || _uploadingAvatar)
                        ? null
                        : const LinearGradient(
                            colors: [_cCyan, _cPurple],
                            begin:  Alignment.centerRight,
                            end:    Alignment.centerLeft,
                          ),
                    color: (_loading || _uploadingAvatar)
                        ? Colors.white12
                        : null,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: (_loading || _uploadingAvatar)
                        ? []
                        : [
                            BoxShadow(
                              color:      _cCyan.withValues(alpha: 0.30),
                              blurRadius: 18,
                              offset:     const Offset(0, 6),
                            ),
                          ],
                  ),
                  child: ElevatedButton(
                    onPressed: (_loading || _uploadingAvatar) ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:         Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      shadowColor:             Colors.transparent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      elevation: 0,
                    ),
                    child: (_loading || _uploadingAvatar)
                        ? const SizedBox(
                            width:  24,
                            height: 24,
                            child:  CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            'profile.save'.tr(),
                            style: const TextStyle(
                              color:      Colors.black,
                              fontSize:   16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ─── Logout text link ──────────────────────────────────────
              TextButton.icon(
                onPressed: _logout,
                icon:  const Icon(Icons.logout_rounded,
                    color: _cPink, size: 20),
                label: Text(
                  'profile.logout'.tr(),
                  style: const TextStyle(
                    color:      _cPink,
                    fontSize:   16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),

      // ─── Bottom Navigation ────────────────────────────────────────────────
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  // ─── Format number with commas ────────────────────────────────────────────
  String _fmt(int n) {
    if (n < 1000) return '$n';
    final s   = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  // ─── Bottom Nav ───────────────────────────────────────────────────────────
  Widget _buildBottomNav(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:  _cSurface,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset:     const Offset(0, -4),
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
                icon:     Icons.home_rounded,
                label:    'home.nav_home'.tr(),
                isActive: false,
                onTap:    () => Navigator.of(context).popUntil((r) => r.isFirst),
              ),
              _NavItem(
                icon:     Icons.leaderboard_rounded,
                label:    'home.nav_ranking'.tr(),
                isActive: false,
                onTap:    () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const LeaderboardScreen())),
              ),
              _NavItem(
                icon:     Icons.people_rounded,
                label:    'home.nav_friends'.tr(),
                isActive: false,
                onTap:    () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const FriendsScreen())),
              ),
              _NavItem(
                icon:     Icons.person_rounded,
                label:    'home.nav_profile'.tr(),
                isActive: true,
                onTap:    () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final String   label;
  final String   value;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color:        _cCard,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color:      Colors.white,
                fontSize:   20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
}

// ─── Field Card ───────────────────────────────────────────────────────────────
class _FieldCard extends StatelessWidget {
  final String label;
  final Widget child;

  const _FieldCard({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color:        _cCard,
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
            width:   double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color:        Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(14),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ─── Source Button ────────────────────────────────────────────────────────────
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
              width:  72,
              height: 72,
              decoration: BoxDecoration(
                color:        _cCyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border:       Border.all(
                    color: _cCyan.withValues(alpha: 0.4)),
              ),
              child: Icon(icon, color: _cCyan, size: 32),
            ),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 13)),
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
                    ? _cCyan.withValues(alpha: 0.15)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isActive ? _cCyan : Colors.white38,
                size:  24,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color:      isActive ? _cCyan : Colors.white38,
                fontSize:   10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      );
}
