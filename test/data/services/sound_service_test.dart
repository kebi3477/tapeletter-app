import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tapeletter_app/data/services/sound_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('tapeletter/ui_sound');

  test('preload는 이름→에셋 경로를 한 번에 넘기고, play는 소리 길이만큼 기다린다', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (c) async {
          calls.add(c);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final s = PlatformSoundService();
    await s.preload();
    expect(calls.single.method, 'preload');
    expect(calls.single.arguments, {
      'on': 'assets/sounds/on.wav',
      'off': 'assets/sounds/off.wav',
      'send': 'assets/sounds/send.wav',
      'open': 'assets/sounds/open.wav',
    });
    final sw = Stopwatch()..start();
    await s.play(UiSound.off);
    expect(calls.last.method, 'play');
    expect(calls.last.arguments, 'off');
    expect(sw.elapsed, greaterThanOrEqualTo(UiSound.off.duration));
    await s.stop(UiSound.send);
    expect(calls.last.method, 'stop');
    expect(calls.last.arguments, 'send');
  });

  test('네이티브가 없어도(시험·웹) 예외 없이 지나간다', () async {
    final s = PlatformSoundService();
    await s.preload();
    await s.play(UiSound.on);
  });
}
