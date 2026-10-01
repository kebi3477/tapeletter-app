import 'package:tapeletter_app/data/services/local/local_behavior.dart';
import 'package:tapeletter_app/ui/player/widgets/player_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../testing/app.dart';
import '../../../testing/fonts.dart';
import '../../../testing/record_harness.dart';

/// 가짜 서버의 0초 지연·탭 이동·오버레이 진입을 흘려보낸다.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(loadAppFonts);

  Future<RecordHarness> pump(
    WidgetTester tester, {
    FailMode mode = FailMode.none,
  }) async {
    useDesignScreen(tester);
    final h = RecordHarness(
      behavior: LocalBehavior.instant.copyWith(failMode: mode),
    );
    await tester.pumpWidget(testApp(h));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    return h;
  }

  Future<void> open(WidgetTester tester, RecordHarness h, String link) async {
    h.deepLinks.open(Uri.parse(link));
    await settle(tester);
  }

  testWidgets('링크 열기: 소포 화면만, 뜯으면 받고 칩 → 재생', (tester) async {
    final h = await pump(tester);
    await open(tester, h, 'https://tapeletter.example/t/abc');
    expect(find.byType(PlayerScreen), findsOneWidget);
    expect(find.text('탭해서 뜯기'), findsOneWidget);
    expect(find.text('유진'), findsOneWidget, reason: '보낸 사람');
    expect(find.text('유진님과 친구가 되었어요'), findsNothing, reason: '받기 전');
    expect(h.store.claimedLinks, isEmpty);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('탭해서 뜯기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(h.store.claimedLinks, contains('abc'));
    expect(find.text('유진님과 친구가 되었어요'), findsOneWidget);
    await settle(tester);
    expect(find.text('탭해서 뜯기'), findsNothing, reason: '재생 화면');
    final id = h.store.claimedLinks['abc']!;
    expect(h.store.unsorted.first.id, id);
    expect(h.store.unsorted.first.opened, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('서랍이 꽉 찼으면: 받기는 되고, 뜯기 대신 꽉 참 시트 → 넓히면 다시 뜯는다', (tester) async {
    final h = await pump(tester);
    h.store.cap = 8; // 뜯은 테이프 8개 (안 뜯은 소포는 세지 않는다)
    await open(tester, h, 'tapeletter://t/abc');
    await tester.tap(find.text('탭해서 뜯기'));
    await settle(tester);
    // 받기는 됐다 — 소포는 분류 안 함에 안 뜯은 채로
    final id = h.store.claimedLinks['abc']!;
    expect(h.store.unsorted.first.id, id);
    expect(h.store.unsorted.first.opened, isFalse);
    expect(h.sound.played, isEmpty, reason: '뜯기 효과음 없음');
    expect(find.text('탭해서 뜯기'), findsOneWidget, reason: '소포 그대로');
    // 꽉 참 시트
    expect(find.text('칸별 보관'), findsOneWidget);
    expect(find.text('한 칸에 최대 10개'), findsOneWidget);
    expect(
      find.text('소포를 뜯으려면 서랍에 자리가 필요해요.\n테이프를 지우거나 서랍을 넓혀 주세요.'),
      findsOneWidget,
    );
    expect(find.text('0개'), findsOneWidget, reason: '분류 안 함은 뜯은 테이프만');
    expect(find.text('4/10'), findsOneWidget);
    expect(find.text('테이프 8/8'), findsOneWidget, reason: '서랍 전체');
    expect(find.text('10개 더 · 100 크레딧'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // 서랍 넓히기 → 구매 확인 → 사고 나면 재생 화면에서 다시 뜯는다
    await tester.tap(find.text('서랍 넓히기'));
    await settle(tester);
    expect(find.text('칸별 보관'), findsNothing);
    await tester.tap(find.text('구매'));
    await settle(tester);
    expect(h.store.cap, 18);
    await tester.tap(find.text('탭해서 뜯기'));
    await settle(tester);
    expect(h.store.unsorted.first.opened, isTrue);
    expect(find.text('탭해서 뜯기'), findsNothing, reason: '재생 화면');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('꽉 참 시트 → 서랍 정리하기: 재생을 닫고 서랍 탭', (tester) async {
    final h = await pump(tester);
    h.store.cap = 8;
    await open(tester, h, 'tapeletter://t/abc');
    await tester.tap(find.text('탭해서 뜯기'));
    await settle(tester);
    await tester.tap(find.text('서랍 정리하기'));
    await settle(tester);
    expect(find.byType(PlayerScreen), findsNothing);
    expect(find.text('지우거나 넓혀야 새 소포를 뜯을 수 있어요'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('뜯지 않고 닫으면 링크는 그대로 받을 수 있다', (tester) async {
    final h = await pump(tester);
    await open(tester, h, 'tapeletter://t/abc');
    expect(find.byType(PlayerScreen), findsOneWidget);
    await tester.tap(find.text('✕'));
    await settle(tester);
    expect(find.byType(PlayerScreen), findsNothing);
    expect(h.store.claimedLinks, isEmpty);
  });

  testWidgets('연 뒤 다른 분이 먼저 받았으면 뜯을 때 오류 화면', (tester) async {
    final h = await pump(tester);
    await open(tester, h, 'tapeletter://t/abc');
    h.store.takenLinks.add('abc');
    await tester.tap(find.text('탭해서 뜯기'));
    await settle(tester);
    expect(find.byType(PlayerScreen), findsNothing);
    expect(find.text('이미 다른 분이 받은 테이프예요'), findsOneWidget);
  });

  testWidgets('연 뒤 만료됐으면 뜯을 때 오류 화면', (tester) async {
    final h = await pump(tester);
    await open(tester, h, 'tapeletter://t/abc');
    h.store.expiredLinks.add('abc');
    await tester.tap(find.text('탭해서 뜯기'));
    await settle(tester);
    expect(find.text('링크가 만료됐어요'), findsOneWidget);
  });

  testWidgets('이미 다른 분이 받은 링크', (tester) async {
    final h = await pump(tester, mode: FailMode.linkTaken);
    await open(tester, h, 'tapeletter://t/abc');
    expect(find.text('이미 다른 분이 받은 테이프예요'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('확인'));
    await settle(tester);
    expect(find.text('이미 다른 분이 받은 테이프예요'), findsNothing);
  });

  testWidgets('만료된 링크', (tester) async {
    final h = await pump(tester, mode: FailMode.linkExpired);
    await open(tester, h, 'tapeletter://t/abc');
    expect(find.text('링크가 만료됐어요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('내가 보낸 링크: 다시 공유하기 / 닫기', (tester) async {
    final h = await pump(tester, mode: FailMode.linkOwn);
    await open(tester, h, 'tapeletter://t/abc');
    expect(find.text('내가 보낸 테이프예요'), findsOneWidget);
    expect(find.text('닫기'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('링크 다시 공유하기'));
    await settle(tester);
    expect(h.share.shared.single, contains('/t/'));
    expect(h.share.shared.single, startsWith('민경님이 목소리 테이프를 보냈어요 '));
    expect(find.text('내가 보낸 테이프예요'), findsNothing);
  });

  testWidgets('로그인 전 링크는 로그인 뒤에 열린다', (tester) async {
    useDesignScreen(tester);
    final h = RecordHarness(signedIn: false);
    await tester.pumpWidget(testApp(h));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('카카오로 시작하기'), findsOneWidget);
    await open(tester, h, 'tapeletter://t/abc');
    expect(find.byType(PlayerScreen), findsNothing);

    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pump(const Duration(milliseconds: 700));
    await settle(tester);
    expect(find.byType(PlayerScreen), findsOneWidget);
    expect(find.text('탭해서 뜯기'), findsOneWidget);
  });
}
