import 'package:tapeletter_app/data/services/sound_service.dart';

/// 효과음 기록. [log]를 녹음기 호출 목록과 같이 쓰면 소리 → 녹음 순서를 볼 수 있다.
class FakeSoundService implements SoundService {
  FakeSoundService({List<String>? log, this.realDuration = false})
    : log = log ?? [];

  final List<String> log;

  /// 참이면 실제 파일 길이만큼 기다린다 (녹음 시작 순서 시험)
  bool realDuration;

  bool preloaded = false;

  /// 울린 소리만
  List<UiSound> get played => [
    for (final l in log)
      if (l.startsWith('sound:') && !l.endsWith(':end'))
        UiSound.values.byName(l.substring(6)),
  ];

  @override
  Future<void> preload() async => preloaded = true;

  @override
  Future<void> play(UiSound sound) async {
    log.add('sound:${sound.name}');
    if (realDuration) await Future<void>.delayed(sound.duration);
    log.add('sound:${sound.name}:end');
  }

  @override
  Future<void> stop(UiSound sound) async => log.add('stop:${sound.name}');
}
