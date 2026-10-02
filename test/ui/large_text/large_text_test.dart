import 'package:tapeletter_app/data/services/local/local_behavior.dart';
import 'package:tapeletter_app/data/services/local/local_store.dart';
import 'package:tapeletter_app/data/services/push_service.dart';
import 'package:tapeletter_app/routing/routes.dart';
import 'package:tapeletter_app/ui/core/ui/keep_all.dart';
import 'package:tapeletter_app/ui/my/view_model/my_view_model.dart';
import 'package:tapeletter_app/ui/player/view_model/player_view_model.dart';
import 'package:tapeletter_app/ui/record/widgets/record_deck.dart';
import 'package:tapeletter_app/ui/shelf/widgets/shelf_list_view.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../testing/app.dart';
import '../../../testing/fonts.dart';
import '../../../testing/large_text.dart';
import '../../../testing/record_harness.dart';

/// 큰 글씨(v10.4): 앱 전체 화면·시트를 시스템 글자 크기 1.0 · 1.3 · 1.6으로 띄워
/// 넘침(RenderFlex overflow), 글자 잘림, 낱말 가운데 줄바꿈이 없는지 본다.
void main() {
  setUpAll(loadAppFonts);
  // 한글 낱말 단위 줄바꿈을 켜고 본다 (다른 시험은 test/flutter_test_config.dart가 끈다)
  setUp(() => KeepAll.enabled = true);
  tearDown(() => KeepAll.enabled = false);

  Future<void> settle(WidgetTester tester, [int n = 8]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<RecordHarness> open(
    WidgetTester tester,
    String loc, {
    RecordHarness? harness,
    String shelfView = 'list',
  }) async {
    final h = harness ?? RecordHarness();
    h.prefs.shelfViewValue = shelfView;
    h.prefs.coachDoneValue = true;
    await tester.pumpWidget(testApp(h, initialLocation: loc));
    await settle(tester);
    return h;
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final f = findPlainText(text).last;
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
    await settle(tester);
  }

  Future<void> more(WidgetTester tester, String name) async {
    final f = find.descendant(
      of: find.ancestor(
        of: findPlainText(name),
        matching: find.byType(ShelfRow),
      ),
      matching: find.byType(MoreButton),
    );
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
    await settle(tester);
  }

  Future<void> record(WidgetTester tester) async {
    await tester.tapAt(tester.getCenter(find.byType(RecordDeck)));
    await settle(tester, 30);
    await tester.tapAt(tester.getCenter(find.byType(RecordDeck)));
    await settle(tester, 25);
  }

  final visits = <String, Future<void> Function(WidgetTester)>{
    '녹음 대기': (t) async => open(t, Routes.record),
    '녹음 확인': (t) async {
      await open(t, Routes.record);
      await record(t);
    },
    '받는 사람 고르기': (t) async {
      final h = await open(t, Routes.record);
      await record(t);
      h.vm.goSend();
      await settle(t);
    },
    '새 친구 이름': (t) async {
      final h = await open(t, Routes.record);
      await record(t);
      h.vm.goSend();
      h.vm.pickNew();
      await settle(t, 20);
    },
    '서랍 목록': (t) async => open(t, Routes.shelf),
    '서랍 책꽂이': (t) async => open(t, Routes.shelf, shelfView: 'shelf'),
    '서랍 꽉 참': (t) async {
      final h = RecordHarness()..store.cap = 8;
      await open(t, Routes.shelf, harness: h);
    },
    '서랍 ⋯ 시트': (t) async {
      await open(t, Routes.shelf);
      await more(t, '은비');
    },
    '옮기기 시트': (t) async {
      await open(t, Routes.shelf);
      await more(t, '은비');
      await tapText(t, '다른 칸으로 옮기기');
    },
    '메모 시트': (t) async {
      await open(t, Routes.shelf);
      await more(t, '은비');
      await tapText(t, '메모 남기기');
    },
    '칸 만들기 시트': (t) async {
      await open(t, Routes.shelf);
      await t.tap(find.bySemanticsLabel('칸 추가'));
      await settle(t);
    },
    '신고 시트': (t) async {
      await open(t, Routes.shelf);
      await more(t, '은비');
      await tapText(t, '신고하기');
    },
    '재생': (t) async {
      final h = RecordHarness();
      final id = h.store.groups[0].items.first.id;
      await open(t, Routes.playItem(const GroupSource('g-1'), id), harness: h);
      await settle(t, 10);
    },
    '소포 + 꽉 참 시트': (t) async {
      final h = RecordHarness()..store.cap = 8;
      await open(t, Routes.shelf, harness: h);
      await tapText(t, '지현');
      await tapText(t, '탭해서 뜯기');
    },
    '상점': (t) async => open(t, Routes.shop),
    '구매 시트': (t) async {
      await open(t, Routes.shop);
      await tapText(t, '1분 테이프');
    },
    '충전 시트': (t) async {
      final h = RecordHarness()..store.credits = 0;
      await open(t, Routes.shop, harness: h);
      await tapText(t, '3분 테이프 5개');
      await tapText(t, '구매');
    },
    '선물 시트': (t) async {
      await open(t, Routes.shop);
      await tapText(t, '크레딧 선물하기');
    },
    '마이': (t) async => open(t, Routes.my),
    '마이 받은 테이프': (t) async => open(t, Routes.myPage(MyPage.recv)),
    '마이 보낸 테이프': (t) async => open(t, Routes.myPage(MyPage.sent)),
    '보낸 테이프 상세': (t) async {
      await open(t, Routes.myPage(MyPage.sent));
      await tapText(t, '유진에게 보냄');
    },
    '마이 친구': (t) async => open(t, Routes.myPage(MyPage.friends)),
    '친구 ⋯ 시트': (t) async {
      await open(t, Routes.myPage(MyPage.friends));
      await t.tap(find.bySemanticsLabel('하늘 더 보기'));
      await settle(t);
    },
    '별명 시트': (t) async {
      await open(t, Routes.myPage(MyPage.friends));
      await t.tap(find.bySemanticsLabel('하늘 더 보기'));
      await settle(t);
      await tapText(t, '별명 설정');
    },
    '보내기 완료(새 친구)': (t) async {
      final h = await open(t, Routes.record);
      await record(t);
      h.vm.goSend();
      h.vm.pickNew();
      await settle(t, 10);
      h.vm.sendNow();
      await settle(t, 40);
    },
    '광고 시트': (t) async {
      await open(t, Routes.shop);
      await tapText(t, '광고 보고 받기');
    },
    '푸시 배너': (t) async {
      final h = await open(t, Routes.record);
      h.push.simulate(
        const PushMessage(
          kind: PushKind.tape,
          title: '유진님이 테이프를 보냈어요',
          body: '3분 테이프 · 탭해서 뜯어보세요',
        ),
      );
      await settle(t, 6);
    },
    '오프라인 배너·토스트': (t) async {
      final h = await open(t, Routes.shelf);
      h.connectivity.set(false);
      h.toast.show('잠시 문제가 생겼어요. 다시 시도해 주세요');
      await settle(t, 3);
    },
    '마이 설정': (t) async => open(t, Routes.myPage(MyPage.settings)),
    '회원 탈퇴 시트': (t) async {
      await open(t, Routes.myPage(MyPage.settings));
      await tapText(t, '회원 탈퇴');
    },
    '크레딧 내역': (t) async => open(t, Routes.credits),
    '친구 화면': (t) async => open(t, Routes.friend('u-mom')),
    '링크 오류': (t) async => open(t, Routes.linkErrorOf('taken')),
    '온보딩': (t) async => open(
      t,
      Routes.onboarding,
      harness: RecordHarness(signedIn: false, onboarded: false),
    ),
    '로그인': (t) async =>
        open(t, Routes.login, harness: RecordHarness(signedIn: false)),
    '이름 정하기': (t) async {
      final h = RecordHarness(
        store: LocalStore(newUser: true),
        signedIn: false,
      );
      await open(t, Routes.login, harness: h);
      await tapText(t, '카카오로 시작하기');
      await settle(t, 10);
    },
    '권한 안내': (t) async => open(
      t,
      Routes.permissionsMic,
      harness: RecordHarness(permissionsAsked: false),
    ),
    '강제 업데이트': (t) async => open(
      t,
      Routes.splash,
      harness: RecordHarness(
        behavior: LocalBehavior.instant.copyWith(
          failMode: FailMode.forceUpdate,
        ),
      ),
    ),
  };

  for (final scale in [1.0, 1.3, 1.6]) {
    group('글자 $scale배', () {
      for (final MapEntry(key: name, value: visit) in visits.entries) {
        testWidgets(name, (tester) async {
          useDesignScreen(tester);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final errors = LayoutErrors();
          try {
            await visit(tester);
            final issues = textIssues(tester);
            if (const bool.fromEnvironment('LT_DUMP')) {
              for (final x in [...errors.errors, ...issues]) {
                debugPrint('ISSUE|$scale|$name|$x');
              }
              return;
            }
            expect(
              [...errors.errors, ...issues],
              isEmpty,
              reason: '$name @ $scale',
            );
          } finally {
            errors.stop();
            await tester.pump(const Duration(seconds: 5));
          }
        });
      }
    });
  }

  testWidgets('1.3배 이상: 받은 테이프 오른쪽 날짜를 부제 앞으로', (tester) async {
    useDesignScreen(tester);
    KeepAll.enabled = false;
    for (final (scale, compact) in [(1.0, false), (1.3, true), (1.6, true)]) {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      await open(tester, Routes.myPage(MyPage.recv));
      final withDate = find.textContaining(RegExp(r'^\d\d\.\d\d \d\d:\d\d · '));
      expect(withDate, compact ? findsWidgets : findsNothing, reason: '$scale');
      await tester.pumpWidget(const SizedBox());
    }
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });

  testWidgets('1.6배를 넘는 시스템 글자 크기는 1.6배로 묶는다', (tester) async {
    useDesignScreen(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester, Routes.shelf);
    final ctx = tester.element(find.text('서랍').first);
    expect(MediaQuery.textScalerOf(ctx).scale(10), 16);
  });
}
