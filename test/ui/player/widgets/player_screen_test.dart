import 'package:flutter/material.dart';
import 'package:tapeletter_app/ui/core/ui/tab_bar.dart';
import 'package:tapeletter_app/ui/core/ui/tape_widget.dart';
import 'package:tapeletter_app/ui/shelf/widgets/shelf_list_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tapeletter_app/ui/player/widgets/player_screen.dart';

import '../../../../testing/app.dart';
import '../../../../testing/fonts.dart';
import '../../../../testing/record_harness.dart';
import '../../../../testing/dates.dart';

void main() {
  setUpAll(loadAppFonts);

  Future<RecordHarness> pumpShelf(WidgetTester tester) async {
    useDesignScreen(tester);
    // 목록 보기를 골라 둔 사용자 (행을 눌러 연다)
    final h = RecordHarness()..prefs.shelfViewValue = 'list';
    await tester.pumpWidget(testApp(h, initialLocation: '/shelf'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    return h;
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  Finder rowOf(String text) =>
      find.ancestor(of: find.text(text), matching: find.byType(ShelfRow));

  testWidgets('소포: 링크 칩 → 탭해서 뜯기 → 재생 → 닫기, 레드 점 줄어듦', (tester) async {
    final h = await pumpShelf(tester);
    await tester.tap(rowOf('하늘'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('하늘님과 친구가 되었어요'), findsOneWidget);
    expect(find.text('탭해서 뜯기'), findsOneWidget);
    expect(find.text('보낸 사람'), findsOneWidget);

    await tester.tap(find.text('탭해서 뜯기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('테이프를 불러오는 중이에요'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('분류 안 함'), findsWidgets);
    expect(find.text('순서대로 재생'), findsOneWidget);
    expect(find.text('1/1'), findsOneWidget);
    expect(find.text('재생 중'), findsOneWidget);
    expect(find.text(at(9, 23)), findsOneWidget); // 테이프 제목(날짜 시:분)
    expect(h.player.playing, isTrue);
    expect(tester.takeException(), isNull);

    await tester.tap(find.bySemanticsLabel('닫기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(h.player.calls.last, 'stop');
    expect(h.store.unsorted.last.opened, isTrue);
    final tab = tester.widget<AppTabBar>(find.byType(AppTabBar));
    expect(tab.hasNew, isTrue, reason: '지현 소포가 아직 남아 있다');
  });

  testWidgets('칸 재생: 이어 듣기 목록, 반복, 다음 곡', (tester) async {
    final h = await pumpShelf(tester);
    await tester.tap(rowOf('수아'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.text('2026 생일'), findsWidgets);
    expect(find.text('3/4'), findsOneWidget);
    expect(find.text('0:48'), findsOneWidget); // 엄마 3분 = 48s
    await tester.tap(find.bySemanticsLabel('반복'));
    await tester.pump();
    expect(find.text('전체 반복'), findsWidgets);
    await tester.tap(find.bySemanticsLabel('다음'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('4/4'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('다음'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('1/4'), findsOneWidget);
    expect(h.player.loaded, 'asset:///assets/audio/sample_48s.m4a');
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('재생 불러오기 실패 → 다시 시도', (tester) async {
    final h = await pumpShelf(tester);
    h.player.failLoad = true;
    await tester.tap(rowOf('수아'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.text('테이프를 불러오지 못했어요'), findsOneWidget);
    h.player.failLoad = false;
    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('테이프를 불러오지 못했어요'), findsNothing);
    expect(h.player.playing, isTrue);
  });

  testWidgets('재생 화면 ⋯: 목록과 같은 메뉴, 지우기 확인 → 취소는 메뉴로, 지우기는 재생을 닫는다', (
    tester,
  ) async {
    final h = await pumpShelf(tester);
    await tester.tap(rowOf('수아'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.tap(
      find.descendant(
        of: find.byType(PlayerScreen),
        matching: find.bySemanticsLabel('더 보기'),
      ),
    );
    await settle(tester);
    final order = ['답장 녹음하기', '메모 남기기', '다른 칸으로 옮기기', '신고하기', '지우기'];
    final ys = [for (final t in order) tester.getCenter(find.text(t)).dy];
    expect(ys, [...ys]..sort());
    expect(find.text(at(3, 15)), findsWidgets);

    await tester.tap(find.text('지우기'));
    await settle(tester);
    expect(find.text('테이프를 지울까요?'), findsOneWidget);
    expect(
      find.text('수아님이 보낸 테이프가 서랍에서 사라져요. 지운 테이프는 되돌릴 수 없어요.'),
      findsOneWidget,
    );
    await tester.tap(find.text('취소'));
    await settle(tester);
    expect(find.text('다른 칸으로 옮기기'), findsOneWidget);

    await tester.tap(find.text('지우기'));
    await settle(tester);
    await tester.tap(find.text('지우기').last);
    await settle(tester);
    expect(find.text('테이프를 지웠어요'), findsOneWidget);
    expect(find.byType(PlayerScreen), findsNothing, reason: '재생을 닫는다');
    expect(
      h.store.groups.first.items.map((x) => x.sender.name),
      isNot(contains('수아')),
    );
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('재생 화면 ⋯ → 다른 칸으로 옮기기: 옮기면 재생을 닫는다', (tester) async {
    final h = await pumpShelf(tester);
    await tester.tap(rowOf('수아'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.tap(
      find.descendant(
        of: find.byType(PlayerScreen),
        matching: find.bySemanticsLabel('더 보기'),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('다른 칸으로 옮기기'));
    await settle(tester);
    expect(find.text('어느 칸으로 옮길까요?'), findsOneWidget);
    await tester.tap(find.text('엄마 목소리').last);
    await settle(tester);
    expect(find.byType(PlayerScreen), findsNothing);
    expect(h.store.groups.last.items.map((x) => x.sender.name), contains('수아'));
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('재생 화면 ⋯ → 메모 남기기: 저장하면 시트를 닫고 라벨·이어 듣기 목록에 메모', (tester) async {
    final h = await pumpShelf(tester);
    await tester.tap(rowOf('수아'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    String title() => tester.widget<TapeWidget>(find.byType(TapeWidget)).title;
    expect(title(), at(3, 15), reason: '메모가 없으면 도착 일시');

    await tester.tap(
      find.descendant(
        of: find.byType(PlayerScreen),
        matching: find.bySemanticsLabel('더 보기'),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('메모 남기기'));
    await settle(tester);
    expect(find.text('수아님의 테이프 · 나에게만 보여요'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '할머니 댁에서');
    await tester.tap(find.text('저장'));
    await settle(tester);

    expect(find.text('테이프 메모'), findsNothing, reason: '재생 화면은 시트를 닫는다');
    expect(find.byType(PlayerScreen), findsOneWidget);
    expect(find.text('메모를 남겼어요'), findsOneWidget);
    expect(title(), '할머니 댁에서');
    expect(find.textContaining('할머니 댁에서 · ${at(3, 15)} · '), findsOneWidget);
    expect(
      h.store.groups.first.items.firstWhere((x) => x.sender.name == '수아').memo,
      '할머니 댁에서',
    );
    await tester.pump(const Duration(seconds: 3));
  });
}
