import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../providers/user_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _picker    = ImagePicker();
  final _dio       = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));

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

  // ─── اختيار صورة ────────────────────────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context); // أغلق bottom-sheet
    final xfile = await _picker.pickImage(
      source:    source,
      maxWidth:  800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (xfile != null) setState(() => _pickedImage = File(xfile.path));
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E3F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
              const Text(
                'اختر مصدر الصورة',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _SourceButton(
                    icon:  Icons.photo_library_rounded,
                    label: 'المعرض',
                    onTap: () => _pickImage(ImageSource.gallery),
                  ),
                  _SourceButton(
                    icon:  Icons.camera_alt_rounded,
                    label: 'الكاميرا',
                    onTap: () => _pickImage(ImageSource.camera),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ─── حفظ التغييرات ──────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final token   = context.read<UserProvider>().token;
    final newName = _nameCtrl.text.trim();

    setState(() { _loading = true; _error = null; });

    try {
      final formData = FormData();

      final currentName = context.read<UserProvider>().user?.name ?? '';
      if (newName != currentName) formData.fields.add(MapEntry('name', newName));

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
          const SnackBar(content: Text('لم تقم بأي تغيير'), behavior: SnackBarBehavior.floating),
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
      await context.read<UserProvider>().updateProfile(
        name:   updatedUser['name'],
        avatar: updatedUser['avatar'],
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم تحديث الملف الشخصي'),
          backgroundColor: Color(0xFF43D8C9),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (mounted) Navigator.pop(context);

    } on DioException catch (e) {
      setState(() {
        _error   = e.response?.data?['message'] ?? 'حدث خطأ، حاول مجدداً';
        _loading = false;
      });
    } catch (_) {
      setState(() { _error = 'حدث خطأ غير متوقع'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        title: const Text('الملف الشخصي', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 12),

              // ─── صورة الأفاتار ─────────────────────────────────────────────
              GestureDetector(
                onTap: _showImageSourceSheet,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFF3D5AF1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 64,
                        backgroundColor: Colors.transparent,
                        backgroundImage: _pickedImage != null
                            ? FileImage(_pickedImage!)
                            : (user?.avatar != null
                                ? NetworkImage(user!.avatar!) as ImageProvider
                                : null),
                        child: (_pickedImage == null && user?.avatar == null)
                            ? Text(
                                user?.name.isNotEmpty == true
                                    ? user!.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF6C63FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              const Text(
                'اضغط على الصورة لتغييرها',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),

              const SizedBox(height: 32),

              // ─── بطاقة المعلومات ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E3F),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'البريد الإلكتروني',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Text(
                        user?.email ?? '',
                        style: const TextStyle(color: Colors.white60, fontSize: 15),
                        textDirection: TextDirection.ltr,
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'اسم الظهور',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      textDirection: TextDirection.rtl,
                      decoration: InputDecoration(
                        hintText: 'أدخل اسمك',
                        hintStyle: const TextStyle(color: Colors.white30),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white10),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF6C63FF)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'الاسم مطلوب';
                        if (v.trim().length < 2) return 'الاسم يجب أن يكون حرفين على الأقل';
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ─── إحصائيات سريعة ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E3F),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatItem(
                        icon: '⭐',
                        label: 'النقاط',
                        value: '${user?.totalScore ?? 0}',
                      ),
                    ),
                    Container(width: 1, height: 48, color: Colors.white10),
                    Expanded(
                      child: _StatItem(
                        icon: '📧',
                        label: 'مزود الحساب',
                        value: user?.avatar?.startsWith('https://lh3') == true
                            ? 'Google'
                            : 'إيميل',
                      ),
                    ),
                  ],
                ),
              ),

              // ─── رسالة خطأ ──────────────────────────────────────────────
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // ─── زر الحفظ ────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    disabledBackgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'حفظ التغييرات',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── عنصر إحصائية سريعة ──────────────────────────────────────────────────────
class _StatItem extends StatelessWidget {
  final String icon;
  final String label;
  final String value;

  const _StatItem({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(icon, style: const TextStyle(fontSize: 22)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
    ],
  );
}

// ─── زر مصدر الصورة ──────────────────────────────────────────────────────────
class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String   label;
  final VoidCallback onTap;

  const _SourceButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(
      children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.4)),
          ),
          child: Icon(icon, color: const Color(0xFF6C63FF), size: 32),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ],
    ),
  );
}
