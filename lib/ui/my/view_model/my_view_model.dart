import 'dart:async';

import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';

import '../../../config/links.dart';
import '../../../data/model/api_error.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/delivery_repository.dart';
import '../../../data/repositories/friend_repository.dart';
import '../../../data/repositories/shelf_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/wallet_repository.dart';
import '../../../data/services/app_info_service.dart';
import '../../../data/services/link_service.dart';
import '../../../data/services/share_service.dart';
import '../../../domain/models/blocked_user.dart';
import '../../../domain/models/friend.dart';
import '../../../domain/models/me.dart';
import '../../../domain/models/sent_tape.dart';
import '../../../domain/models/shelf.dart';
import '../../../domain/models/tape_item.dart';
import '../../../domain/models/tape_type.dart';
import '../../../domain/models/user.dart';
import '../../../domain/models/wallet.dart';
import '../../../utils/format.dart';
import '../../../utils/result.dart';
import '../../core/themes/tape_palette.dart';
import '../../core/ui/toast.dart';

/// 설정 > 정보의 문서
enum AppDoc { terms, privacy, contact }

/// 마이 하위 화면 (`myPage`) — 마이 홈 아이콘 4개 (`myMenu`)
enum MyPage {
  recv('받은 테이프'),
  sent('보낸 테이프'),
  friends('친구'),
  settings('설정');

  const MyPage(this.title);

  /// `mpTitle`
  final String title;

  static MyPage? parse(String? name) =>
      values.where((p) => p.name == name).firstOrNull;
}

/// 받은 테이프 행 (`recvList`) — 서랍의 분류 안 함 + 모든 칸
class ReceivedTape {
  const ReceivedTape({required this.item, required this.where});

  final TapeItem item;

  /// 칸 이름, 분류 안 함이면 `분류 안 함`
  final String where;

  /// 아직 안 뜯은 소포 (`boxed`, `isNew`) — 분류 안 함에만 있다
  bool get boxed => item.groupId == null && !item.opened;
}

/// 보낸 테이프 상태 3종 (`sentSt(r)`)
enum SentKind { link, heard, sealed }

/// 마이 탭 ViewModel — logic.js의 마이·친구 시트·보낸 테이프·설정 부분.
class MyViewModel extends ChangeNotifier {
  MyViewModel({
    required UserRepository userRepository,
    required FriendRepository friendRepository,
    required WalletRepository walletRepository,
    required DeliveryRepository deliveryRepository,
    required AuthRepository authRepository,
    required ShelfRepository shelfRepository,
    required this._share,
    required this._links,
    required this._appInfo,
    required this._toast,
  }) : _users = userRepository,
       _friendsRepo = friendRepository,
       _walletRepo = walletRepository,
       _deliveries = deliveryRepository,
       _auth = authRepository,
       _shelf = shelfRepository {
    _users.addListener(_loadMe);
    _shelf.addListener(_onShelfChanged);
    _friendsRepo.addListener(_onFriendsChanged);
    _walletRepo.addListener(_loadWallet);
  }

  static const skeletonTime = Duration(milliseconds: 650);

  final UserRepository _users;
  final FriendRepository _friendsRepo;
  final WalletRepository _walletRepo;
  final DeliveryRepository _deliveries;
  final AuthRepository _auth;
  final ShelfRepository _shelf;
  final ShareService _share;
  final LinkService _links;
  final AppInfoService _appInfo;
  final ToastController _toast;

  Me? _me;
  Wallet _wallet = const Wallet(credits: 0, owned: {}, adsLeft: 0);
  List<Friend> _friends = const [];
  List<SentTape> _sent = const [];
  String? _sentCursor;
  bool _loadingSent = false;
  List<BlockedUser> _blocked = const [];
  List<ReceivedTape>? _received;
  String _version = '';
  bool _editing = false;
  String _draft = '';
  bool _seen = false;
  bool _skeleton = false;
  Timer? _skelTimer;

  String get name => _me?.name ?? '';
  bool get editingName => _editing;
  String get nameDraft => _draft;
  int get credits => _wallet.credits;
  int get receivedCount => _me?.receivedCount ?? 0;
  int get sentCount => _me?.sentCount ?? 0;
  int get friendCount => _me?.friendCount ?? _friends.length;
  bool get notificationsOn => _me?.notificationsEnabled ?? true;
  String get version => _version;
  bool get skeleton => _skeleton;
  List<SentTape> get sent => _sent;
  bool get hasMoreSent => _sentCursor != null;
  List<BlockedUser> get blocked => _blocked;
  int ownedOf(TapeType t) => _wallet.ownedOf(t);

  /// 받은 테이프 — 날짜 최근 순 (`recvList`)
  List<ReceivedTape> get received => _received ?? const [];

  /// 받은 테이프 수 (`recvCount`) — 서랍을 불러왔으면 그 수, 아니면 통계
  int get receivedTotal => _received?.length ?? receivedCount;

  /// 받은 테이프 아이콘의 레드 점 (`m.dot`) — 안 뜯은 소포가 있으면
  bool get hasNewReceived => received.any((x) => x.boxed);

  /// 아이콘 아래 수 (`myMenu[].n`)
  String menuCount(MyPage p) => switch (p) {
    MyPage.recv => '$receivedTotal개',
    MyPage.sent => '$sentCount개',
    MyPage.friends => '$friendCount명',
    MyPage.settings => '',
  };

  /// 하위 화면 부제 (`mpSub`)
  String pageSubtitle(MyPage p) => switch (p) {
    MyPage.recv => '$receivedTotal개 · 서랍에 모인 목소리예요',
    MyPage.sent => '$sentCount개 · 받은 사람만 들을 수 있어요',
    MyPage.friends => '$friendCount명 · 별명은 나에게만 보여요',
    MyPage.settings => '',
  };

  /// 받은 테이프 행 부제 (`x.sub`) — `칸 · 15초(· 소포 도착)`
  static String receivedSub(ReceivedTape x) =>
      '${x.where} · ${x.item.type.label}${x.boxed ? ' · 소포 도착' : ''}';

  /// 이름 도움말 (`nameHelp`) — 고치는 중이면 글자 수
  String get nameHelp => _editing
      ? '테이프에 적히는 이름이에요 · ${_draft.characters.length}/${User.maxNameLength}'
      : '테이프에 적히는 이름이에요';

  /// 즐겨찾기 먼저 (`myFriends`)
  List<Friend> get friends => [
    ..._friends.where((f) => f.starred),
    ..._friends.where((f) => !f.starred),
  ];

  /// 연결된 계정 (`provider`) — `kakao` · `apple` · `google` · `dev`
  String get providerText {
    const label = {
      'kakao': '카카오',
      'apple': 'Apple',
      'google': 'Google',
      'dev': '개발',
    };
    final p = _me?.providers ?? const [];
    return p.map((x) => label[x] ?? x).join(' · ');
  }

  /// 차단한 친구 행 오른쪽 (`blockedCount`)
  String get blockedCountText =>
      _blocked.isEmpty ? '없음' : '${_blocked.length}명';

  /// 보낸 테이프 상태 종류 (`sentSt(r).stKind`): 링크 대기 → 열어 봄 → 안 열어 봄.
  /// 링크 만료(디자인에 없는 서버 상태)는 다시 공유가 필요한 링크라 링크 대기와 같은 강조.
  static SentKind sentKind(SentTape s) => switch (s.status) {
    SentStatus.linkPending || SentStatus.linkExpired => SentKind.link,
    SentStatus.opened => SentKind.heard,
    SentStatus.unopened => SentKind.sealed,
  };

  /// 보낸 테이프 목록 상태 (`sentSt(r).status`, v10.1) — 연 날짜는 목록에 넣지 않는다(사생활)
  static String sentStatus(SentTape s) => switch (s.status) {
    SentStatus.linkPending => '링크 대기',
    SentStatus.linkExpired => '링크 만료',
    SentStatus.unopened => '안 열어 봄',
    SentStatus.opened => '열어 봄',
  };

  /// 목록 2줄 뒷부분 `· 09.22 · 1분`
  static String sentMeta(SentTape s) =>
      '· ${formatMonthDay(s.date)} · ${TapePalette.of(s.type).name}';

  /// 상세 시트 제목 아래 (`sdStShort`) `열어 봄 · 1분`
  static String sentShort(SentTape s) =>
      '${sentStatus(s)} · ${TapePalette.of(s.type).name}';

  /// 보낸 테이프 상세 상태 (`sdStatus`) — 날짜는 여기에만 "MM.DD에 열어 봤어요"
  static String sentDetailStatus(SentTape s) => switch (s.status) {
    SentStatus.linkPending => '아직 아무도 받지 않았어요',
    SentStatus.linkExpired => '링크가 만료됐어요',
    SentStatus.unopened => '아직 안 열어 봤어요',
    SentStatus.opened =>
      s.openedAt == null ? '열어 봤어요' : '${formatMonthDay(s.openedAt!)}에 열어 봤어요',
  };

  /// 링크 다시 공유하기 버튼 (`sdLink`) — 아직 아무도 받지 않은 링크
  static bool canReshare(SentTape s) =>
      s.status == SentStatus.linkPending || s.status == SentStatus.linkExpired;

  // ── 불러오기 ─────────────────────────────────────
  Future<void> load() async {
    await Future.wait([
      _loadMe(),
      _loadWallet(),
      _loadFriends(),
      _loadSent(),
      _loadBlocked(),
      _loadVersion(),
      _loadReceived(),
    ]);
  }

  /// 서랍이 바뀌면 받은 테이프 목록과 통계(`Me.stats`·`drawer`)를 함께 다시 불러온다.
  Future<void> _onShelfChanged() async {
    await Future.wait([_loadReceived(), _loadMe()]);
  }

  /// 받은 테이프 — `GET /shelf`의 분류 안 함 + 모든 칸을 날짜 최근 순으로
  Future<void> _loadReceived() async {
    final r = await _shelf.getShelf();
    if (r is! Ok<Shelf>) return;
    final s = r.value;
    final list = [
      for (final x in s.unsorted) ReceivedTape(item: x, where: '분류 안 함'),
      for (final g in s.groups)
        for (final x in g.items) ReceivedTape(item: x, where: g.name),
    ];
    // 같은 날짜면 원래 순서 (안정 정렬)
    final indexed = list.indexed.toList()
      ..sort((a, b) {
        final c = b.$2.item.date.compareTo(a.$2.item.date);
        return c != 0 ? c : a.$1.compareTo(b.$1);
      });
    _received = [for (final (_, x) in indexed) x];
    notifyListeners();
  }

  Future<void> _loadMe() async {
    final r = await _users.getMe();
    if (r is Ok<Me>) {
      _me = r.value;
      notifyListeners();
    }
  }

  Future<void> _loadWallet() async {
    final r = await _walletRepo.getWallet();
    if (r is Ok<Wallet>) {
      _wallet = r.value;
      notifyListeners();
    }
  }

  Future<void> _loadFriends() async {
    final r = await _friendsRepo.getFriends();
    if (r is Ok<List<Friend>>) {
      _friends = r.value;
      notifyListeners();
    }
    // 보내기로 친구·보낸 기록·통계가 바뀌었을 수 있다.
    await Future.wait([_loadSent(), _loadMe()]);
  }

  /// 처음부터 다시 (보내기·다시 공유 뒤)
  Future<void> _loadSent() async {
    final r = await _deliveries.getSent();
    if (r is Ok<SentPage>) {
      _sent = r.value.items;
      _sentCursor = r.value.nextCursor;
      notifyListeners();
    }
  }

  /// 보낸 테이프 다음 페이지 (`nextCursor`). 마지막이면 아무것도 안 한다.
  Future<void> loadMoreSent() async {
    final cursor = _sentCursor;
    if (cursor == null || _loadingSent) return;
    _loadingSent = true;
    final r = await _deliveries.getSent(cursor: cursor);
    _loadingSent = false;
    if (r is Ok<SentPage>) {
      _sent = [..._sent, ...r.value.items];
      _sentCursor = r.value.nextCursor;
      notifyListeners();
    }
  }

  /// 친구가 바뀌면(차단·신고하고 차단 포함) 친구와 차단 목록을 함께 다시 불러온다.
  Future<void> _onFriendsChanged() async {
    // 별명이 바뀌면 보낸 테이프 이름도 바뀐다
    await Future.wait([_loadFriends(), _loadBlocked(), _loadSent()]);
  }

  /// 별명 저장 (`saveAlias`) — 비우면 원래 이름으로
  Future<void> setNickname(Friend f, String value) async {
    final r = await _friendsRepo.setNickname(f.id, value);
    switch (r) {
      case Ok():
        _toast.show(value.isEmpty ? '원래 이름으로 보여요' : '별명을 저장했어요');
      case Error(:final error):
        _toast.show(
          error is ApiException ? error.message : '잠시 문제가 생겼어요. 다시 시도해 주세요',
        );
    }
  }

  Future<void> _loadBlocked() async {
    final r = await _friendsRepo.getBlocked();
    if (r is Ok<List<BlockedUser>>) {
      _blocked = r.value;
      notifyListeners();
    }
  }

  Future<void> _loadVersion() async {
    try {
      _version = await _appInfo.version();
      notifyListeners();
    } catch (_) {}
  }

  /// 처음 들어올 때 0.65초 스켈레톤. 화면 initState에서 부르므로 알리지 않는다.
  void enter() {
    if (_seen) return;
    _seen = true;
    _skeleton = true;
    _skelTimer = Timer(skeletonTime, () {
      _skeleton = false;
      notifyListeners();
    });
  }

  // ── 이름 (`editName`, `doneName`) ──────────────────────
  void startEditName() {
    _editing = true;
    _draft = name;
    notifyListeners();
  }

  void setNameDraft(String v) {
    _draft = v.characters.take(User.maxNameLength).toString();
    notifyListeners();
  }

  /// 이름 저장 (`doneName`, 저장 · Enter). 비어 있으면 알리고 고치는 중으로 남는다.
  Future<void> commitName() async {
    if (!_editing) return;
    final next = _draft.trim();
    if (next.isEmpty) {
      _toast.show('이름을 적어 주세요');
      return;
    }
    _editing = false;
    notifyListeners();
    if (next == name) return;
    final prev = _me;
    final r = await _users.updateName(next);
    switch (r) {
      case Ok<Me>(:final value):
        _me = value;
        _toast.show('이름을 저장했어요');
      case Error<Me>(:final error):
        _me = prev;
        _toast.show(_message(error));
    }
    notifyListeners();
  }

  /// 고치기 취소 (`cancelName`, 취소 · Esc) — 원래 이름으로
  void cancelEditName() {
    if (!_editing) return;
    _editing = false;
    _draft = name;
    notifyListeners();
  }

  // ── 친구 ──────────────────────────────────────────
  Future<void> toggleStar(Friend f) async {
    final prev = _friends;
    _friends = [
      for (final x in _friends)
        x.id == f.id ? x.copyWith(starred: !x.starred) : x,
    ];
    notifyListeners();
    final r = await _friendsRepo.setStarred(f.id, !f.starred);
    if (r is Error) {
      _friends = prev;
      notifyListeners();
    }
  }

  /// 친구 삭제 (`friendDel`)
  Future<void> removeFriend(Friend f) async {
    final r = await _friendsRepo.remove(f.id);
    if (r case Error(:final error)) {
      _toast.show(_message(error));
      return;
    }
    _toast.show('${f.name}님을 목록에서 뺐어요');
  }

  /// 차단하기 (`doBlock`)
  Future<void> block(Friend f) async {
    final r = await _friendsRepo.block(f.id);
    if (r case Error(:final error)) {
      _toast.show(_message(error));
      return;
    }
    _toast.show('${f.name}님을 차단했어요');
    await _loadBlocked();
  }

  /// 해제 (`onUnblock`)
  Future<void> unblock(BlockedUser b) async {
    final r = await _friendsRepo.unblock(b.id);
    if (r case Error(:final error)) {
      _toast.show(_message(error));
      return;
    }
    _toast.show('${b.name}님 차단을 풀었어요');
    await _loadBlocked();
  }

  // ── 보낸 테이프 ────────────────────────────────────
  /// 링크 다시 공유하기 (`sdShare`) — `POST /deliveries/sent/{id}/share` 뒤 공유 시트.
  /// 보낸 테이프 하나 — "테이프를 받았어요" 푸시를 눌렀을 때 상세를 연다.
  Future<SentTape?> sentById(String id) async {
    final r = await _deliveries.getSentOne(id);
    return r is Ok<SentTape> ? r.value : null;
  }

  Future<void> reshare(SentTape s) async {
    final r = await _deliveries.reshare(s.id);
    switch (r) {
      case Ok<Uri>(:final value):
        await _share.shareText('$name님이 목소리 테이프를 보냈어요 $value');
        await _loadSent();
      case Error<Uri>(:final error):
        _toast.show(_message(error));
        await _loadSent();
    }
  }

  // ── 설정 ──────────────────────────────────────────
  Future<void> toggleNotifications() async {
    final next = !notificationsOn;
    final r = await _users.setNotifications(next);
    if (r case Ok<Me>(:final value)) {
      _me = value;
      notifyListeners();
    }
  }

  Future<void> openDoc(AppDoc doc) => _links.open(switch (doc) {
    AppDoc.terms => AppLinks.terms,
    AppDoc.privacy => AppLinks.privacy,
    AppDoc.contact => AppLinks.contact,
  });

  /// 로그아웃. 로그인 화면(4단계)이 생기기 전까지는 앱 첫 화면으로 돌아간다.
  Future<void> logout() => _auth.logout();

  /// 회원 탈퇴 (`wdGo`) — 성공하면 true.
  Future<bool> withdraw() async {
    final r = await _users.withdraw();
    switch (r) {
      case Ok():
        _toast.show('탈퇴했어요. 그동안 고마웠어요');
        await _auth.signedOutByServer();
        _friendsRepo.invalidate();
        _walletRepo.invalidate();
        return true;
      case Error(:final error):
        _toast.show(_message(error));
        return false;
    }
  }

  static String _message(Exception e) =>
      e is ApiException ? e.message : '잠시 문제가 생겼어요. 다시 시도해 주세요';

  @override
  void dispose() {
    _skelTimer?.cancel();
    _users.removeListener(_loadMe);
    _shelf.removeListener(_onShelfChanged);
    _friendsRepo.removeListener(_onFriendsChanged);
    _walletRepo.removeListener(_loadWallet);
    super.dispose();
  }
}
