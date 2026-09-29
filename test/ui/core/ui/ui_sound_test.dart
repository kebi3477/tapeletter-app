import 'package:flutter_test/flutter_test.dart';
import 'package:tapeletter_app/data/services/sound_service.dart';
import 'package:tapeletter_app/ui/core/ui/tape_motion.dart';
import 'package:tapeletter_app/ui/record/view_model/record_view_model.dart';

import '../../../../testing/app.dart';
import '../../../../testing/fonts.dart';
import '../../../../testing/record_harness.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets(
    '데크 REC(390×844): 떼면 on.wav, STOP이 0.45초에 가운데, 녹음은 on.wav가 끝난 0.54초에',
    (tester) async {
      useDesignScreen(tester);
      final h = RecordHarness();
      h.sound.realDuration = true;
      await tester.pumpWidget(testApp(h));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      h.recorder.calls.clear();

      await tester.tap(find.bySemanticsLabel('REC'));
      await tester.pump();
      expect(h.recorder.calls, ['sound:on']);
      expect(h.vm.arming, isTrue);
      await tester.pump(const Duration(milliseconds: 450));
      expect(
        tester.getCenter(find.bySemanticsLabel('STOP')).dx,
        closeTo(195, 1),
        reason: '데크는 소리가 끝나기 전에 STOP을 가운데로 민다',
      );
      expect(h.recorder.calls, isNot(contains('start')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(h.recorder.calls, ['sound:on', 'sound:on:end', 'start']);
      expect(h.vm.phase, RecordPhase.rec);

      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.bySemanticsLabel('STOP'));
      await tester.pump();
      expect(h.recorder.calls.sublist(3, 5), ['stop', 'sound:off']);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets('데크 밖(‹ 뒤로 · ✕ 닫기 · 재생 화면 재생 버튼 · Android 뒤로)은 소리가 없다', (
    tester,
  ) async {
    useDesignScreen(tester);
    final h = RecordHarness();
    await tester.pumpWidget(testApp(h, initialLocation: '/my'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.tap(find.bySemanticsLabel('받은 테이프'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('‹'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 재생 화면: 재생·멈춤 버튼, ✕
    await tester.tap(find.bySemanticsLabel('받은 테이프'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.textContaining('2026 생일 ·').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    final player = find.byType(PlayButton);
    await tester.tap(player);
    await tester.pump();
    await tester.tap(player);
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('닫기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Android 뒤로 버튼
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 400));
    expect(h.sound.played, isEmpty);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('확인 화면 데크: PLAY·STOP은 소리가 난다', (tester) async {
    useDesignScreen(tester);
    final h = RecordHarness();
    await tester.pumpWidget(testApp(h));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.bySemanticsLabel('REC'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.bySemanticsLabel('STOP'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(h.sound.played, [UiSound.on, UiSound.off]);
    // 변환 뒤 자동 미리 듣기 중 → STOP
    await tester.tap(find.bySemanticsLabel('STOP'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(h.sound.played.last, UiSound.off);
    await tester.tap(find.bySemanticsLabel('PLAY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(h.sound.played.last, UiSound.on);
    expect(h.sound.played, hasLength(4));
    await tester.pump(const Duration(seconds: 3));
  });
}
