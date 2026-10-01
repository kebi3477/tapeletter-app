import 'package:tapeletter_app/ui/core/themes/colors.dart';
import 'package:tapeletter_app/ui/shelf/view_model/shelf_view_model.dart';
import 'package:tapeletter_app/ui/shelf/widgets/shelf_bookcase_view.dart';
import 'package:tapeletter_app/ui/shelf/widgets/shelf_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../../testing/app.dart';
import '../../../../testing/fonts.dart';
import '../../../../testing/record_harness.dart';
import '../../../../testing/shelf_fill.dart';

/// 칸당 10개 (`gFull`) — 칸 개수 `n/10`, 꽉 참 표시, 옮기기 시트 안내.
void main() {
  setUpAll(loadAppFonts);

  Future<RecordHarness> pumpShelf(
    WidgetTester tester, {
    String view = 'list',
    int? fillMove,
  }) async {
    useDesignScreen(tester);
    final h = RecordHarness()..prefs.shelfViewValue = view;
    // '승진 축하'(g-2)를 10개로
    if (fillMove != null) fillGroup(h.store, 1, fillMove);
    await tester.pumpWidget(testApp(h, initialLocation: '/shelf'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    return h;
  }

  Color? colorOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style?.color;

  testWidgets('목록 보기: 칸은 n/10, 분류 안 함은 n개', (tester) async {
    await pumpShelf(tester);
    expect(find.byType(ShelfListSections), findsOneWidget);
    expect(find.text('2개'), findsOneWidget);
    expect(find.text('4/10'), findsOneWidget);
    expect(find.text('2/10'), findsNWidgets(2));
    expect(colorOf(tester, '4/10'), AppColors.textCount);
    expect(tester.takeException(), isNull);
  });

  testWidgets('10개 찬 칸: "10/10 · 꽉 참" 레드 (목록·책꽂이)', (tester) async {
    await pumpShelf(tester, fillMove: 10);
    expect(find.text('10/10 · 꽉 참'), findsOneWidget);
    expect(colorOf(tester, '10/10 · 꽉 참'), AppColors.red);
    expect(tester.takeException(), isNull);

    tester
        .element(find.byType(Scaffold).first)
        .read<ShelfViewModel>()
        .setView(ShelfView.shelf);
    await tester.pump();
    expect(find.byType(ShelfBookcase), findsOneWidget);
    expect(find.text('10/10 · 꽉 참'), findsOneWidget);
    expect(find.text('4/10'), findsOneWidget);
    expect(colorOf(tester, '10/10 · 꽉 참'), AppColors.red);
    expect(tester.takeException(), isNull);
  });

  testWidgets('9개 칸은 아직 꽉 차지 않았다', (tester) async {
    await pumpShelf(tester, fillMove: 9);
    expect(find.text('9/10'), findsOneWidget);
    expect(colorOf(tester, '9/10'), AppColors.textCount);
  });

  testWidgets('옮기기 시트: 안내 줄, 꽉 찬 칸은 흐린 이름·"꽉 참 10/10", 누르면 토스트만', (
    tester,
  ) async {
    final h = await pumpShelf(tester, fillMove: 10);
    final row = find.ancestor(
      of: find.text('수아'),
      matching: find.byType(ShelfRow),
    );
    await tester.tap(
      find.descendant(of: row, matching: find.byType(MoreButton)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('다른 칸으로 옮기기'));
    await tester.pumpAndSettle();
    expect(find.text('한 칸에 테이프를 10개까지 넣을 수 있어요'), findsOneWidget);
    expect(find.text('꽉 참 10/10'), findsOneWidget);
    expect(colorOf(tester, '꽉 참 10/10'), AppColors.red);
    expect(
      tester.widget<Text>(find.text('승진 축하').last).style?.color,
      AppColors.textFaint,
    );
    expect(find.text('2/10'), findsWidgets);

    await tester.tap(find.text('승진 축하').last);
    await tester.pump();
    expect(find.text('한 칸에는 테이프를 10개까지 넣을 수 있어요'), findsOneWidget);
    expect(find.text('어느 칸으로 옮길까요?'), findsOneWidget, reason: '시트는 그대로');
    expect(h.store.groups[1].items.length, 10);
    expect(h.store.groups[0].items.length, 4);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('칸 만들기 시트 설명에 10개 안내', (tester) async {
    await pumpShelf(tester);
    await tester.tap(find.bySemanticsLabel('칸 추가'));
    await tester.pumpAndSettle();
    expect(
      find.text('사람, 순간, 주제별로 모아 두면 오래 간직할 수 있어요\n한 칸에 테이프를 10개까지 넣을 수 있어요'),
      findsOneWidget,
    );
  });
}
