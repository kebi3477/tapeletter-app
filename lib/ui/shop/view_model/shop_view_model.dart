import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/model/api_error.dart';
import '../../../data/repositories/friend_repository.dart';
import '../../../data/repositories/shelf_repository.dart';
import '../../../data/repositories/shop_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/wallet_repository.dart';
import '../../../data/services/ad_service.dart';
import '../../../data/services/iap_service.dart';
import '../../../domain/models/friend.dart';
import '../../../domain/models/me.dart';
import '../../../domain/models/shop.dart';
import '../../../domain/models/tape_type.dart';
import '../../../domain/models/wallet.dart';
import '../../../utils/idempotency.dart';
import '../../../utils/result.dart';
import '../../core/ui/toast.dart';

/// 상점·크레딧 시트 — logic.js `sheet.kind`
/// (`buy` · `charge` · `pay` · `payFail` · `ad` · `adFail` · `gift`).
sealed class ShopSheet {
  const ShopSheet();
}

/// 구매 확인 (`shBuy`)
class BuySheet extends ShopSheet {
  const BuySheet(this.item);

  final ShopItem item;
}

/// 크레딧 부족 (`shCharge`). 충전하면 [after] 구매 시트로 돌아간다.
class ChargeSheet extends ShopSheet {
  const ChargeSheet({required this.need, this.after});

  final int need;
  final ShopItem? after;
}

/// 결제 진행 (`shPay`)
class PaySheet extends ShopSheet {
  const PaySheet(this.pack, {this.after});

  final CreditPack pack;
  final ShopItem? after;
}

/// 결제 실패 (`shPayFail`)
class PayFailSheet extends ShopSheet {
  const PayFailSheet(this.pack, {this.after});

  final CreditPack pack;
  final ShopItem? after;
}

/// 광고 (`shAd`) — 3 → 2 → 1 카운트. [pending]은 광고를 연 충전 시트.
class AdSheet extends ShopSheet {
  const AdSheet({required this.count, this.pending});

  final int count;
  final ChargeSheet? pending;
}

/// 광고 불러오기 실패 (`shAdFail`)
class AdFailSheet extends ShopSheet {
  const AdFailSheet({this.pending});

  final ChargeSheet? pending;
}

/// 크레딧 선물하기 (`shGift`)
class GiftSheet extends ShopSheet {
  const GiftSheet({this.to, this.amount = 30});

  final Friend? to;
  final int amount;
}

/// 상점 탭과 크레딧 시트 ViewModel — logic.js `buy`, `confirmBuy`, `charge`, `openAd`, 선물.
class ShopViewModel extends ChangeNotifier {
  ShopViewModel({
    required ShopRepository shopRepository,
    required WalletRepository walletRepository,
    required UserRepository userRepository,
    required FriendRepository friendRepository,
    required ShelfRepository shelfRepository,
    required this._iap,
    required this._ads,
    required this._toast,
  }) : _shop = shopRepository,
       _wallet = walletRepository,
       _users = userRepository,
       _friendsRepo = friendRepository,
       _shelf = shelfRepository {
    _wallet.addListener(_reloadWallet);
    _users.addListener(_reloadMe);
    _friendsRepo.addListener(_reloadFriends);
  }

  /// 스켈레톤 `later('skel', 650)`
  static const skeletonTime = Duration(milliseconds: 650);

  /// 녹음 탭에서 온 테이프 행 강조 `later('hl', 1600)`
  static const highlightTime = Duration(milliseconds: 1600);

  /// 코인 떨어짐 `later('coin', 1500)`
  static const coinTime = Duration(milliseconds: 1500);

  /// 산 테이프가 날아감 `later('fly', 850)`
  static const flyTime = Duration(milliseconds: 850);

  /// 광고 카운트 `every('ad', 700)`
  static const adTick = Duration(milliseconds: 700);

  /// 광고 보상 확인: `GET /wallet`을 1초 간격으로 최대 5번 (계약서 §15)
  static const rewardPoll = Duration(seconds: 1);
  static const rewardPollTimes = 5;

  final ShopRepository _shop;
  final WalletRepository _wallet;
  final UserRepository _users;
  final FriendRepository _friendsRepo;
  final ShelfRepository _shelf;
  final IapService _iap;
  final AdService _ads;
  final ToastController _toast;

  ShopCatalog _catalog = ShopCatalog.empty;
  Wallet _w = const Wallet(credits: 0, owned: {}, adsLeft: 0);
  Me? _me;
  List<Friend> _friends = const [];
  bool _seen = false;
  bool _skeleton = false;
  TapeType? _hl;
  bool _coinOn = false;
  TapeType? _flyType;
  ShopSheet? _sheet;
  bool _busy = false;
  int _payGen = 0;
  Timer? _hlTimer;
  Timer? _coinTimer;
  Timer? _flyTimer;
  Timer? _adTimer;
  Timer? _skelTimer;

  ShopCatalog get catalog => _catalog;
  int get credits => _w.credits;
  int get adsLeft => _w.adsLeft;
  int ownedOf(TapeType t) => _w.ownedOf(t);
  int get stored => _me?.drawer.stored ?? 0;
  int get cap => _me?.drawer.cap ?? 0;
  bool get skeleton => _skeleton;

  /// 강조할 테이프 (`hl`) — 1개짜리 행만 `flash 1.6s`
  TapeType? get highlight => _hl;
  bool get coinOn => _coinOn;

  /// 방금 산 테이프 (`flyOn`, `flyType`)
  TapeType? get flyType => _flyType;
  ShopSheet? get sheet => _sheet;

  /// 선물 받는 사람 칩 (즐겨찾기 먼저)
  List<Friend> get giftFriends => [
    ..._friends.where((f) => f.starred),
    ..._friends.where((f) => !f.starred),
  ];

  // ── 불러오기 ─────────────────────────────────────
  Future<void> load() async {
    final c = await _shop.getCatalog();
    if (c is Ok<ShopCatalog>) _catalog = c.value;
    await Future.wait([_reloadWallet(), _reloadMe(), _reloadFriends()]);
  }

  Future<void> _reloadWallet() async {
    final r = await _wallet.getWallet();
    if (r is Ok<Wallet>) {
      _w = r.value;
      notifyListeners();
    }
  }

  Future<void> _reloadMe() async {
    final r = await _users.getMe();
    if (r is Ok<Me>) {
      _me = r.value;
      notifyListeners();
    }
  }

  Future<void> _reloadFriends() async {
    final r = await _friendsRepo.getFriends();
    if (r is Ok<List<Friend>>) {
      _friends = r.value;
      notifyListeners();
    }
  }

  /// 탭에 들어올 때. 처음이면 0.65초 스켈레톤. 화면 initState에서 부르므로 알리지 않는다.
  void enter() {
    if (_seen) return;
    _seen = true;
    _skeleton = true;
    _skelTimer = Timer(skeletonTime, () {
      _skeleton = false;
      notifyListeners();
    });
  }

  int _drawerPop = 0;

  /// 서랍 배너 "넓히기 ›"로 왔을 때 서랍 카드가 팝 (`hl === 'drawer'` → `pop .5s`). 바뀔 때마다 다시 튼다.
  int get drawerPop => _drawerPop;

  void highlightDrawer() {
    _drawerPop++;
    notifyListeners();
  }

  /// 서랍이 거의 찼는지 (`stored >= cap - 2`) — 서랍 카드 레드 틴트
  bool get drawerNear => cap > 0 && stored >= cap - 2;

  /// 녹음 탭에서 0개 테이프를 눌러 왔을 때 (`goShop(hl)`)
  void highlightTape(TapeType type) {
    _hl = type;
    _hlTimer?.cancel();
    _hlTimer = Timer(highlightTime, () {
      _hl = null;
      notifyListeners();
    });
    notifyListeners();
  }

  /// 녹음 탭에서 0개 테이프의 "+"를 눌러 왔을 때 — 강조하고 1개짜리 구매 시트(`shBuy`)를 연다.
  /// 크레딧이 모자라면 "사기"에서 충전 시트로 이어진다.
  Future<void> buyTape(TapeType type) async {
    highlightTape(type);
    TapeProduct? find() =>
        _catalog.tapes.where((p) => p.type == type && p.qty == 1).firstOrNull;
    var item = find();
    if (item == null) {
      // 상점에 처음 들어온 순간이면 상품 목록을 먼저 받는다
      final c = await _shop.getCatalog();
      if (c is Ok<ShopCatalog>) _catalog = c.value;
      item = find();
    }
    if (item != null) buy(item);
  }

  /// 서랍 넓히기 상품 (`etc[0]`). 상품 목록을 아직 못 받았으면 null.
  DrawerProduct? get drawerProduct => _catalog.drawer.firstOrNull;

  /// 재생 화면의 서랍 꽉 참 시트에서 "서랍 넓히기" (`foBuy` → `buy(etc[0])`) — 구매 확인 시트.
  Future<void> buyDrawer() async {
    var item = drawerProduct;
    if (item == null) {
      final c = await _shop.getCatalog();
      if (c is Ok<ShopCatalog>) _catalog = c.value;
      item = drawerProduct;
    }
    if (item != null) buy(item);
  }

  // ── 시트 ──────────────────────────────────────────
  void _show(ShopSheet? s) {
    _sheet = s;
    notifyListeners();
  }

  /// 딤을 눌러 닫기 (`closeSheet`)
  void closeSheet() {
    _adTimer?.cancel();
    if (_sheet is PaySheet) _payGen++;
    _show(null);
  }

  // ── 사기 (`buy`, `confirmBuy`) ───────────────────────
  void buy(ShopItem item) => _show(BuySheet(item));

  Future<void> confirmBuy() async {
    final s = _sheet;
    if (s is! BuySheet || _busy) return;
    final item = s.item;
    if (credits < item.price) {
      _show(ChargeSheet(need: item.price - credits, after: item));
      return;
    }
    _busy = true;
    final r = await _shop.purchase(
      item.id,
      idempotencyKey: newIdempotencyKey(),
    );
    _busy = false;
    switch (r) {
      case Ok<PurchaseResult>(:final value):
        _w = Wallet(
          credits: value.credits,
          owned: value.owned,
          adsLeft: adsLeft,
        );
        _show(null);
        if (item is TapeProduct) {
          _fly(item.type);
          _toast.show('보유 테이프에 넣었어요');
        } else {
          _toast.show('서랍에 10개 더 보관할 수 있어요');
          _shelf.invalidate();
        }
        _wallet.invalidate();
        _users.invalidate();
      case Error<PurchaseResult>(:final error):
        if (error is ApiException &&
            error.code == ApiErrorCode.insufficientCredits) {
          final need = error.extra['need'] as int? ?? item.price - credits;
          _show(ChargeSheet(need: need, after: item));
        } else {
          _toast.show(_message(error));
        }
    }
  }

  void _fly(TapeType type) {
    _flyType = type;
    _flyTimer?.cancel();
    _flyTimer = Timer(flyTime, () {
      _flyType = null;
      notifyListeners();
    });
  }

  void _coins() {
    _coinOn = true;
    _coinTimer?.cancel();
    _coinTimer = Timer(coinTime, () {
      _coinOn = false;
      notifyListeners();
    });
  }

  // ── 충전 (`charge`) ──────────────────────────────────
  /// 팩을 누르면 결제 진행 시트 → 스토어 결제 → `POST /billing/iap`.
  /// 충전 시트에서 왔다면 끝나고 원래 사려던 구매 시트로 돌아간다.
  Future<void> charge(CreditPack pack) async {
    final s = _sheet;
    final after = switch (s) {
      ChargeSheet(:final after) => after,
      PayFailSheet(:final after) => after,
      _ => null,
    };
    final gen = ++_payGen;
    _show(PaySheet(pack, after: after));
    final outcome = await _iap.buy(pack.productId);
    if (gen != _payGen) return;
    switch (outcome) {
      case IapCanceled():
        _payCanceled(after);
      case IapFailed():
        _show(PayFailSheet(pack, after: after));
      case IapPurchased(:final receipt):
        final r = await _shop.verifyIap(
          receipt,
          idempotencyKey: receipt.transactionId,
        );
        if (gen != _payGen) return;
        switch (r) {
          case Ok<int>(:final value):
            await _iap.complete(receipt);
            _w = Wallet(credits: value, owned: _w.owned, adsLeft: adsLeft);
            _coins();
            _show(after != null ? BuySheet(after) : null);
            if (after == null) _toast.show('${pack.credits} 크레딧 충전했어요');
            _wallet.invalidate();
          case Error<int>():
            _show(PayFailSheet(pack, after: after));
        }
    }
  }

  /// 결제 취소 (`payCancel`)
  void payCancel() {
    final s = _sheet;
    if (s is! PaySheet) return;
    _payGen++;
    _iap.cancel();
    _payCanceled(s.after);
  }

  void _payCanceled(ShopItem? after) {
    _show(after != null ? BuySheet(after) : null);
    _toast.show('결제를 취소했어요');
  }

  /// 결제 실패 시트 — 다시 시도 (`payRetry`)
  Future<void> payRetry() async {
    final s = _sheet;
    if (s is PayFailSheet) await charge(s.pack);
  }

  /// 결제 실패 시트 — 닫기 (`payClose`)
  void payClose() {
    final s = _sheet;
    if (s is PayFailSheet) _show(s.after != null ? BuySheet(s.after!) : null);
  }

  // ── 광고 (`openAd`) ──────────────────────────────────
  Future<void> openAd() async {
    if (adsLeft <= 0) {
      _toast.show('오늘은 다 받았어요');
      return;
    }
    final s = _sheet;
    final pending = s is ChargeSheet ? s : null;
    final userId = _me?.id ?? '';
    final loaded = await _ads.load(userId: userId);
    if (!loaded) {
      _show(AdFailSheet(pending: pending));
      return;
    }
    if (_ads.simulated) {
      _show(AdSheet(count: 3, pending: pending));
      _adTimer?.cancel();
      _adTimer = Timer.periodic(adTick, (t) {
        final cur = _sheet;
        if (cur is! AdSheet) {
          t.cancel();
          return;
        }
        if (cur.count <= 1) {
          t.cancel();
          _show(AdSheet(count: 0, pending: cur.pending));
          _finishAd(cur.pending, simulate: true);
          return;
        }
        _show(AdSheet(count: cur.count - 1, pending: cur.pending));
      });
      return;
    }
    final outcome = await _ads.show();
    switch (outcome) {
      case AdOutcome.rewarded:
        await _finishAd(pending);
      case AdOutcome.closedEarly:
        _toast.show('끝까지 봐야 받을 수 있어요');
      case AdOutcome.failed:
        _show(AdFailSheet(pending: pending));
    }
  }

  /// 광고를 다 봤다 — 서버 SSV 보상이 들어왔는지 `GET /wallet`으로 확인한다.
  Future<void> _finishAd(ChargeSheet? pending, {bool simulate = false}) async {
    final before = credits;
    if (simulate) await _ads.simulateReward();
    for (var i = 0; i < rewardPollTimes; i++) {
      if (i > 0) await Future<void>.delayed(rewardPoll);
      final r = await _wallet.getWallet();
      if (r is Ok<Wallet> && r.value.credits > before) {
        _w = r.value;
        _coins();
        _show(
          pending != null
              ? ChargeSheet(
                  need: (pending.need - 10).clamp(0, pending.need),
                  after: pending.after,
                )
              : null,
        );
        _toast.show('10 크레딧 받았어요');
        _wallet.invalidate();
        return;
      }
    }
    _show(pending);
  }

  /// 광고 ✕ (`closeAd`) — 보상 없이 닫는다.
  void closeAd() {
    final s = _sheet;
    if (s is! AdSheet) return;
    _adTimer?.cancel();
    _show(s.pending);
    _toast.show('끝까지 봐야 받을 수 있어요');
  }

  /// 광고 불러오기 실패 — 확인 (`adFailOk`)
  void adFailOk() {
    final s = _sheet;
    if (s is AdFailSheet) _show(s.pending);
  }

  // ── 선물 (`openGift`, `sendGift`) ─────────────────────
  /// [to]가 있으면 그 친구를 미리 골라 둔다 (마이 > 친구 ⋯).
  void openGift({Friend? to}) {
    _reloadFriends();
    _show(GiftSheet(to: to));
  }

  void selectGiftTo(Friend f) {
    final s = _sheet;
    if (s is GiftSheet) _show(GiftSheet(to: f, amount: s.amount));
  }

  void selectGiftAmount(int amount) {
    final s = _sheet;
    if (s is GiftSheet) _show(GiftSheet(to: s.to, amount: amount));
  }

  Future<void> sendGift() async {
    final s = _sheet;
    if (s is! GiftSheet || s.to == null || _busy) return;
    final to = s.to!;
    if (credits < s.amount) {
      _show(ChargeSheet(need: s.amount - credits));
      return;
    }
    _busy = true;
    final r = await _wallet.gift(
      toUserId: to.id,
      amount: s.amount,
      idempotencyKey: newIdempotencyKey(),
    );
    _busy = false;
    switch (r) {
      case Ok<int>(:final value):
        _w = Wallet(credits: value, owned: _w.owned, adsLeft: adsLeft);
        _show(null);
        _toast.show('${to.name}님에게 ${s.amount} 크레딧을 선물했어요');
      case Error<int>(:final error):
        if (error is ApiException &&
            error.code == ApiErrorCode.insufficientCredits) {
          _show(
            ChargeSheet(
              need: error.extra['need'] as int? ?? s.amount - credits,
            ),
          );
        } else {
          _toast.show(_message(error));
        }
    }
  }

  static String _message(Exception e) =>
      e is ApiException ? e.message : '잠시 문제가 생겼어요. 다시 시도해 주세요';

  @override
  void dispose() {
    for (final t in [_hlTimer, _coinTimer, _flyTimer, _adTimer, _skelTimer]) {
      t?.cancel();
    }
    _wallet.removeListener(_reloadWallet);
    _users.removeListener(_reloadMe);
    _friendsRepo.removeListener(_reloadFriends);
    super.dispose();
  }
}
