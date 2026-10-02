import 'package:tapeletter_app/data/services/local/local_behavior.dart';
import 'package:tapeletter_app/ui/player/widgets/player_screen.dart';
import 'package:tapeletter_app/ui/shelf/widgets/shelf_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../testing/app.dart';
import '../../../testing/fonts.dart';
import '../../../testing/record_harness.dart';
import '../../../testing/dates.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(loadAppFonts);

  Future<RecordHarness> pumpAt(
    WidgetTester tester,
    String loc, {
    FailMode mode = FailMode.none,
  }) async {
    useDesignScreen(tester);
    final h = RecordHarness(
      behavior: LocalBehavior.instant.copyWith(failMode: mode),
    )..prefs.shelfViewValue = 'list';
    await tester.pumpWidget(testApp(h, initialLocation: loc));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    return h;
  }

  Finder moreOf(String name) => find.descendant(
    of: find.ancestor(of: find.text(name), matching: find.byType(ShelfRow)),
    matching: find.byType(MoreButton),
  );

  testWidgets('서랍 테이프 ⋯ → 신고하기 → 사유·내용 → 신고하고 차단', (tester) async {
    final h = await pumpAt(tester, '/shelf');
    await tester.ensureVisible(moreOf('은비'));
    await tester.pump();
    await tester.tap(moreOf('은비'));
    await settle(tester);
    // 답장 / 옮기기 / 신고하기 / 지우기
    final order = ['답장 녹음하기', '다른 칸으로 옮기기', '신고하기', '지우기'];
    final ys = [for (final t in order) tester.getCenter(find.text(t)).dy];
    expect(ys, [...ys]..sort());
    await tester.tap(find.text('신고하기'));
    await settle(tester);

    expect(find.text('무엇이 문제인가요?'), findsOneWidget);
    expect(find.text('은비님이 보낸 ${at(6, 3)} 테이프'), findsOneWidget);
    expect(find.text('은비님 차단하기'), findsOneWidget);
    expect(find.text('0/300'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // 사유를 고르기 전에는 눌러도 보내지 않는다
    await tester.tap(find.text('신고하기'));
    await settle(tester);
    expect(h.api.reports, isEmpty);

    await tester.tap(find.text('스팸·광고'));
    await tester.enterText(find.byType(TextField), '모르는 쇼핑몰 광고가 녹음돼 있어요');
    await tester.pump();
    expect(find.text('19/300'), findsOneWidget);
    await tester.tap(find.text('신고하기'));
    await settle(tester);
    expect(find.text('무엇이 문제인가요?'), findsNothing, reason: '시트 닫힘');
    expect(find.text('신고하고 차단했어요'), findsOneWidget);
    expect(h.api.reports.single.reason, 'spam');
    expect(h.store.blocked.single.name, '은비');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('친구 ⋯ → 신고하기 (사람)', (tester) async {
    final h = await pumpAt(tester, '/my/friends');
    await tester.tap(find.bySemanticsLabel('민수 더 보기'));
    await settle(tester);
    final order = ['친구 삭제', '신고하기', '차단'];
    final ys = [for (final t in order) tester.getCenter(find.text(t)).dy];
    expect(ys, [...ys]..sort());
    await tester.tap(find.text('신고하기'));
    await settle(tester);
    expect(find.text('민수님'), findsOneWidget);
    expect(find.text('민수님 차단하기'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // 차단 끄고 보내기
    await tester.tap(find.text('민수님 차단하기'));
    await tester.tap(find.text('사칭'));
    await tester.pump();
    await tester.tap(find.text('신고하기'));
    await settle(tester);
    expect(find.text('신고가 접수됐어요. 확인 후 조치할게요'), findsOneWidget);
    expect(h.api.reports.single.userId, 'u-minsu');
    expect(h.store.blocked, isEmpty);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('설정 › 차단한 친구 → 신고 (차단 체크 숨김)', (tester) async {
    final h = await pumpAt(tester, '/my/settings');
    await h.api.blockUser('u-minsu');
    h.friends.invalidate();
    await settle(tester);
    await tester.scrollUntilVisible(find.text('차단한 친구'), 300);
    await tester.tap(find.text('차단한 친구'));
    await settle(tester);
    final report = tester.getCenter(find.text('신고'));
    final unblock = tester.getCenter(find.text('해제'));
    expect(report.dx, lessThan(unblock.dx));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('신고'));
    await settle(tester);
    expect(find.text('무엇이 문제인가요?'), findsOneWidget);
    expect(find.text('민수님 차단하기'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('괴롭힘·혐오 표현'));
    await tester.pump();
    await tester.tap(find.text('신고하기'));
    await settle(tester);
    expect(h.api.reports.single.alsoBlock, isFalse);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('재생 화면 ⋯ → 답장·신고만 → 신고', (tester) async {
    final h = await pumpAt(tester, '/shelf');
    final sua = find.ancestor(
      of: find.text('수아'),
      matching: find.byType(ShelfRow),
    );
    await tester.ensureVisible(sua);
    await tester.pump();
    await tester.tap(sua);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    final more = find.descendant(
      of: find.byType(PlayerScreen),
      matching: find.bySemanticsLabel('더 보기'),
    );
    expect(more, findsOneWidget);
    expect(tester.getCenter(more).dx, lessThan(100), reason: '왼쪽 위');
    await tester.tap(more);
    await settle(tester);
    expect(find.text('답장 녹음하기'), findsOneWidget);
    // 목록의 ⋯와 같은 메뉴 (itemFull) — 부제는 날짜 시:분만
    expect(find.text('다른 칸으로 옮기기'), findsOneWidget);
    expect(find.text('지우기'), findsOneWidget);
    expect(find.text(at(3, 15)), findsWidgets);
    await tester.tap(find.text('신고하기'));
    await settle(tester);
    expect(find.text('수아님이 보낸 ${at(3, 15)} 테이프'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('기타'));
    await tester.pump();
    await tester.tap(find.text('신고하기'));
    await settle(tester);
    expect(h.api.reports.single.deliveryId, isNotNull);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('네트워크 실패 → 신고를 보내지 못했어요 → 돌아가기(내용 유지)', (tester) async {
    await pumpAt(tester, '/shelf', mode: FailMode.offline);
    await tester.ensureVisible(moreOf('은비'));
    await tester.pump();
    await tester.tap(moreOf('은비'));
    await settle(tester);
    await tester.tap(find.text('신고하기'));
    await settle(tester);
    await tester.tap(find.text('성적인 내용'));
    await tester.enterText(find.byType(TextField), '메모');
    await tester.pump();
    await tester.tap(find.text('신고하기'));
    await settle(tester);
    expect(find.text('신고를 보내지 못했어요'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('돌아가기'));
    await settle(tester);
    expect(find.text('무엇이 문제인가요?'), findsOneWidget);
    expect(find.text('메모'), findsOneWidget);
    expect(find.text('2/300'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}
