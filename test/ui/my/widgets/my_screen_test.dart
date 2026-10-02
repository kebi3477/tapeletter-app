import 'package:tapeletter_app/data/repositories/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tapeletter_app/ui/my/view_model/my_view_model.dart';

import '../../../../testing/app.dart';
import '../../../../testing/fonts.dart';
import '../../../../testing/record_harness.dart';

void main() {
  setUpAll(loadAppFonts);

  Future<RecordHarness> pumpMy(WidgetTester tester) async {
    useDesignScreen(tester);
    final h = RecordHarness();
    await tester.pumpWidget(testApp(h, initialLocation: '/my'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    return h;
  }

  Future<void> openPage(WidgetTester tester, String label) async {
    await tester.tap(find.bySemanticsLabel(label));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('마이 홈(390×844): 이름, 크레딧, 아이콘 4개, 보유 테이프', (tester) async {
    await pumpMy(tester);
    expect(find.text('민경'), findsOneWidget);
    expect(find.text('테이프에 적히는 이름이에요'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    for (final t in ['받은 테이프', '보낸 테이프', '친구', '설정']) {
      expect(find.text(t), findsOneWidget);
    }
    expect(find.text('10개'), findsOneWidget);
    expect(find.text('6명'), findsOneWidget);
    expect(find.text('보유 테이프'), findsOneWidget);
    expect(find.text('15초 무료', findRichText: true), findsOneWidget);
    expect(find.text('3분 0개', findRichText: true), findsOneWidget);
    // 하위 화면 내용은 홈에 없다
    expect(find.text('회원 탈퇴'), findsNothing);
    // 아이콘 4개가 한 줄 — 좌우 18에서 시작해 372에서 끝난다
    final recv = tester.getRect(find.bySemanticsLabel('받은 테이프'));
    final settings = tester.getRect(find.bySemanticsLabel('설정'));
    expect(recv.left, 18);
    expect(settings.right, 372);
    expect(recv.top, settings.top);
    expect(tester.takeException(), isNull);
  });

  testWidgets('받은 테이프: 서랍(분류 안 함 + 모든 칸) 최근 순, 안 뜯은 소포 표시, 누르면 재생', (
    tester,
  ) async {
    final h = await pumpMy(tester);
    await openPage(tester, '받은 테이프');
    expect(find.text('10개 · 서랍에 모인 목소리예요'), findsOneWidget);
    expect(find.text('분류 안 함 · 15초 · 소포 도착'), findsWidgets);
    expect(find.text('2026 생일 · 3분'), findsOneWidget);
    expect(find.text('‹'), findsOneWidget);
    final dates = h.myVm.received.map((x) => x.item.date).toList();
    for (var i = 1; i < dates.length; i++) {
      expect(dates[i].isAfter(dates[i - 1]), isFalse);
    }
    expect(tester.takeException(), isNull);

    final first = h.myVm.received.firstWhere((x) => !x.boxed);
    await tester.tap(find.text(MyViewModel.receivedSub(first)).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    // 그 테이프가 있는 칸의 재생 목록으로 연다
    expect(find.text(first.where), findsWidgets);
    expect(find.bySemanticsLabel('닫기'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('닫기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('‹'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('보유 테이프'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('보낸 테이프 · 친구 · 설정 하위 화면', (tester) async {
    await pumpMy(tester);
    await openPage(tester, '보낸 테이프');
    expect(find.textContaining('· 받은 사람만 들을 수 있어요'), findsOneWidget);
    // v10: 2줄 — 이름 / 상태 점·상태 · MM.DD · 길이
    expect(find.text('유진에게 보냄'), findsOneWidget);
    expect(find.text('링크 대기'), findsOneWidget);
    expect(find.text('열어 봄'), findsNWidgets(2));
    expect(find.text('안 열어 봄'), findsOneWidget);
    expect(find.text('· 09.22 · 15초'), findsOneWidget);
    expect(find.textContaining('들음'), findsNothing, reason: '연 날짜는 목록에 없음');
    await tester.tap(find.text('‹'));
    await tester.pumpAndSettle();

    await openPage(tester, '친구');
    expect(find.text('6명 · 별명은 나에게만 보여요'), findsOneWidget);
    expect(find.text('박과장님'), findsOneWidget);
    await tester.tap(find.text('‹'));
    await tester.pumpAndSettle();

    await openPage(tester, '설정');
    expect(find.text('알림'), findsOneWidget);
    expect(find.text('카카오'), findsOneWidget);
    expect(find.text('1.0.0'), findsOneWidget);
    expect(find.text('없음'), findsOneWidget);
    expect(find.text('회원 탈퇴'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('친구 ⋯ → 별명 설정: 목록에 별명 + 회색 원래 이름', (tester) async {
    await pumpMy(tester);
    await openPage(tester, '친구');
    await tester.tap(find.bySemanticsLabel('엄마 더 보기'));
    await tester.pumpAndSettle();
    expect(find.text('별명 설정'), findsOneWidget);
    await tester.tap(find.text('별명 설정'));
    await tester.pumpAndSettle();
    expect(find.text('엄마님의 별명'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '우리 엄마');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('우리 엄마'), findsOneWidget);
    expect(find.text('엄마'), findsOneWidget);
    expect(find.text('별명을 저장했어요'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('크레딧 행 → 크레딧 내역 → 충전하기 → 상점', (tester) async {
    await pumpMy(tester);
    await tester.tap(find.text('크레딧'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('충전하기'), findsOneWidget);
    expect(find.text('광고 보상'), findsOneWidget);
    expect(find.text('+10'), findsWidgets);
    expect(find.text('−30'), findsOneWidget);
    await tester.tap(find.text('충전하기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('크레딧 받기'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('이름 수정: 저장·취소 버튼, Enter 저장, Esc 취소, 비우면 저장 안 됨', (tester) async {
    final h = await pumpMy(tester);
    await tester.tap(find.text('수정'));
    await tester.pump();
    expect(find.text('취소'), findsOneWidget);
    expect(find.text('저장'), findsOneWidget);
    expect(find.text('테이프에 적히는 이름이에요 · 2/8'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '민경이');
    await tester.pump();
    expect(find.text('테이프에 적히는 이름이에요 · 3/8'), findsOneWidget);
    // 취소 → 원래 이름
    await tester.tap(find.text('취소'));
    await tester.pump();
    expect(find.text('민경'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(h.store.name, '민경');

    // 저장 버튼
    await tester.tap(find.text('수정'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '민경이');
    await tester.tap(find.text('저장'));
    await tester.pump();
    await tester.pump();
    expect(h.store.name, '민경이');
    expect(find.text('민경이'), findsOneWidget);
    expect(find.text('이름을 저장했어요'), findsOneWidget);

    // 비우면 알리고 입력칸에 남는다
    await tester.tap(find.text('수정'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '  ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('이름을 적어 주세요'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    // Esc → 취소
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('민경이'), findsOneWidget);

    // Enter → 저장
    await tester.tap(find.text('수정'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '민경');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump();
    expect(h.store.name, '민경');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('친구 ⋯ → 차단 확인 → 차단한 친구 시트에서 해제', (tester) async {
    final h = await pumpMy(tester);
    await openPage(tester, '친구');
    await tester.tap(find.bySemanticsLabel('민수 더 보기'));
    await tester.pumpAndSettle();
    expect(find.text('녹음해서 보내기'), findsOneWidget);
    expect(find.text('친구 삭제'), findsOneWidget);
    await tester.tap(find.text('차단'));
    await tester.pumpAndSettle();
    expect(find.text('민수님을 차단할까요?'), findsOneWidget);
    await tester.tap(find.text('차단하기'));
    await tester.pumpAndSettle();
    expect(find.text('민수님을 차단했어요'), findsOneWidget);
    expect(h.myVm.blockedCountText, '1명');

    await tester.tap(find.text('‹'));
    await tester.pumpAndSettle();
    await openPage(tester, '설정');
    await tester.tap(find.text('차단한 친구'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('해제'));
    await tester.pumpAndSettle();
    expect(find.text('차단한 친구가 없어요'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('친구 ⋯ → 크레딧 선물하기는 그 친구를 골라 둔다', (tester) async {
    await pumpMy(tester);
    await openPage(tester, '친구');
    await tester.tap(find.bySemanticsLabel('하늘 더 보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('크레딧 선물하기'));
    await tester.pumpAndSettle();
    expect(find.text('하늘에게 30 크레딧 보내기'), findsOneWidget);
  });

  testWidgets('보낸 테이프 상세와 링크 다시 공유하기', (tester) async {
    final h = await pumpMy(tester);
    await openPage(tester, '보낸 테이프');
    await tester.tap(find.text('유진에게 보냄'));
    await tester.pumpAndSettle();
    expect(find.text('유진에게 보낸 테이프'), findsOneWidget);
    // 제목 아래 상태 줄 (`sdStShort`)
    expect(find.text('링크 대기 · 15초'), findsOneWidget);
    expect(find.text('아직 아무도 받지 않았어요'), findsOneWidget);
    expect(find.text('테이프는 이제 받는 사람만 들을 수 있어요'), findsOneWidget);
    await tester.tap(find.text('링크 다시 공유하기'));
    await tester.pumpAndSettle();
    expect(h.deliveries.reshares, 1);
  });

  testWidgets('보낸 테이프 상세: 열어 본 날짜는 상세에만', (tester) async {
    await pumpMy(tester);
    await openPage(tester, '보낸 테이프');
    await tester.tap(find.text('엄마에게 보냄').first);
    await tester.pumpAndSettle();
    expect(find.text('열어 봄 · 1분'), findsOneWidget);
    expect(find.text('09.11에 열어 봤어요'), findsOneWidget);
  });

  testWidgets('회원 탈퇴: 체크해야 탈퇴, 끝나면 첫 화면', (tester) async {
    final h = await pumpMy(tester);
    await openPage(tester, '설정');
    await tester.scrollUntilVisible(find.text('회원 탈퇴'), 200);
    await tester.tap(find.text('회원 탈퇴'));
    await tester.pumpAndSettle();
    expect(find.text('정말 탈퇴할까요?'), findsOneWidget);
    expect(find.text('10개'), findsOneWidget);
    await tester.tap(find.text('탈퇴하기'));
    await tester.pumpAndSettle();
    expect(find.text('정말 탈퇴할까요?'), findsOneWidget);
    await tester.tap(find.text('모두 사라진다는 걸 확인했어요'));
    await tester.pump();
    await tester.tap(find.text('탈퇴하기'));
    await tester.pumpAndSettle();
    expect(find.text('탈퇴했어요. 그동안 고마웠어요'), findsOneWidget);
    expect(h.auth.status, AuthStatus.signedOut);
    // 로그인 화면으로
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('카카오로 시작하기'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });
}
