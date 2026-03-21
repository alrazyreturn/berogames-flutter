import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../providers/user_provider.dart';
import '../services/friends_service.dart';

// ─── Neon-Glass palette ───────────────────────────────────────────────────────
const _cSurface = Color(0xFF131B2E);
const _cCyan    = Color(0xFF00FBFB);
const _cIndigo  = Color(0xFF6366F1);

// حالة العلاقة
enum _RelStatus { loading, none, pendingSent, pendingReceived, accepted }
enum _BlockStatus { loading, none, iBlocked, theyBlocked }

/// شاشة بروفايل مستخدم قابلة لإعادة الاستخدام
/// تُستخدم في: شاشة الأصدقاء، اللوحة، نتائج البحث
class UserProfileSheet extends StatefulWidget {
  final int     userId;
  final String  name;
  final String? avatar;
  final int?    score;
  final bool?   isOnline;
  /// لو عندنا الـ friendshipId مسبقاً (من قائمة الأصدقاء)
  final int?    friendshipId;

  const UserProfileSheet({
    super.key,
    required this.userId,
    required this.name,
    this.avatar,
    this.score,
    this.isOnline,
    this.friendshipId,
  });

  @override
  State<UserProfileSheet> createState() => _UserProfileSheetState();
}

class _UserProfileSheetState extends State<UserProfileSheet> {
  final _service = FriendsService();

  _RelStatus   _rel   = _RelStatus.loading;
  _BlockStatus _block = _BlockStatus.loading;
  bool _actionLoading = false;
  int? _friendshipId;

  static const _ringColors = [
    _cCyan,
    Color(0xFFFF6584),
    Color(0xFFFFD700),
    _cIndigo,
    Colors.greenAccent,
    Colors.orangeAccent,
  ];

  Color get _ring => _ringColors[widget.userId % _ringColors.length];

  @override
  void initState() {
    super.initState();
    _friendshipId = widget.friendshipId;
    _load();
  }

  Future<void> _load() async {
    final token = context.read<UserProvider>().token;
    if (token == null) return;
    try {
      final results = await Future.wait([
        _service.getFollowStatus(widget.userId, token),
        _service.getBlockStatus(widget.userId, token),
      ]);
      if (!mounted) return;
      final relMap = results[0] as Map<String, dynamic>; // ignore: unnecessary_cast
      final blk    = results[1] as Map<String, bool>;

      final relStr = relMap['status'] as String? ?? 'none';
      final fid    = relMap['friendship_id'];
      if (fid != null) _friendshipId = int.tryParse(fid.toString());

      _RelStatus rel;
      switch (relStr) {
        case 'accepted':          rel = _RelStatus.accepted;          break;
        case 'pending_sent':      rel = _RelStatus.pendingSent;       break;
        case 'pending_received':  rel = _RelStatus.pendingReceived;   break;
        default:                  rel = _RelStatus.none;
      }

      _BlockStatus bst;
      if (blk['i_blocked'] == true)         bst = _BlockStatus.iBlocked;
      else if (blk['they_blocked'] == true) bst = _BlockStatus.theyBlocked;
      else                                  bst = _BlockStatus.none;

      setState(() { _rel = rel; _block = bst; });
    } catch (_) {
      if (mounted) setState(() { _rel = _RelStatus.none; _block = _BlockStatus.none; });
    }
  }

  Future<void> _follow() async {
    final token = context.read<UserProvider>().token;
    if (token == null || _actionLoading) return;
    setState(() => _actionLoading = true);
    try {
      final res = await _service.followByUserId(widget.userId, token);
      if (!mounted) return;
      final status = res['status'] as String? ?? '';
      setState(() {
        _actionLoading = false;
        if (status == 'accepted') _rel = _RelStatus.accepted;
        else                      _rel = _RelStatus.pendingSent;
      });
    } catch (_) {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _unfollow() async {
    final token = context.read<UserProvider>().token;
    if (token == null || _friendshipId == null || _actionLoading) return;
    setState(() => _actionLoading = true);
    try {
      await _service.deleteFriend(_friendshipId!, token);
      if (!mounted) return;
      Navigator.pop(context, 'unfollowed');
    } catch (_) {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _blockUser() async {
    final token = context.read<UserProvider>().token;
    if (token == null || _actionLoading) return;
    setState(() => _actionLoading = true);
    try {
      await _service.blockUser(widget.userId, token);
      if (!mounted) return;
      // الـ API يحذف الصداقة تلقائياً — نعكس ذلك محلياً
      setState(() {
        _block         = _BlockStatus.iBlocked;
        _rel           = _RelStatus.none;
        _friendshipId  = null;
        _actionLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _unblock() async {
    final token = context.read<UserProvider>().token;
    if (token == null || _actionLoading) return;
    setState(() => _actionLoading = true);
    try {
      await _service.unblockUser(widget.userId, token);
      if (!mounted) return;
      setState(() { _block = _BlockStatus.none; _actionLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ring = _ring;

    return Container(
      decoration: const BoxDecoration(
        color:        _cSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── الصورة الكبيرة ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ring, width: 3),
              boxShadow: [
                BoxShadow(
                  color:      ring.withValues(alpha: 0.45),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 52,
              backgroundColor: ring.withValues(alpha: 0.15),
              backgroundImage: widget.avatar != null
                  ? NetworkImage(widget.avatar!)
                  : null,
              child: widget.avatar == null
                  ? Text(
                      widget.name.isNotEmpty
                          ? widget.name[0].toUpperCase()
                          : '؟',
                      style: TextStyle(
                        color:      ring,
                        fontSize:   38,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
          ),

          const SizedBox(height: 14),

          // ── الاسم ────────────────────────────────────────────────────────
          Text(
            widget.name,
            style: const TextStyle(
              color:      Colors.white,
              fontSize:   20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          // ── النقاط + الحالة ──────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.score != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color:        Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
                    boxShadow: [BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.2), blurRadius: 8)],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 15),
                    const SizedBox(width: 4),
                    Text('${widget.score}',
                        style: const TextStyle(
                            color: Colors.amber, fontSize: 13,
                            fontWeight: FontWeight.bold)),
                  ]),
                ),
                const SizedBox(width: 10),
              ],
              if (widget.isOnline != null) ...[
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.isOnline!
                        ? Colors.greenAccent
                        : Colors.grey.shade600,
                    boxShadow: widget.isOnline!
                        ? [BoxShadow(
                            color: Colors.greenAccent.withValues(alpha: 0.5),
                            blurRadius: 6)]
                        : [],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  widget.isOnline!
                      ? 'friends.online'.tr()
                      : 'friends.offline'.tr(),
                  style: TextStyle(
                    color:    widget.isOnline!
                        ? Colors.greenAccent
                        : Colors.white38,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 24),

          // ── زر المتابعة / إلغاء المتابعة ─────────────────────────────────
          if (_rel == _RelStatus.loading || _block == _BlockStatus.loading)
            const SizedBox(height: 52,
                child: Center(child: CircularProgressIndicator(
                    color: _cCyan, strokeWidth: 2)))
          else if (_block == _BlockStatus.theyBlocked)
            _infoRow(Icons.block_rounded, Colors.red.shade300,
                'friends.blocked_by_them'.tr())
          else if (_block == _BlockStatus.iBlocked)
            _unfollowBtn(
              icon:  Icons.lock_open_rounded,
              color: Colors.orangeAccent,
              label: 'friends.unblock'.tr(),
              onTap: _unblock,
            )
          else if (_rel == _RelStatus.accepted)
            _unfollowBtn(
              icon:  Icons.person_remove_rounded,
              color: Colors.redAccent,
              label: 'friends.unfollow'.tr(),
              onTap: _unfollow,
            )
          else if (_rel == _RelStatus.pendingSent)
            _infoRow(Icons.check_circle_outline, Colors.white38,
                'leaderboard.request_sent'.tr())
          else
            _followBtn(),

          const SizedBox(height: 10),

          // ── زر الحظر ─────────────────────────────────────────────────────
          if (_block != _BlockStatus.loading &&
              _block != _BlockStatus.iBlocked &&
              _block != _BlockStatus.theyBlocked)
            _unfollowBtn(
              icon:  Icons.block_rounded,
              color: Colors.orange.shade700,
              label: 'friends.block'.tr(),
              onTap: _blockUser,
            ),
        ],
      ),
    );
  }

  Widget _followBtn() => SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: _actionLoading ? null : _follow,
      icon:  _actionLoading
          ? const SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
          : const Icon(Icons.person_add_rounded, size: 20),
      label: Text('friends.follow'.tr(),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: _cCyan,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        shadowColor: _cCyan.withValues(alpha: 0.4),
      ),
    ),
  );

  Widget _unfollowBtn({
    required IconData     icon,
    required Color        color,
    required String       label,
    required VoidCallback onTap,
  }) =>
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _actionLoading ? null : onTap,
          icon:  _actionLoading
              ? SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(color: color, strokeWidth: 2))
              : Icon(icon, color: color, size: 20),
          label: Text(label,
              style: TextStyle(color: color, fontSize: 15,
                  fontWeight: FontWeight.bold)),
          style: OutlinedButton.styleFrom(
            side:    BorderSide(color: color.withValues(alpha: 0.7), width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:   RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
        ),
      );

  Widget _infoRow(IconData icon, Color color, String label) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(color: color, fontSize: 14)),
    ],
  );
}
