import 'dart:async';

import 'package:flutter/services.dart';

/// 효과음 — `assets/sounds/` (모노 16bit 44.1kHz wav). on·off는 원본보다 −8dB,
/// send·open은 on·off와 체감 크기(100ms 최대 RMS 약 −30dBFS)가 같게 맞췄다.
enum UiSound {
  /// 녹음 시작(REC) · 재생 시작(PLAY)
  on('assets/sounds/on.wav', Duration(milliseconds: 540)),

  /// 녹음 멈춤(STOP) · 미리 듣기 멈춤
  off('assets/sounds/off.wav', Duration(milliseconds: 430)),

  /// 보내기 연출 — 테이프가 소포 상자에 들어가기 시작할 때(`tapeIn`)부터 완료 화면까지
  send('assets/sounds/send.wav', Duration(milliseconds: 3260)),

  /// 받은 소포를 뜯는 순간(`tearing`)
  open('assets/sounds/open.wav', Duration(milliseconds: 1350));

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

  /// 울리는 중인 [sound]를 멈춘다 (보내기 실패). 이미 끝났으면 아무 일도 없다.
  Future<void> stop(UiSound sound);
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

  @override
  Future<void> stop(UiSound sound) async {
    try {
      await _channel.invokeMethod<void>('stop', sound.name);
    } catch (_) {}
  }
}

/// 소리 없음 (시험·기본값)
class NoSoundService implements SoundService {
  const NoSoundService();

  @override
  Future<void> preload() async {}

  @override
  Future<void> play(UiSound sound) async {}

  @override
  Future<void> stop(UiSound sound) async {}
}
