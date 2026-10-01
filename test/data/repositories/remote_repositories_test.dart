import 'package:tapeletter_app/data/model/api_error.dart';
import 'package:tapeletter_app/data/model/shop_dto.dart';
import 'package:tapeletter_app/data/repositories/delivery_repository_remote.dart';
import 'package:tapeletter_app/data/repositories/friend_repository_remote.dart';
import 'package:tapeletter_app/data/repositories/recording_repository_remote.dart';
import 'package:tapeletter_app/data/repositories/shelf_repository_remote.dart';
import 'package:tapeletter_app/data/repositories/shop_repository_remote.dart';
import 'package:tapeletter_app/data/repositories/user_repository_remote.dart';
import 'package:tapeletter_app/data/repositories/wallet_repository_remote.dart';
import 'package:tapeletter_app/data/services/local/local_api_client.dart';
import 'package:tapeletter_app/data/services/local/local_behavior.dart';
import 'package:tapeletter_app/data/services/local/local_store.dart';
import 'package:tapeletter_app/data/services/local/local_upload_service.dart';
import 'package:tapeletter_app/domain/models/blocked_user.dart';
import 'package:tapeletter_app/domain/models/friend.dart';
import 'package:tapeletter_app/domain/models/friend_tapes.dart';
import 'package:tapeletter_app/domain/models/me.dart';
import 'package:tapeletter_app/domain/models/recipient.dart';
import 'package:tapeletter_app/domain/models/recording.dart';
import 'package:tapeletter_app/domain/models/sent_tape.dart';
import 'package:tapeletter_app/domain/models/shelf.dart';
import 'package:tapeletter_app/domain/models/shop.dart';
import 'package:tapeletter_app/domain/models/tape_audio.dart';
import 'package:tapeletter_app/domain/models/tape_item.dart';
import 'package:tapeletter_app/domain/models/tape_tag.dart';
import 'package:tapeletter_app/domain/models/tape_type.dart';
import 'package:tapeletter_app/domain/models/wallet.dart';
import 'package:tapeletter_app/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

T ok<T>(Result<T> r) => (r as Ok<T>).value;

ApiException apiError(Result<Object?> r) => (r as Error).error as ApiException;

void main() {
  late LocalStore store;
  late LocalApiClient api;

  setUp(() {
    store = LocalStore(clock: () => DateTime.utc(2026, 9, 25, 3));
    api = LocalApiClient(store, LocalBehavior.instant);
  });

  test('Me: 크레딧·보유·서랍(unopenedCount)', () async {
    final me = ok<Me>(await UserRepositoryRemote(api).getMe());
    expect(me.name, '민경');
    expect(me.credits, 120);
    expect(me.owned, {TapeType.m1: 2, TapeType.m3: 0});
    expect(me.drawer.stored, 8, reason: '뜯은 테이프만 센다');
    expect(me.drawer.cap, 12);
    expect(me.drawer.unopenedCount, 2);
    expect(me.sentCount, 4);
    expect(me.friendCount, 6);
  });

  test('지갑 = /users/me 보유 + /wallet 광고', () async {
    final w = ok<Wallet>(await WalletRepositoryRemote(api).getWallet());
    expect(w.credits, 120);
    expect(w.ownedOf(TapeType.m1), 2);
    expect(w.adsLeft, 3);
  });

  test('친구 정렬: 즐겨찾기 → lastAt 최근 순, userId가 id로', () async {
    final repo = FriendRepositoryRemote(api);
    final list = ok<List<Friend>>(await repo.getFriends());
    expect(list.map((f) => f.name), ['지현', '엄마', '하늘', '민수', '은비', '박과장님']);
    expect(list.first.id, 'u-jihyun');
    final f = ok<Friend>(await repo.setStarred('u-minsu', true));
    expect(f.starred, isTrue);
  });

  test('별명: PATCH /friends/{id} — 목록·친구 화면·서랍 보낸 사람, 비우면 원래 이름', () async {
    final repo = FriendRepositoryRemote(api);
    final f = ok<Friend>(await repo.setNickname('u-mom', '  우리 엄마 '));
    expect(f.name, '우리 엄마');
    expect(f.nickname, '우리 엄마');
    expect(f.originalName, '엄마');
    expect(f.originalHint, '엄마');
    final list = ok<List<Friend>>(await repo.getFriends());
    expect(list.firstWhere((x) => x.id == 'u-mom').name, '우리 엄마');
    final tapes = ok<FriendTapes>(await repo.getFriendTapes('u-mom'));
    expect(tapes.friend.name, '우리 엄마');
    final shelf = ok<Shelf>(await ShelfRepositoryRemote(api).getShelf());
    final mine = [
      ...shelf.unsorted,
      for (final g in shelf.groups) ...g.items,
    ].where((t) => t.senderName == '엄마').toList();
    expect(mine, isNotEmpty);
    expect(mine.every((t) => t.from == '우리 엄마'), isTrue);

    final cleared = ok<Friend>(await repo.setNickname('u-mom', '   '));
    expect(cleared.nickname, isNull);
    expect(cleared.name, '엄마');
    expect(cleared.originalHint, isNull);
    expect(
      apiError(await repo.setNickname('u-mom', '열한글자가넘는별명이다')).code,
      'INVALID_NICKNAME',
    );
  });

  test('친구 화면: 뜯은 테이프만 + 칸 이름, 안 뜯은 수', () async {
    final repo = FriendRepositoryRemote(api);
    final mom = ok<FriendTapes>(await repo.getFriendTapes('u-mom'));
    expect(mom.items.map((x) => x.where), ['2026 생일', '엄마 목소리', '엄마 목소리']);
    expect(mom.unopenedCount, 0);
    final jihyun = ok<FriendTapes>(await repo.getFriendTapes('u-jihyun'));
    expect(jihyun.items, isEmpty);
    expect(jihyun.unopenedCount, 1);
    expect(
      apiError(await repo.getFriendTapes('u-nobody')).code,
      'FRIEND_NOT_FOUND',
    );
  });

  group('서랍', () {
    test('GET /shelf → unsorted + 칸 3개, 태그 코드 매핑', () async {
      final s = ok<Shelf>(await ShelfRepositoryRemote(api).getShelf());
      expect(s.unsorted.map((x) => x.from), ['지현', '하늘']);
      expect(s.unsorted.first.opened, isFalse);
      expect(s.unsorted.last.viaLink, isTrue);
      expect(s.unsorted.last.tag, TapeTag.thinking);
      expect(s.groups.map((g) => g.name), ['2026 생일', '승진 축하', '엄마 목소리']);
      expect(s.groups.first.items.first.groupId, 'g-1');
      expect(s.groups.first.items.first.duration, const Duration(seconds: 48));
    });

    test('옮기기 afterId: null이면 맨 앞, id면 그 뒤', () async {
      final repo = ShelfRepositoryRemote(api);
      var s = ok<Shelf>(await repo.getShelf());
      final last = s.groups[0].items.last.id;
      await repo.moveItem(last, groupId: 'g-1', afterId: null);
      s = ok<Shelf>(await repo.getShelf());
      expect(s.groups[0].items.first.id, last);

      await repo.moveItem(
        last,
        groupId: 'g-2',
        afterId: s.groups[1].items[0].id,
      );
      s = ok<Shelf>(await repo.getShelf());
      expect(s.groups[0].items, hasLength(3));
      expect(s.groups[1].items[1].id, last);
      expect(s.groups[1].items[1].groupId, 'g-2');
    });

    test('안 뜯은 소포는 칸으로 옮길 수 없다(409 TAPE_NOT_OPENED)', () async {
      final repo = ShelfRepositoryRemote(api);
      final s = ok<Shelf>(await repo.getShelf());
      final r = await repo.moveItem(
        s.unsorted.first.id,
        groupId: 'g-1',
        afterId: null,
      );
      expect(apiError(r).code, 'TAPE_NOT_OPENED');
      // 분류 안 함 안에서 순서 바꾸기는 된다
      final ok2 = await repo.moveItem(
        s.unsorted.first.id,
        groupId: null,
        afterId: s.unsorted.last.id,
      );
      expect(ok2, isA<Ok<TapeItem>>());
    });

    test('칸 지우기 → 테이프는 분류 안 함 맨 뒤, 뜯은 상태', () async {
      final repo = ShelfRepositoryRemote(api);
      await repo.deleteGroup('g-2');
      final s = ok<Shelf>(await repo.getShelf());
      expect(s.groups, hasLength(2));
      expect(s.unsorted.map((x) => x.from), ['지현', '하늘', '박과장님', '은비']);
      expect(s.unsorted.last.groupId, isNull);
    });

    test('칸 이름: 비우면 "새 칸", 12자 넘으면 오류', () async {
      final repo = ShelfRepositoryRemote(api);
      expect(ok<ShelfGroup>(await repo.createGroup('  ')).name, '새 칸');
      final r = await repo.renameGroup('g-1', '가나다라마바사아자차카타파');
      expect(apiError(r).code, 'INVALID_GROUP_NAME');
    });

    test('소포 뜯기 → 재생 주소(샘플), 안 뜯은 건 403', () async {
      final repo = ShelfRepositoryRemote(api);
      final id = ok<Shelf>(await repo.getShelf()).unsorted.first.id;
      expect(await repo.audioUrl(id), isA<Error<TapeAudio>>());
      final opened = ok<TapeItem>(await repo.open(id));
      expect(opened.opened, isTrue);
      final audio = ok<TapeAudio>(await repo.audioUrl(id));
      expect(audio.url, 'asset:///assets/audio/sample_34s.m4a');
      expect(audio.duration, const Duration(seconds: 34));
    });
  });

  group('녹음·보내기', () {
    Future<Recording> uploadReady(TapeType type) async {
      final repo = RecordingRepositoryRemote(
        api,
        LocalUploadService(store),
        pollInterval: Duration.zero,
      );
      final up = ok<Recording>(
        await repo.upload(
          filePath: '/tmp/a.m4a',
          type: type,
          duration: const Duration(seconds: 8),
        ),
      );
      expect(up.status, isNot(RecordingStatus.uploading));
      return ok<Recording>(await repo.convert(up.id));
    }

    test('업로드 → complete → 폴링 ready, 미리 듣기는 올린 파일', () async {
      final rec = await uploadReady(TapeType.s15);
      expect(rec.status, RecordingStatus.ready);
      expect(rec.previewUrl, '/tmp/a.m4a');
    });

    test('변환 실패 → retry도 실패 모드면 실패', () async {
      final failing = LocalApiClient(
        store,
        const LocalBehavior(
          failMode: FailMode.convertFail,
          latency: Duration.zero,
          convertFailDelay: Duration.zero,
        ),
      );
      final repo = RecordingRepositoryRemote(
        failing,
        LocalUploadService(store),
        pollInterval: Duration.zero,
      );
      final up = ok<Recording>(
        await repo.upload(
          filePath: '/tmp/a.m4a',
          type: TapeType.s15,
          duration: const Duration(seconds: 3),
        ),
      );
      expect(await repo.convert(up.id), isA<Error<Recording>>());
      expect(await repo.retry(up.id), isA<Error<Recording>>());
    });

    test('1분 보내기: 차감, lastAt 갱신, 같은 키는 한 번만, tag 없음', () async {
      final rec = await uploadReady(TapeType.m1);
      final repo = DeliveryRepositoryRemote(api);
      const to = Recipient.friend(friendId: 'u-haneul', name: '하늘');
      Future<SentTape> send() async => ok<SentTape>(
        await repo.send(recordingId: rec.id, to: to, idempotencyKey: 'k1'),
      );
      final a = await send();
      final b = await send();
      expect(a.id, b.id);
      expect(a.status, SentStatus.unopened);
      expect(store.owned[60], 1);
      expect(store.sent.first.tag, isNull, reason: '앱은 tag를 보내지 않는다');
      expect(
        store.friends.firstWhere((f) => f.name == '하늘').lastAt,
        store.now(),
      );
    });

    test('3분 0개면 NO_TAPE_LEFT, 새 친구는 링크', () async {
      final repo = DeliveryRepositoryRemote(api);
      final five = await uploadReady(TapeType.m3);
      final r = await repo.send(
        recordingId: five.id,
        to: const Recipient.friend(friendId: 'u-jihyun', name: '지현'),
        idempotencyKey: 'k2',
      );
      expect(apiError(r).code, 'NO_TAPE_LEFT');

      final one = await uploadReady(TapeType.s15);
      final link = ok<SentTape>(
        await repo.send(
          recordingId: one.id,
          to: const Recipient.newFriend(linkName: '유진'),
          idempotencyKey: 'k3',
        ),
      );
      expect(link.link, isTrue);
      expect(link.status, SentStatus.linkPending);
      expect(link.to, '유진');
      expect(link.shareUrl, isNotNull);
    });
  });

  test('FailMode.parse', () {
    expect(FailMode.parse('loadFail'), FailMode.loadFail);
    expect(FailMode.parse(''), FailMode.none);
  });

  group('상점·결제·선물·내역', () {
    test('구매 부족이면 402 INSUFFICIENT_CREDITS + need', () async {
      final repo = ShopRepositoryRemote(api);
      final r = await repo.purchase('tape180_5', idempotencyKey: 'p1');
      final e = apiError(r);
      expect(e.status, 402);
      expect(e.code, 'INSUFFICIENT_CREDITS');
      expect(e.extra['need'], 80);
    });

    test('같은 거래(transactionId)는 한 번만 충전', () async {
      final repo = ShopRepositoryRemote(api);
      const receipt = IapReceipt(
        store: 'app_store',
        productId: 'tapeletter.credits_100',
        transactionId: 'tx-1',
        verificationData: 'jws',
      );
      expect(ok<int>(await repo.verifyIap(receipt, idempotencyKey: 'a')), 220);
      expect(ok<int>(await repo.verifyIap(receipt, idempotencyKey: 'b')), 220);
      expect(store.credits, 220);
    });

    test('선물 금액은 10·30·50·100만', () async {
      final repo = WalletRepositoryRemote(api);
      final bad = await repo.gift(
        toUserId: 'u-mom',
        amount: 20,
        idempotencyKey: 'g1',
      );
      expect(apiError(bad).code, 'INVALID_GIFT_AMOUNT');
      expect(
        ok<int>(
          await repo.gift(toUserId: 'u-mom', amount: 50, idempotencyKey: 'g2'),
        ),
        70,
      );
    });

    test('크레딧 내역 커서', () async {
      for (var i = 0; i < 40; i++) {
        store.ledger = [...store.ledger, store.ledger.last];
      }
      final repo = WalletRepositoryRemote(api);
      final p1 = ok<LedgerPage>(await repo.getLedger());
      expect(p1.items, hasLength(30));
      expect(p1.nextCursor, '30');
      final p2 = ok<LedgerPage>(await repo.getLedger(cursor: p1.nextCursor));
      expect(p2.items, hasLength(15));
      expect(p2.nextCursor, isNull);
    });

    test('차단 목록·해제, 목록에서 빼기', () async {
      final repo = FriendRepositoryRemote(api);
      await repo.block('u-park');
      expect(
        ok<List<Friend>>(await repo.getFriends()).map((f) => f.name),
        isNot(contains('박과장님')),
      );
      expect(
        ok<List<BlockedUser>>(await repo.getBlocked()).single.name,
        '박과장님',
      );
      await repo.unblock('u-park');
      expect(ok<List<BlockedUser>>(await repo.getBlocked()), isEmpty);
      await repo.remove('u-park');
      expect(apiError(await repo.remove('u-park')).code, 'FRIEND_NOT_FOUND');
    });

    test('링크 다시 공유하기: 받은 뒤면 LINK_TAKEN', () async {
      final repo = DeliveryRepositoryRemote(api);
      expect(
        ok<Uri>(await repo.reshare('s-1')).toString(),
        'https://tapeletter.lab241.com/t/demo-yujin',
      );
      expect(apiError(await repo.reshare('s-2')).code, 'LINK_TAKEN');
    });
  });

  test('가짜 결제(store: local)는 POST /dev/credits {charge}로 충전', () async {
    final repo = ShopRepositoryRemote(api);
    const r = IapReceipt(
      store: IapReceipt.localStore,
      productId: 'tapeletter.credits_550',
      transactionId: 'local-1',
      verificationData: 'local',
    );
    expect(ok<int>(await repo.verifyIap(r, idempotencyKey: 'x')), 670);
    expect(store.ledger.first.reason, '크레딧 충전 · ₩5,500');
  });

  test('POST /dev/credits {ad}: 하루 3번, 넘으면 AD_LIMIT_REACHED', () async {
    for (var i = 0; i < 3; i++) {
      await api.devCredits(const DevCreditsRequest.ad());
    }
    expect(store.credits, 150);
    await expectLater(
      api.devCredits(const DevCreditsRequest.ad()),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'AD_LIMIT_REACHED'),
      ),
    );
  });

  test('GET /deliveries/sent 커서', () async {
    for (var i = 0; i < 30; i++) {
      store.sent = [...store.sent, store.sent.last];
    }
    final repo = DeliveryRepositoryRemote(api);
    final p1 = ok<SentPage>(await repo.getSent());
    expect(p1.items, hasLength(30));
    final p2 = ok<SentPage>(await repo.getSent(cursor: p1.nextCursor));
    expect(p2.items, hasLength(4));
    expect(p2.nextCursor, isNull);
  });
}
