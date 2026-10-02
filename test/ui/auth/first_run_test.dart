import 'package:tapeletter_app/data/repositories/auth_repository.dart';
import 'package:tapeletter_app/data/services/local/local_behavior.dart';
import 'package:tapeletter_app/data/services/local/local_store.dart';
import 'package:tapeletter_app/data/services/social_auth_service.dart';
import 'package:tapeletter_app/routing/app_flow.dart';
import 'package:tapeletter_app/routing/routes.dart';
import 'package:tapeletter_app/ui/launch/widgets/splash_screen.dart';
import 'package:tapeletter_app/ui/record/widgets/record_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../testing/app.dart';
import '../../../testing/fakes/services/fake_link_service.dart';
import '../../../testing/fonts.dart';
import '../../../testing/record_harness.dart';

/// 온보딩·권한 안내는 계속 도는 애니메이션이 있어 settle 대신 시간을 흘린다.
Future<void> step(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  setUpAll(loadAppFonts);

  Future<RecordHarness> pumpFresh(
    WidgetTester tester, {
    FailMode mode = FailMode.none,
    bool onboarded = false,
  }) async {
    useDesignScreen(tester);
    final h = RecordHarness(
      store: LocalStore(
        clock: () => DateTime.utc(2026, 9, 25, 12),
        newUser: true,
      ),
      behavior: LocalBehavior.instant.copyWith(failMode: mode),
      signedIn: false,
      onboarded: onboarded,
      permissionsAsked: false,
    );
    await tester.pumpWidget(testApp(h, initialLocation: Routes.splash));
    await step(tester);
    return h;
  }

  testWidgets('스플래시 1.4초 뒤 준비 끝', (tester) async {
    useDesignScreen(tester);
    final h = RecordHarness(signedIn: false);
    final flow = AppFlow(
      auth: h.auth,
      prefs: h.prefs,
      app: h.app,
      appInfo: FakeAppInfoService(),
      platform: 'ios',
    )..boot();
    await tester.pumpWidget(MaterialApp(home: SplashScreen(flow: flow)));
    await tester.pump(const Duration(milliseconds: 1300));
    expect(flow.ready, isFalse);
    await tester.pump(const Duration(milliseconds: 200));
    expect(flow.ready, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('처음 실행: 온보딩 3장 → 로그인 → 이름 → 마이크 → 알림 → 녹음', (tester) async {
    final h = await pumpFresh(tester);
    expect(find.text('목소리를 테이프에 담아요'), findsOneWidget);
    await tester.tap(find.text('다음'));
    await step(tester);
    expect(find.text('소포로 포장해서 보내요'), findsOneWidget);
    await tester.tap(find.text('다음'));
    await step(tester);
    expect(find.text('소중한 목소리를\n추억별로 모아 보세요'), findsOneWidget);
    expect(find.text('사람, 순간, 주제별로 칸을 만들어 오래 간직할 수 있어요'), findsOneWidget);
    // v10.6: 서랍장 카드 하나에 칸 3줄 (이름 + n/10)
    for (final n in ['2026 생일', '엄마 목소리', '힘들 때 듣기', '5/10', '4/10', '3/10']) {
      expect(find.text(n), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('시작하기'));
    await step(tester);
    expect(await h.prefs.onboarded(), isTrue);

    // 로그인: "연결 중…" 0.7초
    // 시험 기본 플랫폼은 Android → Apple 대신 Google
    expect(find.text('카카오로 시작하기'), findsOneWidget);
    expect(find.text('Google로 계속하기'), findsOneWidget);
    expect(find.text('Apple로 계속하기'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pump();
    expect(find.text('연결 중…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
    await step(tester);

    // 이름: 추천 이름이 채워져 있다
    expect(find.text('테이프에 적힐\n이름을 알려주세요'), findsOneWidget);
    expect(find.widgetWithText(TextField, '민경'), findsOneWidget);
    expect(find.text('2/8'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(EditableText), '가나다라마바사아자차');
    await tester.pump();
    expect(
      find.widgetWithText(TextField, '가나다라마바사아'),
      findsOneWidget,
      reason: '8자까지',
    );
    expect(find.text('8/8'), findsOneWidget);
    await tester.tap(find.text('시작하기'));
    await step(tester);
    expect(h.store.name, '가나다라마바사아');

    // 마이크 → 실제 OS 권한 요청
    expect(find.text('녹음하려면\n마이크가 필요해요'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('계속'));
    await step(tester);
    expect(h.recorder.calls, contains('hasPermission(request: true)'));

    // 알림 → 실제 OS 권한 요청
    expect(find.text('테이프가 도착하면\n알려드려요'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('알림 받기'));
    await step(tester);
    expect(h.push.permissionRequests, 1);
    expect(h.store.notificationsEnabled, isTrue);
    expect(await h.prefs.permissionsAsked(), isTrue);

    expect(h.flow.inApp, isTrue);
    expect(find.byType(RecordScreen), findsOneWidget);
    expect(h.vm.myName, '가나다라마바사아', reason: '녹음 화면이 새 이름을 쓴다');
    expect(h.store.devices, contains('local-device'), reason: '푸시 토큰 등록');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('온보딩 건너뛰기, 알림 나중에 (iOS Apple)', (tester) async {
    final h = await pumpFresh(tester);
    await tester.tap(find.text('건너뛰기'));
    await step(tester);
    expect(find.text('카카오로 시작하기'), findsOneWidget);
    await tester.tap(find.text('Apple로 계속하기'));
    await tester.pump(const Duration(milliseconds: 700));
    await step(tester);
    // Apple은 추천 이름이 없을 수 있다 → 비워 두면 토스트
    await tester.tap(find.text('시작하기'));
    await tester.pump();
    expect(find.text('이름을 적어주세요'), findsOneWidget);
    await tester.enterText(find.byType(EditableText), '민경');
    await tester.tap(find.text('시작하기'));
    await step(tester);
    await tester.tap(find.text('계속'));
    await step(tester);
    await tester.tap(find.text('나중에 할게요'));
    await step(tester);
    expect(h.push.permissionRequests, 0);
    expect(h.store.notificationsEnabled, isFalse);
    expect(h.flow.inApp, isTrue);
    await tester.pump(const Duration(seconds: 3));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('재가입 제한: 서버 문구 + 날짜 토스트, 로그인 화면 그대로', (tester) async {
    final h = await pumpFresh(
      tester,
      mode: FailMode.rejoinRestricted,
      onboarded: true,
    );
    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    expect(
      find.text('탈퇴 후 30일 동안은 다시 가입할 수 없어요 · 10.25부터 가능해요'),
      findsOneWidget,
    );
    expect(h.auth.status, isNot(AuthStatus.needsName));
    expect(find.text('카카오로 시작하기'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('카카오 키가 없으면 토스트', (tester) async {
    final h = await pumpFresh(tester, onboarded: true);
    h.social.kakaoResult = const SocialUnavailable('카카오 앱 키가 설정되지 않았어요');
    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    expect(find.text('카카오 앱 키가 설정되지 않았어요'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('강제 업데이트 화면 → 스토어', (tester) async {
    final h = await pumpFresh(tester, mode: FailMode.forceUpdate);
    expect(find.text('새 버전이 나왔어요'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('업데이트하기'));
    await tester.pump();
    expect(h.links.opened.single.host, 'apps.apple.com');
  });
}
