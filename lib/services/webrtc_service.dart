import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'socket_service.dart';

/// WebRtcService — اتصال صوتي peer-to-peer عبر WebRTC
/// الإشارات تمر عبر Socket.IO (webrtc_offer / webrtc_answer / webrtc_ice_candidate)
class WebRtcService {
  final SocketService _socket;
  final String        _roomCode;
  final bool          _isHost;

  RTCPeerConnection? _pc;
  MediaStream?       _localStream;

  bool _myMicWanted   = false; // اللاعب ضغط "فتح" — ما يريده هو
  bool _opponentMicOn = false; // حالة ميك الخصم (تصل عبر socket)
  bool _isDisposed    = false;
  bool _isInitialized = false;

  // نحتاج هذا لتأجيل ICE candidates حتى يُعيَّن الـ remote description
  bool                        _remoteDescSet     = false;
  final List<RTCIceCandidate> _pendingCandidates = [];

  static const Map<String, dynamic> _iceConfig = {
    'iceServers': [
      { 'urls': 'stun:stun.l.google.com:19302'  },
      { 'urls': 'stun:stun1.l.google.com:19302' },
    ],
    'sdpSemantics': 'unified-plan',
  };

  static const Map<String, dynamic> _offerConstraints = {
    'mandatory': {
      'OfferToReceiveAudio': true,
      'OfferToReceiveVideo': false,
    },
  };

  WebRtcService({
    required SocketService socket,
    required String        roomCode,
    required bool          isHost,
  })  : _socket   = socket,
        _roomCode  = roomCode,
        _isHost    = isHost;

  bool get micEnabled    => _myMicWanted;  // حالة الزر (ما يريده اللاعب)
  bool get isInitialized => _isInitialized;

  // ─── تهيئة WebRTC ──────────────────────────────────────────────────────────
  Future<void> init() async {
    if (_isDisposed) return;

    // طلب إذن الميكروفون
    final status = await Permission.microphone.request();
    if (!status.isGranted) return;

    // تدفق صوتي محلي مع تحسينات الصوت
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': false,
    });

    // يبدأ الميك صامتاً — اللاعب يفتحه بنفسه
    _localStream!.getAudioTracks().forEach((t) => t.enabled = false);

    // إنشاء RTCPeerConnection
    _pc = await createPeerConnection(_iceConfig);

    // إضافة الـ tracks المحلية
    for (final track in _localStream!.getTracks()) {
      await _pc!.addTrack(track, _localStream!);
    }

    // ─── استقبال الـ tracks القادمة من الطرف الآخر ──────────────────────────
    // هذا هو ما يجعل الصوت القادم يُشغَّل تلقائياً
    _pc!.onTrack = (RTCTrackEvent event) {
      // flutter_webrtc يُشغِّل صوت الـ audio tracks تلقائياً عند استقبالها
      // لا نحتاج لأي renderer إضافي للصوت
    };

    // ─── ICE candidates → أرسلها للطرف الآخر ──────────────────────────────
    _pc!.onIceCandidate = (RTCIceCandidate c) {
      if (_isDisposed || c.candidate == null || c.candidate!.isEmpty) return;
      _socket.sendWebRtcIceCandidate(
        roomCode:  _roomCode,
        candidate: c.toMap(),
      );
    };

    // ─── تسجيل callbacks الإشارات ────────────────────────────────────────
    _socket.onWebRtcOffer        = _handleOffer;
    _socket.onWebRtcAnswer       = _handleAnswer;
    _socket.onWebRtcIceCandidate = _handleIceCandidate;

    _isInitialized = true;

    // توجيه الصوت إلى السماعة الخارجية (speaker) لا الأذن (earpiece)
    try { await Helper.setSpeakerphoneOn(true); } catch (_) {}

    // Host ينشئ ويرسل الـ offer بعد تأخير ليضمن جاهزية الـ guest
    if (_isHost) {
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!_isDisposed) await _sendOffer();
    }
  }

  // ─── Guest يستقبل offer ويرد بـ answer ───────────────────────────────────
  Future<void> _handleOffer(Map<String, dynamic> data) async {
    if (_isDisposed || _pc == null) return;
    try {
      final sdpMap = Map<String, dynamic>.from(data['sdp'] ?? {});
      await _pc!.setRemoteDescription(
        RTCSessionDescription(sdpMap['sdp'], sdpMap['type']),
      );
      _remoteDescSet = true;
      await _flushPendingCandidates();

      final answer = await _pc!.createAnswer(_offerConstraints);
      await _pc!.setLocalDescription(answer);
      _socket.sendWebRtcAnswer(roomCode: _roomCode, sdp: answer.toMap());
    } catch (e) {
      print('❌ WebRTC handleOffer error: $e');
    }
  }

  // ─── Host يستقبل answer ──────────────────────────────────────────────────
  Future<void> _handleAnswer(Map<String, dynamic> data) async {
    if (_isDisposed || _pc == null) return;
    try {
      final sdpMap = Map<String, dynamic>.from(data['sdp'] ?? {});
      await _pc!.setRemoteDescription(
        RTCSessionDescription(sdpMap['sdp'], sdpMap['type']),
      );
      _remoteDescSet = true;
      await _flushPendingCandidates();
    } catch (e) {
      print('❌ WebRTC handleAnswer error: $e');
    }
  }

  // ─── ICE candidate — قد يصل قبل remote description فنؤجله ──────────────
  Future<void> _handleIceCandidate(Map<String, dynamic> data) async {
    if (_isDisposed || _pc == null) return;
    final c = data['candidate'];
    if (c == null) return;
    final candidate = RTCIceCandidate(
      c['candidate'] as String? ?? '',
      c['sdpMid']   as String?,
      c['sdpMLineIndex'] is int ? c['sdpMLineIndex'] as int : 0,
    );
    if (_remoteDescSet) {
      try { await _pc!.addCandidate(candidate); } catch (_) {}
    } else {
      _pendingCandidates.add(candidate); // نؤجله حتى يُعيَّن remote desc
    }
  }

  // ─── إرسال الـ ICE candidates المؤجلة بعد تعيين remote desc ─────────────
  Future<void> _flushPendingCandidates() async {
    for (final c in _pendingCandidates) {
      try { await _pc!.addCandidate(c); } catch (_) {}
    }
    _pendingCandidates.clear();
  }

  // ─── Host ينشئ offer ──────────────────────────────────────────────────────
  Future<void> _sendOffer() async {
    if (_pc == null || _isDisposed) return;
    try {
      final offer = await _pc!.createOffer(_offerConstraints);
      await _pc!.setLocalDescription(offer);
      _socket.sendWebRtcOffer(roomCode: _roomCode, sdp: offer.toMap());
    } catch (e) {
      print('❌ WebRTC sendOffer error: $e');
    }
  }

  // ─── تطبيق حالة الـ track الفعلية (الاتنين لازم فاتحين) ─────────────────
  void _applyMicState() {
    // الصوت يمشي فقط لو أنا فاتح الميك والخصم برضه فاتح الميك
    final shouldEnable = _myMicWanted && _opponentMicOn;
    _localStream?.getAudioTracks().forEach((t) => t.enabled = shouldEnable);
  }

  // ─── اللاعب يضغط زر الميك ────────────────────────────────────────────────
  void toggleMic() {
    if (_localStream == null) return;
    _myMicWanted = !_myMicWanted;
    _applyMicState();
    // أخبر الخصم بما أريده (مش الحالة الفعلية) لتحديث أيقونته
    _socket.sendWebRtcMicStatus(roomCode: _roomCode, micOn: _myMicWanted);
  }

  // ─── حالة ميك الخصم وصلت → أعد حساب حالة الـ track ─────────────────────
  void updateOpponentMicStatus(bool opponentOn) {
    _opponentMicOn = opponentOn;
    _applyMicState(); // لو الخصم فتح وأنا فاتح → الصوت يمشي
  }

  // ─── تنظيف الموارد ───────────────────────────────────────────────────────
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    _socket.onWebRtcOffer        = null;
    _socket.onWebRtcAnswer       = null;
    _socket.onWebRtcIceCandidate = null;

    _localStream?.getTracks().forEach((t) => t.stop());
    await _localStream?.dispose();
    await _pc?.close();
    _pc = null;
  }
}
