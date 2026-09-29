import 'package:tapeletter_app/domain/models/tape_type.dart';
import 'package:tapeletter_app/ui/core/ui/tab_bar.dart';
import 'package:tapeletter_app/ui/record/view_model/record_view_model.dart';
import 'package:tapeletter_app/ui/record/widgets/record_deck.dart';
import 'package:tapeletter_app/ui/record/widgets/tape_carousel.dart';
import 'package:flutter/material.dart';
import 'package:tapeletter_app/ui/shop/view_model/shop_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../testing/app.dart';
import '../../../../testing/fakes/repositories/fake_delivery_repository.dart';
import '../../../../testing/fakes/repositories/fake_recording_repository.dart';
import '../../../../testing/fakes/services/fake_recorder_service.dart';
import '../../../../testing/fonts.dart';
import '../../../../testing/record_harness.dart';

void main() {
  setUpAll(loadAppFonts);

  Future<RecordHarness> pumpApp(
    WidgetTester tester, [
    RecordHarness? harness,
  ]) async {
    useDesignScreen(tester);
    final h = harness ?? RecordHarness();
    await tester.pumpWidget(testApp(h));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    return h;
  }

  /// 데크 가운데 키(대기 REC · 녹음 STOP)를 눌렀다 뗀다
  Future<void> tapRecord(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 500)); // 키 줄이 자리 잡게
    await tester.tapAt(tester.getCenter(find.byType(RecordDeck)));
    await tester.pump();
    await tester.pump();
  }

  /// 녹음 → 멈춤 → 변환 끝까지
  Future<void> recordAndConvert(WidgetTester tester, RecordHarness h) async {
    await tapRecord(tester);
    await tester.pump(const Duration(seconds: 3));
    await tapRecord(tester);
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('대기 화면: 개수 알약, 길이 표시, 탭바 4칸', (tester) async {
    final h = await pumpApp(tester);
    expect(find.text('2개'), findsOneWidget);
    expect(find.text('0개'), findsOneWidget);
    for (final t in ['15초', '1분', '3분']) {
      expect(find.text(t), findsOneWidget);
    }
    for (final t in ['녹음', '서랍', '상점', '마이']) {
      expect(find.text(t), findsOneWidget);
    }
    expect(find.byType(AppTabBar), findsOneWidget);
    expect(h.vm.tape, TapeType.s15);
    expect(tester.takeException(), isNull);
  });

  testWidgets('캐러셀: 왼쪽으로 50px 넘게 밀면 1분, 15초에서 오른쪽은 그대로', (tester) async {
    final h = await pumpApp(tester);
    await tester.drag(find.byType(TapeCarousel), const Offset(120, 0));
    await tester.pump(const Duration(milliseconds: 400));
    expect(h.vm.tape, TapeType.s15);

    await tester.drag(find.byType(TapeCarousel), const Offset(-40, 0));
    await tester.pump(const Duration(milliseconds: 400));
    expect(h.vm.tape, TapeType.s15);

    await tester.drag(find.byType(TapeCarousel), const Offset(-120, 0));
    await tester.pump(const Duration(milliseconds: 400));
    expect(h.vm.tape, TapeType.m1);

    await tester.drag(find.byType(TapeCarousel), const Offset(-120, 0));
    await tester.pump(const Duration(milliseconds: 400));
    expect(h.vm.tape, TapeType.m3);
    expect(h.vm.curLocked, isTrue);
  });

  testWidgets('0개인 테이프에서 녹음 버튼을 누르면 상점으로 간다', (tester) async {
    final h = await pumpApp(tester);
    h.vm.selectTape(TapeType.m3);
    await tester.pump();
    await tapRecord(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('상점'), findsNWidgets(2));
    expect(h.vm.phase, RecordPhase.idle);
    expect(h.shopVm.highlight, TapeType.m3);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('0개인 테이프의 "+"를 누르면 상점에서 바로 구매 시트', (tester) async {
    final h = await pumpApp(tester);
    for (var i = 0; i < 2; i++) {
      await tester.drag(find.byType(TapeCarousel), const Offset(-120, 0));
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(h.vm.tape, TapeType.m3);
    await tester.pump(const Duration(seconds: 1)); // 캐러셀이 자리 잡을 때까지
    // 알약 자리의 누르는 칸이 받는다 (글자 자체가 아니라)
    await tester.tapAt(tester.getCenter(find.text('+')));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(h.shopVm.highlight, TapeType.m3);
    expect((h.shopVm.sheet as BuySheet).item.id, 'tape180_1');
    expect(find.text('3분 테이프'), findsWidgets);
    expect(tester.takeException(), isNull);

    // 닫고 다시 눌러도 또 열린다
    h.shopVm.closeSheet();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('녹음').last);
    await tester.pump(const Duration(milliseconds: 400));
    // 알약 자리의 누르는 칸이 받는다 (글자 자체가 아니라)
    await tester.tapAt(tester.getCenter(find.text('+')));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(h.shopVm.sheet, isA<BuySheet>());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('기존 친구에게 보내는 흐름 전체 (탭바는 확인부터 숨김)', (tester) async {
    final h = await pumpApp(tester);
    await tapRecord(tester);
    expect(find.text('0:00'), findsOneWidget);
    expect(find.text('/ 0:15'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('0:03'), findsOneWidget);

    await tapRecord(tester);
    expect(h.vm.phase, RecordPhase.confirm);
    expect(find.byType(AppTabBar), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    expect(h.vm.playing, isTrue);
    expect(find.text('보낸 사람'), findsOneWidget);
    expect(find.text('민경'), findsOneWidget);

    await tester.tap(find.text('누구에게 보낼까요?'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('누구에게\n보낼까요?'), findsOneWidget);
    expect(find.text('즐겨찾기 · 09.24'), findsOneWidget);
    expect(find.text('새 친구에게 링크로 보내기'), findsOneWidget);

    await tester.tap(find.text('지현'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(h.vm.phase, RecordPhase.label);
    expect(find.text('받는 사람'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('지현'), findsOneWidget);

    await tester.tap(find.text('보내기'));
    await tester.pump();
    expect(h.vm.phase, RecordPhase.sending);
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 800));
    expect(h.vm.phase, RecordPhase.sent);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('지현님에게 보냈어요'), findsOneWidget);
    expect(find.text('테이프는 이제 받는 사람만 들을 수 있어요'), findsOneWidget);

    await tester.tap(find.text('확인'));
    await tester.pump();
    expect(h.vm.phase, RecordPhase.idle);
    expect(find.byType(AppTabBar), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('새 친구: 이름 입력칸, 완료 화면의 카카오톡·문자 버튼', (tester) async {
    final h = await pumpApp(tester);
    await recordAndConvert(tester, h);
    h.vm.goSend();
    h.vm.pickNew();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('받는 사람 이름 (선택)'), findsOneWidget);
    expect(find.text('예) 지현, 동생'), findsOneWidget);
    expect(find.text('누구에게 보냈는지 알아보는 이름이에요. 비우면 ‘새 친구’로 적혀요'), findsOneWidget);
    expect(find.text('0/8'), findsOneWidget);
    expect(find.text('새 친구'), findsOneWidget, reason: '라벨 카드');
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byType(TextField), '유진');
    await tester.pump();
    expect(find.text('2/8'), findsOneWidget);
    await tester.tap(find.text('보내기'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('테이프를 포장했어요'), findsOneWidget);
    expect(find.text('카카오톡으로 보내기'), findsOneWidget);
    expect(find.text('문자로 보내기'), findsOneWidget);

    await tester.tap(find.text('카카오톡으로 보내기'));
    await tester.pump();
    await tester.pump();
    expect(h.vm.phase, RecordPhase.idle);
    expect(find.text('카카오톡으로 링크를 보냈어요'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('변환이 오래 걸릴 때와 실패할 때', (tester) async {
    final repo = FakeRecordingRepository(
      convertDelay: const Duration(seconds: 3),
    );
    final h = await pumpApp(tester, RecordHarness(recordings: repo));
    await tapRecord(tester);
    await tester.pump(const Duration(seconds: 2));
    await tapRecord(tester);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('테이프 소리로 바꾸는 중이에요'), findsOneWidget);
    expect(find.text('조금 오래 걸리고 있어요. 잠시만요'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(h.vm.convSlow, isFalse);

    repo.failConvert = true;
    h.vm.retryConvert();
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('테이프로 바꾸지 못했어요'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(find.text('처음부터 다시 녹음'), findsOneWidget);
    await tester.tap(find.text('처음부터 다시 녹음'));
    await tester.pump();
    expect(h.vm.phase, RecordPhase.idle);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('보내기 실패 패널과 돌아가기', (tester) async {
    final h = await pumpApp(
      tester,
      RecordHarness(deliveries: FakeDeliveryRepository(fail: true)),
    );
    await recordAndConvert(tester, h);
    h.vm.goSend();
    h.vm.pickFriend(h.vm.sortedFriends.first);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('보내기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('보내지 못했어요'), findsOneWidget);
    expect(find.text('다시 보내기'), findsOneWidget);
    await tester.tap(find.text('돌아가기'));
    await tester.pump();
    expect(h.vm.phase, RecordPhase.confirm);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('녹음 멈춤 패널', (tester) async {
    final h = await pumpApp(tester);
    await tapRecord(tester);
    await tester.pump(const Duration(seconds: 9));
    h.vm.onAppHidden();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('앱이 잠시 닫혀서 녹음이 멈췄어요\n0:09까지 담겼어요'), findsOneWidget);
    expect(find.text('이어서 녹음'), findsOneWidget);
    await tester.tap(find.text('여기까지 쓰기'));
    await tester.pump();
    await tester.pump();
    expect(h.vm.phase, RecordPhase.confirm);
    h.vm.backIdle();
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('마이크 거부 카드', (tester) async {
    final h = await pumpApp(
      tester,
      RecordHarness(
        recorder: FakeRecorderService(granted: false, grantOnRequest: false),
      ),
    );
    await tapRecord(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(h.vm.mic, MicPermission.denied);
    expect(find.text('마이크가 꺼져 있어요'), findsOneWidget);
    await tester.tap(find.text('설정으로 이동'));
    await tester.pump();
    expect(h.settings.opened, 1);
  });

  testWidgets('작은 화면(375×667)에서도 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = RecordHarness();
    await tester.pumpWidget(testApp(h));
    await tester.pump(const Duration(milliseconds: 100));
    await recordAndConvert(tester, h);
    h.vm.goSend();
    await tester.pump(const Duration(milliseconds: 400));
    h.vm.pickNew();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    h.vm.backPick();
    h.vm.backConfirm();
    h.vm.backIdle();
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('녹음 중(v6): 개수 알약·길이 선택을 숨기고 그 자리에 시간(700 20), 멈춤·정지 뒤 다시 표시', (
    tester,
  ) async {
    final h = await pumpApp(tester);
    await tester.pump(const Duration(milliseconds: 500));
    // 대기: 알약(∞ · 2개 · 0개+)과 길이 선택
    expect(find.text('2개'), findsOneWidget);
    final lensY = tester.getCenter(find.text('15초')).dy;
    final tapeBottom = tester.getBottomLeft(find.byType(TapeCarousel)).dy;

    await tapRecord(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(h.vm.phase, RecordPhase.rec);
    expect(find.text('2개'), findsNothing);
    expect(find.text('15초'), findsNothing);
    // 옆 테이프는 opacity 0 (대기 .4)
    List<double> ops() => [
      for (final o in tester.widgetList<AnimatedOpacity>(
        find.descendant(
          of: find.byType(TapeCarousel),
          matching: find.byType(AnimatedOpacity),
        ),
      ))
        o.opacity,
    ];
    expect(ops(), [1, 0, 0]);
    // 녹음 중에는 밀어도 테이프가 바뀌지 않는다
    await tester.drag(find.byType(TapeCarousel), const Offset(-120, 0));
    await tester.pump(const Duration(milliseconds: 400));
    expect(h.vm.tape, TapeType.s15);
    final time = find.text('0:02');
    expect(time, findsOneWidget);
    expect(find.text('/ 0:15'), findsOneWidget);
    // 위 60이 아니라 캐러셀 아래, 길이 선택이 있던 자리
    expect(tester.getCenter(time).dy, greaterThan(tapeBottom));
    expect(tester.getCenter(time).dy, closeTo(lensY, 12));
    final style = tester.widget<Text>(time).style!;
    expect(style.fontSize, 20);
    expect(style.fontWeight, FontWeight.w700);
    expect(tester.takeException(), isNull);

    // 멈춤: 그대로 숨김, 시간은 같은 자리
    h.vm.onAppHidden();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('2개'), findsNothing);
    expect(tester.getCenter(find.text('0:02')).dy, closeTo(lensY, 12));
    await tester.tap(find.text('여기까지 쓰기'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(h.vm.phase, RecordPhase.confirm);

    // 확인 → 뒤로 → 대기: 다시 표시
    h.vm.backIdle();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('2개'), findsOneWidget);
    expect(find.text('15초'), findsOneWidget);
    expect(find.text('/ 0:15'), findsNothing);
    expect(ops(), [1, .4, .4]);
    await tester.pump(const Duration(seconds: 3));
  });
}
