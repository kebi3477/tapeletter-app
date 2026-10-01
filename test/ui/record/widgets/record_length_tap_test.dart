import 'package:tapeletter_app/domain/models/tape_type.dart';
import 'package:tapeletter_app/ui/record/widgets/tape_carousel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../testing/app.dart';
import '../../../../testing/fonts.dart';
import '../../../../testing/record_harness.dart';

/// 길이 표시(`lens`)를 눌러도 그 테이프로 넘어간다 — 스와이프와 같은 선택·애니메이션·햅틱.
void main() {
  setUpAll(loadAppFonts);

  late List<MethodCall> haptics;

  Future<RecordHarness> pumpApp(WidgetTester tester) async {
    haptics = [];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') haptics.add(call);
        return null;
      },
    );
    useDesignScreen(tester);
    final h = RecordHarness();
    await tester.pumpWidget(testApp(h));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    return h;
  }

  /// 캐러셀 트랙에서 가운데 테이프의 왼쪽 위치
  double trackLeft(WidgetTester tester, TapeType t) => tester
      .getTopLeft(
        find.descendant(
          of: find.byType(TapeCarousel),
          matching: find.byWidgetPredicate(
            (w) =>
                w.runtimeType.toString() == '_CarouselItem' &&
                (w as dynamic).type == t,
          ),
        ),
      )
      .dx;

  testWidgets('1분을 누르면 1분 테이프로 .35s 동안 넘어가고 햅틱', (tester) async {
    final h = await pumpApp(tester);
    final start = trackLeft(tester, TapeType.m1);
    await tester.tap(find.text('1분'));
    await tester.pump();
    expect(h.vm.tape, TapeType.m1);
    expect(haptics, hasLength(1));
    expect(haptics.single.arguments, 'HapticFeedbackType.selectionClick');
    await tester.pump(const Duration(milliseconds: 175));
    final mid = trackLeft(tester, TapeType.m1);
    expect(mid, lessThan(start), reason: '움직이는 중');
    await tester.pump(const Duration(milliseconds: 200));
    expect(trackLeft(tester, TapeType.m1), closeTo(start - 244, .5));

    // 이미 고른 테이프를 다시 누르면 아무 일 없음
    await tester.tap(find.text('1분'));
    await tester.pump();
    expect(haptics, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('잠긴(0개) 3분도 스와이프처럼 선택만 된다', (tester) async {
    final h = await pumpApp(tester);
    await tester.tap(find.text('3분'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(h.vm.tape, TapeType.m3);
    expect(h.vm.curLocked, isTrue);
  });

  testWidgets('누르는 자리는 글자 위아래로 넉넉하다 (높이 44)', (tester) async {
    final h = await pumpApp(tester);
    final c = tester.getCenter(find.text('1분'));
    // 글자 위 15px(캐러셀과의 간격)을 눌러도 된다
    await tester.tapAt(c.translate(0, -15));
    await tester.pump(const Duration(milliseconds: 400));
    expect(h.vm.tape, TapeType.m1);
    // 글자 사이 간격(22)의 반까지는 그 글자
    final r = tester.getRect(find.text('3분'));
    await tester.tapAt(Offset(r.left - 10, r.center.dy));
    await tester.pump(const Duration(milliseconds: 400));
    expect(h.vm.tape, TapeType.m3);
  });

  testWidgets('스와이프로 넘어갈 때도 같은 햅틱', (tester) async {
    final h = await pumpApp(tester);
    await tester.drag(find.byType(TapeCarousel), const Offset(-120, 0));
    await tester.pump(const Duration(milliseconds: 400));
    expect(h.vm.tape, TapeType.m1);
    expect(haptics, hasLength(1));
    // 넘어가지 않으면 울리지 않는다
    await tester.drag(find.byType(TapeCarousel), const Offset(-30, 0));
    await tester.pump(const Duration(milliseconds: 400));
    expect(haptics, hasLength(1));
  });
}
