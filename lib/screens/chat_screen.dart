import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/message_model.dart';
import '../models/friend_model.dart';
import '../providers/user_provider.dart';
import '../services/chat_service.dart';
import '../services/socket_service.dart';

class ChatScreen extends StatefulWidget {
  final FriendModel friend;

  const ChatScreen({super.key, required this.friend});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _chatService  = ChatService();
  final _socket       = SocketService();
  final _msgCtrl      = TextEditingController();
  final _scrollCtrl   = ScrollController();

  List<MessageModel> _messages   = [];
  bool   _loading    = true;
  bool   _sending    = false;
  bool   _friendTyping = false;
  Timer? _typingTimer;
  Timer? _sendTimeoutTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadHistory();
    _setupSocket();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sendTimeoutTimer?.cancel();
      if (mounted && _sending) setState(() => _sending = false);
      _messages.removeWhere((m) => m.id < 0);

      final user  = context.read<UserProvider>().user;
      if (user == null) return;

      // أعد الاتصال وسجّل المستخدم على السيرفر فور الاتصال
      _socket.connect(userId: user.id, userName: user.name);
      _setupSocket();
      _loadHistory();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _typingTimer?.cancel();
    _sendTimeoutTimer?.cancel();
    _socket.onChatMessageReceived = null;
    _socket.onChatMessageSent     = null;
    _socket.onChatTyping          = null;
    // إلغاء "يكتب الآن" عند المغادرة
    _socket.sendTyping(toUserId: widget.friend.userId, isTyping: false);
    super.dispose();
  }

  // ─── تحميل تاريخ المحادثة ────────────────────────────────────────────────
  Future<void> _loadHistory() async {
    final token = context.read<UserProvider>().token;
    if (token == null) return;
    try {
      final msgs = await _chatService.getMessages(
        friendId: widget.friend.userId,
        token:    token,
      );
      setState(() { _messages = msgs; _loading = false; });
      _scrollToBottom();
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  // ─── إعداد Socket ────────────────────────────────────────────────────────
  void _setupSocket() {
    final myId = context.read<UserProvider>().user?.id;

    // استقبال رسالة جديدة من الطرف الآخر
    _socket.onChatMessageReceived = (data) {
      if (!mounted) return;
      final senderId = data['sender_id'] as int?;
      if (senderId != widget.friend.userId) return; // تجاهل رسائل شخص آخر
      final msg = MessageModel.fromJson(data);
      // منع التكرار: تجاهل لو الرسالة موجودة بالفعل
      if (_messages.any((m) => m.id == msg.id)) return;
      setState(() => _messages.add(msg));
      _scrollToBottom();
    };

    // تأكيد إرسال رسالتي — نستبدل الرسالة المؤقتة بالحقيقية
    _socket.onChatMessageSent = (data) {
      if (!mounted) return;
      final senderId = data['sender_id'] as int?;
      if (senderId != myId) return;
      final realMsg = MessageModel.fromJson(data);
      _sendTimeoutTimer?.cancel();
      setState(() {
        _sending = false;
        // احذف الرسائل المؤقتة (id سالب) واستبدلها بالحقيقية
        _messages.removeWhere((m) => m.id < 0);
        if (!_messages.any((m) => m.id == realMsg.id)) {
          _messages.add(realMsg);
        }
      });
      _scrollToBottom();
    };

    // يكتب الآن...
    _socket.onChatTyping = (data) {
      if (!mounted) return;
      final fromId   = data['from_user_id'] as int?;
      final isTyping = data['is_typing']    as bool? ?? false;
      if (fromId != widget.friend.userId) return;
      setState(() => _friendTyping = isTyping);
      if (isTyping) _scrollToBottom();
    };
  }

  // ─── إرسال رسالة ─────────────────────────────────────────────────────────
  void _send() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    final myId = context.read<UserProvider>().user?.id ?? 0;

    // Optimistic: أضف الرسالة فوراً بـ ID مؤقت (سالب) بدون انتظار السيرفر
    final tempMsg = MessageModel(
      id:         -DateTime.now().millisecondsSinceEpoch,
      senderId:   myId,
      receiverId: widget.friend.userId,
      message:    text,
      isRead:     false,
      createdAt:  DateTime.now(),
    );

    setState(() {
      _messages.add(tempMsg);
      _sending = true;
    });
    _msgCtrl.clear();
    _scrollToBottom();

    // إيقاف إشعار الكتابة
    _socket.sendTyping(toUserId: widget.friend.userId, isTyping: false);
    _typingTimer?.cancel();

    _socket.sendChatMessage(toUserId: widget.friend.userId, message: text);

    // Timeout: لو مفيش رد من السيرفر خلال 6 ثوانٍ — أعد التفعيل
    _sendTimeoutTimer?.cancel();
    _sendTimeoutTimer = Timer(const Duration(seconds: 6), () {
      if (mounted && _sending) {
        setState(() {
          _sending = false;
          // احذف الرسالة المؤقتة لو لم تُؤكَّد
          _messages.removeWhere((m) => m.id < 0);
        });
      }
    });
  }

  // ─── إشعار "يكتب الآن" أثناء الكتابة ────────────────────────────────────
  void _onTextChanged(String value) {
    _typingTimer?.cancel();
    if (value.isNotEmpty) {
      _socket.sendTyping(toUserId: widget.friend.userId, isTyping: true);
      _typingTimer = Timer(const Duration(seconds: 2), () {
        _socket.sendTyping(toUserId: widget.friend.userId, isTyping: false);
      });
    } else {
      _socket.sendTyping(toUserId: widget.friend.userId, isTyping: false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve:    Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.read<UserProvider>().user?.id ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E3F),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                  child: Text(
                    widget.friend.name.isNotEmpty
                        ? widget.friend.name[0].toUpperCase()
                        : '؟',
                    style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0, left: 0,
                  child: Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:  widget.friend.isOnline ? Colors.greenAccent : Colors.grey,
                      border: Border.all(color: const Color(0xFF1E1E3F), width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.friend.name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                if (_friendTyping)
                  const Text(
                    'يكتب الآن...',
                    style: TextStyle(color: Colors.greenAccent, fontSize: 11),
                  )
                else
                  Text(
                    widget.friend.isOnline ? 'أونلاين' : 'أوفلاين',
                    style: TextStyle(
                      color: widget.friend.isOnline ? Colors.greenAccent : Colors.grey,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),

      body: Column(
        children: [
          // ─── قائمة الرسائل ──────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('💬', style: TextStyle(fontSize: 60)),
                            const SizedBox(height: 12),
                            Text(
                              'ابدأ محادثة مع ${widget.friend.name}!',
                              style: const TextStyle(color: Colors.white54, fontSize: 15),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) {
                          final msg   = _messages[i];
                          final isMe  = msg.senderId == myId;
                          final showDate = i == 0 ||
                              _messages[i].createdAt.day !=
                                  _messages[i - 1].createdAt.day;
                          return Column(
                            children: [
                              if (showDate) _DateDivider(date: msg.createdAt),
                              _MessageBubble(msg: msg, isMe: isMe),
                            ],
                          );
                        },
                      ),
          ),

          // ─── حقل الكتابة ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E3F),
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller:  _msgCtrl,
                      onChanged:   _onTextChanged,
                      onSubmitted: (_) => _send(),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      textDirection: TextDirection.rtl,
                      maxLines: 4,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText:  'اكتب رسالة...',
                        hintStyle: const TextStyle(color: Colors.white30),
                        filled:    true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _send,
                    child: Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFF3D5AF1)],
                          begin: Alignment.topLeft,
                          end:   Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:  const Color(0xFF6C63FF).withValues(alpha: 0.4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: _sending
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.send_rounded,
                              color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── فقاعة رسالة ──────────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final MessageModel msg;
  final bool         isMe;

  const _MessageBubble({required this.msg, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          gradient: isMe
              ? const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF3D5AF1)],
                  begin:  Alignment.topLeft,
                  end:    Alignment.bottomRight,
                )
              : null,
          color: isMe ? null : const Color(0xFF16213E),
          borderRadius: BorderRadius.only(
            topLeft:     const Radius.circular(18),
            topRight:    const Radius.circular(18),
            bottomLeft:  Radius.circular(isMe ? 4 : 18),
            bottomRight: Radius.circular(isMe ? 18 : 4),
          ),
          boxShadow: [
            BoxShadow(
              color:     Colors.black.withValues(alpha: 0.15),
              blurRadius: 4,
              offset:    const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            Text(
              msg.message,
              style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 4),
            Text(
              '${msg.createdAt.hour.toString().padLeft(2, '0')}:'
              '${msg.createdAt.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── فاصل التاريخ ─────────────────────────────────────────────────────────────
class _DateDivider extends StatelessWidget {
  final DateTime date;
  const _DateDivider({required this.date});

  String _label() {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d     = DateTime(date.year, date.month, date.day);
    if (d == today) return 'اليوم';
    if (d == today.subtract(const Duration(days: 1))) return 'أمس';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        const Expanded(child: Divider(color: Colors.white10)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            _label(),
            style: const TextStyle(color: Colors.white30, fontSize: 11),
          ),
        ),
        const Expanded(child: Divider(color: Colors.white10)),
      ],
    ),
  );
}
