import 'package:tapeletter_app/data/services/iap_service.dart';
import 'package:tapeletter_app/data/services/local/local_behavior.dart';
import 'package:tapeletter_app/domain/models/shop.dart';
import 'package:tapeletter_app/domain/models/tape_type.dart';
import 'package:tapeletter_app/ui/shop/view_model/shop_view_model.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../testing/record_harness.dart';

void main() {
  late RecordHarness h;
  late ShopViewModel vm;

  void setup(
    FakeAsync async, {
    LocalBehavior behavior = LocalBehavior.instant,
  }) {
    h = RecordHarness(behavior: behavior);
    vm = h.shopVm..load();
    async.flushMicrotasks();
  }

  TapeProduct tape(String id) => vm.catalog.tapes.firstWhere((t) => t.id == id);

  test('불러오기: 상품·잔액·보유·서랍', () {
    fakeAsync((async) {
      setup(async);
      expect(vm.catalog.tapes.map((t) => t.name), [
        '1분 테이프',
        '1분 테이프 5개',
        '3분 테이프',
        '3분 테이프 5개',
      ]);
      expect(vm.catalog.packs.map((p) => p.priceLabel), [
        '₩1,100',
        '₩5,500',
        '₩11,000',
      ]);
      expect(vm.credits, 120);
      expect(vm.ownedOf(TapeType.m1), 2);
      expect(vm.adsLeft, 3);
      // 보관량은 뜯은 테이프만 센다 (안 뜯은 소포 2개 제외)
      expect('${vm.stored}/${vm.cap}', '8/12');
    });
  });

  test('구매: 크레딧 차감, 보유 증가, 날아가는 테이프 0.85초, 토스트', () {
    fakeAsync((async) {
      setup(async);
      vm.buy(tape('tape60_5'));
      expect(vm.sheet, isA<BuySheet>());
      vm.confirmBuy();
      async.flushMicrotasks();
      expect(vm.sheet, isNull);
      expect(vm.credits, 0);
      expect(vm.ownedOf(TapeType.m1), 7);
      expect(vm.flyType, TapeType.m1);
      expect(h.toast.message, '보유 테이프에 넣었어요');
      expect(h.store.ledger.first.reason, '1분 테이프 5개 구매');
      async.elapse(const Duration(milliseconds: 850));
      expect(vm.flyType, isNull);
      // 녹음 탭 알약도 다시 불러온다
      h.vm.load();
      async.flushMicrotasks();
      expect(h.vm.wallet.ownedOf(TapeType.m1), 7);
    });
  });

  test('서랍 넓히기: cap +10', () {
    fakeAsync((async) {
      setup(async);
      vm.buy(vm.catalog.drawer.first);
      vm.confirmBuy();
      async.flushMicrotasks();
      expect(vm.cap, 22);
      expect(h.toast.message, '서랍에 10개 더 보관할 수 있어요');
      expect(h.store.ledger.first.reason, '서랍 넓히기');
    });
  });

  test('부족하면 charge(need) → 충전 → 원래 구매 시트로 돌아온다', () {
    fakeAsync((async) {
      setup(async);
      final five = tape('tape180_5'); // 200
      vm.buy(five);
      vm.confirmBuy();
      async.flushMicrotasks();
      final charge = vm.sheet as ChargeSheet;
      expect(charge.need, 80);
      expect(charge.after, five);

      vm.charge(vm.catalog.packs.first); // +100
      expect(vm.sheet, isA<PaySheet>());
      async.flushMicrotasks();
      expect(vm.credits, 220);
      expect(vm.coinOn, isTrue);
      final back = vm.sheet as BuySheet;
      expect(back.item, five);
      expect(h.toast.message, isNull, reason: '구매로 돌아갈 때는 충전 토스트가 없다');
      expect(h.iap.completed, hasLength(1));
      expect(h.store.ledger.first.reason, '크레딧 충전 · ₩1,100');
      async.elapse(const Duration(milliseconds: 1500));
      expect(vm.coinOn, isFalse);

      vm.confirmBuy();
      async.flushMicrotasks();
      expect(vm.ownedOf(TapeType.m3), 5);
      expect(vm.credits, 20);
    });
  });

  test('상점에서 바로 충전하면 토스트', () {
    fakeAsync((async) {
      setup(async);
      vm.charge(vm.catalog.packs[1]);
      async.flushMicrotasks();
      expect(vm.sheet, isNull);
      expect(vm.credits, 670);
      expect(h.toast.message, '550 크레딧 충전했어요');
    });
  });

  test('결제 취소 → 토스트, 원래 구매로 / 결제 실패 → payFail → 다시 시도', () {
    fakeAsync((async) {
      setup(async);
      h.iap.delay = const Duration(seconds: 1);
      vm.buy(tape('tape180_5'));
      vm.confirmBuy();
      async.flushMicrotasks();
      vm.charge(vm.catalog.packs.first);
      vm.payCancel();
      expect(vm.sheet, isA<BuySheet>());
      expect(h.toast.message, '결제를 취소했어요');
      async.elapse(const Duration(seconds: 2));
      expect(vm.credits, 120, reason: '취소한 결제 결과는 무시한다');

      h.iap.delay = Duration.zero;
      h.iap.outcome = (_) => const IapFailed();
      vm.confirmBuy();
      async.flushMicrotasks();
      vm.charge(vm.catalog.packs.first);
      async.flushMicrotasks();
      expect(vm.sheet, isA<PayFailSheet>());
      vm.payClose();
      expect(vm.sheet, isA<BuySheet>());

      vm.confirmBuy();
      async.flushMicrotasks();
      vm.charge(vm.catalog.packs.first);
      async.flushMicrotasks();
      h.iap.outcome = (id) => IapPurchased(
        IapReceipt(
          store: 'app_store',
          productId: id,
          transactionId: 'tx-retry',
          verificationData: 'jws',
        ),
      );
      vm.payRetry();
      async.flushMicrotasks();
      expect(vm.credits, 220);
      expect(vm.sheet, isA<BuySheet>());
    });
  });

  test('광고: 3·2·1(0.7초 간격) 뒤 +10, 남은 횟수 −1, 하루 3번', () {
    fakeAsync((async) {
      setup(async);
      vm.openAd();
      async.flushMicrotasks();
      expect((vm.sheet as AdSheet).count, 3);
      async.elapse(const Duration(milliseconds: 700));
      expect((vm.sheet as AdSheet).count, 2);
      async.elapse(const Duration(milliseconds: 700));
      expect((vm.sheet as AdSheet).count, 1);
      async.elapse(const Duration(milliseconds: 700));
      async.flushMicrotasks();
      expect(vm.sheet, isNull);
      expect(vm.credits, 130);
      expect(vm.adsLeft, 2);
      expect(h.toast.message, '10 크레딧 받았어요');
      expect(h.store.ledger.first.reason, '광고 보상');

      for (var i = 0; i < 2; i++) {
        vm.openAd();
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 2100));
        async.flushMicrotasks();
      }
      expect(vm.adsLeft, 0);
      vm.openAd();
      async.flushMicrotasks();
      expect(vm.sheet, isNull);
      expect(h.toast.message, '오늘은 다 받았어요');
    });
  });

  test('광고 ✕ → 보상 없이 닫고 충전 시트로 돌아간다', () {
    fakeAsync((async) {
      setup(async);
      vm.buy(tape('tape180_5'));
      vm.confirmBuy();
      async.flushMicrotasks();
      vm.openAd();
      async.flushMicrotasks();
      expect((vm.sheet as AdSheet).pending, isNotNull);
      async.elapse(const Duration(milliseconds: 700));
      vm.closeAd();
      expect(vm.sheet, isA<ChargeSheet>());
      expect(h.toast.message, '끝까지 봐야 받을 수 있어요');
      async.elapse(const Duration(seconds: 3));
      expect(vm.credits, 120);
      expect(vm.adsLeft, 3);
    });
  });

  test('충전 시트에서 광고를 보면 need가 10 줄어든다', () {
    fakeAsync((async) {
      setup(async);
      vm.buy(tape('tape180_5'));
      vm.confirmBuy();
      async.flushMicrotasks();
      vm.openAd();
      async.flushMicrotasks();
      async.elapse(const Duration(milliseconds: 2100));
      async.flushMicrotasks();
      expect((vm.sheet as ChargeSheet).need, 70);
    });
  });

  test('광고 불러오기 실패(adFail) → 확인하면 원래 시트로', () {
    fakeAsync((async) {
      setup(
        async,
        behavior: const LocalBehavior(
          failMode: FailMode.adFail,
          latency: Duration.zero,
        ),
      );
      vm.openAd();
      async.flushMicrotasks();
      expect(vm.sheet, isA<AdFailSheet>());
      vm.adFailOk();
      expect(vm.sheet, isNull);
    });
  });

  test('선물: 받는 사람 없으면 안 됨, 30 기본, 보내면 차감, 부족하면 charge', () {
    fakeAsync((async) {
      setup(async);
      vm.openGift();
      async.flushMicrotasks();
      var g = vm.sheet as GiftSheet;
      expect(g.amount, 30);
      expect(g.to, isNull);
      vm.sendGift();
      async.flushMicrotasks();
      expect(vm.sheet, isA<GiftSheet>());

      final jihyun = vm.giftFriends.first;
      expect(jihyun.name, '지현');
      vm.selectGiftTo(jihyun);
      vm.selectGiftAmount(100);
      g = vm.sheet as GiftSheet;
      expect(g.to, jihyun);
      expect(g.amount, 100);
      vm.sendGift();
      async.flushMicrotasks();
      expect(vm.sheet, isNull);
      expect(vm.credits, 20);
      expect(h.toast.message, '지현님에게 100 크레딧을 선물했어요');
      expect(h.store.ledger.first.reason, '지현님에게 선물');

      vm.openGift(to: jihyun);
      async.flushMicrotasks();
      vm.sendGift();
      async.flushMicrotasks();
      final c = vm.sheet as ChargeSheet;
      expect(c.need, 10);
      expect(c.after, isNull);
    });
  });

  test('녹음 탭의 "+": 강조하고 1개짜리 구매 시트를 바로 연다', () {
    fakeAsync((async) {
      setup(async);
      vm.buyTape(TapeType.m3);
      async.flushMicrotasks();
      expect(vm.highlight, TapeType.m3);
      final s = vm.sheet as BuySheet;
      expect(s.item.id, 'tape180_1');
      async.elapse(const Duration(seconds: 2));
    });
  });

  test('"+"로 연 구매 시트: 크레딧이 모자라면 충전 시트로', () {
    fakeAsync((async) {
      setup(async);
      h.store.credits = 10;
      h.wallet.invalidate();
      async.flushMicrotasks();
      vm.buyTape(TapeType.m1);
      async.flushMicrotasks();
      expect((vm.sheet as BuySheet).item.id, 'tape60_1');
      vm.confirmBuy();
      async.flushMicrotasks();
      final c = vm.sheet as ChargeSheet;
      expect(c.need, 20);
      expect((c.after as TapeProduct).id, 'tape60_1');
      async.elapse(const Duration(seconds: 2));
    });
  });

  test('녹음 탭에서 온 강조는 1.6초', () {
    fakeAsync((async) {
      setup(async);
      vm.highlightTape(TapeType.m3);
      expect(vm.highlight, TapeType.m3);
      async.elapse(const Duration(milliseconds: 1600));
      expect(vm.highlight, isNull);
    });
  });

  test('처음 들어오면 0.65초 스켈레톤', () {
    fakeAsync((async) {
      setup(async);
      vm.enter();
      expect(vm.skeleton, isTrue);
      async.elapse(const Duration(milliseconds: 650));
      expect(vm.skeleton, isFalse);
    });
  });
}
