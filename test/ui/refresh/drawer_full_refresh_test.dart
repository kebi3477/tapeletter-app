import 'package:tapeletter_app/ui/player/widgets/player_screen.dart';
import 'package:tapeletter_app/ui/shelf/widgets/shelf_list_view.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../testing/app.dart';
import '../../../testing/fonts.dart';
import '../../../testing/record_harness.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(loadAppFonts);

  Future<RecordHarness> pumpFull(WidgetTester tester) async {
    useDesignScreen(tester);
    final h = RecordHarness()..prefs.shelfViewValue = 'list';
    h.store.cap = 8; // 뜯은 테이프 8개 → 꽉 참
    await tester.pumpWidget(testApp(h, initialLocation: '/shelf'));
    await settle(tester);
    return h;
  }

  Future<void> tapParcel(WidgetTester tester) async {
    final parcel = find.ancestor(
      of: find.text('지현'),
      matching: find.byType(ShelfRow),
    );
    await tester.ensureVisible(parcel.first);
    await tester.pump();
    await tester.tap(parcel.first);
    await settle(tester);
    expect(find.byType(PlayerScreen), findsOneWidget);
    await tester.tap(find.text('탭해서 뜯기'));
    await settle(tester);
  }

  Future<void> deleteFromList(WidgetTester tester, String from) async {
    final row = find.ancestor(
      of: find.text(from),
      matching: find.byType(ShelfRow),
    );
    await tester.ensureVisible(row);
    await tester.pump();
    await tester.tap(
      find.descendant(of: row, matching: find.byType(MoreButton)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('지우기').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('지우기').last);
    await settle(tester);
  }

  testWidgets('꽉 참 → 서랍 정리하기 → 지우기 → 바로 뜯기 성공', (tester) async {
    final h = await pumpFull(tester);
    await tapParcel(tester);
    expect(find.text('칸별 보관'), findsOneWidget);
    await tester.tap(find.text('서랍 정리하기'));
    await settle(tester);
    expect(find.byType(PlayerScreen), findsNothing);
    await deleteFromList(tester, '은비');
    expect(h.store.groups[1].items, hasLength(1));
    await tapParcel(tester);
    expect(find.text('칸별 보관'), findsNothing);
    expect(h.store.unsorted.first.opened, isTrue);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('꽉 참 → 재생 화면 ⋯에서 지우기 → 바로 뜯기 성공', (tester) async {
    final h = await pumpFull(tester);
    await tester.ensureVisible(find.text('은비'));
    await tester.pump();
    await tester.tap(find.text('은비'));
    await settle(tester);
    expect(find.byType(PlayerScreen), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('더 보기'));
    await settle(tester);
    await tester.tap(find.text('지우기').last);
    await settle(tester);
    await tester.tap(find.text('지우기').last);
    await settle(tester);
    expect(find.byType(PlayerScreen), findsNothing, reason: '지우면 재생을 닫는다');
    expect(h.store.groups[1].items, hasLength(1));
    await tapParcel(tester);
    expect(find.text('칸별 보관'), findsNothing);
    expect(h.store.unsorted.first.opened, isTrue);
    await tester.pump(const Duration(seconds: 3));
  });
}
