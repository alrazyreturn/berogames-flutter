import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../models/message_model.dart';
import '../models/friend_model.dart';
import '../providers/user_provider.dart';
import '../services/chat_service.dart';
import '../services/friends_service.dart';
import '../services/socket_service.dart';
import '../services/sound_service.dart';
import '../widgets/user_profile_sheet.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
const _cBg      = Color(0xFF0B1326);
const _cSurface = Color(0xFF131B2E);
const _cCyan    = Color(0xFF00FBFB);
const _cNavBg   = Color(0xFF10102B);

class ChatScreen extends StatefulWidget {
  final FriendModel friend;
  const ChatScreen({super.key, required this.friend});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _chatService    = ChatService();
  final _friendsService = FriendsService();
  final _socket         = SocketService();
  final _msgCtrl        = TextEditingController();
  final _scrollCtrl     = ScrollController();

  List<MessageModel> _messages     = [];
  final Set<int>     _filteredIds  = {};   // IDs الرسائل المرفوضة بسبب كلمات سيئة
  bool   _loading      = true;
  bool   _sending      = false;
  bool   _friendTyping = false;
  bool   _iBlocked     = false;
  bool   _theyBlocked  = false;
  Timer? _typingTimer;
  Timer? _sendTimeoutTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _socket.activeChatFriendId = widget.friend.userId;
    _loadHistory();
    _loadBlockStatus();
    _setupSocket();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sendTimeoutTimer?.cancel();
      if (mounted && _sending) setState(() => _sending = false);
      _messages.removeWhere((m) => m.id < 0);
      final user = context.read<UserProvider>().user;
      if (user == null) return;
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
    _socket.onChatMessageReceived  = null;
    _socket.onChatMessageSent      = null;
    _socket.onChatTyping           = null;
    _socket.onChatMessageDeleted   = null;
    _socket.activeChatFriendId     = null;
    _socket.sendTyping(toUserId: widget.friend.userId, isTyping: false);
    super.dispose();
  }

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

  Future<void> _loadBlockStatus() async {
    final token = context.read<UserProvider>().token;
    if (token == null) return;
    try {
      final status = await _friendsService.getBlockStatus(
          widget.friend.userId, token);
      if (!mounted) return;
      setState(() {
        _iBlocked    = status['i_blocked']    ?? false;
        _theyBlocked = status['they_blocked'] ?? false;
      });
    } catch (_) {}
  }

  Future<void> _showFriendProfile() async {
    await showModalBottomSheet<String>(
      context:           context,
      backgroundColor:   Colors.transparent,
      isScrollControlled: true,
      builder: (_) => UserProfileSheet(
        userId:       widget.friend.userId,
        name:         widget.friend.name,
        avatar:       widget.friend.avatar,
        score:        widget.friend.totalScore,
        isOnline:     widget.friend.isOnline,
        friendshipId: widget.friend.friendshipId,
      ),
    );
    // تحديث حالة الحظر بعد إغلاق الشيت
    if (mounted) _loadBlockStatus();
  }

  void _setupSocket() {
    final myId = context.read<UserProvider>().user?.id;

    _socket.onChatMessageReceived = (data) {
      if (!mounted) return;
      final senderId = data['sender_id'] as int?;
      if (senderId != widget.friend.userId) return;
      final msg = MessageModel.fromJson(data);
      if (_messages.any((m) => m.id == msg.id)) return;
      setState(() => _messages.add(msg));
      _scrollToBottom();
      SoundService().playChatNotify();
    };

    _socket.onChatMessageSent = (data) {
      if (!mounted) return;
      final senderId = data['sender_id'] as int?;
      if (senderId != myId) return;
      final realMsg = MessageModel.fromJson(data);
      _sendTimeoutTimer?.cancel();
      setState(() {
        _sending = false;
        _messages.removeWhere((m) => m.id < 0);
        if (!_messages.any((m) => m.id == realMsg.id)) {
          _messages.add(realMsg);
        }
      });
      _scrollToBottom();
    };

    _socket.onChatMessageDeleted = (data) {
      if (!mounted) return;
      final deletedId = data['message_id'] as int?;
      if (deletedId == null) return;
      setState(() => _messages.removeWhere((m) => m.id == deletedId));
    };

    _socket.onChatTyping = (data) {
      if (!mounted) return;
      final fromId   = data['from_user_id'] as int?;
      final isTyping = data['is_typing']    as bool? ?? false;
      if (fromId != widget.friend.userId) return;
      setState(() => _friendTyping = isTyping);
      if (isTyping) _scrollToBottom();
    };

    _socket.onChatBlocked = (_) {
      if (!mounted) return;
      setState(() => _iBlocked = true);
    };

    _socket.onChatFiltered = (_) {
      if (!mounted) return;
      // ابحث عن آخر رسالة مؤقتة (id سالب) وعلّمها كـ filtered
      final tempMsg = _messages.lastWhere(
        (m) => m.id < 0,
        orElse: () => _messages.first,
      );
      if (tempMsg.id < 0) {
        setState(() {
          _sending = false;
          _filteredIds.add(tempMsg.id);
          _sendTimeoutTimer?.cancel();
        });
      }
    };
  }

  void _send() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    final myId = context.read<UserProvider>().user?.id ?? 0;
    final tempMsg = MessageModel(
      id:         -DateTime.now().millisecondsSinceEpoch,
      senderId:   myId,
      receiverId: widget.friend.userId,
      message:    text,
      isRead:     false,
      createdAt:  DateTime.now(),
    );
    setState(() { _messages.add(tempMsg); _sending = true; });
    _msgCtrl.clear();
    _scrollToBottom();
    _socket.sendTyping(toUserId: widget.friend.userId, isTyping: false);
    _typingTimer?.cancel();
    _socket.sendChatMessage(toUserId: widget.friend.userId, message: text);
    _sendTimeoutTimer?.cancel();
    _sendTimeoutTimer = Timer(const Duration(seconds: 6), () {
      if (mounted && _sending) {
        setState(() {
          _sending = false;
          _messages.removeWhere((m) => m.id < 0);
        });
      }
    });
  }

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

  Future<void> _deleteMessage(MessageModel msg) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _cSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('chat.delete_msg'.tr(),
            style: const TextStyle(color: Colors.white)),
        content: Text('chat.delete_confirm'.tr(),
            style: const TextStyle(color: Colors.white60)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr(),
                style: const TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('common.delete'.tr(),
                style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final token = context.read<UserProvider>().token;
    if (token == null) return;
    try {
      await ChatService().deleteMessage(messageId: msg.id, token: token);
      _socket.deleteChatMessage(
          messageId: msg.id, toUserId: widget.friend.userId);
      setState(() => _messages.removeWhere((m) => m.id == msg.id));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('chat.delete_failed'.tr()),
            backgroundColor: _cSurface,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
      backgroundColor: _cBg,

      // ─── Header مخصص ────────────────────────────────────────────────────
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: BoxDecoration(
            color: _cSurface,
            boxShadow: [
              BoxShadow(
                color: _cCyan.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  // معلومات الصديق (يسار الشاشة في RTL = يمين منطقي)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.friend.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _friendTyping
                              ? 'chat.typing_now'.tr()
                              : widget.friend.isOnline
                                  ? 'friends.online'.tr()
                                  : 'friends.offline'.tr(),
                          style: TextStyle(
                            color: (_friendTyping || widget.friend.isOnline)
                                ? _cCyan
                                : Colors.white38,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // أفاتار الصديق
                  GestureDetector(
                    onTap: _showFriendProfile,
                    child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.friend.isOnline
                                ? _cCyan
                                : Colors.white24,
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: _cCyan.withValues(alpha: 0.12),
                          backgroundImage: widget.friend.avatar != null
                              ? NetworkImage(widget.friend.avatar!)
                              : null,
                          child: widget.friend.avatar == null
                              ? Text(
                                  widget.friend.name.isNotEmpty
                                      ? widget.friend.name[0].toUpperCase()
                                      : '؟',
                                  style: const TextStyle(
                                    color: _cCyan,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      // نقطة الحالة
                      Positioned(
                        bottom: 2,
                        left: 2,
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.friend.isOnline
                                ? Colors.greenAccent
                                : Colors.grey.shade600,
                            border: Border.all(color: _cSurface, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  ),

                  const SizedBox(width: 12),

                  // زر الرجوع (← سيان)
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: _cCyan,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),

      body: Column(
        children: [
          // ─── قائمة الرسائل ─────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _cCyan))
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded,
                                color: Colors.white12, size: 70),
                            const SizedBox(height: 12),
                            Text(
                              'chat.start_with'.tr(
                                  namedArgs: {'name': widget.friend.name}),
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 15),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) {
                          final msg      = _messages[i];
                          final isMe     = msg.senderId == myId;
                          final showDate = i == 0 ||
                              _messages[i].createdAt.day !=
                                  _messages[i - 1].createdAt.day;
                          return Column(
                            children: [
                              if (showDate)
                                _DateDivider(date: msg.createdAt),
                              GestureDetector(
                                onLongPress: isMe && msg.id > 0
                                    ? () => _deleteMessage(msg)
                                    : null,
                                child: _MessageBubble(
                                  msg:        msg,
                                  isMe:       isMe,
                                  friend:     widget.friend,
                                  isFiltered: _filteredIds.contains(msg.id),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
          ),

          // ─── "يكتب الآن" indicator ─────────────────────────────────────
          if (_friendTyping)
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 4),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _cSurface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _DotPulse(),
                    const SizedBox(width: 6),
                    Text(
                      'chat.typing_now'.tr(),
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

          // ─── banner الحظر ──────────────────────────────────────────────
          if (_iBlocked || _theyBlocked)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.red.shade900.withValues(alpha: 0.25),
                border: Border(
                    top: BorderSide(
                        color: Colors.redAccent.withValues(alpha: 0.4))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.block_rounded,
                      color: Colors.redAccent, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    _iBlocked
                        ? 'chat.you_blocked'.tr()
                        : 'chat.they_blocked'.tr(),
                    style: const TextStyle(
                        color: Colors.redAccent, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            // ─── منطقة الكتابة ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(
                color: _cSurface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    // أيقونة الإيموجي (يسار)
                    const Icon(Icons.sentiment_satisfied_alt_rounded,
                        color: Colors.white38, size: 26),
                    const SizedBox(width: 10),
                    // حقل الكتابة
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: _cBg,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: TextField(
                          controller:  _msgCtrl,
                          onChanged:   _onTextChanged,
                          onSubmitted: (_) => _send(),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                          textDirection: TextDirection.rtl,
                          maxLines: 4,
                          minLines: 1,
                          decoration: InputDecoration(
                            hintText:  'chat.type_hint'.tr(),
                            hintStyle: const TextStyle(
                                color: Colors.white30, fontSize: 14),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // زر الإرسال (يمين)
                    GestureDetector(
                      onTap: _send,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _cCyan,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _cCyan.withValues(alpha: 0.4),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: _sending
                            ? const Padding(
                                padding: EdgeInsets.all(13),
                                child: CircularProgressIndicator(
                                  color: _cNavBg, strokeWidth: 2),
                              )
                            : const Icon(Icons.send_rounded,
                                color: _cNavBg, size: 22),
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
  final FriendModel  friend;
  final bool         isFiltered;

  const _MessageBubble({
    required this.msg,
    required this.isMe,
    required this.friend,
    this.isFiltered = false,
  });

  @override
  Widget build(BuildContext context) {
    final time =
        '${msg.createdAt.hour.toString().padLeft(2, '0')}:'
        '${msg.createdAt.minute.toString().padLeft(2, '0')}';

    // فقاعة الرسالة
    final bubble = isFiltered
        // ── رسالة مرفوضة (كلمة سيئة) ─────────────────────────────────────
        ? Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.65,
            ),
            decoration: BoxDecoration(
              color: Colors.red.shade900.withValues(alpha: 0.18),
              borderRadius: const BorderRadius.only(
                topLeft:     Radius.circular(18),
                topRight:    Radius.circular(18),
                bottomLeft:  Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.4), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.orangeAccent, size: 16),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'chat.filtered_msg'.tr(),
                    style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 12,
                        fontStyle: FontStyle.italic),
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ],
            ),
          )
        // ── رسالة عادية ───────────────────────────────────────────────────
        : Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.65,
            ),
            decoration: BoxDecoration(
              gradient: isMe
                  ? const LinearGradient(
                      colors: [Color(0xFF00FBFB), Color(0xFF00C8D8)],
                      begin:  Alignment.bottomLeft,
                      end:    Alignment.topRight,
                    )
                  : null,
              color: isMe ? null : _cSurface,
              borderRadius: BorderRadius.only(
                topLeft:     const Radius.circular(18),
                topRight:    const Radius.circular(18),
                bottomLeft:  Radius.circular(isMe ? 4  : 18),
                bottomRight: Radius.circular(isMe ? 18 : 4),
              ),
              boxShadow: isMe
                  ? [
                      BoxShadow(
                        color: _cCyan.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ],
            ),
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                Text(
                  msg.message,
                  style: TextStyle(
                    color: isMe ? _cNavBg : Colors.white,
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: isMe ? FontWeight.w600 : FontWeight.normal,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: TextStyle(
                    color: isMe
                        ? _cNavBg.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.35),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          );

    // الرسائل المُستقبَلة: فقاعة + أفاتار (الأفاتار دائماً على اليمين)
    if (!isMe) {
      return Align(
        alignment: Alignment.centerRight,
        child: Directionality(
          // نُجبر LTR دائماً حتى في وضع العربية
          // بذلك يكون الترتيب: فقاعة ← SizedBox ← أفاتار (أفاتار على اليمين)
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              bubble,
              const SizedBox(width: 6),
              CircleAvatar(
                radius: 14,
                backgroundColor: _cCyan.withValues(alpha: 0.15),
                backgroundImage: friend.avatar != null
                    ? NetworkImage(friend.avatar!)
                    : null,
                child: friend.avatar == null
                    ? Text(
                        friend.name.isNotEmpty
                            ? friend.name[0].toUpperCase()
                            : '؟',
                        style: const TextStyle(
                          color: _cCyan,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      );
    }

    // الرسائل المُرسَلة: فقاعة فقط على اليسار
    return Align(
      alignment: Alignment.centerLeft,
      child: bubble,
    );
  }
}

// ─── فاصل التاريخ ─────────────────────────────────────────────────────────────
class _DateDivider extends StatelessWidget {
  final DateTime date;
  const _DateDivider({required this.date});

  @override
  Widget build(BuildContext context) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d     = DateTime(date.year, date.month, date.day);
    String label;
    if (d == today) {
      label = 'chat.today'.tr();
    } else if (d == today.subtract(const Duration(days: 1))) {
      label = 'chat.yesterday'.tr();
    } else {
      label = '${date.day}/${date.month}/${date.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: _cSurface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ),
      ),
    );
  }
}

// ─── نبضة "يكتب الآن" ─────────────────────────────────────────────────────────
class _DotPulse extends StatefulWidget {
  @override
  State<_DotPulse> createState() => _DotPulseState();
}

class _DotPulseState extends State<_DotPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) => Container(
          width: 5, height: 5,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: const BoxDecoration(
            color: _cCyan, shape: BoxShape.circle,
          ),
        )),
      ),
    );
  }
}
