import 'package:tapeletter_app/data/repositories/auth_repository.dart';
import 'package:tapeletter_app/data/services/local/local_behavior.dart';
import 'package:tapeletter_app/data/services/local/local_store.dart';
import 'package:tapeletter_app/data/services/social_auth_service.dart';
import 'package:tapeletter_app/ui/auth/view_model/login_view_model.dart';
import 'package:tapeletter_app/ui/auth/widgets/login_screen.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../testing/fonts.dart';
import '../../../testing/record_harness.dart';

void main() {
  RecordHarness fresh({FailMode mode = FailMode.none}) => RecordHarness(
    store: LocalStore(
      clock: () => DateTime.utc(2026, 9, 25, 12),
      newUser: true,
    ),
    behavior: LocalBehavior.instant.copyWith(failMode: mode),
    signedIn: false,
  );

  group('LoginViewModel Google', () {
    test('성공: 연결 중… → 이름 정하기', () {
      fakeAsync((async) {
        final h = fresh();
        final vm = LoginViewModel(auth: h.auth, toast: h.toast);
        vm.signIn(LoginProvider.google);
        async.flushMicrotasks();
        expect(vm.busy, LoginProvider.google);
        async.elapse(LoginViewModel.connectingTime);
        expect(h.auth.status, AuthStatus.needsName);
        expect(h.toast.message, isNull);
        vm.dispose();
      });
    });

    test('취소: 토스트 없이 버튼으로 돌아온다', () {
      fakeAsync((async) {
        final h = fresh();
        h.social.googleResult = const SocialCanceled();
        final vm = LoginViewModel(auth: h.auth, toast: h.toast);
        vm.signIn(LoginProvider.google);
        async.elapse(LoginViewModel.connectingTime);
        expect(vm.busy, isNull);
        expect(h.toast.message, isNull);
        expect(h.auth.status, isNot(AuthStatus.needsName));
        vm.dispose();
      });
    });

    test('서버 거절(REJOIN_RESTRICTED): 서버 문구 + 날짜 토스트', () {
      fakeAsync((async) {
        final h = fresh(mode: FailMode.rejoinRestricted);
        final vm = LoginViewModel(auth: h.auth, toast: h.toast);
        vm.signIn(LoginProvider.google);
        async.elapse(LoginViewModel.connectingTime);
        expect(vm.busy, isNull);
        expect(h.toast.message, '탈퇴 후 30일 동안은 다시 가입할 수 없어요 · 10.25부터 가능해요');
        expect(h.tokens.tokens, isNull);
        vm.dispose();
      });
    });

    test('설정 없음(serverClientId 비어 있음): 일반 실패 토스트', () {
      fakeAsync((async) {
        final h = fresh();
        h.social.googleResult = const SocialFailed('missing');
        final vm = LoginViewModel(auth: h.auth, toast: h.toast);
        vm.signIn(LoginProvider.google);
        async.elapse(LoginViewModel.connectingTime);
        expect(h.toast.message, '로그인하지 못했어요. 다시 시도해 주세요');
        vm.dispose();
      });
    });
  });

  group('로그인 버튼 플랫폼', () {
    setUpAll(loadAppFonts);

    Future<void> pumpLogin(WidgetTester tester) async {
      final h = fresh();
      final vm = LoginViewModel(auth: h.auth, toast: h.toast);
      addTearDown(vm.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            viewModel: vm,
            onOpenTerms: () {},
            onOpenPrivacy: () {},
            devLogin: false,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('Android: Google 버튼, Apple 없음', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await pumpLogin(tester);
        expect(find.text('카카오로 시작하기'), findsOneWidget);
        expect(find.text('Google로 계속하기'), findsOneWidget);
        expect(find.text('Apple로 계속하기'), findsNothing);
        // Apple 버튼과 같은 자리·크기 (높이 56)
        final size = tester.getSize(
          find.ancestor(
            of: find.text('Google로 계속하기'),
            matching: find.byType(AnimatedContainer),
          ),
        );
        expect(size.height, 56);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('iOS: Apple 버튼, Google 없음', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await pumpLogin(tester);
        expect(find.text('카카오로 시작하기'), findsOneWidget);
        expect(find.text('Apple로 계속하기'), findsOneWidget);
        expect(find.text('Google로 계속하기'), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
