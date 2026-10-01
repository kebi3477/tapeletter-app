@Tags(['server'])
// 로그인 횟수 제한을 기다릴 수 있어 기본 30초보다 길게
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:tapeletter_app/data/model/api_error.dart';
import 'package:tapeletter_app/data/model/auth_dto.dart';
import 'package:tapeletter_app/data/model/delivery_dto.dart';
import 'package:tapeletter_app/data/model/mappers.dart';
import 'package:tapeletter_app/data/model/me_dto.dart';
import 'package:tapeletter_app/data/model/recording_dto.dart';
import 'package:tapeletter_app/data/model/report_dto.dart';
import 'package:tapeletter_app/data/model/shelf_dto.dart';
import 'package:tapeletter_app/data/model/shop_dto.dart';
import 'package:tapeletter_app/data/services/api/api_status.dart';
import 'package:tapeletter_app/data/services/api/authorized_api_client.dart';
import 'package:tapeletter_app/data/services/api/http_api_client.dart';
import 'package:tapeletter_app/data/services/api/token_store.dart';
import 'package:tapeletter_app/data/services/audio_cache.dart';
import 'package:tapeletter_app/data/services/http_upload_service.dart';
import 'package:tapeletter_app/utils/idempotency.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// 실제 서버(`tapeletter-api`)에 HTTP로 붙어 앱의 [HttpApiClient]를 끝까지 확인한다.
///
/// ```bash
/// cd ../tapeletter-api && npm run start:dev
/// flutter test --tags server --dart-define=API_BASE_URL=http://localhost:3000/api
/// ```
/// `API_BASE_URL`이 없으면 건너뛴다 (기본 `flutter test`).
const baseUrl = String.fromEnvironment('API_BASE_URL');

/// 실행마다 새 계정 (같은 key면 같은 사용자)
final run = DateTime.now().millisecondsSinceEpoch.toRadixString(36);

class Account {
  Account(this.api, this.auth);

  final HttpApiClient api;
  final AuthResponseDto auth;

  String get id => auth.user.id;
}

Future<Account> login(String key, {String? name}) async {
  final api = HttpApiClient(baseUrl: baseUrl);
  final auth = await devLogin(api, 'it-$run-$key', name: name);
  api.accessToken = auth.tokens.accessToken;
  return Account(api, auth);
}

/// 로그인은 IP당 1분 20번 (`429 RATE_LIMITED`, 계약서 §1). 넘으면 잠시 기다렸다 다시.
Future<AuthResponseDto> devLogin(
  HttpApiClient api,
  String key, {
  String? name,
}) async {
  for (var i = 0; ; i++) {
    try {
      return await api.authDev(key: key, name: name);
    } on ApiException catch (e) {
      if (e.code != ApiErrorCode.rateLimited || i >= 15) rethrow;
      await Future<void>.delayed(const Duration(seconds: 5));
    }
  }
}

Matcher apiError(int status, String code) => throwsA(
  isA<ApiException>()
      .having((e) => e.status, 'status', status)
      .having((e) => e.code, 'code', code),
);

/// 샘플을 녹음처럼 올리고 변환이 끝날 때까지 기다린다.
/// 15초(무료) 테이프는 10초 파일(`test/fixtures/sample_10s.m4a`), 나머지는 번들 20초 샘플.
Future<RecordingDto> recordSample(
  HttpApiClient api, {
  int tapeType = 15,
}) async {
  final short = tapeType == 15;
  final created = await api.createRecording(
    CreateRecordingRequest(
      tapeType: tapeType,
      durationMs: short ? 10000 : 20000,
    ),
  );
  expect(created.recording.status, 'uploading');
  expect(created.upload.method, 'PUT');
  await HttpUploadService().upload(
    created.upload,
    short ? 'test/fixtures/sample_10s.m4a' : 'assets/audio/sample_20s.m4a',
  );
  var r = await api.completeRecording(created.recording.id);
  // 확인 화면처럼 1초 간격 폴링
  for (var i = 0; i < 30 && r.status != 'ready'; i++) {
    expect(r.status, isNot('failed'));
    await Future<void>.delayed(const Duration(seconds: 1));
    r = await api.getRecording(r.id);
  }
  expect(r.status, 'ready');
  expect(r.preview, isNotNull, reason: '보내기 전 미리 듣기');
  return r;
}

int? qtyOf(MeDto me, int tapeType) =>
    me.tapes.firstWhere((t) => t.tapeType == tapeType).qty;

void main() {
  if (baseUrl.isEmpty) {
    test('서버 시험', () {}, skip: 'API_BASE_URL이 없어 건너뛴다 (docs/SETUP.md)');
    return;
  }

  setUpAll(() async {
    // 서버가 떠 있는지 먼저 본다
    await HttpApiClient(baseUrl: baseUrl).health();
  });

  test('dev 로그인 → 시드 → me · shelf · wallet', () async {
    final a = await login('seed', name: '민경');
    expect(a.auth.isNewUser, isTrue);
    expect(a.auth.user.name, '민경');
    await a.api.devSeed();

    final me = await a.api.getMe();
    expect(me.credits, 120);
    expect(me.drawer.cap, 12);
    expect(qtyOf(me, 15), isNull, reason: '15초는 무료');
    expect(qtyOf(me, 60), 2);
    expect(me.stats.friendCount, 6);

    final shelf = await a.api.getShelf();
    expect(shelf.unsorted, hasLength(2));
    expect(shelf.unsorted.where((x) => !x.opened), hasLength(2));
    expect(shelf.unsorted.where((x) => x.viaLink), hasLength(1));
    expect(shelf.groups.map((g) => g.name), ['2026 생일', '승진 축하', '엄마 목소리']);
    expect(shelf.stored, 8, reason: '뜯은 테이프만 센다');
    expect(shelf.groups.map((g) => g.cap), [10, 10, 10]);

    final wallet = await a.api.getWallet();
    expect(wallet.credits, 120);
    expect(wallet.ads.dailyLimit, 3);

    final friends = await a.api.getFriends();
    expect(friends.items.first.starred, isTrue, reason: '즐겨찾기 먼저');
  });

  test('녹음 → 업로드 → 변환 → 친구에게 보내기 (같은 Idempotency-Key 재시도)', () async {
    final a = await login('send', name: '민경');
    await a.api.devSeed();
    final b = await login('recv', name: '지현');
    await a.api.devFriend(userId: b.id);

    final rec = await recordSample(a.api, tapeType: 60);
    final key = newIdempotencyKey();
    final body = CreateDeliveryRequest(recordingId: rec.id, recipientId: b.id);
    final first = await a.api.createDelivery(body, idempotencyKey: key);
    // "다시 보내기": 같은 키 → 첫 응답 그대로, 테이프는 한 번만 차감
    final again = await a.api.createDelivery(body, idempotencyKey: key);
    expect(again.id, first.id);
    expect(first.recipient?.userId, b.id);
    expect(first.status, 'unopened');
    expect(qtyOf(await a.api.getMe(), 60), 1);

    // 이미 보낸 녹음을 새 키로 보내면 거절
    await expectLater(
      a.api.createDelivery(body, idempotencyKey: newIdempotencyKey()),
      apiError(409, ApiErrorCode.recordingAlreadySent),
    );

    // 받는 쪽: 분류 안 함 맨 위 → 뜯기 → 재생 URL → 파일
    final shelf = await b.api.getShelf();
    final item = shelf.unsorted.first;
    expect(item.id, first.id);
    expect(item.opened, isFalse);
    expect(item.sender.name, '민경');
    await expectLater(
      b.api.getDeliveryAudio(item.id),
      apiError(409, ApiErrorCode.tapeNotOpened),
    );
    final opened = await b.api.openDelivery(item.id);
    expect(opened.opened, isTrue);
    final audio = await b.api.getDeliveryAudio(item.id);
    expect(audio.durationMs, greaterThan(0));

    // 앱 캐시: delivery id로 저장
    final dir = await Directory.systemTemp.createTemp('tapes');
    addTearDown(() => dir.delete(recursive: true));
    final cache = FileAudioCache(root: dir);
    final file = await cache.save(item.id, audio.url);
    expect(await file.length(), greaterThan(1000));
    expect((await cache.find(item.id))?.path, file.path);

    // 보낸 사람은 들을 수 없다 · 보낸 기록은 opened
    await expectLater(
      a.api.getDeliveryAudio(item.id),
      apiError(404, ApiErrorCode.tapeNotFound),
    );
    expect((await a.api.getSentTape(first.id)).status, 'opened');
  });

  test('링크로 보내기 → 다른 계정이 받기 → 서로 친구, 또 받으면 LINK_TAKEN', () async {
    final a = await login('link-a', name: '민경');
    final rec = await recordSample(a.api);
    final sent = await a.api.createDelivery(
      CreateDeliveryRequest(recordingId: rec.id, linkName: '유진'),
      idempotencyKey: newIdempotencyKey(),
    );
    expect(sent.status, 'link_pending');
    final url = sent.share!.url;
    final token = Uri.parse(url).pathSegments.last;
    expect(url, contains('/t/$token'));

    // 보낸 사람이 앱으로 열면 LINK_OWN (+url)
    await expectLater(
      a.api.getShare(token),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', ApiErrorCode.linkOwn)
            .having((e) => e.extra['url'], 'url', url),
      ),
    );

    final c = await login('link-c', name: '유진');
    final info = await c.api.getShare(token);
    expect(info.state, 'available');
    expect(info.sender.name, '민경');
    // 열기만 하고 닫음 → 여전히 받을 수 있다
    expect((await c.api.getShare(token)).state, 'available');

    final key = newIdempotencyKey();
    final claimed = await c.api.claimShare(token, idempotencyKey: key);
    expect(claimed.item.viaLink, isTrue);
    expect(claimed.friend?.userId, a.id);
    final replay = await c.api.claimShare(token, idempotencyKey: key);
    expect(replay.item.id, claimed.item.id);
    expect((await c.api.getShare(token)).state, 'claimed');
    expect((await c.api.getShelf()).unsorted.first.id, claimed.item.id);

    final d = await login('link-d', name: '하늘');
    await expectLater(
      d.api.getShare(token),
      apiError(409, ApiErrorCode.linkTaken),
    );
    await expectLater(
      d.api.claimShare(token, idempotencyKey: newIdempotencyKey()),
      apiError(409, ApiErrorCode.linkTaken),
    );

    // 보낸 쪽: 친구가 생기고 보낸 기록이 바뀐다
    final friends = await a.api.getFriends();
    expect(friends.items.map((f) => f.userId), contains(c.id));
    expect((await a.api.getSentTape(sent.id)).status, isNot('link_pending'));
  });

  test('새 친구 이름은 선택: linkName 없이 링크로, 받으면 recipient가 채워진다', () async {
    final a = await login('noname-a', name: '민경');
    final b = await login('noname-b', name: '지현');
    await a.api.devFriend(userId: b.id);

    // 친구에게 linkName을 같이 보내면 400 (앱은 만들 수 없는 본문이라 직접 보낸다)
    final rec0 = await recordSample(a.api);
    final raw = await Dio().post<Object?>(
      '$baseUrl/deliveries',
      data: {'recordingId': rec0.id, 'recipientId': b.id, 'linkName': '지현'},
      options: Options(
        headers: {
          'Authorization': 'Bearer ${a.auth.tokens.accessToken}',
          'Idempotency-Key': newIdempotencyKey(),
        },
        validateStatus: (_) => true,
      ),
    );
    expect(raw.statusCode, 400);
    expect((raw.data as Map)['code'], ApiErrorCode.validationFailed);

    final rec = await recordSample(a.api);
    final sent = await a.api.createDelivery(
      CreateDeliveryRequest(recordingId: rec.id),
      idempotencyKey: newIdempotencyKey(),
    );
    expect(sent.linkName, isNull);
    expect(sent.recipient, isNull);
    expect(sent.toDomain().to, '새 친구');
    final token = Uri.parse(sent.share!.url).pathSegments.last;

    final c = await login('noname-c', name: '하늘');
    await c.api.claimShare(token, idempotencyKey: newIdempotencyKey());
    final after = await a.api.getSentTape(sent.id);
    expect(after.recipient?.userId, c.id);
    expect(after.toDomain().to, '하늘');
  });

  test('서랍: 칸 만들기 · 옮기기 · 정렬 · 칸 지우기', () async {
    final a = await login('shelf', name: '민경');
    await a.api.devSeed();
    var shelf = await a.api.getShelf();
    final birthday = shelf.groups.first;
    final second = birthday.items[1];

    final g = await a.api.createGroup('테스트 칸');
    expect(g.items, isEmpty);

    // 칸으로 옮기기
    await a.api.moveShelfItem(
      second.id,
      MoveShelfItemRequest(groupId: g.id, afterId: null),
    );
    // 생일 칸 안에서 정렬: 첫 테이프를 마지막 뒤로
    final first = birthday.items.first;
    final last = birthday.items.last;
    await a.api.moveShelfItem(
      first.id,
      MoveShelfItemRequest(groupId: birthday.id, afterId: last.id),
    );
    shelf = await a.api.getShelf();
    final b2 = shelf.groups.firstWhere((x) => x.id == birthday.id);
    expect(b2.items.map((x) => x.id), isNot(contains(second.id)));
    expect(b2.items.last.id, first.id);
    expect(
      shelf.groups.firstWhere((x) => x.id == g.id).items.single.id,
      second.id,
    );

    // 안 뜯은 소포는 칸으로 못 옮긴다
    final parcel = shelf.unsorted.firstWhere((x) => !x.opened);
    await expectLater(
      a.api.moveShelfItem(
        parcel.id,
        MoveShelfItemRequest(groupId: g.id, afterId: null),
      ),
      apiError(409, ApiErrorCode.tapeNotOpened),
    );

    // 칸 지우기 → 테이프는 분류 안 함의 끝으로
    await a.api.deleteGroup(g.id);
    shelf = await a.api.getShelf();
    expect(shelf.groups.map((x) => x.id), isNot(contains(g.id)));
    expect(shelf.unsorted.last.id, second.id);

    // 테이프 지우기
    await a.api.deleteShelfItem(second.id);
    shelf = await a.api.getShelf();
    expect(shelf.unsorted.map((x) => x.id), isNot(contains(second.id)));
  });

  test('상점: 구매 🔑, 부족하면 402 need', () async {
    final a = await login('shop', name: '민경');
    await a.api.devSeed();
    final products = await a.api.getProducts();
    expect(products.tapes.map((t) => t.id), contains('tape60_1'));

    final key = newIdempotencyKey();
    final r = await a.api.purchase('tape60_1', idempotencyKey: key);
    expect(r.credits, 90);
    // 같은 키로 다시 → 한 번만
    final again = await a.api.purchase('tape60_1', idempotencyKey: key);
    expect(again.credits, 90);
    expect(qtyOf(await a.api.getMe(), 60), 3);

    // 새 계정: 가입 선물 10 크레딧 → 3분 테이프(50) 부족
    final poor = await login('shop-poor', name: '은비');
    await expectLater(
      poor.api.purchase('tape180_1', idempotencyKey: newIdempotencyKey()),
      throwsA(
        isA<ApiException>()
            .having((e) => e.status, 'status', 402)
            .having((e) => e.code, 'code', ApiErrorCode.insufficientCredits)
            .having((e) => e.extra['need'], 'need', 40),
      ),
    );
    await expectLater(
      a.api.purchase('nope', idempotencyKey: newIdempotencyKey()),
      apiError(404, ApiErrorCode.productNotFound),
    );
  });

  test('선물 · /dev/credits · 크레딧 내역 커서', () async {
    final a = await login('gift-a', name: '민경');
    await a.api.devSeed();
    final b = await login('gift-b', name: '지현');
    await a.api.devFriend(userId: b.id);

    final g = await a.api.sendGift(
      toUserId: b.id,
      amount: 30,
      idempotencyKey: newIdempotencyKey(),
    );
    expect(g.credits, 90);
    expect((await b.api.getWallet()).credits, 40, reason: '가입 10 + 선물 30');
    await expectLater(
      a.api.sendGift(
        toUserId: b.id,
        amount: 7,
        idempotencyKey: newIdempotencyKey(),
      ),
      apiError(400, ApiErrorCode.invalidGiftAmount),
    );

    final ad = await a.api.devCredits(const DevCreditsRequest.ad());
    expect(ad.credits, 100);
    expect(ad.ads.remainingToday, 2);
    final charge = await a.api.devCredits(
      const DevCreditsRequest.charge('tapeletter.credits_100'),
    );
    expect(charge.credits, 200);

    // 커서로 끝까지: 겹치지 않고 최신이 앞
    final ids = <String>[];
    String? cursor;
    var pages = 0;
    do {
      final p = await a.api.getLedger(cursor: cursor, limit: 3);
      ids.addAll(p.items.map((e) => e.id));
      cursor = p.nextCursor;
      pages++;
    } while (cursor != null && pages < 10);
    expect(pages, greaterThan(1));
    expect(ids.toSet(), hasLength(ids.length));
    expect(ids.length, 8, reason: '시드 5줄 + 선물 + 광고 + 충전');
    final top = (await a.api.getLedger(limit: 1)).items.single;
    expect(top.delta, 100);
  });

  test('별명: PATCH /friends/{id} → 목록·서랍 sender·보낸 테이프 recipient에 nickname, 비우면 null', () async {
    final a = await login('alias', name: '민경');
    await a.api.devSeed();
    final mom = (await a.api.getFriends()).items.firstWhere(
      (f) => f.name == '엄마',
    );
    final set = await a.api.setFriendNickname(mom.userId, '우리 엄마');
    expect(set.nickname, '우리 엄마');
    expect(set.name, '엄마');
    expect(
      (await a.api.getFriends()).items
          .firstWhere((f) => f.userId == mom.userId)
          .nickname,
      '우리 엄마',
    );
    final shelf = await a.api.getShelf();
    final fromMom = [
      ...shelf.unsorted,
      for (final g in shelf.groups) ...g.items,
    ].where((x) => x.sender.userId == mom.userId);
    expect(fromMom, isNotEmpty);
    expect(fromMom.every((x) => x.sender.nickname == '우리 엄마'), isTrue);
    expect(fromMom.every((x) => x.sender.name == '엄마'), isTrue);
    final sent = (await a.api.getSent()).items.where(
      (x) => x.recipient?.userId == mom.userId,
    );
    expect(sent.every((x) => x.recipient!.nickname == '우리 엄마'), isTrue);

    await expectLater(
      a.api.setFriendNickname(mom.userId, '열한글자가넘는별명이다'),
      apiError(400, ApiErrorCode.invalidNickname),
    );
    final cleared = await a.api.setFriendNickname(mom.userId, null);
    expect(cleared.nickname, isNull);
    expect(
      (await a.api.setFriendNickname(mom.userId, '')).nickname,
      isNull,
      reason: '빈 문자열도 지우기',
    );
  });

  test('차단 · 해제', () async {
    final a = await login('block', name: '민경');
    await a.api.devSeed();
    final friends = (await a.api.getFriends()).items;
    final minsu = friends.firstWhere((f) => f.name == '민수');

    final blocked = await a.api.blockUser(minsu.userId);
    expect(blocked.userId, minsu.userId);
    expect(
      (await a.api.getFriends()).items.map((f) => f.userId),
      isNot(contains(minsu.userId)),
    );
    expect(
      (await a.api.getBlocks()).items.map((x) => x.userId),
      contains(minsu.userId),
    );
    await a.api.unblockUser(minsu.userId);
    expect(
      (await a.api.getFriends()).items.map((f) => f.userId),
      contains(minsu.userId),
    );
    await expectLater(
      a.api.unblockUser(minsu.userId),
      apiError(404, ApiErrorCode.blockNotFound),
    );
    await expectLater(
      a.api.blockUser(a.id),
      apiError(400, ApiErrorCode.cannotBlockSelf),
    );
  });

  test('신고: 테이프(같이 차단)·사람, 24시간 중복은 기존 신고, 없는 대상 404', () async {
    final a = await login('report', name: '민경');
    await a.api.devSeed();
    final shelf = await a.api.getShelf();
    final tape = shelf.groups.first.items.first;
    final senderId = tape.sender.userId!;
    expect(tape.sender.nickname, isNull, reason: '별명 필드를 받는다');

    final key = newIdempotencyKey();
    final r1 = await a.api.createReport(
      CreateReportRequest.tape(
        deliveryId: tape.id,
        reason: 'spam',
        memo: '  광고예요  ',
        alsoBlock: true,
      ),
      idempotencyKey: key,
    );
    expect(r1.id, isNotEmpty);
    expect(
      (await a.api.getBlocks()).items.map((b) => b.userId),
      contains(senderId),
      reason: '테이프 신고의 alsoBlock은 보낸 사람을 차단',
    );
    expect(
      (await a.api.getFriends()).items.map((f) => f.userId),
      isNot(contains(senderId)),
    );

    // 24시간 안 같은 대상 → 새 키여도 기존 신고
    final r2 = await a.api.createReport(
      CreateReportRequest.tape(deliveryId: tape.id, reason: 'other'),
      idempotencyKey: newIdempotencyKey(),
    );
    expect(r2.id, r1.id);

    // 사람 신고 (차단한 사람도 가능)
    final person = await a.api.createReport(
      CreateReportRequest.user(userId: senderId, reason: 'harassment'),
      idempotencyKey: newIdempotencyKey(),
    );
    expect(person.id, isNot(r1.id));

    await expectLater(
      a.api.createReport(
        const CreateReportRequest.tape(
          deliveryId: '00000000-0000-4000-8000-000000000000',
          reason: 'spam',
        ),
        idempotencyKey: newIdempotencyKey(),
      ),
      apiError(404, ApiErrorCode.reportTargetNotFound),
    );
    await expectLater(
      a.api.createReport(
        CreateReportRequest.user(userId: a.id, reason: 'spam'),
        idempotencyKey: newIdempotencyKey(),
      ),
      apiError(400, ApiErrorCode.cannotReportSelf),
    );
  });

  test('401 → refresh 뒤 한 번 다시 보낸다, refresh token은 회전', () async {
    final raw = HttpApiClient(baseUrl: baseUrl);
    final auth = await devLogin(raw, 'it-$run-refresh', name: '민경');
    final tokens = MemoryTokenStore()
      ..tokens = AuthTokens(
        access: 'expired.or.invalid',
        refresh: auth.tokens.refreshToken,
      );
    final api = AuthorizedApiClient(raw, tokens, ApiStatus());
    var expired = false;
    api.onSessionExpired = () async => expired = true;

    final me = await api.getMe();
    expect(me.id, auth.user.id);
    expect(tokens.tokens!.refresh, isNot(auth.tokens.refreshToken));
    expect(expired, isFalse);

    // 쓴 refresh token은 다시 못 쓴다
    await expectLater(
      raw.refreshTokens(auth.tokens.refreshToken),
      apiError(401, ApiErrorCode.invalidRefreshToken),
    );

    // refresh도 안 되면 세션 끝
    tokens.tokens = const AuthTokens(access: 'bad', refresh: 'bad');
    await expectLater(api.getMe(), throwsA(isA<ApiException>()));
    expect(expired, isTrue);
    expect(tokens.tokens, isNull);
  });

  test('탈퇴하면 그 토큰은 바로 401', () async {
    final a = await login('withdraw', name: '민경');
    await a.api.deleteMe();
    await expectLater(a.api.getMe(), apiError(401, ApiErrorCode.unauthorized));
  });

  test('없는 경로·잘못된 본문은 계약서 오류 모양', () async {
    final a = await login('errors', name: '민경');
    await expectLater(
      a.api.patchMe(const PatchMeRequest(name: '아홉글자가넘는이름')),
      apiError(400, ApiErrorCode.invalidName),
    );
    await expectLater(
      a.api.createRecording(
        const CreateRecordingRequest(tapeType: 15, durationMs: 90000),
      ),
      apiError(400, ApiErrorCode.recordingTooLong),
    );
    // 저장소 서명이 틀리면 업로드 실패 (앱 코드 UPLOAD_FAILED)
    final created = await a.api.createRecording(
      const CreateRecordingRequest(tapeType: 15, durationMs: 1000),
    );
    // 서명 한 글자를 바꾼다
    final u = Uri.parse(created.upload.url);
    final sig = u.queryParameters['sig']!;
    final flipped = '${sig[0] == 'a' ? 'b' : 'a'}${sig.substring(1)}';
    final bad = UploadTicketDto(
      url: u
          .replace(queryParameters: {...u.queryParameters, 'sig': flipped})
          .toString(),
      method: created.upload.method,
      headers: created.upload.headers,
      expiresAt: created.upload.expiresAt,
    );
    await expectLater(
      HttpUploadService().upload(bad, 'assets/audio/sample_20s.m4a'),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'UPLOAD_FAILED'),
      ),
    );
    await expectLater(
      a.api.completeRecording(created.recording.id),
      apiError(409, ApiErrorCode.uploadNotFound),
    );
  });

  test('Dio 직접: 재생 URL은 Range 요청(206)을 지원한다', () async {
    final a = await login('range', name: '민경');
    await a.api.devSeed();
    final shelf = await a.api.getShelf();
    final item = shelf.groups.first.items.first;
    final audio = await a.api.getDeliveryAudio(item.id);
    final r = await Dio().get<List<int>>(
      audio.url,
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'Range': 'bytes=0-99'},
      ),
    );
    expect(r.statusCode, 206);
    expect(r.data, hasLength(100));
  });
}
