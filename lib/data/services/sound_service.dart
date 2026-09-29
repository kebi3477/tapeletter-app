import 'dart:async';

import 'package:flutter/services.dart';

/// 녹음 탭 데크 키 효과음 — `assets/sounds/` (모노 16bit 44.1kHz wav, 원본보다 −8dB)
enum UiSound {
  /// 녹음 시작(REC) · 재생 시작(PLAY)
  on('assets/sounds/on.wav', Duration(milliseconds: 540)),

  /// 녹음 멈춤(STOP) · 미리 듣기 멈춤
  off('assets/sounds/off.wav', Duration(milliseconds: 430));

  const UiSound(this.asset, this.duration);

  final String asset;

  /// 파일 길이 (on 0.539s, off 0.429s를 올림)
  final Duration duration;
}

/// 짧은 효과음. 녹음·재생 소리를 끊거나 줄이지 않고 섞이며, iOS 무음 모드면 울리지 않는다.
abstract class SoundService {
  /// 앱 시작 때 한 번 — 효과음을 미리 읽어 둔다.
  Future<void> preload();

  /// [sound]를 울린다. 반환된 Future는 소리가 **끝난 뒤** 끝난다
  /// (녹음을 on.wav 뒤에 시작하려고). 실패해도 예외를 던지지 않는다.
  Future<void> play(UiSound sound);
}

/// 네이티브 효과음 (`tapeletter/ui_sound` 채널).
/// - iOS: System Sound Services(`AudioServicesPlaySystemSound`) — 무음 스위치를 따르고,
///   앱의 AVAudioSession(녹음·재생)을 건드리지 않아 다른 소리를 끊거나 줄이지 않는다.
/// - Android: `SoundPool` + `USAGE_ASSISTANCE_SONIFICATION` — 오디오 포커스를 요청하지 않는다.
class PlatformSoundService implements SoundService {
  static const _channel = MethodChannel('tapeletter/ui_sound');

  @override
  Future<void> preload() async {
    try {
      await _channel.invokeMethod<void>('preload', {
        for (final s in UiSound.values) s.name: s.asset,
      });
    } catch (_) {}
  }

  @override
  Future<void> play(UiSound sound) async {
    unawaited(
      _channel.invokeMethod<void>('play', sound.name).catchError((_) {}),
    );
    // 시스템 효과음은 끝 알림을 믿을 수 없어(무음 모드 등) 파일 길이만큼 기다린다.
    await Future<void>.delayed(sound.duration);
  }
}

/// 소리 없음 (시험·기본값)
class NoSoundService implements SoundService {
  const NoSoundService();

  @override
  Future<void> preload() async {}

  @override
  Future<void> play(UiSound sound) async {}
}
