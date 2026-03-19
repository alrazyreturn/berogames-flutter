import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'socket_service.dart';

/// WebRtcService — اتصال صوتي peer-to-peer عبر WebRTC
/// الإشارات تمر عبر Socket.IO (webrtc_offer / webrtc_answer / webrtc_ice_candidate)
///
/// ⚡ getUserMedia لا يُستدعى إلا عند أول ضغطة على زر الميك
///    → لا يظهر ضوء الميك الأخضر في بداية التحدي
class WebRtcService {
  final SocketService _socket;
  final String        _roomCode;
  final bool          _isHost;

  RTCPeerConnection? _pc;
  MediaStream?       _localStream; // null حتى أول ضغطة على الميك

  bool _myMicWanted     = false; // ما يريده اللاعب (يتحكم في زر الـ UI)
  bool _opponentMicOn   = false; // حالة ميك الخصم (تصل عبر socket)
  bool _isDisposed      = false;
  bool _isInitialized   = false;
  bool _connectionReady = false; // true بعد اكتمال الـ offer/answer الأولي

  // ICE candidates تصل قبل remote description → نؤجلها
  bool                        _remoteDescSet     = false;
  final List<RTCIceCandidate> _pendingCandidates = [];

  static const Map<String, dynamic> _iceConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
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

  bool get micEnabled    => _myMicWanted;
  bool get isInitialized => _isInitialized;

  // ─── تهيئة WebRTC بدون getUserMedia (لا ضوء أخضر في البداية) ─────────────
  Future<void> init() async {
    if (_isDisposed) return;

    // إنشاء RTCPeerConnection فقط — بدون stream محلي بعد
    _pc = await createPeerConnection(_iceConfig);

    // استقبال tracks قادمة من الخصم (الصوت يُشغَّل تلقائياً)
    _pc!.onTrack = (RTCTrackEvent event) {
      // flutter_webrtc يُشغِّل audio tracks تلقائياً
    };

    // إرسال ICE candidates للخصم عبر socket
    _pc!.onIceCandidate = (RTCIceCandidate c) {
      if (_isDisposed || c.candidate == null || c.candidate!.isEmpty) return;
      _socket.sendWebRtcIceCandidate(
        roomCode:  _roomCode,
        candidate: c.toMap(),
      );
    };

    // عند إضافة track محلي لاحقاً → نعيد التفاوض (renegotiation)
    _pc!.onRenegotiationNeeded = () async {
      // فقط بعد اكتمال الـ handshake الأولي
      if (!_connectionReady || _isDisposed) return;
      await _sendOffer();
    };

    // تسجيل callbacks الإشارات
    _socket.onWebRtcOffer        = _handleOffer;
    _socket.onWebRtcAnswer       = _handleAnswer;
    _socket.onWebRtcIceCandidate = _handleIceCandidate;

    _isInitialized = true;

    // توجيه الصوت للسماعة الخارجية
    try { await Helper.setSpeakerphoneOn(true); } catch (_) {}

    // Host يرسل offer أولية لفتح القناة (بدون tracks محلية بعد)
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
      _remoteDescSet  = true;
      _connectionReady = true;
      await _flushPendingCandidates();

      final answer = await _pc!.createAnswer(_offerConstraints);
      await _pc!.setLocalDescription(answer);
      _socket.sendWebRtcAnswer(roomCode: _roomCode, sdp: answer.toMap());
    } catch (e) {
      print('❌ handleOffer: $e');
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
      _remoteDescSet  = true;
      _connectionReady = true;
      await _flushPendingCandidates();
    } catch (e) {
      print('❌ handleAnswer: $e');
    }
  }

  // ─── ICE candidate (مؤجل إذا لم يُعيَّن remote desc بعد) ─────────────────
  Future<void> _handleIceCandidate(Map<String, dynamic> data) async {
    if (_isDisposed || _pc == null) return;
    final c = data['candidate'];
    if (c == null) return;
    final candidate = RTCIceCandidate(
      c['candidate']   as String? ?? '',
      c['sdpMid']      as String?,
      c['sdpMLineIndex'] is int ? c['sdpMLineIndex'] as int : 0,
    );
    if (_remoteDescSet) {
      try { await _pc!.addCandidate(candidate); } catch (_) {}
    } else {
      _pendingCandidates.add(candidate);
    }
  }

  Future<void> _flushPendingCandidates() async {
    for (final c in _pendingCandidates) {
      try { await _pc!.addCandidate(c); } catch (_) {}
    }
    _pendingCandidates.clear();
  }

  Future<void> _sendOffer() async {
    if (_pc == null || _isDisposed) return;
    try {
      final offer = await _pc!.createOffer(_offerConstraints);
      await _pc!.setLocalDescription(offer);
      _socket.sendWebRtcOffer(roomCode: _roomCode, sdp: offer.toMap());
    } catch (e) {
      print('❌ sendOffer: $e');
    }
  }

  // ─── الصوت يمشي فقط لو الاتنين فاتحين ───────────────────────────────────
  void _applyMicState() {
    final shouldEnable = _myMicWanted && _opponentMicOn;
    _localStream?.getAudioTracks().forEach((t) => t.enabled = shouldEnable);
  }

  // ─── اللاعب يضغط زر الميك ────────────────────────────────────────────────
  // عند أول ضغطة: getUserMedia() ← هنا فقط يظهر الضوء الأخضر للنظام
  Future<void> toggleMic() async {
    if (_pc == null) return;

    if (_localStream == null) {
      // أول ضغطة: اطلب إذن الميك واحصل على الـ stream
      final status = await Permission.microphone.request();
      if (!status.isGranted) return;

      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl':  true,
        },
        'video': false,
      });

      // ابدأ بالـ track مغلقاً
      _localStream!.getAudioTracks().forEach((t) => t.enabled = false);

      // أضف الـ track → يُطلق onRenegotiationNeeded تلقائياً
      for (final track in _localStream!.getTracks()) {
        await _pc!.addTrack(track, _localStream!);
      }
    }

    _myMicWanted = !_myMicWanted;
    _applyMicState();
    // أبلغ الخصم بما تريده أنت (لتحديث أيقونته)
    _socket.sendWebRtcMicStatus(roomCode: _roomCode, micOn: _myMicWanted);
  }

  // ─── حالة ميك الخصم تغيرت → أعد حساب الـ track ──────────────────────────
  void updateOpponentMicStatus(bool opponentOn) {
    _opponentMicOn = opponentOn;
    _applyMicState();
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
