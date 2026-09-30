import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tapeletter_app/domain/models/tape_type.dart';
import 'package:tapeletter_app/routing/routes.dart';
import 'package:tapeletter_app/ui/player/view_model/player_view_model.dart';

import '../testing/app.dart';
import '../testing/record_harness.dart';

/// 스토어 제출용 스크린샷 — 문구 합성 없이 화면 그대로.
///
/// ```bash
/// tool/store_screenshots.sh            # iPhone 17 Pro Max 시뮬레이터 (6.9인치 1320×2868)
/// ```
/// 가짜 모드(프로토타입 초기 데이터, `testing/`)로 장면마다 앱을 새로 띄운다.
/// 로그인·권한 안내·온보딩은 지난 상태다. 앱은 로그에 `TAPELETTER_SHOT <이름>`을 찍고
/// 1.5초 멈춰 있고, 바깥 스크립트가 그 사이에 `xcrun simctl io … screenshot`으로 찍는다
/// (상태바 포함 네이티브 해상도).
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  Future<void> wait(WidgetTester tester, Duration d) async {
    final end = DateTime.now().add(d);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> shot(WidgetTester tester, String name) async {
    // ignore: avoid_print
    print('TAPELETTER_SHOT $name');
    await wait(tester, const Duration(milliseconds: 1500));
  }

  Future<RecordHarness> open(
    WidgetTester tester,
    String location, {
    RecordHarness? harness,
  }) async {
    final h = harness ?? RecordHarness();
    // 장면마다 새 앱 (같은 자리의 앱은 상태·주소를 그대로 들고 있어서 키로 갈아 끼운다)
    await tester.pumpWidget(
      KeyedSubtree(
        key: UniqueKey(),
        child: testApp(h, initialLocation: location),
      ),
    );
    // 스켈레톤·등장 애니메이션이 끝날 때까지
    await wait(tester, const Duration(milliseconds: 1500));
    return h;
  }

  testWidgets('스토어 스크린샷', (tester) async {
    // 1. 녹음 대기 — 1분 테이프
    final h = await open(tester, Routes.record);
    h.vm.selectTape(TapeType.m1);
    await wait(tester, const Duration(milliseconds: 800));
    await shot(tester, '01_record');

    // 2. 녹음 중 — 시간 표시, 옆 테이프·개수 숨김
    h.vm.startRec();
    await wait(tester, const Duration(milliseconds: 7300));
    await shot(tester, '02_recording');

    // 3. 보내기 — 소포 포장 연출
    h.vm.stopRec();
    await wait(tester, const Duration(seconds: 3));
    h.vm.goSend();
    await wait(tester, const Duration(milliseconds: 600));
    h.vm.pickFriend(h.vm.sortedFriends.firstWhere((f) => f.name == '지현'));
    await wait(tester, const Duration(milliseconds: 600));
    // 스크립트는 표시 0.8초 뒤에 찍고 캡처까지 약 0.5초가 더 걸린다. 표시를 먼저 남기고
    // 0.5초 뒤 보내면 연출 약 0.8초 — 테이프가 열린 상자에 들어간 프레임
    // ignore: avoid_print
    print('TAPELETTER_SHOT 03_sending');
    await wait(tester, const Duration(milliseconds: 500));
    h.vm.sendNow();
    await wait(tester, const Duration(milliseconds: 1500));
    await wait(tester, const Duration(seconds: 2));

    // 4. 서랍 — 칸별 목록 (시·분)
    await open(
      tester,
      Routes.shelf,
      harness: RecordHarness()..prefs.shelfViewValue = 'list',
    );
    await shot(tester, '04_shelf');

    // 5. 받은 소포 (뜯기 전)
    final p = RecordHarness();
    await open(
      tester,
      Routes.playItem(const UnsortedSource(), p.store.unsorted.first.id),
      harness: p,
    );
    await shot(tester, '05_parcel');

    // 6. 재생 — 칸 '2026 생일'의 수아
    final r = RecordHarness();
    final sua = r.store.groups.first.items.firstWhere(
      (x) => x.sender.name == '수아',
    );
    await open(
      tester,
      Routes.playItem(const GroupSource('g-1'), sua.id),
      harness: r,
    );
    r.player.emitPosition(const Duration(seconds: 5));
    await wait(tester, const Duration(milliseconds: 600));
    await shot(tester, '06_player');

    // 7. 친구 화면
    await open(tester, Routes.friend('u-mom'));
    await shot(tester, '07_friend');

    // 8. 상점
    await open(tester, Routes.shop);
    await shot(tester, '08_shop');

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
