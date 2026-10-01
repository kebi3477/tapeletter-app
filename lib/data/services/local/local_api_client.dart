import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';

import '../../model/api_error.dart';
import '../../model/json.dart';
import '../../model/auth_dto.dart';
import '../../model/delivery_dto.dart';
import '../../model/friend_dto.dart';
import '../../model/me_dto.dart';
import '../../model/page_dto.dart';
import '../../model/recording_dto.dart';
import '../../model/report_dto.dart';
import '../../model/shop_dto.dart';
import '../../model/shelf_dto.dart';
import '../../model/wallet_dto.dart';
import '../api/api_client.dart';
import 'local_behavior.dart';
import 'local_store.dart';

/// 계약서(`tapeletter-api/docs/api.md`) 모양 그대로 응답하는 메모리 서버.
///
/// 다음 단계에서 HTTP 구현으로 바꿔 끼운다. 서버 규칙(보유 차감, 정렬, 오류 코드)도 흉내 낸다.
class LocalApiClient implements ApiClient {
  LocalApiClient(this._s, [this._b = const LocalBehavior()]);

  final LocalStore _s;
  final LocalBehavior _b;

  /// 번들 샘플 (tapeType별 길이 = 프로토타입 `DUR`)
  static String sampleAudio(int tapeType) =>
      'asset:///assets/audio/sample_${LocalStore.durationMs[tapeType]! ~/ 1000}s.m4a';

  /// 공개 API 응답 시간
  Future<void> _waitPublic([Duration? d]) async {
    final wait = d ?? _b.latency;
    // 지연이 없으면 타이머를 만들지 않는다 (fake_async 시험에서 마이크로태스크로 끝나게).
    if (wait > Duration.zero) await Future<void>.delayed(wait);
  }

  /// 보호된 API: 응답 시간 + 서버 오류 흉내 + access token 확인
  Future<void> _wait([Duration? d]) async {
    await _waitPublic(d);
    if (_b.serverDown) {
      _fail(500, ApiErrorCode.internalError, '잠시 문제가 생겼어요. 다시 시도해 주세요');
    }
    if (_b.requireAuth && !_s.accessTokens.contains(accessToken)) {
      _fail(401, ApiErrorCode.unauthorized, '다시 로그인해 주세요');
    }
  }

  @override
  String? accessToken;

  // ── 공개 ──────────────────────────────────────────
  @override
  Future<void> health() async {
    await _waitPublic();
    if (_b.serverDown) {
      _fail(500, ApiErrorCode.internalError, '잠시 문제가 생겼어요. 다시 시도해 주세요');
    }
  }

  /// 최소 버전 1.0.0. `FAIL_MODE=forceUpdate`면 업데이트가 필요하다고 답한다.
  @override
  Future<AppVersionDto> getAppVersion({
    required String platform,
    String? version,
  }) async {
    await _waitPublic();
    final force = _b.forcesUpdate;
    return AppVersionDto(
      platform: platform,
      minVersion: force ? '99.0.0' : '1.0.0',
      latestVersion: force ? '99.0.0' : '1.0.0',
      storeUrl: platform == 'ios'
          ? 'https://apps.apple.com/app/id0000000000'
          : 'https://play.google.com/store/apps/details?id=com.kebi.tapeletter',
      updateRequired: version == null ? null : force,
      updateAvailable: version == null ? null : force,
    );
  }

  int _tokenN = 0;

  TokenPairDto _issue() {
    final n = _tokenN++;
    final access = 'local-access-$n';
    final refresh = 'local-refresh-$n';
    _s.accessTokens.add(access);
    _s.refreshTokens.add(refresh);
    final now = _s.now();
    return TokenPairDto(
      accessToken: access,
      accessTokenExpiresAt: now.add(const Duration(hours: 1)),
      refreshToken: refresh,
      refreshTokenExpiresAt: now.add(const Duration(days: 60)),
    );
  }

  AuthResponseDto _signIn({
    String? suggestedName,
    String? devName,
    bool social = true,
  }) {
    final isNew = !_s.signedUp;
    // 탈퇴 후 30일 동안은 같은 계정으로 다시 가입할 수 없다 (`FAIL_MODE=rejoinRestricted`)
    if (social && _b.failMode == FailMode.rejoinRestricted) {
      _fail(403, ApiErrorCode.rejoinRestricted, '탈퇴 후 30일 동안은 다시 가입할 수 없어요', {
        'availableAt': _s
            .now()
            .add(const Duration(days: 30))
            .toUtc()
            .toIso8601String(),
      });
    }
    _s.signedUp = true;
    if (isNew && devName != null) _s.name = devName;
    if (isNew) {
      _s.ledger = [
        LedgerEntryDto(
          id: _s.nextId('l'),
          delta: 10,
          reason: '가입 선물',
          kind: 'signup_gift',
          createdAt: _s.now(),
        ),
        ..._s.ledger,
      ];
    }
    return AuthResponseDto(
      tokens: _issue(),
      isNewUser: isNew,
      suggestedName: suggestedName,
      user: _me(),
    );
  }

  /// 카카오 토큰은 확인하지 않는다 (메모리 서버). 닉네임 대신 '민경'을 제안한다.
  @override
  Future<AuthResponseDto> authKakao(String kakaoAccessToken) async {
    await _waitPublic();
    if (kakaoAccessToken.isEmpty) {
      _fail(401, ApiErrorCode.socialTokenInvalid, '로그인하지 못했어요. 다시 시도해 주세요');
    }
    return _signIn(suggestedName: '민경');
  }

  @override
  Future<AuthResponseDto> authApple(AppleAuthRequest body) async {
    await _waitPublic();
    if (body.identityToken.isEmpty) {
      _fail(401, ApiErrorCode.socialTokenInvalid, '로그인하지 못했어요. 다시 시도해 주세요');
    }
    return _signIn();
  }

  @override
  Future<AuthResponseDto> authGoogle(String idToken) async {
    await _waitPublic();
    if (idToken.isEmpty) {
      _fail(401, ApiErrorCode.socialTokenInvalid, '로그인하지 못했어요. 다시 시도해 주세요');
    }
    return _signIn();
  }

  @override
  Future<AuthResponseDto> authDev({required String key, String? name}) async {
    await _waitPublic();
    return _signIn(devName: name, suggestedName: name, social: false);
  }

  @override
  Future<TokenPairDto> refreshTokens(String refreshToken) async {
    await _waitPublic();
    if (!_s.refreshTokens.remove(refreshToken)) {
      _fail(401, ApiErrorCode.invalidRefreshToken, '다시 로그인해 주세요');
    }
    return _issue();
  }

  @override
  Future<void> logout(String refreshToken) async {
    await _waitPublic();
    _s.refreshTokens.remove(refreshToken);
  }

  /// 시험용: 이미 로그인한 기기처럼 토큰을 발급한다.
  @visibleForTesting
  TokenPairDto issueTokensForTest() => _issue();

  /// 시험용: access token을 모두 만료시킨다 (다음 요청이 401).
  void expireAccessTokens() => _s.accessTokens.clear();

  // ── notifications ─────────────────────────────────
  @override
  Future<void> registerDevice({
    required String token,
    required String platform,
  }) async {
    await _wait();
    _s.devices[token] = platform;
  }

  @override
  Future<void> unregisterDevice(String token) async {
    await _wait();
    _s.devices.remove(token);
  }

  // ── share ─────────────────────────────────────────
  /// 링크를 보낸 새 친구 (메모리 서버의 모든 받을 수 있는 링크)
  static const linkSender = UserRefDto(userId: 'u-yujin2', name: '유진');

  void _checkLink(String token) {
    switch (_b.failMode) {
      case FailMode.linkTaken:
        _fail(409, ApiErrorCode.linkTaken, '이미 다른 분이 받은 테이프예요');
      case FailMode.linkExpired:
        _fail(410, ApiErrorCode.linkExpired, '링크가 만료됐어요');
      case FailMode.linkOwn:
        _linkOwn(_s.sent.firstWhere((x) => x.share != null));
      default:
    }
    if (_s.takenLinks.contains(token)) {
      _fail(409, ApiErrorCode.linkTaken, '이미 다른 분이 받은 테이프예요');
    }
    if (_s.expiredLinks.contains(token)) {
      _fail(410, ApiErrorCode.linkExpired, '링크가 만료됐어요');
    }
    for (final t in _s.sent) {
      final url = t.share?.url;
      if (url != null && url.endsWith('/t/$token')) _linkOwn(t);
    }
  }

  Never _linkOwn(SentTapeDto t) => _fail(
    409,
    ApiErrorCode.linkOwn,
    '내가 보낸 테이프예요',
    {'deliveryId': t.id, 'url': t.share?.url},
  );

  @override
  Future<ShareInfoDto> getShare(String token) async {
    await _wait();
    _checkLink(token);
    final claimed = _s.claimedLinks[token];
    final now = _s.now();
    return ShareInfoDto(
      state: claimed == null ? 'available' : 'claimed',
      deliveryId: claimed,
      sender: linkSender,
      tapeType: 15,
      durationMs: LocalStore.durationMs[15]!,
      sentAt: now.subtract(const Duration(hours: 2)),
      expiresAt: now.add(const Duration(days: 7)),
    );
  }

  /// 받으면 "분류 안 함" 맨 위에 들어가고 서로 친구가 된다. 이미 받았으면 같은 결과.
  @override
  Future<ClaimResultDto> claimShare(
    String token, {
    required String idempotencyKey,
  }) async {
    await _wait();
    _checkLink(token);
    final existing = _s.claimedLinks[token];
    if (existing != null) {
      return ClaimResultDto(
        item: _find(existing).item,
        friend: _s.friends
            .where((f) => f.userId == linkSender.userId)
            .firstOrNull,
      );
    }
    final now = _s.now();
    final item = ShelfItemDto(
      id: _s.nextId('t'),
      sender: linkSender,
      tapeType: 15,
      durationMs: LocalStore.durationMs[15]!,
      tag: null,
      sentAt: now,
      opened: false,
      viaLink: true,
    );
    _s.unsorted = [item, ..._s.unsorted];
    _s.claimedLinks[token] = item.id;
    final friend = FriendDto(
      userId: linkSender.userId!,
      name: linkSender.name,
      starred: false,
      lastAt: now,
    );
    _s.friends = [
      friend,
      ..._s.friends.where((f) => f.userId != friend.userId),
    ];
    return ClaimResultDto(item: item, friend: friend);
  }

  Never _fail(
    int status,
    String code,
    String message, [
    Json extra = const {},
  ]) => throw ApiException(
    status: status,
    code: code,
    message: message,
    extra: extra,
  );

  /// 보관량 = 뜯은 테이프 수 (안 뜯은 소포는 세지 않는다)
  int _stored() =>
      _s.unsorted.where((x) => x.opened).length +
      _s.groups.fold<int>(0, (a, g) => a + g.items.length);

  /// 칸 하나의 한도
  static const groupCap = 10;

  // ── users ─────────────────────────────────────────
  MeDto _me() {
    final total =
        _s.unsorted.length +
        _s.groups.fold<int>(0, (a, g) => a + g.items.length);
    final stored = _stored();
    return MeDto(
      id: LocalStore.meId,
      name: _s.name,
      credits: _s.credits,
      drawer: DrawerDto(
        stored: stored,
        cap: _s.cap,
        full: stored >= _s.cap,
        unopenedCount: _s.unsorted.where((x) => !x.opened).length,
      ),
      tapes: [
        const TapeStockDto(tapeType: 15, qty: null),
        TapeStockDto(tapeType: 60, qty: _s.owned[60]),
        TapeStockDto(tapeType: 180, qty: _s.owned[180]),
      ],
      stats: StatsDto(
        receivedCount: total,
        sentCount: _s.sent.length,
        friendCount: _s.friends.length,
      ),
      providers: const ['kakao'],
      notificationsEnabled: _s.notificationsEnabled,
      createdAt: LocalStore.d(9, 1),
    );
  }

  @override
  Future<MeDto> getMe() async {
    await _wait();
    return _me();
  }

  @override
  Future<MeDto> patchMe(PatchMeRequest body) async {
    await _wait();
    final name = body.name?.trim();
    if (name != null) {
      if (name.isEmpty || name.runes.length > 8) {
        _fail(400, 'INVALID_NAME', '이름은 1~8자로 적어주세요');
      }
      _s.name = name;
    }
    if (body.notificationsEnabled != null) {
      _s.notificationsEnabled = body.notificationsEnabled!;
    }
    return _me();
  }

  /// 회원 탈퇴 — 메모리 서버는 프로토타입 초기 상태로 되돌린다.
  @override
  Future<void> deleteMe() async {
    await _wait();
    _s.reset();
    // 같은 계정으로 다시 로그인하면 새로 가입한다 (이름 정하기부터).
    _s.signedUp = false;
    _s.name = null;
  }

  // ── friends ───────────────────────────────────────
  /// 정렬: 즐겨찾기 먼저 → lastAt 최근 순(없으면 뒤)
  @override
  Future<PageDto<FriendDto>> getFriends() async {
    await _wait();
    final list = [..._s.friends]
      ..sort((a, b) {
        if (a.starred != b.starred) return a.starred ? -1 : 1;
        final la = a.lastAt, lb = b.lastAt;
        if (la == null && lb == null) return 0;
        if (la == null) return 1;
        if (lb == null) return -1;
        return lb.compareTo(la);
      });
    return PageDto(items: list);
  }

  FriendDto _friend(String userId) =>
      _s.friends.where((f) => f.userId == userId).firstOrNull ??
      _fail(404, ApiErrorCode.friendNotFound, '친구 목록에 없는 사람이에요');

  @override
  Future<FriendDto> patchFriend(String userId, {required bool starred}) async {
    await _wait();
    final f = _friend(userId).copyWith(starred: starred);
    _s.friends = [for (final x in _s.friends) x.userId == userId ? f : x];
    return f;
  }

  /// 별명 (최대 10자, 앞뒤 공백 제거, 비우면 지움)
  @override
  Future<FriendDto> setFriendNickname(String userId, String? nickname) async {
    await _wait();
    final v = nickname?.trim();
    if (v != null && v.characters.length > 10) {
      _fail(400, ApiErrorCode.invalidNickname, '별명은 10자까지 적을 수 있어요');
    }
    final f = _friend(userId)
        .copyWith(nickname: () => v == null || v.isEmpty ? null : v);
    _s.friends = [for (final x in _s.friends) x.userId == userId ? f : x];
    return f;
  }

  /// 보낸 사람에 내가 붙인 별명을 얹는다 (서버는 응답마다 채운다)
  ShelfItemDto _nick(ShelfItemDto x) {
    final id = x.sender.userId;
    final f = id == null
        ? null
        : _s.friends.where((f) => f.userId == id).firstOrNull;
    if (f == null || f.nickname == x.sender.nickname) return x;
    return x.copyWith(
      sender: UserRefDto(
        userId: x.sender.userId,
        name: x.sender.name,
        nickname: f.nickname,
      ),
    );
  }

  @override
  Future<FriendTapesDto> getFriendTapes(String userId) async {
    await _wait();
    final f = _friend(userId);
    final items = <ShelfItemDto>[];
    for (final g in _s.groups) {
      for (final x in g.items) {
        if (x.sender.userId == userId) {
          items.add(x.copyWith(groupName: () => g.name));
        }
      }
    }
    for (final x in _s.unsorted) {
      if (x.sender.userId == userId && x.opened) items.add(x);
    }
    return FriendTapesDto(
      friend: f,
      items: items,
      unopenedCount: _s.unsorted
          .where((x) => x.sender.userId == userId && !x.opened)
          .length,
    );
  }

  @override
  Future<void> deleteFriend(String userId) async {
    await _wait();
    _friend(userId);
    _s.friends = _s.friends.where((f) => f.userId != userId).toList();
  }

  /// 친구가 아니어도(링크로 받은 사람) 차단할 수 있다.
  @override
  Future<BlockedUserDto> blockUser(String userId) async {
    await _wait();
    if (userId == LocalStore.meId) {
      _fail(400, ApiErrorCode.cannotBlockSelf, '나는 차단할 수 없어요');
    }
    final existing = _s.blocked.where((b) => b.userId == userId).firstOrNull;
    if (existing != null) {
      return BlockedUserDto(
        userId: existing.userId,
        name: existing.name,
        blockedAt: existing.at,
      );
    }
    final friend = _s.friends.where((f) => f.userId == userId).firstOrNull;
    final name = friend?.name ?? _senderName(userId);
    if (name == null) _fail(404, ApiErrorCode.userNotFound, '찾을 수 없는 사용자예요');
    final b = LocalBlock(
      userId: userId,
      name: name,
      at: _s.now(),
      friend: friend,
    );
    _s.blocked = [b, ..._s.blocked];
    _s.friends = _s.friends.where((f) => f.userId != userId).toList();
    return BlockedUserDto(userId: b.userId, name: b.name, blockedAt: b.at);
  }

  String? _senderName(String userId) {
    for (final x in [..._s.unsorted, for (final g in _s.groups) ...g.items]) {
      if (x.sender.userId == userId) return x.sender.name;
    }
    return null;
  }

  @override
  Future<PageDto<BlockedUserDto>> getBlocks() async {
    await _wait();
    return PageDto(
      items: [
        for (final b in _s.blocked)
          BlockedUserDto(userId: b.userId, name: b.name, blockedAt: b.at),
      ],
    );
  }

  /// 차단 전에 친구였다면 즐겨찾기·lastAt까지 그대로 돌아온다.
  @override
  Future<void> unblockUser(String userId) async {
    await _wait();
    final b = _s.blocked.where((x) => x.userId == userId).firstOrNull;
    if (b == null) _fail(404, ApiErrorCode.blockNotFound, '차단한 친구가 아니에요');
    _s.blocked = _s.blocked.where((x) => x.userId != userId).toList();
    if (b.friend != null) _s.friends = [..._s.friends, b.friend!];
  }

  // ── recordings ────────────────────────────────────
  @override
  Future<RecordingUploadDto> createRecording(
    CreateRecordingRequest body,
  ) async {
    await _wait();
    // 종류 코드가 곧 한도(초)다
    if (body.durationMs > body.tapeType * 1000 + 1000) {
      _fail(400, ApiErrorCode.recordingTooLong, '테이프 길이를 넘었어요');
    }
    final id = _s.nextId('r');
    final url = 'local://uploads/$id.m4a';
    _s.recordings[id] = LocalRecording(
      id: id,
      tapeType: body.tapeType,
      durationMs: body.durationMs,
      uploadUrl: url,
    );
    return RecordingUploadDto(
      recording: RecordingDto(
        id: id,
        tapeType: body.tapeType,
        durationMs: body.durationMs,
        status: 'uploading',
      ),
      upload: UploadTicketDto(
        url: url,
        method: 'PUT',
        headers: {'Content-Type': body.contentType},
        expiresAt: _s.now().add(const Duration(minutes: 15)),
      ),
    );
  }

  LocalRecording _rec(String id) =>
      _s.recordings[id] ??
      _fail(404, ApiErrorCode.recordingNotFound, '녹음을 찾을 수 없어요');

  void _startProcessing(LocalRecording r) {
    r.status = 'processing';
    r.willFail = _b.failsConvert;
    r.readyAt = _s.now().add(
      _b.failsConvert
          ? _b.convertFailDelay
          : _b.slowConvert
          ? _b.convertSlowDelay
          : _b.convertDelay,
    );
  }

  RecordingDto _recDto(LocalRecording r) {
    if (r.status == 'processing' && !_s.now().isBefore(r.readyAt!)) {
      r.status = r.willFail ? 'failed' : 'ready';
    }
    final path = _s.uploads[r.uploadUrl];
    return RecordingDto(
      id: r.id,
      tapeType: r.tapeType,
      durationMs: r.durationMs,
      status: r.status,
      preview: r.status == 'ready' && !r.sent && path != null
          ? PreviewDto(
              url: path,
              expiresAt: _s.now().add(const Duration(minutes: 10)),
            )
          : null,
    );
  }

  @override
  Future<RecordingDto> completeRecording(String id) async {
    await _wait();
    final r = _rec(id);
    if (!_s.uploads.containsKey(r.uploadUrl)) {
      _fail(409, ApiErrorCode.uploadNotFound, '녹음 파일을 올리지 못했어요. 다시 시도해 주세요');
    }
    _startProcessing(r);
    return _recDto(r);
  }

  @override
  Future<RecordingDto> getRecording(String id) async {
    await _wait();
    return _recDto(_rec(id));
  }

  @override
  Future<RecordingDto> retryRecording(String id) async {
    await _wait();
    final r = _rec(id);
    _startProcessing(r);
    return _recDto(r);
  }

  // ── deliveries ────────────────────────────────────
  @override
  Future<SentTapeDto> createDelivery(
    CreateDeliveryRequest body, {
    required String idempotencyKey,
  }) async {
    final replay = _s.idempotency[idempotencyKey];
    if (replay is SentTapeDto) {
      await _wait();
      return replay;
    }
    if (_b.failsSend) {
      await _wait(_b.sendFailDelay);
      // 보내기 실패는 네트워크 끊김으로 흉내 낸다 (디자인 `sendFailOn`).
      throw const ApiException.network();
    }
    await _wait(_b.sendDelay);
    if (body.recipientId != null && body.linkName != null) {
      _fail(400, ApiErrorCode.validationFailed, '요청이 올바르지 않아요');
    }
    final r = _rec(body.recordingId);
    final dto = _recDto(r);
    if (r.sent) {
      _fail(409, ApiErrorCode.recordingAlreadySent, '이미 보낸 녹음이에요');
    }
    if (dto.status != 'ready') {
      _fail(409, ApiErrorCode.recordingNotReady, '테이프 소리로 바꾸는 중이에요', {
        'status': dto.status,
      });
    }
    FriendDto? friend;
    if (body.recipientId != null) {
      friend = _s.friends
          .where((f) => f.userId == body.recipientId)
          .firstOrNull;
      if (friend == null) {
        _fail(403, ApiErrorCode.notFriend, '친구에게만 보낼 수 있어요');
      }
    }
    if (r.tapeType != 15) {
      final n = _s.owned[r.tapeType] ?? 0;
      if (n <= 0) {
        _fail(409, ApiErrorCode.noTapeLeft, '테이프가 없어요. 상점에서 채워 주세요', {
          'tapeType': r.tapeType,
        });
      }
      _s.owned = {..._s.owned, r.tapeType: n - 1};
    }
    r.sent = true;
    final now = _s.now();
    final id = _s.nextId('s');
    final sent = SentTapeDto(
      id: id,
      recipient: friend == null
          ? null
          : UserRefDto(userId: friend.userId, name: friend.name),
      linkName: body.linkName,
      tapeType: r.tapeType,
      durationMs: r.durationMs,
      tag: body.tag,
      sentAt: now,
      status: friend == null ? 'link_pending' : 'unopened',
      claimedAt: friend == null ? null : now,
      share: friend == null
          ? ShareLinkDto(
              url: 'https://tapeletter.lab241.com/t/$id',
              expiresAt: now.add(const Duration(days: 7)),
            )
          : null,
    );
    _s.sent = [sent, ..._s.sent];
    if (friend != null) {
      _s.friends = [
        for (final f in _s.friends)
          f.userId == friend.userId ? f.copyWith(lastAt: now) : f,
      ];
    }
    _s.idempotency[idempotencyKey] = sent;
    return sent;
  }

  @override
  Future<PageDto<SentTapeDto>> getSent({String? cursor, int? limit}) async {
    await _wait();
    return _page(_s.sent, cursor, limit);
  }

  /// `{ items, nextCursor }` — 커서는 다음 시작 위치
  static PageDto<T> _page<T>(List<T> all, String? cursor, int? limit) {
    final start = (int.tryParse(cursor ?? '') ?? 0).clamp(0, all.length);
    final end = (start + (limit ?? 30).clamp(1, 100)).clamp(0, all.length);
    return PageDto(
      items: all.sublist(start, end),
      nextCursor: end < all.length ? '$end' : null,
    );
  }

  /// 아직 아무도 받지 않은 링크만. 만료됐으면 새 링크(7일).
  @override
  Future<SentTapeDto> getSentTape(String id) async {
    await _wait();
    final t = _s.sent.where((x) => x.id == id).firstOrNull;
    if (t == null) _fail(404, ApiErrorCode.tapeNotFound, '테이프를 찾을 수 없어요');
    return t;
  }

  @override
  Future<ShareLinkDto> reshareSent(String id) async {
    await _wait();
    final i = _s.sent.indexWhere((x) => x.id == id);
    if (i < 0) _fail(404, ApiErrorCode.tapeNotFound, '테이프를 찾을 수 없어요');
    final t = _s.sent[i];
    if (t.share == null || t.recipient != null) {
      _fail(409, ApiErrorCode.linkTaken, '이미 다른 분이 받은 테이프예요');
    }
    final now = _s.now();
    final share = t.share != null && t.share!.expiresAt.isAfter(now)
        ? t.share!
        : ShareLinkDto(
            url: 'https://tapeletter.lab241.com/t/${_s.nextId('link')}',
            expiresAt: now.add(const Duration(days: 7)),
          );
    _s.sent = [..._s.sent]
      ..[i] = SentTapeDto(
        id: t.id,
        linkName: t.linkName,
        tapeType: t.tapeType,
        durationMs: t.durationMs,
        tag: t.tag,
        sentAt: t.sentAt,
        status: 'link_pending',
        share: share,
      );
    return share;
  }

  ({ShelfItemDto item, int index, LocalGroup? group}) _find(String id) {
    final i = _s.unsorted.indexWhere((x) => x.id == id);
    if (i >= 0) return (item: _s.unsorted[i], index: i, group: null);
    for (final g in _s.groups) {
      final j = g.items.indexWhere((x) => x.id == id);
      if (j >= 0) return (item: g.items[j], index: j, group: g);
    }
    _fail(404, ApiErrorCode.tapeNotFound, '테이프를 찾을 수 없어요');
  }

  void _replace(String id, ShelfItemDto next) {
    final f = _find(id);
    if (f.group == null) {
      _s.unsorted = [..._s.unsorted]..[f.index] = next;
    } else {
      f.group!.items = [...f.group!.items]..[f.index] = next;
    }
  }

  @override
  Future<ShelfItemDto> getDelivery(String id) async {
    await _wait();
    return _find(id).item;
  }

  @override
  Future<ShelfItemDto> openDelivery(String id) async {
    await _wait();
    final item = _find(id).item;
    if (item.opened) return item;
    if (_stored() >= _s.cap) {
      _fail(409, ApiErrorCode.drawerFull, '서랍이 꽉 찼어요');
    }
    final next = item.copyWith(opened: true, openedAt: _s.now());
    _replace(id, next);
    return next;
  }

  @override
  Future<AudioUrlDto> getDeliveryAudio(String id) async {
    await _wait();
    final item = _find(id).item;
    if (!item.opened) {
      _fail(409, ApiErrorCode.tapeNotOpened, '소포를 먼저 뜯어 주세요');
    }
    if (_b.failsAudio) {
      _fail(409, ApiErrorCode.audioNotReady, '테이프를 불러오지 못했어요');
    }
    return AudioUrlDto(
      url: sampleAudio(item.tapeType),
      expiresAt: _s.now().add(const Duration(minutes: 10)),
      durationMs: item.durationMs,
    );
  }

  // ── shelf ─────────────────────────────────────────
  @override
  Future<ShelfDto> getShelf() async {
    await _wait();
    final me = _me();
    return ShelfDto(
      stored: me.drawer.stored,
      cap: me.drawer.cap,
      full: me.drawer.full,
      unopenedCount: me.drawer.unopenedCount,
      unsorted: [for (final x in _s.unsorted) _nick(x)],
      groups: [
        for (final g in _s.groups)
          ShelfGroupDto(
            id: g.id,
            name: g.name,
            cap: groupCap,
            items: [for (final x in g.items) _nick(x)],
          ),
      ],
    );
  }

  String _groupName(String name) {
    final n = name.trim().isEmpty ? '새 칸' : name.trim();
    if (n.runes.length > 12) {
      _fail(400, ApiErrorCode.invalidGroupName, '칸 이름은 1~12자로 적어주세요');
    }
    return n;
  }

  LocalGroup _group(String id) =>
      _s.groups.where((g) => g.id == id).firstOrNull ??
      _fail(404, ApiErrorCode.groupNotFound, '칸을 찾을 수 없어요');

  @override
  Future<ShelfGroupDto> createGroup(String name) async {
    await _wait();
    final g = LocalGroup(_s.nextId('g'), _groupName(name), []);
    _s.groups = [..._s.groups, g];
    return ShelfGroupDto(
      id: g.id,
      name: g.name,
      cap: groupCap,
      items: const [],
    );
  }

  @override
  Future<ShelfGroupDto> renameGroup(String id, String name) async {
    await _wait();
    final g = _group(id)..name = _groupName(name);
    return ShelfGroupDto(
      id: g.id,
      name: g.name,
      cap: groupCap,
      items: List.of(g.items),
    );
  }

  /// 칸을 지우면 안의 테이프는 분류 안 함(맨 뒤)으로 가고 뜯은 상태가 된다.
  @override
  Future<void> deleteGroup(String id) async {
    await _wait();
    final g = _group(id);
    _s.groups = _s.groups.where((x) => x.id != id).toList();
    _s.unsorted = [
      ..._s.unsorted,
      for (final x in g.items) x.copyWith(opened: true, groupId: () => null),
    ];
  }

  @override
  Future<ShelfItemDto> moveShelfItem(
    String id,
    MoveShelfItemRequest body,
  ) async {
    await _wait();
    final from = _find(id);
    // 안 뜯은 소포는 칸으로 못 옮긴다. 분류 안 함 안에서 순서 바꾸기는 된다.
    if (!from.item.opened && body.groupId != null) {
      _fail(409, ApiErrorCode.tapeNotOpened, '소포를 먼저 뜯어 주세요');
    }
    final target = body.groupId == null ? null : _group(body.groupId!);
    // 칸 하나에 10개까지. 같은 칸 안에서 순서 바꾸기는 된다.
    if (target != null &&
        from.group?.id != target.id &&
        target.items.length >= groupCap) {
      _fail(409, ApiErrorCode.groupFull, '한 칸에는 10개까지 넣을 수 있어요');
    }
    // 빼기
    if (from.group == null) {
      _s.unsorted = [..._s.unsorted]..removeAt(from.index);
    } else {
      from.group!.items = [...from.group!.items]..removeAt(from.index);
    }
    final moved = from.item.copyWith(groupId: () => body.groupId);
    final list = target == null ? [..._s.unsorted] : [...target.items];
    var at = 0;
    if (body.afterId != null) {
      final k = list.indexWhere((x) => x.id == body.afterId);
      at = k < 0 ? list.length : k + 1;
    }
    list.insert(at, moved);
    if (target == null) {
      _s.unsorted = list;
    } else {
      target.items = list;
    }
    return moved;
  }

  /// 메모 (최대 40자, 앞뒤 공백 제거, 비우면 지움)
  @override
  Future<ShelfItemDto> setShelfItemMemo(String id, SetMemoRequest body) async {
    await _wait();
    final v = body.memo?.trim();
    if (v != null && (v.characters.length > 40 || v.contains('\n'))) {
      _fail(400, ApiErrorCode.invalidMemo, '메모는 40자까지 적을 수 있어요');
    }
    final next = _find(id).item
        .copyWith(memo: () => v == null || v.isEmpty ? null : v);
    _replace(id, next);
    return next;
  }

  @override
  Future<void> deleteShelfItem(String id) async {
    await _wait();
    final f = _find(id);
    if (f.group == null) {
      _s.unsorted = [..._s.unsorted]..removeAt(f.index);
    } else {
      f.group!.items = [...f.group!.items]..removeAt(f.index);
    }
  }

  // ── wallet ────────────────────────────────────────
  @override
  Future<WalletDto> getWallet() async {
    await _wait();
    return WalletDto(
      credits: _s.credits,
      ads: AdsDto(
        rewardPerView: 10,
        dailyLimit: 3,
        remainingToday: _s.adsRemaining,
      ),
    );
  }

  @override
  Future<PageDto<LedgerEntryDto>> getLedger({
    String? cursor,
    int? limit,
  }) async {
    await _wait();
    return _page(_s.ledger, cursor, limit);
  }

  void _addLedger(int delta, String reason, String kind) => _s.ledger = [
    LedgerEntryDto(
      id: _s.nextId('l'),
      delta: delta,
      reason: reason,
      kind: kind,
      createdAt: _s.now(),
    ),
    ..._s.ledger,
  ];

  Never _insufficient(int need) =>
      _fail(402, ApiErrorCode.insufficientCredits, '크레딧이 부족해요', {'need': need});

  @override
  Future<GiftResultDto> sendGift({
    required String toUserId,
    required int amount,
    required String idempotencyKey,
  }) async {
    await _wait();
    final replay = _s.idempotency[idempotencyKey];
    if (replay is GiftResultDto) return replay;
    if (!const [10, 30, 50, 100].contains(amount)) {
      _fail(
        400,
        ApiErrorCode.invalidGiftAmount,
        '선물은 10, 30, 50, 100 크레딧만 할 수 있어요',
      );
    }
    final f = _friend(toUserId);
    if (_s.credits < amount) _insufficient(amount - _s.credits);
    _s.credits -= amount;
    _addLedger(-amount, '${f.name}님에게 선물', 'gift_sent');
    final r = GiftResultDto(credits: _s.credits, entry: _s.ledger.first);
    _s.idempotency[idempotencyKey] = r;
    return r;
  }

  // ── shop · billing ────────────────────────────────
  /// 계약서 §14 예시와 같은 상품 (= 프로토타입 `shopTapes`, `etc`, `packs`)
  static const products = ProductsDto(
    tapes: [
      TapeProductDto(
        id: 'tape60_1',
        tapeType: 60,
        qty: 1,
        name: '1분 테이프',
        price: 30,
      ),
      TapeProductDto(
        id: 'tape60_5',
        tapeType: 60,
        qty: 5,
        name: '1분 테이프 5개',
        price: 120,
      ),
      TapeProductDto(
        id: 'tape180_1',
        tapeType: 180,
        qty: 1,
        name: '3분 테이프',
        price: 50,
      ),
      TapeProductDto(
        id: 'tape180_5',
        tapeType: 180,
        qty: 5,
        name: '3분 테이프 5개',
        price: 200,
      ),
    ],
    drawer: [
      DrawerProductDto(id: 'drawer_10', name: '서랍 넓히기', slots: 10, price: 100),
    ],
    creditPacks: [
      CreditPackDto(
        productId: 'tapeletter.credits_100',
        credits: 100,
        priceLabel: '₩1,100',
      ),
      CreditPackDto(
        productId: 'tapeletter.credits_550',
        credits: 550,
        priceLabel: '₩5,500',
      ),
      CreditPackDto(
        productId: 'tapeletter.credits_1200',
        credits: 1200,
        priceLabel: '₩11,000',
      ),
    ],
    giftAmounts: [10, 30, 50, 100],
  );

  @override
  Future<ProductsDto> getProducts() async {
    await _wait();
    return products;
  }

  @override
  Future<PurchaseResultDto> purchase(
    String productId, {
    required String idempotencyKey,
  }) async {
    await _wait();
    final replay = _s.idempotency[idempotencyKey];
    if (replay is PurchaseResultDto) return replay;
    final tape = products.tapes.where((t) => t.id == productId).firstOrNull;
    final drawer = products.drawer.where((d) => d.id == productId).firstOrNull;
    if (tape == null && drawer == null) {
      _fail(404, ApiErrorCode.productNotFound, '없는 상품이에요');
    }
    final price = tape?.price ?? drawer!.price;
    if (_s.credits < price) _insufficient(price - _s.credits);
    _s.credits -= price;
    if (tape != null) {
      _s.owned = {
        ..._s.owned,
        tape.tapeType: (_s.owned[tape.tapeType] ?? 0) + tape.qty,
      };
      _addLedger(-price, '${tape.name} 구매', 'tape_purchase');
    } else {
      _s.cap += drawer!.slots;
      _addLedger(-price, drawer.name, 'drawer_expand');
    }
    final me = _me();
    final r = PurchaseResultDto(
      credits: _s.credits,
      tapes: me.tapes,
      drawer: me.drawer,
      entry: _s.ledger.first,
    );
    _s.idempotency[idempotencyKey] = r;
    return r;
  }

  /// 같은 결제(verificationData)를 다시 보내면 지급 없이 `alreadyProcessed: true`.
  /// 메모리 서버에는 스토어 키가 없으므로 실제 영수증 검증은 하지 않는다.
  @override
  Future<IapResultDto> verifyIap(
    IapRequest body, {
    required String idempotencyKey,
  }) async {
    await _wait();
    final seen = 'iap:${body.verificationData}:${body.transactionId}';
    if (_s.idempotency.containsKey(seen)) {
      return IapResultDto(
        credits: _s.credits,
        granted: 0,
        alreadyProcessed: true,
      );
    }
    final pack =
        _pack(body.productId) ??
        _fail(400, ApiErrorCode.receiptInvalid, '결제를 확인하지 못했어요');
    final r = _charge(pack);
    _s.idempotency[seen] = r;
    return r;
  }

  CreditPackDto? _pack(String? id) =>
      products.creditPacks.where((p) => p.productId == id).firstOrNull;

  IapResultDto _charge(CreditPackDto pack) {
    _s.credits += pack.credits;
    _addLedger(pack.credits, '크레딧 충전 · ${pack.priceLabel}', 'iap');
    return IapResultDto(
      credits: _s.credits,
      granted: pack.credits,
      entry: _s.ledger.first,
    );
  }

  @override
  Future<WalletDto> devCredits(DevCreditsRequest body) async {
    await _wait();
    switch (body.type) {
      case 'ad':
        if (_s.adsRemaining <= 0) {
          _fail(429, ApiErrorCode.adLimitReached, '오늘은 다 받았어요');
        }
        _s.adsRemaining--;
        _s.credits += 10;
        _addLedger(10, '광고 보상', 'ad_reward');
      case 'charge':
        _charge(
          _pack(body.productId) ??
              _fail(404, ApiErrorCode.productNotFound, '없는 상품이에요'),
        );
      default:
        _s.credits += body.amount ?? 0;
        _addLedger(body.amount ?? 0, '개발용 지급', 'admin');
    }
    return getWallet();
  }

  /// SSV 콜백을 흉내 낸다 (시험용 도우미). 하루 3번이 넘으면 조용히 무시한다.
  void grantAdReward() {
    if (_s.adsRemaining <= 0) return;
    _s.adsRemaining--;
    _s.credits += 10;
    _addLedger(10, '광고 보상', 'ad_reward');
  }

  @override
  Future<void> devSeed() async {
    await _wait();
    final name = _s.name;
    _s.reset();
    _s.signedUp = true;
    _s.name = name;
  }

  @override
  Future<FriendDto> devFriend({
    String? userId,
    String? name,
    bool? starred,
  }) async {
    await _wait();
    final f = FriendDto(
      userId: userId ?? _s.nextId('u'),
      name: name ?? '친구',
      starred: starred ?? false,
      lastAt: _s.now(),
    );
    _s.friends = [f, ..._s.friends.where((x) => x.userId != f.userId)];
    return f;
  }

  // ── reports ───────────────────────────────────────
  /// 받은 신고 (시험에서 확인)
  final List<CreateReportRequest> reports = [];
  final Map<String, ReportResultDto> _reportKeys = {};

  @override
  Future<ReportResultDto> createReport(
    CreateReportRequest body, {
    required String idempotencyKey,
  }) async {
    await _wait();
    final replay = _reportKeys[idempotencyKey];
    if (replay != null) return replay;
    if (_b.offline) throw ApiException.network();
    if (_b.failMode == FailMode.reportLimit) {
      _fail(429, ApiErrorCode.rateLimited, '잠시 후에 다시 시도해 주세요');
    }
    if (_b.failMode == FailMode.reportGone) {
      _fail(404, ApiErrorCode.reportTargetNotFound, '신고할 대상을 찾을 수 없어요');
    }
    // 테이프면 보낸 사람을, 사람이면 그 사람을 차단 대상으로
    String? blockId;
    final deliveryId = body.deliveryId;
    if (deliveryId != null) {
      final all = [..._s.unsorted, for (final g in _s.groups) ...g.items];
      final item = all.where((x) => x.id == deliveryId).firstOrNull;
      if (item == null) {
        _fail(404, ApiErrorCode.reportTargetNotFound, '신고할 대상을 찾을 수 없어요');
      }
      blockId = item.sender.userId;
    } else {
      final id = body.userId!;
      if (id == LocalStore.meId) {
        _fail(400, ApiErrorCode.cannotReportSelf, '나는 신고할 수 없어요');
      }
      final known =
          _s.friends.any((f) => f.userId == id) ||
          _s.blocked.any((b) => b.userId == id) ||
          _senderName(id) != null;
      if (!known) {
        _fail(404, ApiErrorCode.reportTargetNotFound, '신고할 대상을 찾을 수 없어요');
      }
      blockId = id;
    }
    if (body.alsoBlock && blockId != null) {
      final already = _s.blocked.any((b) => b.userId == blockId);
      if (!already) await blockUser(blockId);
    }
    reports.add(body);
    final r = ReportResultDto(id: _s.nextId('rp'), createdAt: _s.now());
    _reportKeys[idempotencyKey] = r;
    return r;
  }
}
