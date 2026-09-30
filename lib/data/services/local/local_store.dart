import '../../model/delivery_dto.dart';
import '../../model/friend_dto.dart';
import '../../model/shelf_dto.dart';
import '../../model/wallet_dto.dart';

/// 서버 없이 앱을 돌리기 위한 메모리 저장소. [LocalApiClient]가 서버처럼 읽고 쓴다.
///
/// 초기값은 프로토타입 `state = {…}`(source/TapeletterApp.logic.js)와 같다.
/// 날짜는 프로토타입의 `MM.DD`에 2026년을 붙이고, 시간대와 상관없이 같은 날로 보이게
/// UTC 정오로 둔다. 재생 길이는 프로토타입 `DUR`(15초 20s · 1분 34s · 3분 48s, 옛 1·3·5분 자리)과 같다.
class LocalStore {
  /// [newUser]면 처음 로그인이 가입이 되고 이름이 비어 있다(이름 정하기 화면).
  LocalStore({DateTime Function()? clock, this.newUser = false})
    : now = clock ?? DateTime.now {
    reset();
  }

  final bool newUser;

  final DateTime Function() now;

  /// 프로토타입 `DUR`과 번들 샘플 파일 길이
  static const durationMs = {15: 20000, 60: 34000, 180: 48000};

  static const meId = 'u-me';

  late String? name;
  late int credits;
  late int cap;
  late bool notificationsEnabled;
  late Map<int, int> owned;
  late int adsRemaining;
  late List<LedgerEntryDto> ledger;
  late List<FriendDto> friends;
  late List<ShelfItemDto> unsorted;
  late List<LocalGroup> groups;
  late List<SentTapeDto> sent;

  /// 차단한 사람 (최근이 앞). 친구였다면 [LocalBlock.friend]에 즐겨찾기·lastAt을 남겨 둔다.
  late List<LocalBlock> blocked;
  final Map<String, LocalRecording> recordings = {};

  /// presigned URL → 올린 파일 경로
  final Map<String, String> uploads = {};

  /// Idempotency-Key → 첫 응답
  final Map<String, Object> idempotency = {};

  // 인증 (서버 테이블 `refresh_tokens` 등)
  bool signedUp = false;
  final Set<String> accessTokens = {};
  final Set<String> refreshTokens = {};

  /// 등록된 FCM 기기 토큰
  final Map<String, String> devices = {};

  /// 링크 토큰 → 내가 받은 테이프 id
  final Map<String, String> claimedLinks = {};

  /// 다른 사람이 받은 링크 / 만료된 링크 (시험에서 소포를 연 뒤에 바꿔 본다)
  final Set<String> takenLinks = {};
  final Set<String> expiredLinks = {};

  int _uid = 100;

  String nextId(String prefix) => '$prefix-${_uid++}';

  /// 프로토타입 초기 상태로 되돌린다.
  void reset() {
    _uid = 100;
    recordings.clear();
    uploads.clear();
    idempotency.clear();
    accessTokens.clear();
    refreshTokens.clear();
    devices.clear();
    claimedLinks.clear();
    takenLinks.clear();
    expiredLinks.clear();
    signedUp = !newUser;
    blocked = [];
    name = newUser ? null : '민경';
    credits = 120;
    cap = 12;
    notificationsEnabled = true;
    owned = {60: 2, 180: 0};
    adsRemaining = 3;
    ledger = [
      _ledger(9, 24, 10, '광고 보상', 'ad_reward'),
      _ledger(9, 20, -30, '1분 테이프 구매', 'tape_purchase'),
      _ledger(9, 18, 100, '크레딧 충전 · ₩1,100', 'iap'),
      _ledger(9, 12, 30, '지현님이 선물', 'gift_received'),
      _ledger(9, 1, 10, '가입 선물', 'signup_gift'),
    ];
    friends = [
      FriendDto(
        userId: 'u-jihyun',
        name: '지현',
        starred: true,
        lastAt: d(9, 24),
      ),
      FriendDto(userId: 'u-mom', name: '엄마', starred: true, lastAt: d(9, 10)),
      FriendDto(
        userId: 'u-minsu',
        name: '민수',
        starred: false,
        lastAt: d(8, 30),
      ),
      FriendDto(
        userId: 'u-haneul',
        name: '하늘',
        starred: false,
        lastAt: d(9, 23),
      ),
      FriendDto(
        userId: 'u-park',
        name: '박과장님',
        starred: false,
        lastAt: d(6, 2),
      ),
      FriendDto(userId: 'u-eunbi', name: '은비', starred: false, lastAt: d(6, 3)),
    ];
    unsorted = [
      _it('u-jihyun', '지현', 9, 24, 60, at: (12, 20), opened: false),
      _it(
        'u-haneul',
        '하늘',
        9,
        23,
        15,
        at: (19, 43),
        tag: 'thinking',
        opened: false,
        viaLink: true,
      ),
    ];
    groups = [
      LocalGroup('g-1', '2026 생일', [
        _it('u-mom', '엄마', 3, 14, 180, at: (2, 6)),
        _it('u-minsu', '민수', 3, 14, 15, at: (9, 29)),
        _it('u-sua', '수아', 3, 15, 60, at: (16, 52)),
        _it('u-grandma', '할머니', 3, 14, 15, at: (23, 15)),
      ]),
      LocalGroup('g-2', '승진 축하', [
        _it('u-park', '박과장님', 6, 2, 60, at: (6, 38), tag: 'congrats'),
        _it('u-eunbi', '은비', 6, 3, 15, at: (13, 1), tag: 'congrats'),
      ]),
      LocalGroup('g-3', '엄마 목소리', [
        _it('u-mom', '엄마', 1, 1, 180, at: (20, 24), tag: 'thinking'),
        _it('u-mom', '엄마', 5, 8, 60, at: (3, 47), tag: 'thinking'),
      ]),
    ];
    for (final g in groups) {
      g.items = [for (final x in g.items) x.copyWith(groupId: () => g.id)];
    }
    sent = [
      SentTapeDto(
        id: 's-1',
        linkName: '유진',
        tapeType: 15,
        durationMs: durationMs[15]!,
        tag: 'thinking',
        sentAt: d(9, 22),
        status: 'link_pending',
        share: ShareLinkDto(
          url: 'https://tapeletter.lab241.com/t/demo-yujin',
          expiresAt: d(9, 29),
        ),
      ),
      SentTapeDto(
        id: 's-2',
        recipient: const UserRefDto(userId: 'u-mom', name: '엄마'),
        tapeType: 60,
        durationMs: durationMs[60]!,
        tag: 'thinking',
        sentAt: d(9, 10),
        status: 'opened',
        claimedAt: d(9, 10),
        openedAt: d(9, 11),
      ),
      SentTapeDto(
        id: 's-3',
        recipient: const UserRefDto(userId: 'u-minsu', name: '민수'),
        tapeType: 15,
        durationMs: durationMs[15]!,
        tag: 'birthday',
        sentAt: d(8, 30),
        status: 'unopened',
        claimedAt: d(8, 30),
      ),
      SentTapeDto(
        id: 's-4',
        recipient: const UserRefDto(userId: 'u-park', name: '박과장님'),
        tapeType: 15,
        durationMs: durationMs[15]!,
        tag: 'congrats',
        sentAt: d(6, 1),
        status: 'opened',
        claimedAt: d(6, 1),
        openedAt: d(6, 2),
      ),
    ];
  }

  /// 2026-MM-DD (UTC 정오)
  static DateTime d(int m, int day) => DateTime.utc(2026, m, day, 12);

  /// 받은 테이프 시각 — 기기 시간대의 [h]:[min] (프로토타입 `it()`의 `time`과 같은 값)
  static DateTime dt(int m, int day, int h, int min) =>
      DateTime(2026, m, day, h, min).toUtc();

  LedgerEntryDto _ledger(
    int m,
    int day,
    int delta,
    String reason,
    String kind,
  ) => LedgerEntryDto(
    id: nextId('l'),
    delta: delta,
    reason: reason,
    kind: kind,
    createdAt: d(m, day),
  );

  ShelfItemDto _it(
    String senderId,
    String from,
    int m,
    int day,
    int type, {
    String tag = 'birthday',
    bool opened = true,
    bool viaLink = false,
    required (int, int) at,
  }) => ShelfItemDto(
    id: nextId('t'),
    sender: UserRefDto(userId: senderId, name: from),
    tapeType: type,
    durationMs: durationMs[type]!,
    tag: tag,
    sentAt: dt(m, day, at.$1, at.$2),
    opened: opened,
    openedAt: opened ? dt(m, day, at.$1, at.$2) : null,
    viaLink: viaLink,
  );
}

/// 칸 (서버 테이블 `shelf_groups` + 순서)
class LocalGroup {
  LocalGroup(this.id, this.name, this.items);

  final String id;
  String name;
  List<ShelfItemDto> items;
}

/// 올린 녹음 (서버 테이블 `recordings`)
class LocalRecording {
  LocalRecording({
    required this.id,
    required this.tapeType,
    required this.durationMs,
    required this.uploadUrl,
  });

  final String id;
  final int tapeType;
  int durationMs;
  final String uploadUrl;

  /// `uploading | processing | ready | failed`
  String status = 'uploading';

  /// 변환이 끝나는 시각
  DateTime? readyAt;
  bool willFail = false;
  bool sent = false;
}

/// 차단 기록 (서버 테이블 `blocks`)
class LocalBlock {
  LocalBlock({
    required this.userId,
    required this.name,
    required this.at,
    this.friend,
  });

  final String userId;
  final String name;
  final DateTime at;

  /// 차단 전 친구 관계 (해제하면 그대로 돌아온다)
  final FriendDto? friend;
}
