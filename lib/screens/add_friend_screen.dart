import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/friends_service.dart';

/// شاشة إضافة صديق بالإيميل
class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key});

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final _emailCtrl = TextEditingController();
  final _service   = FriendsService();
  bool   _loading  = false;
  String? _message;
  bool   _success  = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendRequest() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() { _message = 'أدخل بريداً إلكترونياً صحيحاً'; _success = false; });
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
        if (msg.contains('404')) msg = 'المستخدم غير موجود';
        if (msg.contains('400')) {
          if (msg.contains('أصدقاء')) msg = 'أنتما أصدقاء بالفعل ✅';
          else if (msg.contains('مُرسَل')) msg = 'الطلب مُرسَل بالفعل';
          else msg = 'لا يمكنك إضافة نفسك';
        }
        setState(() { _message = msg; _success = false; _loading = false; });
      }
    }
  }

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
        title: const Text(
          'إضافة صديق 👋',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('👋', style: TextStyle(fontSize: 70)),
            const SizedBox(height: 20),
            const Text(
              'أضف صديقاً بالإيميل',
              style: TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'سيصله طلب صداقة ويمكنه قبوله',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 32),

            // ─── حقل الإيميل ─────────────────────────────────────────────
            TextField(
              controller:  _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText:     'example@email.com',
                hintStyle:    const TextStyle(color: Colors.white24),
                prefixIcon:   const Icon(Icons.email_outlined, color: Colors.white38),
                filled:       true,
                fillColor:    Colors.white.withValues(alpha: 0.07),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:   BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:   const BorderSide(color: Color(0xFF6C63FF), width: 2),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ─── رسالة النتيجة ───────────────────────────────────────────
            if (_message != null)
              Container(
                width:   double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color:        (_success ? Colors.greenAccent : Colors.redAccent)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _success ? Colors.greenAccent : Colors.redAccent,
                    width: 1,
                  ),
                ),
                child: Text(
                  _message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _success ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 14,
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // ─── زر الإرسال ──────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _sendRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'إرسال طلب الصداقة',
                        style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white,
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
