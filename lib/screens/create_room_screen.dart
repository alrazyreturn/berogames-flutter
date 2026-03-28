import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../models/category_model.dart';
import '../models/friend_model.dart';
import '../models/room_model.dart';
import '../providers/user_provider.dart';
import '../services/game_service.dart';
import '../services/room_service.dart';
import '../services/socket_service.dart';
import '../services/energy_service.dart';
import '../services/ad_service.dart';
import 'dual_game_screen.dart';
import 'subscription_screen.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
const _cBg      = Color(0xFF0B1326);
const _cSurface = Color(0xFF131B2E);
const _cCard    = Color(0xFF171F33);
const _cCyan    = Color(0xFF00FBFB);
const _cIndigo  = Color(0xFF6366F1);
const _cGold    = Color(0xFFFFD700);
const _cGreen   = Color(0xFF10B981);

// ─── Premium category names (name field in DB) ────────────────────────────────
const _premiumNames = {'quran', 'hadith', 'seerah', 'companions',
                       'السيرة النبوية', 'تاريخ الصحابة',
                       'القرآن الكريم',  'الأحاديث الشريفة'};

bool _isPremiumCategory(CategoryModel cat) =>
    cat.isPremium == true || _premiumNames.contains(cat.nameAr);

class CreateRoomScreen extends StatefulWidget {
  final FriendModel? inviteFriend;
  const CreateRoomScreen({super.key, this.inviteFriend});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final _gameService   = GameService();
  final _roomService   = RoomService();
  final _socket        = SocketService();
  final _energyService = EnergyService();

  List<CategoryModel> _categories      = [];
  CategoryModel?      _selected;
  RoomModel?          _room;
  bool _loadingCategories = true;
  bool _creatingRoom      = false;
  bool _checkingEnergy    = false;

  bool    _guestJoined = false;
  String? _guestName;
  int?    _guestId;
  String? _guestAvatar;
  int     _guestLevel  = 1;
  bool    _catsLoaded  = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_catsLoaded) { _catsLoaded = true; _loadCategories(); }
  }

  @override
  void dispose() {
    if (_room == null) _socket.clearCallbacks();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _gameService.getCategories(lang: context.locale.languageCode);
      if (mounted) setState(() { _categories = cats; _loadingCategories = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  // ─── tap on category card ──────────────────────────────────────────────────
  void _onCategoryTap(CategoryModel cat) {
    final provider = context.read<UserProvider>();
    final canPlayPremium = provider.canPlayPremium;

    if (_isPremiumCategory(cat) && !canPlayPremium) {
      _showPremiumGate();
      return;
    }
    setState(() => _selected = cat);
  }

  // ─── Create Room button ────────────────────────────────────────────────────
  Future<void> _onCreateRoomTap() async {
    if (_selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('create_room.select_first'.tr()),
            behavior: SnackBarBehavior.floating),
      );
      return;
    }

    final provider = context.read<UserProvider>();

    // Premium category → already gated at selection, but double-check
    if (_isPremiumCategory(_selected!) && !provider.canPlayPremium) {
      _showPremiumGate(); return;
    }

    // Subscribers with unlimited energy → skip energy check
    if (provider.hasUnlimitedEnergy) {
      await _createRoom(); return;
    }

    // Non-premium or no-ads subscriber → consume energy
    await _checkEnergyAndCreate();
  }

  Future<void> _checkEnergyAndCreate() async {
    final token = context.read<UserProvider>().token;
    if (token == null) return;

    setState(() => _checkingEnergy = true);
    try {
      final result = await _energyService.consumeEnergy(token);
      if (!mounted) return;
      final canPlay = result['can_play'] as bool? ?? false;
      if (canPlay) {
        await _createRoom();
      } else {
        _showNoEnergyDialog();
      }
    } catch (_) {
      if (mounted) _showNoEnergyDialog();
    } finally {
      if (mounted) setState(() => _checkingEnergy = false);
    }
  }

  // ─── Dialogs ───────────────────────────────────────────────────────────────
  void _showPremiumGate() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PremiumGateSheet(
        onSubscribe: () {
          Navigator.pop(context);
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
        },
      ),
    );
  }

  void _showNoEnergyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding:   const EdgeInsets.fromLTRB(20, 28, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        actionsPadding: EdgeInsets.zero,
        title: Column(children: [
          Container(
            width: 68, height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.amber.withValues(alpha: 0.15),
              boxShadow: [BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.4), blurRadius: 24)],
            ),
            child: const Center(
              child: Text('⚡', style: TextStyle(fontSize: 34)),
            ),
          ),
          const SizedBox(height: 14),
          Text('energy.no_energy_title'.tr(),
              style: const TextStyle(color: Colors.white, fontSize: 17,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── نص الجسم ──────────────────────────────────────────────
            Text('energy.no_energy_body'.tr(),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 14, height: 1.5),
                textAlign: TextAlign.center),
            const SizedBox(height: 18),

            // ─── زر شاهد الإعلان ──────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _cIndigo,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  elevation: 0,
                ),
                icon:  const Icon(Icons.play_circle_rounded, size: 20),
                label: Text('energy.watch_ad'.tr(),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _watchAdAndCreate();
                },
              ),
            ),
            const SizedBox(height: 10),

            // ─── زر الاشتراك VIP ──────────────────────────────────────
            GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const SubscriptionScreen()));
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFB300), Color(0xFFFF6F00)],
                    begin:  Alignment.centerRight,
                    end:    Alignment.centerLeft,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color:      const Color(0xFFFFB300).withValues(alpha: 0.40),
                      blurRadius: 18,
                      offset:     const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('👑', style: TextStyle(fontSize: 17)),
                    const SizedBox(width: 8),
                    Text(
                      'energy.subscribe_vip'.tr(),
                      style: const TextStyle(
                        color:      Colors.white,
                        fontSize:   14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),

            // ─── زر الإلغاء ───────────────────────────────────────────
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('common.cancel'.tr(),
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  void _watchAdAndCreate() {
    final token = context.read<UserProvider>().token;
    if (token == null) return;
    AdService().showRewarded(onRewarded: () async {
      try {
        await _energyService.rechargeEnergy(token);
        if (!mounted) return;
        await _createRoom();
      } catch (_) {}
    });
  }

  // ─── Actual room creation ──────────────────────────────────────────────────
  Future<void> _createRoom() async {
    final token = context.read<UserProvider>().token;
    final user  = context.read<UserProvider>().user;
    if (token == null || user == null) return;

    setState(() => _creatingRoom = true);
    try {
      final room = await _roomService.createRoom(
          categoryId: _selected!.id, token: token);

      _socket.connect();
      _socket.onPlayerJoined = (data) {
        if (!mounted) return;
        setState(() {
          _guestJoined = true;
          _guestName   = data['guest_name'] ?? 'common.opponent'.tr();
          _guestId     = data['guest_id'] != null
              ? int.tryParse('${data['guest_id']}') : null;
          _guestAvatar = data['guest_avatar'] as String?;
          _guestLevel  = (data['guest_level'] as int?) ?? 1;
        });
      };
      _socket.onError = (msg) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
      };

      _socket.joinRoom(
        roomCode: room.roomCode, userId: user.id,
        userName: user.name,    userAvatar: user.avatar,
        role: 'host',           lang: context.locale.languageCode,
      );

      if (widget.inviteFriend != null) {
        _guestName = widget.inviteFriend!.name;
        _socket.sendGameInvite(
          toUserId:     widget.inviteFriend!.userId,
          fromName:     user.name,
          roomCode:     room.roomCode,
          categoryName: _selected?.localizedName(context.locale.languageCode) ?? '',
        );
        _socket.onInviteSent = (data) {
          if (!mounted) return;
          final success = data['success'] == true;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(success
                ? 'create_room.invite_sent'.tr(
                    namedArgs: {'name': widget.inviteFriend!.name})
                : (data['message'] ?? 'create_room.offline'.tr())),
            behavior: SnackBarBehavior.floating,
          ));
        };
      }

      if (mounted) setState(() { _room = room; _creatingRoom = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _creatingRoom = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('common.error_prefix'.tr(namedArgs: {'msg': e.toString()})),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  void _startGame() {
    if (_room == null) return;
    final user = context.read<UserProvider>().user;
    _socket.startGame(
      roomCode: _room!.roomCode, categoryId: _room!.categoryId,
      roomId: _room!.roomId,    difficulty: 1,
      lang: context.locale.languageCode,
    );
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => DualGameScreen(
        room: _room!,          role: 'host',
        myName: user?.name ?? 'common.you'.tr(),
        guestName: _guestName ?? 'common.opponent'.tr(),
        opponentId: _guestId ?? widget.inviteFriend?.userId,
        opponentAvatar: _guestAvatar,
        opponentLevel: _guestLevel,
      ),
    ));
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cBg,
      appBar: _buildAppBar(),
      body: _room == null ? _buildSetup() : _buildWaiting(),
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    leading: IconButton(
      icon: Icon(Icons.arrow_back_ios_rounded, color: _cCyan.withValues(alpha: 0.8)),
      onPressed: () => Navigator.pop(context),
    ),
    title: Text('create_room.title'.tr(),
        style: const TextStyle(color: _cCyan, fontWeight: FontWeight.bold,
            fontSize: 18, letterSpacing: 0.5)),
    centerTitle: true,
    flexibleSpace: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [_cCyan.withValues(alpha: 0.06), Colors.transparent],
        ),
      ),
    ),
  );

  Widget _buildSetup() {
    final canPlayPremium = context.watch<UserProvider>().canPlayPremium;

    return SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(children: [
              Container(
                width: 4, height: 20,
                decoration: BoxDecoration(
                  color: _cCyan, borderRadius: BorderRadius.circular(2),
                  boxShadow: [BoxShadow(color: _cCyan.withValues(alpha: 0.6),
                      blurRadius: 8)],
                ),
              ),
              const SizedBox(width: 10),
              Text('create_room.choose_section'.tr(),
                  style: const TextStyle(color: Colors.white, fontSize: 16,
                      fontWeight: FontWeight.bold, letterSpacing: 0.3)),
            ]),
          ),

          // ─── Legend ───────────────────────────────────────────────────────
          if (!canPlayPremium)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(children: [
                Icon(Icons.lock_rounded, color: _cGold, size: 14),
                const SizedBox(width: 6),
                Text('subscription.premium_gate_title'.tr(),
                    style: TextStyle(color: _cGold.withValues(alpha: 0.8),
                        fontSize: 12)),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: _showPremiumGate,
                  child: Text('subscription.premium_gate_btn'.tr(),
                      style: const TextStyle(color: _cCyan, fontSize: 12,
                          decoration: TextDecoration.underline)),
                ),
              ]),
            ),

          // ─── Grid ─────────────────────────────────────────────────────────
          Expanded(
            child: _loadingCategories
                ? Center(child: CircularProgressIndicator(color: _cCyan, strokeWidth: 2))
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GridView.builder(
                      padding: const EdgeInsets.only(top: 12, bottom: 8),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12, mainAxisSpacing: 12,
                        childAspectRatio: 1.2,
                      ),
                      itemCount: _categories.length,
                      itemBuilder: (_, i) => _buildCategoryCard(
                          _categories[i], canPlayPremium),
                    ),
                  ),
          ),

          // ─── Create Button ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: _buildCreateButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(CategoryModel cat, bool canPlayPremium) {
    final isSelected  = _selected?.id == cat.id;
    final isPremium   = _isPremiumCategory(cat);
    final isLocked    = isPremium && !canPlayPremium;

    // Colors
    final Color glowColor = isPremium ? _cGold : _cCyan;
    final Color borderColor = isLocked
        ? _cGold.withValues(alpha: 0.35)
        : isSelected ? glowColor : Colors.white.withValues(alpha: 0.07);

    return GestureDetector(
      onTap: () => _onCategoryTap(cat),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isLocked
              ? _cCard.withValues(alpha: 0.6)
              : isSelected
                  ? glowColor.withValues(alpha: 0.12)
                  : _cCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor,
              width: isSelected ? 1.8 : 1),
          boxShadow: isSelected
              ? [BoxShadow(color: glowColor.withValues(alpha: 0.28),
                    blurRadius: 16, spreadRadius: 1)]
              : isPremium && !isLocked
                  ? [BoxShadow(color: _cGold.withValues(alpha: 0.12),
                        blurRadius: 10)]
                  : [],
        ),
        child: Stack(
          children: [
            // ─── Main content ───────────────────────────────────────────────
            Opacity(
              opacity: isLocked ? 0.45 : 1.0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 54, height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? glowColor.withValues(alpha: 0.12)
                          : Colors.white.withValues(alpha: 0.04),
                      boxShadow: isSelected
                          ? [BoxShadow(color: glowColor.withValues(alpha: 0.3),
                                blurRadius: 12)]
                          : [],
                    ),
                    child: Center(child: Text(cat.icon,
                        style: TextStyle(fontSize: isSelected ? 28 : 25))),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      cat.localizedName(context.locale.languageCode),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected ? glowColor : Colors.white70,
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.bold : FontWeight.normal,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ─── Lock badge (top-right) ──────────────────────────────────────
            if (isLocked)
              Positioned(
                top: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: _cGold.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: _cGold.withValues(alpha: 0.4)),
                    boxShadow: [BoxShadow(color: _cGold.withValues(alpha: 0.3),
                        blurRadius: 8)],
                  ),
                  child: const Icon(Icons.lock_rounded, color: _cGold, size: 13),
                ),
              ),

            // ─── Crown badge for unlocked premium ────────────────────────────
            if (isPremium && !isLocked)
              Positioned(
                top: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _cGold.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: _cGold.withValues(alpha: 0.4),
                        blurRadius: 6)],
                  ),
                  child: const Icon(Icons.workspace_premium_rounded,
                      color: _cGold, size: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateButton() {
    final busy = _creatingRoom || _checkingEnergy;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: _selected != null
              ? [_cCyan.withValues(alpha: 0.85), _cIndigo]
              : [Colors.white12, Colors.white.withValues(alpha: 0.06)],
        ),
        boxShadow: _selected != null
            ? [BoxShadow(color: _cCyan.withValues(alpha: 0.3),
                  blurRadius: 20, spreadRadius: 1, offset: const Offset(0, 4))]
            : [],
      ),
      child: ElevatedButton(
        onPressed: busy ? null : _onCreateRoomTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: busy
            ? SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(color: _cBg, strokeWidth: 2.5))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.meeting_room_rounded,
                    color: _selected != null ? _cBg : Colors.white24, size: 20),
                const SizedBox(width: 8),
                Text('create_room.create_btn'.tr(),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                        color: _selected != null ? _cBg : Colors.white24,
                        letterSpacing: 0.5)),
              ]),
      ),
    );
  }

  // ─── Waiting Room ──────────────────────────────────────────────────────────
  Widget _buildWaiting() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _cCyan.withValues(alpha: 0.08),
                border: Border.all(color: _cCyan.withValues(alpha: 0.3), width: 1.5),
                boxShadow: [BoxShadow(color: _cCyan.withValues(alpha: 0.15),
                    blurRadius: 30)],
              ),
              child: const Center(child: Text('🏠', style: TextStyle(fontSize: 40))),
            ),
            const SizedBox(height: 20),
            Text('create_room.share_code'.tr(),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14, letterSpacing: 0.5)),
            const SizedBox(height: 20),

            // Room Code
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: _room!.roomCode));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('create_room.copied'.tr()),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 1),
                ));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
                decoration: BoxDecoration(
                  color: _cCyan.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _cCyan.withValues(alpha: 0.6), width: 1.8),
                  boxShadow: [BoxShadow(color: _cCyan.withValues(alpha: 0.2),
                      blurRadius: 24, spreadRadius: 2)],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(_room!.roomCode,
                      style: TextStyle(color: _cCyan, fontSize: 36,
                          fontWeight: FontWeight.w900, letterSpacing: 8,
                          shadows: [Shadow(color: _cCyan.withValues(alpha: 0.7),
                              blurRadius: 12)])),
                  const SizedBox(width: 14),
                  Icon(Icons.copy_rounded, color: _cCyan.withValues(alpha: 0.5),
                      size: 20),
                ]),
              ),
            ),
            const SizedBox(height: 36),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: _guestJoined ? _buildGuestJoined() : _buildWaitingIndicator(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestJoined() {
    return Column(key: const ValueKey('joined'), children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: _cGreen.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cGreen.withValues(alpha: 0.4), width: 1.2),
          boxShadow: [BoxShadow(color: _cGreen.withValues(alpha: 0.15),
              blurRadius: 16)],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('✅', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Text('create_room.joined'.tr(
              namedArgs: {'name': _guestName ?? 'common.opponent'.tr()}),
              style: TextStyle(color: _cGreen, fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ]),
      ),
      const SizedBox(height: 28),
      Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
              colors: [Color(0xFF00FBFB), Color(0xFF00C8C8)]),
          boxShadow: [BoxShadow(color: _cCyan.withValues(alpha: 0.4),
              blurRadius: 20, spreadRadius: 1, offset: const Offset(0, 4))],
        ),
        child: ElevatedButton.icon(
          onPressed: _startGame,
          icon: const Icon(Icons.play_arrow_rounded, color: _cBg, size: 24),
          label: Text('create_room.start_btn'.tr(),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
                  color: _cBg, letterSpacing: 0.5)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
        ),
      ),
    ]);
  }

  Widget _buildWaitingIndicator() {
    return Column(key: const ValueKey('waiting'), children: [
      SizedBox(width: 40, height: 40,
          child: CircularProgressIndicator(color: _cCyan, strokeWidth: 2.5)),
      const SizedBox(height: 14),
      Text('create_room.waiting'.tr(),
          style: TextStyle(color: Colors.white.withValues(alpha: 0.45),
              fontSize: 14, letterSpacing: 0.3)),
    ]);
  }
}

// ─── Premium Gate Bottom Sheet ─────────────────────────────────────────────────
class _PremiumGateSheet extends StatelessWidget {
  final VoidCallback onSubscribe;
  const _PremiumGateSheet({required this.onSubscribe});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF131B2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 24),

        // Crown icon
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              _cGold.withValues(alpha: 0.3),
              _cGold.withValues(alpha: 0.05),
            ]),
            boxShadow: [BoxShadow(color: _cGold.withValues(alpha: 0.4),
                blurRadius: 24, spreadRadius: 2)],
            border: Border.all(color: _cGold.withValues(alpha: 0.5), width: 1.5),
          ),
          child: const Icon(Icons.workspace_premium_rounded,
              color: _cGold, size: 40),
        ),
        const SizedBox(height: 16),

        Text('subscription.premium_gate_title'.tr(),
            style: const TextStyle(color: Colors.white, fontSize: 20,
                fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('subscription.premium_gate_body'.tr(),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14, height: 1.5),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),

        // Features list
        ...['subscription.feature_all_sections',
            'subscription.feature_unlimited_energy',
            'subscription.feature_no_ads'].map((k) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.check_circle_rounded, color: _cGold, size: 16),
            const SizedBox(width: 8),
            Text(k.tr(),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13)),
          ]),
        )),
        const SizedBox(height: 24),

        // Subscribe button
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(colors: [
              _cGold.withValues(alpha: 0.9), const Color(0xFFFF8C00)]),
            boxShadow: [BoxShadow(color: _cGold.withValues(alpha: 0.4),
                blurRadius: 16, spreadRadius: 1, offset: const Offset(0, 4))],
          ),
          child: ElevatedButton.icon(
            onPressed: onSubscribe,
            icon: const Icon(Icons.workspace_premium_rounded,
                color: Colors.white, size: 20),
            label: Text('subscription.premium_gate_btn'.tr(),
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        const SizedBox(height: 12),

        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('common.cancel'.tr(),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
        ),
      ]),
    );
  }
}
