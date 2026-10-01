import 'package:tapeletter_app/data/services/push_service.dart';
import 'package:tapeletter_app/ui/my/widgets/credit_history_screen.dart';
import 'package:tapeletter_app/ui/player/widgets/player_screen.dart';
import 'package:tapeletter_app/ui/shelf/widgets/shelf_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../testing/app.dart';
import '../../../testing/fonts.dart';
import '../../../testing/record_harness.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(loadAppFonts);

  Future<RecordHarness> pump(WidgetTester tester) async {
    useDesignScreen(tester);
    final h = RecordHarness();
    await tester.pumpWidget(testApp(h));
    await settle(tester);
    return h;
  }

  PushMessage tape(RecordHarness h) => PushMessage(
    kind: PushKind.tape,
    title: '유진님이 테이프를 보냈어요',
    body: '3분 테이프 · 탭해서 뜯어보세요',
    deliveryId: h.store.unsorted.first.id,
  );

  testWidgets('로그인하면 기기 푸시 토큰을 등록한다', (tester) async {
    final h = await pump(tester);
    expect(h.store.devices, {'local-device': 'ios'});
  });

  testWidgets('앱 안 배너: 6초 뒤 사라진다', (tester) async {
    final h = await pump(tester);
    h.push.simulate(tape(h));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.text('유진님이 테이프를 보냈어요'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();
    expect(find.text('유진님이 테이프를 보냈어요'), findsNothing);
  });

  testWidgets('앱 안 배너: 위로 밀면 이동하지 않고 사라진다', (tester) async {
    final h = await pump(tester);
    h.push.simulate(tape(h));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 450));
    await tester.fling(
      find.text('유진님이 테이프를 보냈어요'),
      const Offset(0, -120),
      1000,
    );
    await settle(tester);
    expect(find.text('유진님이 테이프를 보냈어요'), findsNothing);
    expect(find.byType(PlayerScreen), findsNothing);
  });

  testWidgets('앱 안 배너: 조금만 밀면 제자리로 돌아온다', (tester) async {
    final h = await pump(tester);
    h.push.simulate(tape(h));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 450));
    await tester.timedDrag(
      find.text('유진님이 테이프를 보냈어요'),
      const Offset(0, -20),
      const Duration(milliseconds: 400),
    );
    await settle(tester);
    expect(find.text('유진님이 테이프를 보냈어요'), findsOneWidget);
  });

  testWidgets('테이프 배너를 누르면 서랍 + 소포 화면', (tester) async {
    final h = await pump(tester);
    h.push.simulate(tape(h));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 450));
    await tester.tap(find.text('유진님이 테이프를 보냈어요'));
    await settle(tester);
    expect(find.byType(PlayerScreen), findsOneWidget);
    expect(find.byType(ShelfScreen, skipOffstage: false), findsOneWidget);
    expect(find.text('유진님이 테이프를 보냈어요'), findsNothing);
  });

  testWidgets('선물 알림을 눌러 앱을 열면 크레딧 내역', (tester) async {
    final h = await pump(tester);
    h.push.simulateOpened(
      const PushMessage(
        kind: PushKind.gift,
        title: '유진님이 크레딧을 선물했어요',
        body: '+100',
      ),
    );
    await settle(tester);
    expect(find.byType(CreditHistoryScreen), findsOneWidget);
  });

  testWidgets('"테이프를 받았어요" 알림을 누르면 보낸 테이프 상세', (tester) async {
    final h = await pump(tester);
    final sent = h.store.sent.first;
    final to = sent.recipient?.name ?? sent.linkName;
    h.push.simulateOpened(
      PushMessage(
        kind: PushKind.claimed,
        title: '$to님이 테이프를 받았어요',
        body: '이제 서로 친구예요',
        deliveryId: sent.id,
      ),
    );
    await settle(tester);
    expect(find.text('$to에게 보낸 테이프'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('로그인 전에 누른 알림은 로그인 뒤에 연다', (tester) async {
    useDesignScreen(tester);
    final h = RecordHarness(signedIn: false);
    h.push.initial = tape(h);
    await tester.pumpWidget(testApp(h));
    await settle(tester);
    expect(find.text('카카오로 시작하기'), findsOneWidget);
    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pump(const Duration(milliseconds: 700));
    await settle(tester);
    expect(find.byType(PlayerScreen), findsOneWidget);
  });
}
