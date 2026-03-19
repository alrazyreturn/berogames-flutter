import 'dart:math';
import 'package:audioplayers/audioplayers.dart';

/// خدمة الصوت - تشغيل صوت عشوائي عند الإجابة الصحيحة أو الخاطئة
class SoundService {
  // Singleton
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _player     = AudioPlayer();
  final AudioPlayer _chatPlayer = AudioPlayer(); // player مستقل للـ chat
  final Random _random = Random();

  // ─── أصوات الإجابة الصحيحة ───────────────────────────────────────────────
  static const List<String> _happySounds = [
    'sounds/happy/answer-correct.mp3',
    'sounds/happy/default_eKkIk7O.mp3',
    'sounds/happy/kids_cheering.mp3',
    'sounds/happy/omgwow.mp3',
    'sounds/happy/original-sheesh.mp3',
    'sounds/happy/very-nice-borat.mp3',
    'sounds/happy/yeah-boymp4.mp3',
  ];

  // ─── أصوات الإجابة الخاطئة ───────────────────────────────────────────────
  static const List<String> _sadSounds = [
    'sounds/sad/ceeday-huh-sound-effect.mp3',
    'sounds/sad/fahhhhh-5.mp3',
    'sounds/sad/final_60108db6919bc200b087a3a2_239343.mp3',
    'sounds/sad/oh_no_1.mp3',
    'sounds/sad/ow2-online-audio-converter.mp3',
    'sounds/sad/sorry-sorry-sorry.mp3',
    'sounds/sad/tf_nemesis.mp3',
    'sounds/sad/y2mate_VKI8qDn.mp3',
  ];

  /// تشغيل صوت عشوائي للإجابة الصحيحة
  Future<void> playCorrect() async {
    try {
      final path = _happySounds[_random.nextInt(_happySounds.length)];
      await _player.stop();
      await _player.play(AssetSource(path));
    } catch (_) {}
  }

  /// تشغيل صوت عشوائي للإجابة الخاطئة
  Future<void> playWrong() async {
    try {
      final path = _sadSounds[_random.nextInt(_sadSounds.length)];
      await _player.stop();
      await _player.play(AssetSource(path));
    } catch (_) {}
  }

  /// تشغيل صوت إشعار الرسالة الواردة (ding خفيف وسريع)
  Future<void> playChatNotify() async {
    try {
      await _chatPlayer.stop();
      await _chatPlayer.play(AssetSource('sounds/notification/chat_notify.wav'));
    } catch (_) {}
  }

  void dispose() {
    _player.dispose();
    _chatPlayer.dispose();
  }
}
