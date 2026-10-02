import 'package:tapeletter_app/ui/core/themes/colors.dart';
import 'package:tapeletter_app/ui/core/ui/tab_bar.dart';
import 'package:tapeletter_app/ui/shelf/view_model/shelf_view_model.dart';
import 'package:tapeletter_app/ui/shelf/widgets/shelf_bookcase_view.dart';
import 'package:tapeletter_app/ui/shelf/widgets/shelf_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../../testing/app.dart';
import '../../../../testing/fonts.dart';
import '../../../../testing/record_harness.dart';
import '../../../../testing/dates.dart';

void main() {
  setUpAll(loadAppFonts);

  Future<RecordHarness> pumpShelf(
    WidgetTester tester, [
    void Function(RecordHarness h)? setup,
  ]) async {
    useDesignScreen(tester);
    // 목록 보기를 골라 둔 사용자 (기본은 책장형)
    final h = RecordHarness()..prefs.shelfViewValue = 'list';
    setup?.call(h);
    await tester.pumpWidget(testApp(h, initialLocation: '/shelf'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    return h;
  }

  ShelfViewModel vmOf(WidgetTester tester) =>
      tester.element(find.byType(Scaffold).first).read<ShelfViewModel>();

  List<String> groupNames(WidgetTester tester, String groupId) =>
      vmOf(tester).shelf.itemsOf(groupId).map((x) => x.from).toList();

  testWidgets('목록 보기: 헤더, 분류 안 함, 칸, 거의 참, 탭바 레드 점', (tester) async {
    await pumpShelf(tester, (h) => h.store.cap = 10);
    expect(find.text('서랍'), findsWidgets);
    expect(find.text('테이프 8/10'), findsOneWidget);
    expect(find.text('분류 안 함'), findsOneWidget);
    // 도착한 소포 구역 (v10.2): 안 뜯은 소포 2개, 부제에 "소포 도착" 없음
    expect(find.text('도착한 소포'), findsOneWidget);
    expect(find.text('2개'), findsOneWidget);
    expect(find.text('눌러서 뜯어 주세요'), findsOneWidget);
    expect(find.text('${at(9, 24)} · 1분'), findsOneWidget);
    expect(find.text('0개'), findsOneWidget, reason: '분류 안 함은 뜯은 테이프만');
    expect(find.text('뜯은 테이프 중 칸에 넣지 않은 테이프가 여기 모여요'), findsOneWidget);
    expect(find.text('2026 생일'), findsOneWidget);
    expect(find.text('승진 축하'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('서랍이 거의 찼어요'), 200);
    expect(find.text('+ 칸 추가'), findsOneWidget);
    final tabBar = tester.widget<AppTabBar>(find.byType(AppTabBar));
    expect(tabBar.hasNew, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('기본 보기는 책장형, 바꾸면 기억한다', (tester) async {
    useDesignScreen(tester);
    final h = RecordHarness();
    await tester.pumpWidget(testApp(h, initialLocation: '/shelf'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(ShelfBookcase), findsOneWidget);
    expect(find.byType(ShelfRow), findsNothing);
    expect(tester.takeException(), isNull);
    vmOf(tester).setView(ShelfView.list);
    await tester.pump();
    expect(find.byType(ShelfRow), findsWidgets);
    await tester.pump();
    expect(h.prefs.shelfViewValue, 'list');
  });

  testWidgets('처음 들어가면 스켈레톤 0.65초', (tester) async {
    useDesignScreen(tester);
    final h = RecordHarness();
    await tester.pumpWidget(testApp(h, initialLocation: '/shelf'));
    await tester.pump();
    expect(find.text('분류 안 함'), findsOneWidget);
    expect(vmOf(tester).skeleton, isTrue);
    await tester.pump(const Duration(milliseconds: 700));
    expect(vmOf(tester).skeleton, isFalse);
  });

  testWidgets('책꽂이 보기', (tester) async {
    await pumpShelf(tester);
    await tester.tap(find.bySemanticsLabel('책꽂이 보기'));
    await tester.pump();
    expect(vmOf(tester).view, ShelfView.shelf);
    expect(find.text('할'), findsOneWidget); // 세로쓰기 '할머니'
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -400),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('꽉 찬 서랍 배너', (tester) async {
    await pumpShelf(tester, (h) => h.store.cap = 8);
    expect(find.text('서랍이 꽉 찼어요'), findsOneWidget);
    expect(find.text('지우거나 넓혀야 새 소포를 뜯을 수 있어요'), findsOneWidget);
    await tester.tap(find.text('넓히기 ›'));
    await tester.pump();
    await tester.pump();
    expect(find.text('상점'), findsNWidgets(2));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('빈 서랍 → 녹음하러 가기', (tester) async {
    await pumpShelf(tester, (h) {
      h.store.unsorted = [];
      h.store.groups = [];
    });
    expect(find.text('아직 받은 테이프가 없어요'), findsOneWidget);
    await tester.tap(find.text('녹음하러 가기'));
    await tester.pump();
    await tester.pump();
    expect(find.text('15초'), findsOneWidget);
  });

  testWidgets('길게 눌러 끌어서 같은 칸 안에서 아래로 옮긴다', (tester) async {
    await pumpShelf(tester);
    final mom = find.ancestor(
      of: find.text('${at(3, 14)} · 3분'),
      matching: find.byType(ShelfRow),
    );
    final grandma = find.ancestor(
      of: find.text('할머니'),
      matching: find.byType(ShelfRow),
    );
    final start = tester.getCenter(mom);
    final target = tester.getRect(grandma).topCenter + const Offset(0, 10);

    final g = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 400));
    expect(vmOf(tester).dragging, isTrue);
    expect(find.byType(DragGhost), findsOneWidget);
    await g.moveTo(start + const Offset(0, 20));
    await tester.pump();
    await g.moveTo(target);
    await tester.pump();
    await g.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1300));
    expect(groupNames(tester, 'g-1'), ['민수', '수아', '엄마', '할머니']);
    expect(find.byType(DragGhost), findsNothing);
  });

  testWidgets('짧게 누르기 전에 움직이면 드래그가 아니다', (tester) async {
    await pumpShelf(tester);
    final row = find.ancestor(
      of: find.text('${at(3, 14)} · 3분'),
      matching: find.byType(ShelfRow),
    );
    await tester.ensureVisible(row);
    await tester.pump();
    final g = await tester.startGesture(tester.getCenter(row));
    await g.moveBy(const Offset(0, -40));
    await tester.pump(const Duration(milliseconds: 400));
    expect(vmOf(tester).dragging, isFalse);
    await g.up();
    await tester.pump();
  });

  testWidgets('⋯ 시트 → 다른 칸으로 옮기기 → 칸 고르기', (tester) async {
    await pumpShelf(tester);
    final row = find.ancestor(
      of: find.text('은비'),
      matching: find.byType(ShelfRow),
    );
    await tester.ensureVisible(row);
    await tester.pump();
    await tester.tap(
      find.descendant(of: row, matching: find.byType(MoreButton)),
    );
    await tester.pumpAndSettle();
    expect(find.text('${at(6, 3)} · 승진 축하'), findsOneWidget);
    expect(find.text('답장 녹음하기'), findsOneWidget);
    expect(find.text('지우기'), findsOneWidget);
    await tester.tap(find.text('다른 칸으로 옮기기'));
    await tester.pumpAndSettle();
    expect(find.text('어느 칸으로 옮길까요?'), findsOneWidget);
    await tester.tap(find.text('엄마 목소리').last);
    await tester.pumpAndSettle();
    expect(groupNames(tester, 'g-3'), ['엄마', '엄마', '은비']);
    expect(find.text('‘엄마 목소리’ 칸으로 옮겼어요'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('⋯ 시트 → 메모 남기기 → 메뉴에 메모 카드, 목록 부제 앞에 메모 → 지우기', (tester) async {
    await pumpShelf(tester);
    Future<void> openMenu() async {
      final row = find.ancestor(
        of: find.text('은비'),
        matching: find.byType(ShelfRow),
      );
      await tester.ensureVisible(row);
      await tester.pump();
      await tester.tap(
        find.descendant(of: row, matching: find.byType(MoreButton)),
      );
      await tester.pumpAndSettle();
    }

    await openMenu();
    await tester.tap(find.text('메모 남기기'));
    await tester.pumpAndSettle();
    expect(find.text('테이프 메모'), findsOneWidget);
    expect(find.text('은비님의 테이프 · 나에게만 보여요'), findsOneWidget);
    expect(find.text('테이프 라벨에도 적혀요'), findsOneWidget);
    expect(find.text('0/40'), findsOneWidget);
    expect(find.text('지우기'), findsNothing); // 메모가 없으면 지우기 없음

    await tester.enterText(find.byType(TextField), '회사 앞에서\n받은 축하');
    await tester.pump();
    expect(find.text('회사 앞에서받은 축하'), findsOneWidget); // 줄바꿈은 들어가지 않는다
    await tester.enterText(find.byType(TextField), '회사 앞에서 받은 축하');
    await tester.pump();
    expect(find.text('12/40'), findsOneWidget);
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    // 메뉴로 돌아와 메모 카드와 "메모 수정하기"
    expect(find.text('메모를 남겼어요'), findsOneWidget);
    expect(find.text('회사 앞에서 받은 축하'), findsOneWidget);
    expect(find.text('메모 수정하기'), findsOneWidget);
    expect(find.text('답장 녹음하기'), findsOneWidget);

    await tester.tapAt(const Offset(20, 20)); // 시트 닫기
    await tester.pumpAndSettle();
    expect(
      find.textContaining('회사 앞에서 받은 축하 · ${at(6, 3)} · '),
      findsOneWidget,
    );

    // 메모 카드를 누르면 수정 — 지우기
    await openMenu();
    await tester.tap(find.text('회사 앞에서 받은 축하'));
    await tester.pumpAndSettle();
    expect(find.text('12/40'), findsOneWidget);
    await tester.tap(find.text('지우기'));
    await tester.pumpAndSettle();
    expect(find.text('메모를 지웠어요'), findsOneWidget);
    expect(find.text('메모 남기기'), findsOneWidget);
    expect(find.text('회사 앞에서 받은 축하'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('메모 40자에 닿으면 카운터가 빨강, 더 적히지 않는다', (tester) async {
    await pumpShelf(tester);
    final row = find.ancestor(
      of: find.text('은비'),
      matching: find.byType(ShelfRow),
    );
    await tester.ensureVisible(row);
    await tester.pump();
    await tester.tap(
      find.descendant(of: row, matching: find.byType(MoreButton)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('메모 남기기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '가' * 45);
    await tester.pump();
    final counter = tester.widget<Text>(find.text('40/40'));
    expect(counter.style!.color, AppColors.red);
  });

  testWidgets('안 뜯은 소포 ⋯에는 옮기기가 없다', (tester) async {
    await pumpShelf(tester);
    final row = find.ancestor(
      of: find.text('${at(9, 24)} · 1분'),
      matching: find.byType(ShelfRow),
    );
    await tester.ensureVisible(row);
    await tester.pump();
    await tester.tap(
      find.descendant(of: row, matching: find.byType(MoreButton)),
    );
    await tester.pumpAndSettle();
    expect(find.text('다른 칸으로 옮기기'), findsNothing);
    expect(find.text('답장 녹음하기'), findsOneWidget);
  });

  testWidgets('칸 제목 → 이름 바꾸기 / 칸 삭제', (tester) async {
    await pumpShelf(tester);
    await tester.tap(find.text('승진 축하'));
    await tester.pumpAndSettle();
    expect(find.text('칸 이름'), findsOneWidget);
    expect(find.text('저장'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '가나다라마바사아자차카타파하');
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text.length,
      12,
    );
    await tester.tap(find.text('칸 삭제'));
    await tester.pumpAndSettle();
    expect(find.text('승진 축하'), findsNothing);
    expect(find.text('칸을 지웠어요 · 테이프는 분류 안 함으로'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('+ 칸 만들기: 카테고리 칩 → 예시 이름, 이름 없으면 비활성', (tester) async {
    await pumpShelf(tester);
    await tester.tap(find.bySemanticsLabel('칸 추가'));
    await tester.pumpAndSettle();
    expect(find.text('이 칸에 어떤 목소리를 모을까요?'), findsOneWidget);
    for (final c in ['사람', '기념일', '여행', '일상', '가족', '연인', '직접 입력']) {
      expect(find.text(c), findsOneWidget);
    }
    expect(find.text('0/12'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // 이름이 없으면 눌러도 만들지 않는다
    final before = vmOf(tester).shelf.groups.length;
    await tester.tap(find.text('칸 만들기'));
    await tester.pump();
    expect(find.text('칸 이름을 적어 주세요'), findsWidgets);
    expect(vmOf(tester).shelf.groups.length, before);

    await tester.tap(find.text('여행'));
    await tester.pump();
    expect(find.widgetWithText(TextField, '제주 여행'), findsOneWidget);
    expect(find.text('5/12'), findsOneWidget);
    await tester.tap(find.text('직접 입력'));
    await tester.pump();
    expect(find.widgetWithText(TextField, '제주 여행'), findsNothing);
    await tester.enterText(find.byType(TextField), '우리의 여행');
    await tester.pump();
    await tester.tap(find.text('칸 만들기'));
    await tester.pumpAndSettle();
    expect(vmOf(tester).shelf.groups.last.name, '우리의 여행');
    expect(find.text('‘우리의 여행’ 칸을 만들었어요'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('답장 녹음하기 → 녹음 탭에 받는 사람 칩', (tester) async {
    final h = await pumpShelf(tester);
    final row = find.ancestor(
      of: find.text('은비'),
      matching: find.byType(ShelfRow),
    );
    await tester.ensureVisible(row);
    await tester.pump();
    await tester.tap(
      find.descendant(of: row, matching: find.byType(MoreButton)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('답장 녹음하기'));
    await tester.pumpAndSettle();
    expect(h.vm.to?.name, '은비');
    expect(find.text('은비에게'), findsOneWidget);
  });
}
