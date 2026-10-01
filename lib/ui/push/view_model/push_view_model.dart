import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/device_repository.dart';
import '../../../data/repositories/shelf_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/wallet_repository.dart';
import '../../../data/services/push_service.dart';
import '../../../routing/app_flow.dart';

/// 푸시: 기기 토큰 등록, 앱 안 배너(`pushOn`), 알림을 눌렀을 때 이동.
class PushViewModel extends ChangeNotifier {
  PushViewModel({
    required this._push,
    required this._devices,
    required this._auth,
    required this._flow,
    required this._shelf,
    required this._wallet,
    required this._users,
  });

  /// 배너가 떠 있는 시간 `later('push', 6000)`
  static const bannerTime = Duration(seconds: 6);

  final PushService _push;
  final DeviceRepository _devices;
  final AuthRepository _auth;
  final AppFlow _flow;
  final ShelfRepository _shelf;
  final WalletRepository _wallet;
  final UserRepository _users;

  final _opens = StreamController<PushMessage>.broadcast();
  final List<StreamSubscription<Object?>> _subs = [];
  PushMessage? _banner;
  PushMessage? _pendingOpen;
  int _serial = 0;
  Timer? _timer;

  /// 앱 안 배너
  PushMessage? get banner => _banner;

  /// 배너 애니메이션을 다시 틀기 위한 값
  int get serial => _serial;

  /// 알림을 눌렀다 → 라우터를 가진 위젯이 이동한다.
  Stream<PushMessage> get opens => _opens.stream;

  Future<void> start() async {
    _subs.add(_push.onForeground.listen(_received));
    _subs.add(_push.onOpened.listen(_open));
    _subs.add(_push.onTokenRefresh.listen((_) => _register()));
    _auth.addListener(_register);
    _flow.addListener(_flush);
    unawaited(_register()); // 이미 로그인해 있으면 바로
    final initial = await _push.initialMessage();
    if (initial != null) _open(initial);
  }

  /// 로그인한 뒤 기기 토큰을 등록한다 (`PUT /notifications/devices`).
  Future<void> _register() async {
    if (_auth.status != AuthStatus.signedIn) {
      if (_auth.status == AuthStatus.signedOut) _devices.forget();
      return;
    }
    final t = await _push.token();
    if (t != null) await _devices.register(t, _push.platform);
  }

  void _received(PushMessage m) {
    // 새 테이프·선물이 왔으니 서랍·크레딧을 다시 불러온다.
    switch (m.kind) {
      case PushKind.tape:
        _shelf.invalidate();
        _users.invalidate();
      case PushKind.gift:
        _wallet.invalidate();
      case PushKind.claimed:
        _users.invalidate();
    }
    _banner = m;
    _serial++;
    _timer?.cancel();
    _timer = Timer(bannerTime, () {
      _banner = null;
      notifyListeners();
    });
    notifyListeners();
  }

  /// 배너를 눌렀다 (`pushTap`)
  void tapBanner() {
    final m = _banner;
    if (m == null) return;
    _timer?.cancel();
    _banner = null;
    notifyListeners();
    _open(m);
  }

  /// 배너를 위로 밀어 치웠다 — 이동하지 않고 닫기만 한다.
  void dismissBanner() {
    if (_banner == null) return;
    _timer?.cancel();
    _banner = null;
    notifyListeners();
  }

  void _open(PushMessage m) {
    if (_flow.inApp) {
      _opens.add(m);
    } else {
      _pendingOpen = m; // 로그인·권한 안내가 끝나면
    }
  }

  void _flush() {
    final m = _pendingOpen;
    if (m == null || !_flow.inApp) return;
    _pendingOpen = null;
    _opens.add(m);
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _auth.removeListener(_register);
    _flow.removeListener(_flush);
    _opens.close();
    super.dispose();
  }
}
