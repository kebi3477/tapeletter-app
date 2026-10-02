import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tapeletter_app/ui/shelf/view_model/shelf_view_model.dart';
import 'package:tapeletter_app/ui/shelf/widgets/shelf_bookcase_view.dart';
import 'package:tapeletter_app/ui/shelf/widgets/shelf_list_view.dart';

import '../../../../testing/app.dart';
import '../../../../testing/fonts.dart';
import '../../../../testing/record_harness.dart';

void main() {
  setUpAll(loadAppFonts);

  Future<RecordHarness> pumpShelf(
    WidgetTester tester, {
    bool coachDone = false,
  }) async {
    useDesignScreen(tester);
    final h = RecordHarness()..prefs.coachDoneValue = coachDone;
    await tester.pumpWidget(testApp(h, initialLocation: '/shelf'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    return h;
  }

  ShelfViewModel vmOf(WidgetTester tester) =>
      tester.element(find.byType(ShelfBookcase)).read<ShelfViewModel>();

  List<String> names(WidgetTester tester, String gid) =>
      vmOf(tester).shelf.group(gid)!.items.map((x) => x.from).toList();

  /// 책꽂이 등(세로쓰기 이름)의 가운데
  Offset spine(WidgetTester tester, String name, {int at = 0}) {
    // 세로쓰기라 첫 글자로 찾는다
    final first = find.text(name.characters.first);
    return tester.getCenter(first.at(at));
  }

  Future<void> dragTo(WidgetTester tester, Offset from, Offset to) async {
    final g = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 400));
    await g.moveTo(from + const Offset(0, 20));
    await tester.pump();
    await g.moveTo(to);
    await tester.pump();
    await g.up();
    await tester.pump();
  }

  testWidgets('도착한 소포 구역: 안 뜯은 소포만, 분류 안 함은 뜯은 테이프만, 끌 수 없다', (tester) async {
    final h = await pumpShelf(tester, coachDone: true);
    expect(find.text('도착한 소포'), findsOneWidget);
    expect(find.text('2개'), findsOneWidget);
    expect(find.text('눌러서 뜯어 주세요'), findsOneWidget);
    expect(find.text('0개'), findsOneWidget, reason: '분류 안 함');
    expect(find.text('뜯은 테이프 중 칸에 넣지 않은 테이프가 여기 모여요'), findsOneWidget);
    // 소포를 길게 눌러도 드래그가 시작되지 않는다
    final g = await tester.startGesture(tester.getCenter(find.text('지현')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(vmOf(tester).dragging, isFalse);
    expect(find.byType(SpineGhost), findsNothing);
    await g.cancel();
    await tester.pump();
    // 소포를 뜯으면 구역에서 빠지고 분류 안 함으로
    await h.shelf.open(h.store.unsorted.first.id);
    await tester.pump();
    await tester.pump();
    expect(find.text('1개'), findsNWidgets(2));
    await h.shelf.open(h.store.unsorted[1].id);
    await tester.pump();
    await tester.pump();
    expect(find.text('도착한 소포'), findsNothing, reason: '마지막 소포를 뜯으면 구역이 사라진다');
    expect(find.text('2개'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('코치마크: 처음 한 번, 알겠어요로 닫고 기억한다', (tester) async {
    final h = await pumpShelf(tester);
    expect(find.text('테이프를 원하는 칸으로 끌어 보세요'), findsOneWidget);
    expect(find.text('길게 누르면 집을 수 있어요'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('알겠어요'));
    await tester.pump();
    expect(find.text('테이프를 원하는 칸으로 끌어 보세요'), findsNothing);
    expect(h.prefs.coachDoneValue, isTrue);
  });

  testWidgets('이미 봤으면 코치마크 없음, 목록 보기에서도 없음', (tester) async {
    await pumpShelf(tester, coachDone: true);
    expect(find.text('테이프를 원하는 칸으로 끌어 보세요'), findsNothing);
  });

  testWidgets('책꽂이 드래그: 다른 칸 선반에 놓으면 맨 뒤, 토스트, 코치마크 사라짐', (tester) async {
    final h = await pumpShelf(tester);
    expect(find.text('테이프를 원하는 칸으로 끌어 보세요'), findsOneWidget);
    final start = spine(tester, '민수'); // 2026 생일의 민수
    // 승진 축하 선반의 빈 곳(맨 오른쪽)
    final board = find.text('승진 축하');
    final to = tester.getCenter(board) + const Offset(120, 110);
    await dragTo(tester, start, to);
    await tester.pump(const Duration(milliseconds: 300));
    expect(names(tester, 'g-2'), ['박과장님', '은비', '민수']);
    expect(find.text('‘승진 축하’ 칸으로 옮겼어요'), findsOneWidget);
    expect(find.text('테이프를 원하는 칸으로 끌어 보세요'), findsNothing);
    expect(h.prefs.coachDoneValue, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('같은 칸 안: 등의 오른쪽 절반이면 그 뒤, 왼쪽 절반이면 그 앞', (tester) async {
    await pumpShelf(tester, coachDone: true);
    expect(names(tester, 'g-1'), ['엄마', '민수', '수아', '할머니']);
    // 엄마를 할머니 오른쪽 절반으로 → 맨 뒤
    final mom = spine(tester, '엄마');
    final grandma = spine(tester, '할머니');
    await dragTo(tester, mom, grandma + const Offset(8, 0));
    await tester.pump(const Duration(milliseconds: 1300));
    expect(names(tester, 'g-1'), ['민수', '수아', '할머니', '엄마']);

    // 할머니를 민수 왼쪽 절반으로 → 민수 앞(맨 앞)
    final g2 = spine(tester, '할머니');
    final minsu = spine(tester, '민수');
    await dragTo(tester, g2, minsu - const Offset(8, 0));
    await tester.pump(const Duration(milliseconds: 1300));
    expect(names(tester, 'g-1'), ['할머니', '민수', '수아', '엄마']);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('390×844 넘침 없음 (드래그 중 고스트 포함)', (tester) async {
    await pumpShelf(tester);
    final g = await tester.startGesture(spine(tester, '수아'));
    await tester.pump(const Duration(milliseconds: 400));
    // 책꽂이 보기의 고스트는 흰 카드가 아니라 테이프 등 (그 테이프의 shell/band 색)
    expect(find.byType(DragGhost), findsNothing);
    expect(find.byType(SpineGhost), findsOneWidget);
    final ghost = find.byType(SpineGhost);
    expect(
      find.descendant(of: ghost, matching: find.byType(TapeSpine)),
      findsOneWidget,
    );
    final rotate = tester.widget<Transform>(
      find.descendant(of: ghost, matching: find.byType(Transform)).first,
    );
    expect(rotate.transform.getRotation().entry(1, 0), closeTo(-0.02618, 1e-4));
    await g.moveBy(const Offset(30, 40));
    await tester.pump();
    // 손가락 가운데를 따라온다
    final at = spine(tester, '수아') + const Offset(30, 40);
    expect((tester.getCenter(ghost) - at).distance, lessThan(4));
    expect(tester.takeException(), isNull);
    await g.up();
    await tester.pump(const Duration(seconds: 2));
  });
}
